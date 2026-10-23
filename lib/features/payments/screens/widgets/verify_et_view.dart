import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/features/payments/controllers/payments_controller.dart';
import 'package:m_admin/features/payments/controllers/verify_et_controller.dart';
import 'package:m_admin/features/payments/models/verify_et_model.dart';
import 'package:m_admin/features/payments/screens/widgets/verify_et_settings_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class VerifyEtView extends StatefulWidget {
  const VerifyEtView({super.key});

  @override
  State<VerifyEtView> createState() => _VerifyEtViewState();
}

class _VerifyEtViewState extends State<VerifyEtView> {
  final _ctrl = Get.put(VerifyEtController(), permanent: true);

  final List<Map<String, String>> _supportedBanks = [
    {'id': 'universal', 'label': 'Universal', 'icon': '🌐'},
    {'id': 'cbe', 'label': 'CBE', 'icon': '🏦'},
    {'id': 'telebirr', 'label': 'Telebirr', 'icon': '📱'},
    {'id': 'boa', 'label': 'Abyssinia', 'icon': '🦁'},
    {'id': 'cbebirr', 'label': 'CBE Birr', 'icon': '💳'},
    {'id': 'mpesa', 'label': 'M-Pesa', 'icon': '📲'},
    {'id': 'dashen', 'label': 'Dashen', 'icon': '🏛️'},
    {'id': 'awash', 'label': 'Awash', 'icon': '🌊'},
    {'id': 'coopayebirr', 'label': 'Coopay', 'icon': '🤝'},
  ];

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Top Header Strip ─────────────────────────────────────────────
          _buildHeaderBar(context, dark),
          const SizedBox(height: AppSizes.spaceBtwItems),

