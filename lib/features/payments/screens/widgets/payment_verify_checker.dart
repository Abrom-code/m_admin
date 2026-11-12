import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:m_admin/data/repositories/admin_payment_repository.dart';
import 'package:m_admin/data/services/receipt_extractor_service.dart';
import 'package:m_admin/data/services/scanned_receipt_storage.dart';
import 'package:m_admin/data/services/verify_et_service.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/models/verify_et_model.dart';
import 'package:m_admin/features/payments/screens/widgets/verify_et_settings_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

/// Content-first inline verification widget embedded on the payment approval screen.
/// Implements Verify.ET bank-level verification (https://verify.et/docs/api).
class PaymentVerifyChecker extends StatefulWidget {
  const PaymentVerifyChecker({
    super.key,
    required this.review,
    this.onApproveWithAmount,
    this.onTransactionExtracted,
  });

  final PaymentReview review;
  final void Function(num verifiedAmount)? onApproveWithAmount;
  final void Function(String extractedTransactionId)? onTransactionExtracted;

  /// Returns supported bank key or null otherwise.
  static String? resolveSupportedBank(String rawMethod) {
    final clean = rawMethod.toLowerCase().replaceAll('payment_', '').trim();
    if (clean.contains('telebirr')) return 'telebirr';
    if (clean.contains('cbe') || clean.contains('commercial_bank')) return 'cbe';
    if (clean.contains('abyssinia') || clean.contains('boa')) return 'boa';
    if (clean.contains('awash')) return 'awash';
    if (clean.contains('zemen')) return 'zemen';
    if (clean.contains('oromia') || clean.contains('coop') || clean.contains('cbo') || clean.contains('coopay')) {
      return 'oromia';
    }
    if (clean.contains('dashen')) return 'dashen';
    if (clean.contains('cbebirr') || clean.contains('cbe_birr')) return 'cbebirr';
    if (clean.contains('mpesa') || clean.contains('m-pesa')) return 'mpesa';
    return null;
  }

  @override
  State<PaymentVerifyChecker> createState() => _PaymentVerifyCheckerState();
}

class _PaymentVerifyCheckerState extends State<PaymentVerifyChecker> {
  final _service = VerifyEtService.instance;
  final _scannedStorage = ScannedReceiptStorage.instance;

  late final TextEditingController _refCtrl;
  late final TextEditingController _suffixCtrl;
  late final TextEditingController _phoneCtrl;

  bool _isLoading = false;
  bool _isExtracting = false;
  String? _pollStatus;
  ReceiptExtractionResult? _extractedInfo;
  LinksEtResult? _result;
  String? _errorMessage;
  ScannedReceiptRecord? _previousRecord;

