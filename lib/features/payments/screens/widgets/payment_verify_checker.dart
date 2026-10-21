import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:m_admin/data/repositories/admin_payment_repository.dart';
import 'package:m_admin/data/services/receipt_extractor_service.dart';
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
/// Exclusively activates for CBE, Telebirr, or Bank of Abyssinia receipts.
class PaymentVerifyChecker extends StatefulWidget {
  const PaymentVerifyChecker({
    super.key,
    required this.review,
    this.onApproveWithAmount,
  });

  final PaymentReview review;
  final void Function(num verifiedAmount)? onApproveWithAmount;

  /// Returns 'cbe', 'telebirr', or 'boa' if supported, or null otherwise.
  static String? resolveSupportedBank(String rawMethod) {
    final clean = rawMethod.toLowerCase().replaceAll('payment_', '').trim();
    if (clean.contains('telebirr')) return 'telebirr';
    if (clean.contains('cbe') || clean.contains('commercial_bank')) return 'cbe';
    if (clean.contains('abyssinia') || clean.contains('boa')) return 'boa';
    return null;
  }

  @override
  State<PaymentVerifyChecker> createState() => _PaymentVerifyCheckerState();
}

class _PaymentVerifyCheckerState extends State<PaymentVerifyChecker> {
  final _service = VerifyEtService.instance;
  late final TextEditingController _refCtrl;
  late final TextEditingController _suffixCtrl;

  bool _isLoading = false;
  bool _isExtracting = false;
  ReceiptExtractionResult? _extractedInfo;
  VerifyEtResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _refCtrl = TextEditingController(text: widget.review.verificationUrl.trim());
    _suffixCtrl = TextEditingController();

