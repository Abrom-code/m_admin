import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/data/services/verify_et_service.dart';
import 'package:m_admin/features/payments/controllers/verify_et_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

/// Modal dialog to view and update the Verify.ET API key and settlement settings.
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
  final _service = VerifyEtService.instance;
  late final TextEditingController _apiKeyCtrl;
  late final TextEditingController _settlementCtrl;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController(text: _service.apiKey.value);
    _settlementCtrl = TextEditingController(text: _service.defaultSettlementAccount.value);
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    _settlementCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final key = _apiKeyCtrl.text.trim();
    final acc = _settlementCtrl.text.trim();

    _service.saveApiKey(key);
    _service.saveDefaultSettlementAccount(acc);

    if (VerifyEtController.isRegistered) {
      final ctrl = VerifyEtController.instance;
      ctrl.apiKeyCtrl.text = key;
      ctrl.defaultSettlementCtrl.text = acc;
      if (ctrl.historyList.isEmpty && key.isNotEmpty) {
        ctrl.loadHistory();
      }
    }

    Navigator.of(context).pop();
    SnackbarHelper.success(
      'Verify.ET Settings Saved',
      'API Key and settlement configuration updated successfully.',
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
                    child: Text(
                      'Verify.ET Configuration',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceBtwItems),

              // API Key input
              TextField(
                controller: _apiKeyCtrl,
                obscureText: _obscureKey,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'x-api-key',
                  hintText: 'VERIFY_BANK_ET_...',
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
              const SizedBox(height: AppSizes.spaceBtwInputFields),

              // Default Settlement Account input
              TextField(
                controller: _settlementCtrl,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Default Settlement Account (Optional)',
                  hintText: 'e.g. 1000303997441 or 0911234567',
                  prefixIcon: const Icon(Iconsax.card_pos_copy, size: 18),
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