  @override
  void initState() {
    super.initState();
    final initialText = widget.review.verificationUrl.trim();
    final bank = PaymentVerifyChecker.resolveSupportedBank(widget.review.paymentMethod);
    String cleanInitial = initialText;
    if (bank == 'telebirr' && initialText.isNotEmpty) {
      final sanitized = VerifyEtService.sanitizeTelebirrReference(initialText);
      if (sanitized.isNotEmpty && !sanitized.startsWith('http')) {
        cleanInitial = sanitized;
      }
    }
    _refCtrl = TextEditingController(text: cleanInitial);
    _refCtrl.addListener(_onRefChanged);

    final initialSuffix = VerifyEtService.resolveDefaultAccountSuffix(bank ?? '');
    _suffixCtrl = TextEditingController(text: initialSuffix);
    _phoneCtrl = TextEditingController();

    _checkPreviousRecord();

    // Auto-detect transaction ID or link from receipt image if input is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoExtractIfApplicable();
    });
  }

  void _onRefChanged() {
    _checkPreviousRecord();
    final text = _refCtrl.text.trim();
    if (text.isNotEmpty) {
      final bank = PaymentVerifyChecker.resolveSupportedBank(widget.review.paymentMethod);
      var clean = text;
      if (bank == 'telebirr' && text.contains('transactioninfo.ethiotelecom.et')) {
        final sanitized = VerifyEtService.sanitizeTelebirrReference(text);
        if (sanitized.isNotEmpty && !sanitized.startsWith('http')) {
          clean = sanitized;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_refCtrl.text != clean) {
              _refCtrl.value = TextEditingValue(
                text: clean,
                selection: TextSelection.collapsed(offset: clean.length),
              );
            }
          });
        }
      }
      widget.onTransactionExtracted?.call(clean);
    }
    if (mounted) setState(() {});
  }

  void _checkPreviousRecord() {
    final text = _refCtrl.text.trim();
    if (text.isEmpty) {
      _previousRecord = null;
    } else {
      _previousRecord = _scannedStorage.findRecord(text);
    }
  }

  @override
  void didUpdateWidget(covariant PaymentVerifyChecker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.id != widget.review.id) {
      final raw = widget.review.verificationUrl.trim();
      final bank = PaymentVerifyChecker.resolveSupportedBank(widget.review.paymentMethod);
      String cleanText = raw;
      if (bank == 'telebirr' && raw.isNotEmpty) {
        final sanitized = VerifyEtService.sanitizeTelebirrReference(raw);
        if (sanitized.isNotEmpty && !sanitized.startsWith('http')) {
          cleanText = sanitized;
        }
      }
      _refCtrl.text = cleanText;
      _suffixCtrl.text = VerifyEtService.resolveDefaultAccountSuffix(bank ?? '');
      _phoneCtrl.clear();
      _result = null;
      _errorMessage = null;
      _pollStatus = null;
      _extractedInfo = null;
      _checkPreviousRecord();
      _autoExtractIfApplicable();
    }
  }

  Future<void> _extractFromReceipt({bool manual = false}) async {
    final bank = PaymentVerifyChecker.resolveSupportedBank(widget.review.paymentMethod);
    if (!widget.review.hasScreenshot) {
      if (manual) {
        SnackbarHelper.warning('No Image', 'This receipt does not have an uploaded screenshot.');
      }
      return;
    }

    setState(() {
      _isExtracting = true;
    });

    try {
      final repo = AdminPaymentRepository();
      final imageUrl = await repo.signedReceiptUrl(
        widget.review.receiptPath,
        fallbackUrl: widget.review.receiptUrl,
      );

      if (imageUrl.isEmpty) {
        if (manual) {
          SnackbarHelper.warning('Image Unavailable', 'Could not retrieve receipt image URL.');
        }
        return;
      }

      final cacheKey = widget.review.id.isNotEmpty
          ? widget.review.id
          : (widget.review.receiptPath.isNotEmpty
              ? widget.review.receiptPath
              : imageUrl.split('?').first);

      final res = await ReceiptExtractorService.instance.extractFromUrl(
        imageUrl,
        bankHint: bank,
        cacheKey: cacheKey,
      );

      if (mounted) {
        setState(() {
          _isExtracting = false;
          _extractedInfo = res;
          if (res != null && res.hasTransactionId) {
            final isTelebirr = (bank == 'telebirr') ||
                widget.review.paymentMethod.toLowerCase().contains('telebirr') ||
                (res.bank?.toLowerCase() == 'telebirr');

            String targetRef;
            if (isTelebirr) {
              // For Telebirr, ALWAYS display the clean 10-character reference number, NOT a URL
              final raw = res.transactionId ?? res.receiptUrl ?? '';
              final cleanRef = VerifyEtService.sanitizeTelebirrReference(raw);
              targetRef = cleanRef.isNotEmpty && !cleanRef.startsWith('http') ? cleanRef : raw;
            } else {
              targetRef = res.receiptUrl ?? res.transactionId!;
            }

            _refCtrl.text = targetRef;
            if (bank == 'boa' && _suffixCtrl.text.isEmpty) {
              if (res.receiverAccount != null && res.receiverAccount!.length >= 5) {
                _suffixCtrl.text = res.receiverAccount!.substring(res.receiverAccount!.length - 5);
              } else {
                _suffixCtrl.text = VerifyEtService.resolveDefaultAccountSuffix('boa');
              }
            } else if (bank == 'cbe' && _suffixCtrl.text.isEmpty) {
              if (targetRef.contains('-')) {
                _suffixCtrl.text = targetRef.split('-').last;
              } else {
                _suffixCtrl.text = VerifyEtService.resolveDefaultAccountSuffix('cbe');
              }
            }

            _checkPreviousRecord();
            ReceiptExtractorService.instance.setCache(widget.review.id, res);
            widget.onTransactionExtracted?.call(targetRef);
            if (manual) {
              final isLink = targetRef.startsWith('http');
              SnackbarHelper.success(
                isLink ? 'Receipt Link Extracted' : 'Reference Number Extracted',
                'Found $targetRef from receipt image.',
              );
            }
          } else if (manual) {
            SnackbarHelper.info(
              'Notice',
              'Could not detect transaction ID automatically. You can enter the URL or ID manually.',
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isExtracting = false;
        });
        if (manual) {
          SnackbarHelper.error('Scan Error', 'Failed to scan receipt image: $e');
        }
      }
    }
  }

  void _autoExtractIfApplicable() {
    if (_refCtrl.text.trim().isEmpty && widget.review.hasScreenshot) {
      _extractFromReceipt(manual: false);
    }
  }

  @override
  void dispose() {
    _refCtrl.removeListener(_onRefChanged);
    _refCtrl.dispose();
    _suffixCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    final reqId = _result?.requestId;
    if (reqId == null || reqId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pollStatus = 'Checking verification status on verify.et...';
    });

    try {
      final res = await _service.getVerificationStatus(reqId);
      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
          _pollStatus = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _pollStatus = null;
        });
      }
    }
  }

  Future<void> _check() async {
    final bank = PaymentVerifyChecker.resolveSupportedBank(widget.review.paymentMethod);
    if (bank == null) return;

    if (!_service.hasApiKey) {
      VerifyEtSettingsDialog.show(context);
      SnackbarHelper.warning(
        'Verify.ET Key Required',
        'Please enter your Verify.ET API key (VERIFY_BANK_ET_...) to perform automated bank verification.',
      );
      return;
    }

    final inputVal = _refCtrl.text.trim();
    if (inputVal.isEmpty) {
      setState(() => _errorMessage = 'Please enter a receipt URL or Telebirr reference.');
      return;
    }

    final resolved = LinksEtService.resolveReceiptInput(
      input: inputVal,
      bank: bank,
    );

    if (resolved.primaryTarget.isEmpty) {
      setState(() => _errorMessage = 'Please enter a valid reference code, receipt link, or confirmation SMS.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
      _pollStatus = resolved.isAutoConstructed && resolved.note != null
          ? resolved.note
          : null;
    });

    final effSuffix = _suffixCtrl.text.trim().isNotEmpty
        ? _suffixCtrl.text.trim()
        : resolved.accountSuffix;
    final effPhone = _phoneCtrl.text.trim().isNotEmpty
        ? _phoneCtrl.text.trim()
        : resolved.phone;

    try {
      final res = await _service.verifyReceipt(
        url: resolved.url,
        reference: resolved.reference,
        bankHint: resolved.resolvedBank,
        accountSuffix: effSuffix,
        phone: effPhone,
        settlementAccount: VerifyEtService.resolveDefaultSettlementAccount(resolved.resolvedBank),
        onPollTick: (attempt, max) {
          if (mounted) {
            setState(() {
              _pollStatus = 'Checking upstream bank confirmation ($attempt/$max)...';
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
          _pollStatus = null;
        });
        _checkPreviousRecord();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
          _pollStatus = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bank = PaymentVerifyChecker.resolveSupportedBank(widget.review.paymentMethod);
    if (bank == null) return const SizedBox.shrink();

    final dark = AppHelperFunctions.isDark(context);

    String bankName;
    String bankIcon;
    String refLabel;
    String refHint;
    String methodExplanation;

    switch (bank) {
      case 'telebirr':
        bankName = 'Telebirr';
        bankIcon = '📱';
        refLabel = 'Telebirr Reference or Receipt URL';
        refHint = 'e.g. DET8FJGUJ4 or https://transactioninfo.ethiotelecom.et/...';
        methodExplanation = 'Supported: Reference number (e.g. DET8...) or official receipt link.';
        break;
      case 'cbe':
        bankName = 'CBE';
        bankIcon = '🏦';
        refLabel = 'CBE Reference, Receipt Link, or SMS';
        refHint = 'e.g. FT... or https://mbreciept.cbe.com.et/...';
        methodExplanation = 'Supported: SMS receipt link, dashed token (FT...-12345678), branch slip (FT...), or raw SMS.';
        break;
      case 'boa':
      case 'abyssinia':
        bankName = 'Abyssinia';
        bankIcon = '🦁';
        refLabel = 'Abyssinia Reference (FT...) or Slip Link';
        refHint = 'e.g. FT... or https://cs.bankofabyssinia.com/slip/?trx=...';
        methodExplanation = 'Supported: Reference token (FT...), digital slip link, or raw confirmation SMS.';
        break;
      case 'awash':
        bankName = 'Awash Bank';
        bankIcon = '🌊';
        refLabel = 'AwashPay Receipt URL';
        refHint = 'e.g. https://awashpay.awashbank.com:8225/...';
        methodExplanation = 'Supported: AwashPay web receipt link.';
        break;
      case 'zemen':
        bankName = 'Zemen Bank';
        bankIcon = '🏛️';
        refLabel = 'Zemen Bank Receipt URL';
        refHint = 'e.g. https://share.zemenbank.com/rt/.../pdf';
        methodExplanation = 'Supported: Zemen share receipt PDF URL.';
        break;
      case 'dashen':
        bankName = 'Dashen';
        bankIcon = '🏛️';
        refLabel = 'Dashen Receipt URL';
        refHint = 'e.g. https://... or Dashen web receipt URL';
        methodExplanation = 'Supported: Dashen Super App or PDF receipt link.';
        break;
      case 'cbebirr':
        bankName = 'CBE Birr';
        bankIcon = '💳';
        refLabel = 'CBE Birr Receipt URL';
        refHint = 'Official CBE Birr receipt URL';
        methodExplanation = 'Supported: CBE Birr web receipt link.';
        break;
      case 'mpesa':
        bankName = 'M-Pesa';
        bankIcon = '📲';
        refLabel = 'M-Pesa Receipt URL';
        refHint = 'Official M-Pesa receipt link';
        methodExplanation = 'Supported: M-Pesa digital receipt URL.';
        break;
      default:
        bankName = bank.toUpperCase();
        bankIcon = '💳';
        refLabel = '$bankName Receipt URL';
        refHint = 'Official web receipt link';
        methodExplanation = 'Supported: Full official receipt URL.';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSizes.spaceBtwItems),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkContainer : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;

              return Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Iconsax.shield_tick_copy, color: Color(0xFF6366F1), size: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            '$bankIcon Verify with $bankName',
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                          ),
                          child: const Text(
                            'verify.et',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: AppColors.success),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Manual Scan Button
                  if (widget.review.hasScreenshot) ...[
                    InkWell(
                      onTap: _isExtracting ? null : () => _extractFromReceipt(manual: true),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isNarrow ? 6 : 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isExtracting)
                              const SizedBox(
                                width: 11,
                                height: 11,
                                child: CircularProgressIndicator(strokeWidth: 1.8, color: Color(0xFF6366F1)),
                              )
                            else
                              const Icon(Iconsax.scan_barcode_copy, size: 12, color: Color(0xFF6366F1)),
                            const SizedBox(width: 4),
                            Text(
                              _isExtracting
                                  ? (isNarrow ? '...' : 'Scanning...')
                                  : (isNarrow ? 'Scan' : 'Scan Image'),
                              style: const TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6366F1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  if (_result != null)
                    InkWell(
                      onTap: () => setState(() => _result = null),
                      child: const Padding(
                        padding: EdgeInsets.all(2),
                        child: Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 10),

          // ── DOUBLE-SCAN / PREVIOUS SCAN ALERT BANNER ───────────────────────
          if (_previousRecord != null) () {
            final isPrevApproved = _previousRecord!.isApproved;
            final bannerColor = isPrevApproved ? AppColors.error : AppColors.warning;

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bannerColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: bannerColor.withValues(alpha: 0.5), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(isPrevApproved ? Icons.gpp_bad_rounded : Icons.warning_amber_rounded, size: 16, color: bannerColor),
                      const SizedBox(width: 6),
                      Text(
                        isPrevApproved ? 'ALREADY APPROVED BEFORE' : 'ALREADY SCANNED BEFORE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: bannerColor,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: bannerColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Scanned ${_previousRecord!.scanCount}x',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: bannerColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        'Status: ',
                        style: TextStyle(fontSize: 11, color: dark ? Colors.white70 : Colors.black87),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: (isPrevApproved ? AppColors.error : AppColors.success).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          _previousRecord!.status.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPrevApproved ? AppColors.error : AppColors.success),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isPrevApproved
                              ? 'Approved: ${_previousRecord!.formattedApprovedDate ?? _previousRecord!.formattedScannedDate}'
                              : 'Date: ${_previousRecord!.formattedScannedDate}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (_previousRecord!.userEmail != null && _previousRecord!.userEmail!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'User: ${_previousRecord!.userEmail}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (_previousRecord!.amount != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Amount: ${_previousRecord!.amount} ${_previousRecord!.currency} (${_previousRecord!.method.toUpperCase()})',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            );
          }(),

          // Supported Verify Way Guide Note
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 13, color: Color(0xFF6366F1)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    methodExplanation,
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
          ),

          // Input Area (URL or Reference)
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _refCtrl,
                  style: const TextStyle(fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: refLabel,
                    hintText: refHint,
                    prefixIcon: const Icon(Iconsax.receipt_2_copy, size: 16),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_refCtrl.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear, size: 16),
                            tooltip: 'Clear',
                            onPressed: () {
                              _refCtrl.clear();
                              setState(() {
                                _result = null;
                                _errorMessage = null;
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.content_paste_rounded, size: 16),
                          tooltip: 'Paste from clipboard',
                          onPressed: () async {
                            final data = await Clipboard.getData('text/plain');
                            if (data?.text != null && data!.text!.trim().isNotEmpty) {
                              _refCtrl.text = data.text!.trim();
                              _checkPreviousRecord();
                              widget.onTransactionExtracted?.call(_refCtrl.text.trim());
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 38,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _check,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Iconsax.tick_circle_copy, size: 15),
                  label: Text(
                    _isLoading ? 'Checking...' : 'Check',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          // Contextual account suffix / phone inputs for bank verification
          if (bank == 'boa' || bank == 'cbe' || bank == 'cbebirr') ...[
            const SizedBox(height: 8),
            Row(
              children: [
                if (bank == 'boa' || bank == 'cbe')
                  Expanded(
                    child: TextField(
                      controller: _suffixCtrl,
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: bank == 'boa'
                            ? 'Account Suffix (5 digits for BOA) *'
                            : 'Account Suffix (8 digits for CBE FT)',
                        hintText: bank == 'boa' ? '93089' : '435011237',
                        prefixIcon: const Icon(Iconsax.card_copy, size: 14),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                if (bank == 'cbebirr')
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      style: const TextStyle(fontSize: 12),
                      keyboardType: TextInputType.phone,
                      decoration: InputDecoration(
                        labelText: 'Payer Phone *',
                        hintText: '0911223344',
                        prefixIcon: const Icon(Iconsax.call_copy, size: 14),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
              ],
            ),
          ],

          // Quick Option Switcher if receipt link was extracted
          if (_extractedInfo != null && _extractedInfo!.receiptUrl != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 13, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _extractedInfo!.receiptUrl!,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace', color: Color(0xFF6366F1)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () {
                      _refCtrl.text = _extractedInfo!.receiptUrl!;
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('Use Link', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Scanning / Polling status
          if (_isExtracting) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                children: [
                  SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scanning receipt screenshot for transaction link / reference...',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6366F1), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (_pollStatus != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 1.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _pollStatus!,
                      style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error Message Box
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, size: 15, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(fontSize: 11, color: AppColors.error),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Inline Verification Result Card
          if (_result != null) ...[
            const SizedBox(height: 12),
            _buildResultView(context, dark, _result!),
          ],
        ],
      ),
    );
  }

  Widget _buildResultView(BuildContext context, bool dark, LinksEtResult res) {
    final isOk = res.verified;
    final statusColor = isOk ? AppColors.success : (res.isPending ? AppColors.warning : AppColors.error);
    final dateStr = res.receipt?.paymentDate ?? _formatResultDate(res.timestamp);
    final refVal = res.referenceNumber ?? '';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: dark ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Result Header
          Row(
            children: [
              Icon(
                isOk
                    ? Icons.check_circle_rounded
                    : (res.isPending ? Icons.hourglass_top_rounded : Icons.cancel_rounded),
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isOk
                      ? 'CONFIRMED BY ${res.providerKey.toUpperCase()}'
                      : (res.isPending
                          ? 'QUEUED UPSTREAM'
                          : (res.isParsedButInvalid ? 'RECEIPT NOT FOUND AT BANK' : 'UNVERIFIED')),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              if (res.amount > 0)
                Text(
                  '${res.amount.toStringAsFixed(res.amount.truncateToDouble() == res.amount ? 0 : 2)} ${res.currency}',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: statusColor),
                ),
            ],
          ),
          const Divider(height: 16),

          // Failure Diagnosis Banner (for parsed but failed, missing receipt, etc.)
          if (!isOk && !res.isPending) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.error.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 14, color: AppColors.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          res.isParsedButInvalid
                              ? 'Receipt Not Found on Bank Portal'
                              : 'Verification Not Confirmed',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.error),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    res.userFriendlyErrorMessage,
                    style: TextStyle(fontSize: 10.5, color: dark ? Colors.white70 : Colors.black87),
                  ),
                  if ((res.upstreamInspectionUrl ?? res.telebirrPortalUrl) != null) ...[
                    () {
                      final inspectionUrl = (res.upstreamInspectionUrl ?? res.telebirrPortalUrl)!;
                      final provKey = res.providerKey.toLowerCase();
                      final portalName = provKey.contains('telebirr')
                          ? 'Ethio Telecom Portal'
                          : (provKey.contains('cbe')
                              ? 'CBE Portal'
                              : (provKey.contains('boa') || provKey.contains('abyssinia')
                                  ? 'Bank of Abyssinia Portal'
                                  : '${res.providerKey.toUpperCase()} Portal'));

                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            InkWell(
                              onTap: () async {
                                final uri = Uri.tryParse(inspectionUrl);
                                if (uri != null) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF6366F1).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.open_in_new_rounded, size: 11, color: Color(0xFF6366F1)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Open in $portalName',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _check,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.refresh, size: 11, color: AppColors.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      'Retry',
                                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }(),
                  ],
                ],
              ),
            ),
          ],

          // If previously scanned, show reminder in result card too
          if (res.wasScannedBefore) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Notice: Verified successfully. Note that this transaction was already in database (previous scan: ${res.previousRecord?.formattedPreviousDate ?? res.previousRecord?.formattedScannedDate}, status: ${res.previousRecord?.previousStatus ?? res.previousRecord?.status}).',
                style: const TextStyle(fontSize: 10.5, color: AppColors.warning, fontWeight: FontWeight.w600),
              ),
            ),
          ],

          if (res.isPending && res.requestId != null && res.requestId!.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 14, color: AppColors.warning),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Upstream verification is in progress. Tap Check Status to refresh.',
                      style: TextStyle(fontSize: 10.5, color: AppColors.warning, fontWeight: FontWeight.w600),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: _isLoading ? null : _refreshStatus,
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    ),
                    child: const Text('Check Status', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ],

          // Details
          if (dateStr != null && dateStr.isNotEmpty)
            _buildInfoRow('Date', dateStr, icon: Iconsax.calendar_1_copy),
          if (res.senderName != null && res.senderName!.isNotEmpty)
            _buildInfoRow('Sender', res.senderName!, icon: Iconsax.user_copy),
          if (res.receiverName != null && res.receiverName!.isNotEmpty)
            _buildInfoRow('Receiver', res.receiverName!, icon: Iconsax.user_tick_copy),
          if (res.receiverAccount != null && res.receiverAccount!.isNotEmpty)
            _buildInfoRow('Receiver Acc', res.receiverAccount!, icon: Iconsax.card_copy),
          if (refVal.isNotEmpty)
            _buildInfoRow('Reference #', refVal, canCopy: true, icon: Iconsax.receipt_2_copy),
          if (res.receipt?.source != null)
            _buildInfoRow('Receipt Source', res.receipt!.source, icon: Iconsax.document_copy),

          // Quick Approve Action
          if (isOk && widget.onApproveWithAmount != null && widget.review.isPending) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: ElevatedButton.icon(
                onPressed: () => widget.onApproveWithAmount!(res.amount),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                ),
                icon: const Icon(Icons.check_rounded, size: 14),
                label: Text(
                  'Approve with Verified ${res.amount.toStringAsFixed(0)} ETB',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String? _formatResultDate(DateTime? dt) {
    if (dt == null) return null;
    final eat = EthiopianTimeHelper.toEastAfricaTime(dt);
    return '${DateFormat('d MMM yyyy, h:mm a').format(eat)} EAT';
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    bool canCopy = false,
    IconData? icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: AppColors.textSecondary),
            const SizedBox(width: 5),
          ],
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                ),
                if (canCopy) ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      SnackbarHelper.info('Copied', '$value copied to clipboard');
                    },
                    child: const Icon(Icons.copy, size: 11, color: AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
