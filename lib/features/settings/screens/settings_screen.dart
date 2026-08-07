import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

// ── Controller ───────────────────────────────────────────────────────

class SettingsController extends GetxController {
  static SettingsController get instance => Get.find();

  final _sb = Supabase.instance.client;

  // Payment config
  final isSavingPayment = false.obs;
  final cbeBirr = TextEditingController();
  final telebirr = TextEditingController();
  final awash = TextEditingController();
  final mpesa = TextEditingController();

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
    telebirr.dispose();
    awash.dispose();
    mpesa.dispose();
    webhookSecret.dispose();
    trialCount.dispose();
    subscriptionPrice.dispose();
    super.onClose();
  }

  Future<void> _loadSettings() async {
    try {
      final rows = await _sb
          .from('app_config')
          .select('key, value');

      for (final row in rows) {
        final key = row['key']?.toString() ?? '';
        final value = row['value']?.toString() ?? '';
        switch (key) {
          case 'payment_cbe_birr':
            cbeBirr.text = value;
          case 'payment_telebirr':
            telebirr.text = value;
          case 'payment_awash':
            awash.text = value;
          case 'payment_mpesa':
            mpesa.text = value;
          case 'webhook_secret':
            webhookSecret.text = value;
          case 'trial_count':
            trialCount.text = value;
          case 'subscription_price':
            subscriptionPrice.text = value;
        }
      }
    } catch (e) {
      // Non-critical: show a snackbar but do not block the UI
      SnackbarHelper.error('Load error', AppExceptionHandler.handle(e).message);
    }
  }

  Future<void> savePaymentNumbers() async {
    try {
      isSavingPayment.value = true;
      await _upsertMany({
        'payment_cbe_birr': cbeBirr.text.trim(),
        'payment_telebirr': telebirr.text.trim(),
        'payment_awash': awash.text.trim(),
        'payment_mpesa': mpesa.text.trim(),
      });
      SnackbarHelper.success('Saved', 'Payment numbers updated.');
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

  Future<void> _upsertMany(Map<String, String> pairs) async {
    for (final entry in pairs.entries) {
      await _sb.from('app_config').upsert(
        {'key': entry.key, 'value': entry.value},
        onConflict: 'key',
      );
    }
  }
}

// ── Screen ───────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SettingsController());

    return AdminScaffold(
      title: 'Settings',
      subtitle: 'App configuration and payment methods',
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
      title: 'Payment numbers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account numbers shown to students on the payment screen.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: AppSizes.md),
          _SettingsRow(
            label: 'CBE Birr',
            controller: c.cbeBirr,
            hint: '1000xxxxxxxx',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSizes.md),
          _SettingsRow(
            label: 'Telebirr',
            controller: c.telebirr,
            hint: '09xxxxxxxx',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSizes.md),
          _SettingsRow(
            label: 'Awash',
            controller: c.awash,
            hint: '0900xxxxxxxx',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSizes.md),
          _SettingsRow(
            label: 'M-Pesa',
            controller: c.mpesa,
            hint: '07xxxxxxxx',
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSizes.md),
          Align(
            alignment: Alignment.centerRight,
            child: Obx(
              () => FilledButton(
                onPressed: c.isSavingPayment.value ? null : c.savePaymentNumbers,
                child: c.isSavingPayment.value
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save payment numbers'),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
              () => FilledButton(
                onPressed:
                    c.isSavingWebhook.value ? null : c.saveWebhookSecret,
                child: c.isSavingWebhook.value
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Update secret'),
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
            'Trial count and pricing.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: AppSizes.md),
          _SettingsRow(
            label: 'Trial questions',
            controller: c.trialCount,
            hint: '5',
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          ),
          const SizedBox(height: AppSizes.md),
          _SettingsRow(
            label: 'Subscription price (ETB)',
            controller: c.subscriptionPrice,
            hint: '0',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: AppSizes.md),
          Align(
            alignment: Alignment.centerRight,
            child: Obx(
              () => FilledButton(
                onPressed:
                    c.isSavingApp.value ? null : c.saveAppConfig,
                child: c.isSavingApp.value
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save config'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared field widget ───────────────────────────────────────────────

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.label,
    required this.controller,
    required this.hint,
    this.keyboardType,
    this.inputFormatters,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}