          // ── Main Verification Form & Live Result ──────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 900;
              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: _buildFormCard(context, dark),
                    ),
                    const SizedBox(width: AppSizes.spaceBtwItems),
                    Expanded(
                      flex: 5,
                      child: Obx(() => _buildResultOrHistory(context, dark)),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildFormCard(context, dark),
                  const SizedBox(height: AppSizes.spaceBtwItems),
                  Obx(() => _buildResultOrHistory(context, dark)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Iconsax.shield_tick_copy, color: Color(0xFF6366F1), size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Verify.ET',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                SizedBox(width: 8),
                _StatusTag(label: 'GATEWAY', color: AppColors.success),
              ],
            ),
          ),
          Obx(() {
            final hasKey = _ctrl.hasApiKey;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: (hasKey ? AppColors.success : AppColors.warning).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: (hasKey ? AppColors.success : AppColors.warning).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hasKey ? Icons.check_circle_outline : Icons.warning_amber_rounded,
                        size: 13,
                        color: hasKey ? AppColors.success : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        hasKey ? 'Ready' : 'Key Needed',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: hasKey ? AppColors.success : AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  tooltip: 'Verify.ET Settings',
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.all(6),
                  constraints: const BoxConstraints(),
                  icon: const Icon(Iconsax.setting_2_copy, size: 18),
                  onPressed: () => VerifyEtSettingsDialog.show(context),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Iconsax.search_status_copy, size: 17, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Instant Verification',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: _ctrl.resetForm,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Reset', style: TextStyle(fontSize: 11.5)),
                style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Provider Chips
          Obx(() {
            final current = _ctrl.selectedBank.value;
            return Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _supportedBanks.map((b) {
                final isSelected = current == b['id'];
                return ChoiceChip(
                  showCheckmark: false,
                  label: Text(
                    '${b['icon']} ${b['label']}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? AppColors.primary
                          : (dark ? AppColors.white : AppColors.textPrimary),
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withValues(alpha: 0.16),
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  visualDensity: VisualDensity.compact,
                  onSelected: (val) {
                    if (val) _ctrl.selectedBank.value = b['id']!;
                  },
                );
              }).toList(),
            );
          }),
          const SizedBox(height: 14),

          // Reference Input Field
          Obx(() {
            final bank = _ctrl.selectedBank.value;
            String label = 'Reference / Receipt Number / Transaction ID *';
            String hint = 'e.g. fHCxyExampleRcpt1, FT26..., or DET8FJGUJ4';

            if (bank == 'cbe') {
              label = 'CBE Receipt ID or Reference *';
              hint = 'e.g. fHCxyExampleRcpt1 or mbreciept link';
            } else if (bank == 'telebirr') {
              label = 'Telebirr Transaction Number *';
              hint = 'e.g. DET8FJGUJ4 or fHCxy...';
            } else if (bank == 'mpesa') {
              label = 'M-Pesa Transaction Code *';
              hint = 'e.g. DET8FJGUJ4';
            } else if (bank == 'boa') {
              label = 'Abyssinia Reference *';
              hint = 'e.g. FT26...';
            } else if (bank == 'cbebirr') {
              label = 'CBE Birr Receipt Number *';
              hint = 'e.g. 1009827361';
            }

            return TextField(
              controller: _ctrl.referenceCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                prefixIcon: const Icon(Iconsax.receipt_2_copy, size: 17),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }),
          const SizedBox(height: 10),

          // Contextual Fields: Suffix for CBE, BoA, Universal and phone for CBE Birr, Coopay
          Obx(() {
            final bank = _ctrl.selectedBank.value;
            final isCbe = bank == 'cbe';
            final isBoa = bank == 'boa';
            final isUniversal = bank == 'universal';
            final needsSuffix = isBoa || isCbe || isUniversal;
            final needsPhone = bank == 'cbebirr' || isUniversal || bank == 'coopayebirr';

            if (!needsSuffix && !needsPhone) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (needsSuffix)
                        Expanded(
                          child: TextField(
                            controller: _ctrl.accountSuffixCtrl,
                            keyboardType: TextInputType.number,
                            maxLength: (isCbe || isUniversal) ? 8 : 5,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              labelText: isCbe
                                  ? 'Account Suffix (8 digits for FT)'
                                  : (isBoa ? 'Account Suffix (5 digits for BoA)' : 'Account Suffix (optional)'),
                              hintText: (isCbe || isUniversal) ? 'e.g. 03997441' : 'e.g. 07441',
                              counterText: '',
                              prefixIcon: const Icon(Iconsax.hashtag_copy, size: 15),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      if (needsSuffix && needsPhone) const SizedBox(width: 8),
                      if (needsPhone)
                        Expanded(
                          child: TextField(
                            controller: _ctrl.phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: const TextStyle(fontSize: 12.5),
                            decoration: InputDecoration(
                              labelText: 'Phone Number (Wallet/Birr)',
                              hintText: 'e.g. 0911234567',
                              prefixIcon: const Icon(Iconsax.call_copy, size: 15),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (isCbe)
                    const Padding(
                      padding: EdgeInsets.only(top: 3, left: 2),
                      child: Text(
                        'CBE FT references require the 8-digit suffix. CBE receipt IDs & links do not.',
                        style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                      ),
                    ),
                ],
              ),
            );
          }),

          // Settlement Account Matching
          TextField(
            controller: _ctrl.settlementAccountCtrl,
            style: const TextStyle(fontSize: 12.5),
            decoration: InputDecoration(
              labelText: 'Expected Settlement Account (Optional)',
              hintText: 'Leave empty to use default account',
              prefixIcon: const Icon(Iconsax.bank_copy, size: 16),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 12),

          // Receipt Image Dropzone
          Obx(() {
            final bytes = _ctrl.selectedImageBytes.value;
            final fileName = _ctrl.selectedImageName.value;

            if (bytes != null) {
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(bytes, width: 42, height: 42, fit: BoxFit.cover),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        fileName ?? 'Receipt Image',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Remove Image',
                      visualDensity: VisualDensity.compact,
                      onPressed: _ctrl.clearImage,
                    ),
                  ],
                ),
              );
            }

            return InkWell(
              onTap: _ctrl.pickReceiptImage,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Iconsax.document_upload_copy, size: 17, color: AppColors.primary),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text(
                        'Upload Receipt Photo (QR / OCR)',
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('IMAGE', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: AppColors.secondary)),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 14),

          // Submit Action Button
          Obx(() {
            final loading = _ctrl.isLoading.value;
            final pollMsg = _ctrl.pollingStatusMessage.value;
            final labelText = pollMsg.isNotEmpty
                ? pollMsg
                : (loading ? 'Verifying with Bank...' : 'Verify Transaction');

            return SizedBox(
              width: double.infinity,
              height: 42,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: loading ? null : _ctrl.submitVerification,
                icon: loading
                    ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Iconsax.tick_circle_copy, size: 17),
                label: Text(
                  labelText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            );
          }),

          // Error Message Display
          Obx(() {
            final err = _ctrl.errorMessage.value;
            if (err == null || err.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(err, style: const TextStyle(fontSize: 11.5, color: AppColors.error))),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildResultOrHistory(BuildContext context, bool dark) {
    final result = _ctrl.activeResult.value;

    if (result != null) {
      return _buildResultCard(context, dark, result);
    }

    return _buildHistoryCard(context, dark);
  }

  Widget _buildResultCard(BuildContext context, bool dark, VerifyEtResult res) {
    final isVerified = res.verified;
    final statusColor = isVerified ? AppColors.success : (res.status == 'pending' ? AppColors.warning : AppColors.error);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isVerified ? Icons.check_circle : (res.status == 'pending' ? Icons.hourglass_empty : Icons.cancel),
                  color: statusColor,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isVerified ? 'TRANSACTION VERIFIED' : 'VERIFICATION ${res.status.toUpperCase()}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: statusColor),
                    ),
                    Text(
                      'Gateway: ${res.bank.toUpperCase()}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                tooltip: 'Dismiss Result',
                visualDensity: VisualDensity.compact,
                onPressed: () => _ctrl.activeResult.value = null,
              ),
            ],
          ),
          const Divider(height: 20),

          // Queued Telebirr / Bank Notification & Manual Status Refresh Button
          if (res.isPending) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 15, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${res.bank.toUpperCase()} verification is queued in the bank network.',
                      style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (res.requestId != null && res.requestId!.isNotEmpty)
                    Obx(() {
                      final isBusy = _ctrl.isLoading.value;
                      return FilledButton.tonal(
                        onPressed: isBusy ? null : () => _ctrl.refreshStatus(res.requestId!),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                        ),
                        child: Text(
                          isBusy ? 'Checking...' : 'Check Status',
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      );
                    }),
                ],
              ),
            ),
          ],

          // Amount Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Verified Amount:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Text(
                '${res.amount.toStringAsFixed(res.amount.truncateToDouble() == res.amount ? 0 : 2)} ${res.currency}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Details Table with overflow protection
          _buildDetailRow('Sender Name', res.senderName ?? '—'),
          _buildDetailRow('Receiver Name', res.receiverName ?? '—'),
          _buildDetailRow('Receiver Account', res.receiverAccount ?? '—'),
          _buildDetailRow('Reference Number', res.referenceNumber ?? '—', canCopy: res.referenceNumber != null),
          _buildDetailRow('Receipt Number', res.receiptNumber ?? '—', canCopy: res.receiptNumber != null),
          if (res.timestamp != null)
            _buildDetailRow('Timestamp', EthiopianTimeHelper.formatDateTimeWithEth(res.timestamp!)),

          // Settlement Account Match Badge
          if (res.settlementAccountMatch != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: res.settlementAccountMatch!.matched
                    ? AppColors.success.withValues(alpha: 0.1)
                    : AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: res.settlementAccountMatch!.matched
                      ? AppColors.success.withValues(alpha: 0.3)
                      : AppColors.error.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    res.settlementAccountMatch!.matched ? Icons.verified_user : Icons.gpp_bad,
                    size: 15,
                    color: res.settlementAccountMatch!.matched ? AppColors.success : AppColors.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          res.settlementAccountMatch!.matched ? 'Settlement Matched' : 'Settlement Mismatch',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: res.settlementAccountMatch!.matched ? AppColors.success : AppColors.error,
                          ),
                        ),
                        Text(
                          res.settlementAccountMatch!.reasonLabel,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Confirmation History Badge (Double Spend Protection)
          if (res.confirmationHistory != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(
                    res.confirmationHistory!.isFirstConfirmation ? Icons.security : Icons.warning_amber,
                    size: 15,
                    color: res.confirmationHistory!.isFirstConfirmation ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      res.confirmationHistory!.isFirstConfirmation
                          ? 'First Confirmation (Safe)'
                          : 'Warning: Confirmed ${res.confirmationHistory!.confirmationCount}x previously!',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: res.confirmationHistory!.isFirstConfirmation ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actions
          if (isVerified) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final paymentsCtrl = Get.find<PaymentsController>();
                  final ref = res.referenceNumber ?? res.receiptNumber ?? '';
                  if (ref.isNotEmpty) {
                    paymentsCtrl.searchController.text = ref;
                    paymentsCtrl.onSearchChanged(ref);
                  }
                  paymentsCtrl.changeTab('pending');
                  SnackbarHelper.info('Queue Filtered', 'Switched to Pending tab matching $ref');
                },
                icon: const Icon(Iconsax.search_normal_copy, size: 14),
                label: const Text('Find Matching Receipt in Queue', style: TextStyle(fontSize: 11.5)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool canCopy = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ),
                if (canCopy && value != '—') ...[
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value));
                      SnackbarHelper.info('Copied', '$value copied to clipboard');
                    },
                    child: const Icon(Icons.copy, size: 12, color: AppColors.primary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, bool dark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Iconsax.clock_copy, size: 17, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Recent Verifications',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh, size: 15),
                tooltip: 'Refresh History',
                visualDensity: VisualDensity.compact,
                onPressed: _ctrl.loadHistory,
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_ctrl.isLoadingHistory.value)
            const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
          else if (_ctrl.historyList.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Column(
                  children: [
                    Icon(Iconsax.receipt_item_copy, size: 32, color: dark ? AppColors.darkGrey : AppColors.grey),
                    const SizedBox(height: 6),
                    const Text('No recent verifications yet.', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ctrl.historyList.take(8).length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, idx) {
                final item = _ctrl.historyList[idx];
                final isOk = item.verified;

                return ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 13,
                    backgroundColor: (isOk ? AppColors.success : AppColors.error).withValues(alpha: 0.15),
                    child: Icon(
                      isOk ? Icons.check : Icons.close,
                      size: 13,
                      color: isOk ? AppColors.success : AppColors.error,
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(item.bank.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                      const SizedBox(width: 6),
                      _StatusTag(label: item.status.toUpperCase(), color: isOk ? AppColors.success : AppColors.error),
                    ],
                  ),
                  subtitle: Text(
                    item.requestId.length > 12 ? '${item.requestId.substring(0, 12)}...' : item.requestId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5),
                  ),
                  trailing: item.createdAt != null
                      ? Text(EthiopianTimeHelper.formatDate(item.createdAt!), style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))
                      : null,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _StatusTag extends StatelessWidget {
  const _StatusTag({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
    );
  }
}