    // Auto-detect transaction ID from receipt image if input is empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoExtractIfApplicable();
    });
  }

  @override
  void didUpdateWidget(covariant PaymentVerifyChecker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.id != widget.review.id) {
      _refCtrl.text = widget.review.verificationUrl.trim();
      _suffixCtrl.clear();
      _result = null;
      _errorMessage = null;
      _extractedInfo = null;
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

      final res = await ReceiptExtractorService.instance.extractFromUrl(
        imageUrl,
        bankHint: bank,
      );

      if (mounted) {
        setState(() {
          _isExtracting = false;
          _extractedInfo = res;
          if (res != null && res.hasTransactionId) {
            final targetRef = res.transactionId ?? res.receiptUrl!;
            _refCtrl.text = targetRef;
            if (manual) {
              final isLink = targetRef.startsWith('http');
              SnackbarHelper.success(
                isLink ? 'Receipt Link Extracted' : 'Transaction ID Extracted',
                'Found $targetRef from receipt image.',
              );
            }
          } else if (manual) {
            SnackbarHelper.info(
              'Notice',
              'Could not detect transaction ID automatically. You can enter it manually.',
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
    _refCtrl.dispose();
    _suffixCtrl.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    final bank = PaymentVerifyChecker.resolveSupportedBank(widget.review.paymentMethod);
    if (bank == null) return;

    if (!_service.hasApiKey) {
      VerifyEtSettingsDialog.show(context);
      SnackbarHelper.warning(
        'Verify.ET Key Required',
        'Please enter your Verify.ET API key to perform automated verification.',
      );
      return;
    }

    final ref = _refCtrl.text.trim();
    if (ref.isEmpty) {
      setState(() => _errorMessage = 'Please enter a transaction reference or receipt ID.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final res = await _service.verifyTransaction(
        bank: bank,
        reference: ref,
        accountSuffix: bank == 'boa' && _suffixCtrl.text.trim().isNotEmpty
            ? _suffixCtrl.text.trim()
            : null,
      );

      if (mounted) {
        setState(() {
          _result = res;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
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

    switch (bank) {
      case 'cbe':
        bankName = 'CBE';
        bankIcon = '🏦';
        refLabel = 'CBE Transaction ID / Receipt Link';
        refHint = 'e.g. FT26... or https://mreciept.cbe.com.et/...';
        break;
      case 'telebirr':
        bankName = 'Telebirr';
        bankIcon = '📱';
        refLabel = 'Telebirr Transaction Number';
        refHint = 'e.g. DET8FJGUJ4';
        break;
      case 'boa':
      default:
        bankName = 'Abyssinia';
        bankIcon = '🦁';
        refLabel = 'Abyssinia Reference';
        refHint = 'e.g. FT26...';
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
          // Header Bar (Responsive & Protected from Overflow)
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
                            'LIVE',
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
          const SizedBox(height: 12),

          // Responsive Input Area (No Overflow)
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 420;

              final inputField = TextField(
                controller: _refCtrl,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: refLabel,
                  hintText: refHint,
                  prefixIcon: const Icon(Iconsax.receipt_2_copy, size: 16),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              );

              final suffixField = bank == 'boa'
                  ? TextField(
                      controller: _suffixCtrl,
                      keyboardType: TextInputType.number,
                      maxLength: 5,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        labelText: 'Suffix',
                        hintText: '07441',
                        counterText: '',
                        prefixIcon: const Icon(Iconsax.hashtag_copy, size: 14),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        isDense: true,
                      ),
                    )
                  : null;

              final checkButton = SizedBox(
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
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    inputField,
                    if (suffixField != null) ...[
                      const SizedBox(height: 8),
                      suffixField,
                    ],
                    const SizedBox(height: 8),
                    checkButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(flex: 5, child: inputField),
                  if (suffixField != null) ...[
                    const SizedBox(width: 6),
                    Expanded(flex: 2, child: suffixField),
                  ],
                  const SizedBox(width: 8),
                  checkButton,
                ],
              );
            },
          ),

          // Reference Option Switcher (When a CBE Receipt Link is available)
          if (_extractedInfo != null && _extractedInfo!.receiptUrl != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 12, color: Color(0xFF6366F1)),
                      SizedBox(width: 4),
                      Text(
                        'Quick Option:',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: () => setState(() => _refCtrl.text = _extractedInfo!.receiptUrl!),
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _refCtrl.text == _extractedInfo!.receiptUrl
                            ? const Color(0xFF6366F1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: _refCtrl.text == _extractedInfo!.receiptUrl
                              ? const Color(0xFF6366F1)
                              : AppColors.borderPrimary,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.link_rounded,
                            size: 11,
                            color: _refCtrl.text == _extractedInfo!.receiptUrl
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            'Use Full Link',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: _refCtrl.text == _extractedInfo!.receiptUrl
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (_extractedInfo!.receiptToken != null)
                    InkWell(
                      onTap: () => setState(() => _refCtrl.text = _extractedInfo!.receiptToken!),
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _refCtrl.text == _extractedInfo!.receiptToken
                              ? const Color(0xFF6366F1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _refCtrl.text == _extractedInfo!.receiptToken
                                ? const Color(0xFF6366F1)
                                : AppColors.borderPrimary,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tag_rounded,
                              size: 11,
                              color: _refCtrl.text == _extractedInfo!.receiptToken
                                  ? Colors.white
                                  : AppColors.textSecondary,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              'Use Token (${_extractedInfo!.receiptToken!.length > 10 ? '${_extractedInfo!.receiptToken!.substring(0, 8)}...' : _extractedInfo!.receiptToken})',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: _refCtrl.text == _extractedInfo!.receiptToken
                                    ? Colors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Scanning in-progress pill
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
                  SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Scanning receipt image for Transaction ID...',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6366F1),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Extracted info preview (Shows detected ID, Link, Date & Parties before checking)
          if (_extractedInfo != null && _result == null && !_isExtracting) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.25)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Iconsax.scan_barcode_copy, size: 14, color: Color(0xFF6366F1)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _extractedInfo!.receiptUrl != null
                              ? 'Detected Receipt Reference / Link:'
                              : 'Extracted ID: ${_extractedInfo!.transactionId ?? '—'}',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6366F1),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_extractedInfo!.receiptUrl != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            _extractedInfo!.receiptUrl!,
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.tryParse(_extractedInfo!.receiptUrl!);
                                  if (uri != null) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.open_in_new_rounded, size: 11, color: Color(0xFF6366F1)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Open Official CBE Receipt',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: _extractedInfo!.receiptUrl!));
                                  SnackbarHelper.info('Copied', 'Receipt link copied to clipboard');
                                },
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.copy_rounded, size: 11, color: Color(0xFF6366F1)),
                                    SizedBox(width: 3),
                                    Text(
                                      'Copy Link',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: Color(0xFF6366F1),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_extractedInfo!.amount != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Amount: ${_extractedInfo!.amount!.toStringAsFixed(2)} ${_extractedInfo!.currency}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (_extractedInfo!.senderName != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Sender: ${_extractedInfo!.senderName!}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (_extractedInfo!.receiverAccount != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Receiver: ${_extractedInfo!.receiverAccount!}${_extractedInfo!.receiverName != null ? ' (${_extractedInfo!.receiverName!})' : ''}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (_extractedInfo!.date != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Receipt Date: ${_extractedInfo!.date!}',
                            style: const TextStyle(
                              fontSize: 10.5,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
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

  Widget _buildResultView(BuildContext context, bool dark, VerifyEtResult res) {
    final isOk = res.verified;
    final statusColor = isOk ? AppColors.success : (res.status == 'pending' ? AppColors.warning : AppColors.error);
    final dateStr = _formatResultDate(res.timestamp) ?? _extractedInfo?.date;
    final refVal = (res.referenceNumber != null && res.referenceNumber!.isNotEmpty)
        ? res.referenceNumber!
        : (res.receiptNumber ?? '');

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
                isOk ? Icons.check_circle_rounded : Icons.cancel_rounded,
                size: 16,
                color: statusColor,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isOk ? 'TRANSACTION CONFIRMED' : 'UNVERIFIED (${res.status.toUpperCase()})',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
              if (res.amount > 0)
                Text(
                  '${res.amount.toStringAsFixed(res.amount.truncateToDouble() == res.amount ? 0 : 2)} ${res.currency}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
            ],
          ),
          const Divider(height: 16),

          // Details List with strict overflow guards
          // 1. Transaction Date (From verified timestamp or receipt image)
          if (dateStr != null && dateStr.isNotEmpty)
            _buildInfoRow('Date', dateStr, icon: Iconsax.calendar_1_copy),

          // 2. Sender Name
          if (res.senderName != null && res.senderName!.isNotEmpty)
            _buildInfoRow('Sender', res.senderName!, icon: Iconsax.user_copy),

          // 3. Receiver Account
          if (res.receiverAccount != null && res.receiverAccount!.isNotEmpty)
            _buildInfoRow('Receiver Acc', res.receiverAccount!, icon: Iconsax.card_copy),

          // 4. Ref #
          if (refVal.isNotEmpty)
            _buildInfoRow('Ref #', refVal, canCopy: true, icon: Iconsax.receipt_2_copy),

          // Settlement Badge
          if (res.settlementAccountMatch != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  res.settlementAccountMatch!.matched ? Icons.verified_user : Icons.gpp_bad,
                  size: 13,
                  color: res.settlementAccountMatch!.matched ? AppColors.success : AppColors.error,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    res.settlementAccountMatch!.matched
                        ? 'Settlement Matched (Funds landed in your account)'
                        : 'Settlement Mismatch: ${res.settlementAccountMatch!.reasonLabel}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: res.settlementAccountMatch!.matched ? AppColors.success : AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],

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
    return '${DateFormat('d MMM yyyy, HH:mm').format(eat)} EAT';
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
