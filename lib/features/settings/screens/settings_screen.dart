import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

// ── Extra account model ───────────────────────────────────────────────

class ExtraPaymentAccount {
  ExtraPaymentAccount({
    required this.key,
    required this.label,
    required this.account,
    required this.holder,
  });

  String key;
  String label;
  String account;
  String holder;

  factory ExtraPaymentAccount.fromJson(Map<String, dynamic> json) =>
      ExtraPaymentAccount(
        key: json['key']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        account: json['account']?.toString() ?? '',
        holder: json['holder']?.toString() ?? '',
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'label': label,
        'account': account,
        'holder': holder,
      };
}

// ── Controller ────────────────────────────────────────────────────────

class SettingsController extends GetxController {
  static SettingsController get instance => Get.find();

  final _sb = Supabase.instance.client;

  // Payment config – built-in methods
  final isSavingPayment = false.obs;
  final cbeBirr = TextEditingController();
  final cbeBirrHolder = TextEditingController();
  final telebirr = TextEditingController();
  final telebirrHolder = TextEditingController();
  final abyssinia = TextEditingController();
  final abyssiniaHolder = TextEditingController();
  final mpesa = TextEditingController();
  final mpesaHolder = TextEditingController();

  // Extra accounts
  final extraAccounts = <ExtraPaymentAccount>[].obs;

  // Webhook
  final isSavingWebhook = false.obs;
  final webhookSecret = TextEditingController();
  final showSecret = false.obs;

  // App config
  final isSavingApp = false.obs;
  final trialCount = TextEditingController(text: '5');
  final subscriptionPrice = TextEditingController(text: '0');

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  @override
  void onClose() {
    cbeBirr.dispose();
    cbeBirrHolder.dispose();
    telebirr.dispose();
    telebirrHolder.dispose();
    abyssinia.dispose();
    abyssiniaHolder.dispose();
    mpesa.dispose();
    mpesaHolder.dispose();
    webhookSecret.dispose();
    trialCount.dispose();
    subscriptionPrice.dispose();
    super.onClose();
  }

  Future<void> _loadSettings() async {
    try {
      final rows = await _sb.from('app_config').select('key, value');

      // Build a flat map for PaymentMethodInfo and fill form controllers.
      final cfg = <String, String>{};
      for (final row in rows) {
        final key = row['key']?.toString() ?? '';
        final value = row['value']?.toString() ?? '';
        cfg[key] = value;
        switch (key) {
          case 'payment_cbe_birr':
            cbeBirr.text = value;
          case 'payment_cbe_birr_holder':
            cbeBirrHolder.text = value;
          case 'payment_telebirr':
            telebirr.text = value;
          case 'payment_telebirr_holder':
            telebirrHolder.text = value;
          case 'payment_abyssinia':
            abyssinia.text = value;
          case 'payment_abyssinia_holder':
            abyssiniaHolder.text = value;
          case 'payment_mpesa':
            mpesa.text = value;
          case 'payment_mpesa_holder':
            mpesaHolder.text = value;
          case 'webhook_secret':
            webhookSecret.text = value;
          case 'trial_count':
            trialCount.text = value;
          case 'subscription_price':
            subscriptionPrice.text = value;
          case 'payment_extra_accounts':
            _parseExtraAccounts(value);
        }
      }

      // Refresh the live PaymentMethodInfo map so the payments queue
      // immediately shows the up-to-date account numbers and holder names.
      PaymentMethodInfo.loadFromConfig(cfg);
    } catch (e) {
      SnackbarHelper.error('Load error', AppExceptionHandler.handle(e).message);
    }
  }

  void _parseExtraAccounts(String raw) {
    try {
      final list = jsonDecode(raw.isEmpty ? '[]' : raw) as List<dynamic>;
      extraAccounts.value = list
          .whereType<Map<String, dynamic>>()
          .map(ExtraPaymentAccount.fromJson)
          .toList();
    } catch (_) {
      extraAccounts.value = [];
    }
  }

