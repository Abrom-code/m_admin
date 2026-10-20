import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/data/services/verify_et_service.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/models/verify_et_model.dart';
import 'package:m_admin/features/payments/screens/widgets/verify_et_settings_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
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
  VerifyEtResult? _result;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _refCtrl = TextEditingController(text: widget.review.verificationUrl.trim());
    _suffixCtrl = TextEditingController();
  }

  @override
  void didUpdateWidget(covariant PaymentVerifyChecker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.id != widget.review.id) {
      _refCtrl.text = widget.review.verificationUrl.trim();
      _suffixCtrl.clear();
      _result = null;
      _errorMessage = null;
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
        refLabel = 'CBE Receipt ID / Reference';
        refHint = 'e.g. fHCxyExampleRcpt1';
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
          // Header Bar
          Row(
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
                    Text(
                      '$bankIcon Verify with $bankName',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
              if (_result != null)
                InkWell(
                  onTap: () => setState(() => _result = null),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.close_rounded, size: 16, color: AppColors.textSecondary),
                  ),
                ),
            ],
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
          if (res.senderName != null && res.senderName!.isNotEmpty)
            _buildInfoRow('Sender', res.senderName!),
          if (res.receiverAccount != null && res.receiverAccount!.isNotEmpty)
            _buildInfoRow('Receiver Acc', res.receiverAccount!),
          if (res.referenceNumber != null && res.referenceNumber!.isNotEmpty)
            _buildInfoRow('Ref #', res.referenceNumber!, canCopy: true),

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

  Widget _buildInfoRow(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
