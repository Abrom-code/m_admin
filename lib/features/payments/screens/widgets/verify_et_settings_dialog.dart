import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/data/services/verify_et_service.dart';
import 'package:m_admin/features/payments/controllers/verify_et_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

/// Modal dialog to view and update the links.et API key configuration.
class VerifyEtSettingsDialog extends StatefulWidget {
  const VerifyEtSettingsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const VerifyEtSettingsDialog(),
    );
  }

  @override
  State<VerifyEtSettingsDialog> createState() => _VerifyEtSettingsDialogState();
}

class _VerifyEtSettingsDialogState extends State<VerifyEtSettingsDialog> {
  final _service = LinksEtService.instance;
  late final TextEditingController _apiKeyCtrl;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController(text: _service.apiKey.value);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final key = _apiKeyCtrl.text.trim();
    _service.saveApiKey(key);

    if (VerifyEtController.isRegistered) {
      final ctrl = VerifyEtController.instance;
      ctrl.apiKeyCtrl.text = key;
      if (ctrl.historyList.isEmpty && key.isNotEmpty) {
        ctrl.loadHistory();
      }
    }

    Navigator.of(context).pop();
    SnackbarHelper.success(
      'Verify.ET Key Saved',
      'API Key updated successfully.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg)),
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Iconsax.shield_tick_copy, color: Color(0xFF6366F1), size: 20),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Verify.ET Configuration',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Ethiopian Bank & Wallet Payment Verification Gateway',
                          style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceBtwItems),

              // API Key Info Box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Iconsax.info_circle_copy, size: 16, color: Color(0xFF6366F1)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Mint your API key from the Verify.ET dashboard at https://verify.et. Production keys start with "VERIFY_BANK_ET_".',
                        style: TextStyle(fontSize: 12, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.spaceBtwInputFields),

              // API Key input
              TextField(
                controller: _apiKeyCtrl,
                obscureText: _obscureKey,
                style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  labelText: 'x-api-key',
                  hintText: 'VERIFY_BANK_ET_xxxxxxxxxxxxxxxxxxxxxxxx',
                  prefixIcon: const Icon(Iconsax.key_copy, size: 18),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureKey ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                      size: 18,
                    ),
                    onPressed: () => setState(() => _obscureKey = !_obscureKey),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: AppSizes.spaceBtwSections),

              // Action buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