  Future<void> savePaymentNumbers() async {
    try {
      isSavingPayment.value = true;
      await _upsertMany({
        'payment_cbe_birr': cbeBirr.text.trim(),
        'payment_cbe_birr_holder': cbeBirrHolder.text.trim(),
        'payment_telebirr': telebirr.text.trim(),
        'payment_telebirr_holder': telebirrHolder.text.trim(),
        'payment_abyssinia': abyssinia.text.trim(),
        'payment_abyssinia_holder': abyssiniaHolder.text.trim(),
        'payment_mpesa': mpesa.text.trim(),
        'payment_mpesa_holder': mpesaHolder.text.trim(),
        'payment_extra_accounts':
            jsonEncode(extraAccounts.map((e) => e.toJson()).toList()),
      });
      SnackbarHelper.success('Saved', 'Payment accounts updated.');
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      isSavingPayment.value = false;
    }
  }

  Future<void> saveWebhookSecret() async {
    final secret = webhookSecret.text.trim();
    if (secret.isEmpty) {
      SnackbarHelper.error('Invalid', 'Secret cannot be empty.');
      return;
    }
    try {
      isSavingWebhook.value = true;
      await _upsertMany({'webhook_secret': secret});
      SnackbarHelper.success('Saved', 'Webhook secret updated.');
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      isSavingWebhook.value = false;
    }
  }

  Future<void> saveAppConfig() async {
    try {
      isSavingApp.value = true;
      await _upsertMany({
        'trial_count': trialCount.text.trim(),
        'subscription_price': subscriptionPrice.text.trim(),
      });
      SnackbarHelper.success('Saved', 'App config updated.');
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      isSavingApp.value = false;
    }
  }

  void addExtraAccount() {
    extraAccounts.add(ExtraPaymentAccount(
      key: 'method_${DateTime.now().millisecondsSinceEpoch}',
      label: '',
      account: '',
      holder: '',
    ));
  }

  void removeExtraAccount(int index) {
    extraAccounts.removeAt(index);
  }

  Future<void> _upsertMany(Map<String, String> pairs) async {
    for (final entry in pairs.entries) {
      await _sb.from('app_config').upsert(
        {'key': entry.key, 'value': entry.value},
        onConflict: 'key',
      );
    }
  }
}

// ── Screen ────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());

    return AdminScaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _PaymentSection(controller),
          const SizedBox(height: AppSizes.spaceBtwSections),
          _WebhookSection(controller),
          const SizedBox(height: AppSizes.spaceBtwSections),
          _AppConfigSection(controller),
        ],
      ),
    );
  }
}

// ── Payment section ───────────────────────────────────────────────────

class _PaymentSection extends StatelessWidget {
  const _PaymentSection(this.c);
  final SettingsController c;

