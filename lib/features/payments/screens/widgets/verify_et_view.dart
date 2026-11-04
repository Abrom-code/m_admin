import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
    {'id': 'telebirr', 'label': 'Telebirr', 'icon': '📱'},
    {'id': 'cbe', 'label': 'CBE', 'icon': '🏦'},
    {'id': 'boa', 'label': 'Abyssinia', 'icon': '🦁'},
    {'id': 'awash', 'label': 'Awash', 'icon': '🌊'},
    {'id': 'zemen', 'label': 'Zemen', 'icon': '🏛️'},
    {'id': 'dashen', 'label': 'Dashen', 'icon': '🏢'},
    {'id': 'cbebirr', 'label': 'CBE Birr', 'icon': '💳'},
    {'id': 'mpesa', 'label': 'M-Pesa', 'icon': '📲'},
    {'id': 'oromia', 'label': 'Oromia / Coop', 'icon': '🤝'},
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
                  'verify.et',
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
                  tooltip: 'Verify.ET Configuration',
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
                    'Instant Bank Verification',
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
          const SizedBox(height: 12),

          // ── PREVIOUSLY SCANNED WARNING BANNER ─────────────────────────────
          Obx(() {
            final prev = _ctrl.previousScannedRecord.value;
            if (prev == null) return const SizedBox.shrink();

            final isPrevApproved = prev.isApproved;
            final bannerColor = isPrevApproved ? AppColors.error : AppColors.warning;

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                          'Scanned ${prev.scanCount}x',
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
                          prev.status.toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isPrevApproved ? AppColors.error : AppColors.success),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isPrevApproved
                              ? 'Approved: ${prev.formattedApprovedDate ?? prev.formattedScannedDate}'
                              : 'Date: ${prev.formattedScannedDate}',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  if (prev.userEmail != null && prev.userEmail!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(Icons.person_outline, size: 12, color: AppColors.textSecondary),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'User: ${prev.userEmail}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (prev.amount != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      'Amount: ${prev.amount} ${prev.currency} (${prev.method.toUpperCase()})',
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            );
          }),

          // Supported Way Guide
          Obx(() {
            final bank = _ctrl.selectedBank.value;
            String guide;
            if (bank == 'telebirr') {
              guide = 'Supported: Telebirr Transaction Number (e.g. DF33KS5FB9), Receipt URL, or Screenshot image.';
            } else if (bank == 'cbe') {
              guide = 'Supported: CBE SMS link, dashed token (FT...-12345678), branch slip (FT...), or raw SMS.';
            } else if (bank == 'boa') {
              guide = 'Supported: Abyssinia reference token (FT...), digital slip link, or raw confirmation SMS.';
            } else if (bank == 'awash') {
              guide = 'Supported: AwashPay receipt URL (https://awashpay.awashbank.com:8225/...).';
            } else if (bank == 'zemen') {
              guide = 'Supported: Zemen Bank PDF receipt URL (https://share.zemenbank.com/rt/.../pdf).';
            } else if (bank == 'universal') {
              guide = 'Supported: Works for every bank via receipt URL, reference token, or SMS text.';
            } else {
              guide = 'Supported: Official digital receipt URL or reference for ${bank.toUpperCase()}.';
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, size: 13, color: Color(0xFF6366F1)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      guide,
                      style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Input Field (URL or Reference)
          Obx(() {
            final bank = _ctrl.selectedBank.value;
            String label = 'Receipt URL, Reference, or SMS *';
            String hint = 'https://... or reference code';

            if (bank == 'telebirr') {
              label = 'Telebirr Reference or Receipt URL *';
              hint = 'e.g. DF33KS5FB9 or https://transactioninfo.ethiotelecom.et/...';
            } else if (bank == 'cbe') {
              label = 'CBE Reference, Receipt Link, or SMS *';
              hint = 'e.g. FT... or https://mbreciept.cbe.com.et/...';
            } else if (bank == 'boa') {
              label = 'Abyssinia Reference (FT...) or Slip Link *';
              hint = 'e.g. FT... or https://cs.bankofabyssinia.com/slip/?trx=...';
            } else if (bank == 'awash') {
              label = 'AwashPay Receipt URL *';
              hint = 'e.g. https://awashpay.awashbank.com:8225/...';
            } else if (bank == 'zemen') {
              label = 'Zemen Bank Receipt URL *';
              hint = 'e.g. https://share.zemenbank.com/rt/.../pdf';
            } else if (bank != 'universal') {
              label = '${bank.toUpperCase()} Digital Receipt URL or Code *';
              hint = 'Official receipt URL or reference';
            }

            return TextField(
              controller: _ctrl.referenceCtrl,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: label,
                hintText: hint,
                prefixIcon: const Icon(Iconsax.receipt_2_copy, size: 17),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_ctrl.referenceCtrl.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        tooltip: 'Clear',
                        onPressed: () {
                          _ctrl.referenceCtrl.clear();
                          _ctrl.activeResult.value = null;
                        },
                      ),
                    IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 16),
                      tooltip: 'Paste from clipboard',
                      onPressed: () async {
                        final data = await Clipboard.getData('text/plain');
                        if (data?.text != null && data!.text!.trim().isNotEmpty) {
                          _ctrl.referenceCtrl.text = data.text!.trim();
                          _ctrl.checkPriorScan();
                        }
                      },
                    ),
                  ],
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            );
          }),
          const SizedBox(height: 12),

          // Receipt Image Dropzone (for Telebirr auto-OCR & verification)
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            fileName ?? 'Receipt Image',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Will be verified via Verify.ET Image Processing',
                            style: TextStyle(fontSize: 10, color: AppColors.textSecondary),
                          ),
                        ],
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
                        'Upload Receipt Screenshot (AI Detector & OCR)',
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
                : (loading ? 'Verifying with verify.et...' : 'Verify Receipt');

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

  Widget _buildResultCard(BuildContext context, bool dark, LinksEtResult res) {
    final isVerified = res.verified;
    final statusColor = isVerified ? AppColors.success : (res.isPending ? AppColors.warning : AppColors.error);

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
                  isVerified ? Icons.check_circle : (res.isPending ? Icons.hourglass_empty : Icons.cancel),
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
                      isVerified
                          ? 'CONFIRMED BY ${res.providerKey.toUpperCase()}'
                          : (res.isPending
                              ? 'QUEUED UPSTREAM'
                              : (res.isParsedButInvalid ? 'RECEIPT NOT FOUND AT BANK' : 'UNVERIFIED')),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: statusColor),
                    ),
                    Text(
                      'Gateway: verify.et (${res.providerKey})',
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

          // Failure Diagnosis Banner (for parsed but failed, missing receipt, etc.)
          if (!isVerified && !res.isPending) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
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
                    style: TextStyle(fontSize: 11, color: dark ? Colors.white70 : Colors.black87),
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
                                      style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            InkWell(
                              onTap: _ctrl.submitVerification,
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
                                      style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: AppColors.primary),
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

          // Double-scan alert if this was in database before
          if (res.wasScannedBefore) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, size: 16, color: AppColors.warning),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notice: Verified successfully. Note that this transaction was already in database (Previous scan: ${res.previousRecord?.formattedPreviousDate ?? res.previousRecord?.formattedScannedDate}, Status: ${res.previousRecord?.previousStatus ?? res.previousRecord?.status}).',
                      style: const TextStyle(fontSize: 11, color: AppColors.warning, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Queued status refresh button
          if (res.isPending && res.requestId != null && res.requestId!.isNotEmpty) ...[
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

          // Details Table
          _buildDetailRow('Sender Name', res.senderName ?? '—'),
          _buildDetailRow('Receiver Name', res.receiverName ?? '—'),
          _buildDetailRow('Receiver Account', res.receiverAccount ?? '—'),
          _buildDetailRow('Reference Number', res.referenceNumber ?? '—', canCopy: res.referenceNumber != null),
          if (res.receipt?.source != null)
            _buildDetailRow('Receipt Source', res.receipt!.source),
          if (res.timestamp != null)
            _buildDetailRow('Timestamp', '${DateFormat('d MMM yyyy, h:mm a').format(EthiopianTimeHelper.toEastAfricaTime(res.timestamp!))} EAT'),
          if (res.resolvedUrl != null)
            _buildDetailRow('Upstream URL', res.resolvedUrl!, canCopy: true),

          // Actions
          if (isVerified) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  final paymentsCtrl = Get.find<PaymentsController>();
                  final ref = res.referenceNumber ?? '';
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
                    'Scanned Receipts (Database)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_ctrl.historyList.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, size: 16, color: AppColors.error),
                      tooltip: 'Clear Scanned Database',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => _confirmClearHistory(context),
                    ),
                  IconButton(
                    icon: const Icon(Icons.refresh, size: 15),
                    tooltip: 'Refresh History',
                    visualDensity: VisualDensity.compact,
                    onPressed: _ctrl.loadHistory,
                  ),
                ],
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
                    const Text('No scanned receipts in local database yet.', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _ctrl.historyList.take(10).length,
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
                      if (item.scanCount > 1) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            '${item.scanCount}x',
                            style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.warning),
                          ),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Text(
                    item.requestId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, fontFamily: 'monospace'),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (item.amount > 0)
                        Text(
                          '${item.amount.toStringAsFixed(0)} ${item.currency}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      if (item.createdAt != null)
                        Text(
                          '${DateFormat('d MMM yyyy, h:mm a').format(EthiopianTimeHelper.toEastAfricaTime(item.createdAt!))} EAT',
                          style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _confirmClearHistory(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear Scanned Database?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will remove all stored verification records and scan timestamps from the local app database.',
          style: TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () {
              Navigator.of(ctx).pop();
              _ctrl.clearAllHistory();
            },
            child: const Text('Clear All'),
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