  @override
  Widget build(BuildContext context) {
    return AdminSection(
      title: 'Payment accounts',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account numbers and holder names shown to students on the payment screen.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: AppSizes.lg),
          _BuiltInMethodRow(
            icon: Iconsax.mobile_copy,
            label: 'Telebirr',
            accountController: c.telebirr,
            holderController: c.telebirrHolder,
            accountHint: '09xxxxxxxx',
          ),
          const _Divider(),
          _BuiltInMethodRow(
            icon: Iconsax.bank_copy,
            label: 'CBE Birr',
            accountController: c.cbeBirr,
            holderController: c.cbeBirrHolder,
            accountHint: '1000xxxxxxxx',
          ),
          const _Divider(),
          _BuiltInMethodRow(
            icon: Iconsax.bank_copy,
            label: 'Abyssinia',
            accountController: c.abyssinia,
            holderController: c.abyssiniaHolder,
            accountHint: '1800xxxxxxxx',
          ),
          const _Divider(),
          _BuiltInMethodRow(
            icon: Iconsax.mobile_copy,
            label: 'M-Pesa',
            accountController: c.mpesa,
            holderController: c.mpesaHolder,
            accountHint: '07xxxxxxxx',
          ),
          const SizedBox(height: AppSizes.lg),

          // ── Extra accounts ────────────────────────────────────────
          Row(
            children: [
              Text(
                'Additional accounts',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: c.addExtraAccount,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: const Text('Add account'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Obx(() {
            if (c.extraAccounts.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.sm),
                child: Text(
                  'No additional accounts. Tap "Add account" to add one.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B7280),
                  ),
                ),
              );
            }
            return Column(
              children: [
                for (var i = 0; i < c.extraAccounts.length; i++) ...[
                  _ExtraAccountRow(
                    account: c.extraAccounts[i],
                    onRemove: () => c.removeExtraAccount(i),
                  ),
                  if (i < c.extraAccounts.length - 1) const _Divider(),
                ],
              ],
            );
          }),
          const SizedBox(height: AppSizes.lg),
          Align(
            alignment: Alignment.centerRight,
            child: Obx(
              () => FilledButton.icon(
                onPressed:
                    c.isSavingPayment.value ? null : c.savePaymentNumbers,
                icon: c.isSavingPayment.value
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save payment accounts'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuiltInMethodRow extends StatelessWidget {
  const _BuiltInMethodRow({
    required this.icon,
    required this.label,
    required this.accountController,
    required this.holderController,
    required this.accountHint,
  });

  final IconData icon;
  final String label;
  final TextEditingController accountController;
  final TextEditingController holderController;
  final String accountHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Method label
          SizedBox(
            width: 110,
            child: Row(
              children: [
                Icon(icon, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // Account number
          Expanded(
            child: TextFormField(
              controller: accountController,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Account number',
                hintText: accountHint,
                isDense: true,
                prefixIcon: const Icon(Iconsax.card_copy, size: 16),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // Holder name / title
          Expanded(
            child: TextFormField(
              controller: holderController,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Account holder name',
                hintText: 'e.g. Abebe Kebede',
                isDense: true,
                prefixIcon: Icon(Iconsax.user_copy, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExtraAccountRow extends StatelessWidget {
  const _ExtraAccountRow({
    required this.account,
    required this.onRemove,
  });

  final ExtraPaymentAccount account;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextFormField(
              initialValue: account.label,
              onChanged: (v) => account.label = v,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Method name',
                hintText: 'e.g. BOA',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: TextFormField(
              initialValue: account.account,
              onChanged: (v) => account.account = v,
              keyboardType: TextInputType.phone,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Account number',
                hintText: '1000xxxxxxxx',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: TextFormField(
              initialValue: account.holder,
              onChanged: (v) => account.holder = v,
              style: const TextStyle(fontSize: 13),
              decoration: const InputDecoration(
                labelText: 'Holder name',
                hintText: 'e.g. Abebe Kebede',
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: AppSizes.xs),
          IconButton(
            tooltip: 'Remove',
            onPressed: onRemove,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 18,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(height: 1, thickness: 0.5);
}

// ── Webhook section ───────────────────────────────────────────────────

class _WebhookSection extends StatelessWidget {
  const _WebhookSection(this.c);
  final SettingsController c;

  @override
  Widget build(BuildContext context) {
    return AdminSection(
      title: 'Notification webhook',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Secret shared with the send-push edge function. '
            'Must match the x-webhook-secret header value.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: AppSizes.md),
          Obx(
            () => TextFormField(
              controller: c.webhookSecret,
              obscureText: !c.showSecret.value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Webhook secret',
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () => Clipboard.setData(
                        ClipboardData(text: c.webhookSecret.text),
                      ),
                    ),
                    IconButton(
                      tooltip: c.showSecret.value ? 'Hide' : 'Show',
                      icon: Icon(
                        c.showSecret.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      onPressed: () =>
                          c.showSecret.value = !c.showSecret.value,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSizes.md),
          Align(
            alignment: Alignment.centerRight,
            child: Obx(
              () => FilledButton.icon(
                onPressed:
                    c.isSavingWebhook.value ? null : c.saveWebhookSecret,
                icon: c.isSavingWebhook.value
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Update secret'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── App config section ────────────────────────────────────────────────

class _AppConfigSection extends StatelessWidget {
  const _AppConfigSection(this.c);
  final SettingsController c;

  @override
  Widget build(BuildContext context) {
    return AdminSection(
      title: 'App config',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Trial count and pricing shown in the student app.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: AppSizes.md),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: c.trialCount,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Trial questions',
                    hintText: '5',
                    prefixIcon: Icon(Iconsax.task_square_copy, size: 16),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: TextFormField(
                  controller: c.subscriptionPrice,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    labelText: 'Subscription price (ETB)',
                    hintText: '0',
                    prefixIcon: Icon(Iconsax.money_copy, size: 16),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Align(
            alignment: Alignment.centerRight,
            child: Obx(
              () => FilledButton.icon(
                onPressed: c.isSavingApp.value ? null : c.saveAppConfig,
                icon: c.isSavingApp.value
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save config'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
