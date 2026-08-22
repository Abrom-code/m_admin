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
import 'package:m_admin/utils/helpers/helper_functions.dart';
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

  // App config & Subscription plan pricing
  final isSavingApp = false.obs;
  final trialCount = TextEditingController(text: '5');
  final subscriptionPrice = TextEditingController(text: '250');
  final planPrice6Months = TextEditingController(text: '150');
  final planPrice1Year = TextEditingController(text: '250');
  final planPrice2Years = TextEditingController(text: '400');
  final planPrice3Years = TextEditingController(text: '550');
  final planPrice4Years = TextEditingController(text: '650');
  final telegramLink = TextEditingController();
  final shareLink = TextEditingController();

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
    planPrice6Months.dispose();
    planPrice1Year.dispose();
    planPrice2Years.dispose();
    planPrice3Years.dispose();
    planPrice4Years.dispose();
    telegramLink.dispose();
    shareLink.dispose();
    super.onClose();
  }

  Future<void> _loadSettings() async {
    try {
      final rows = await _sb.from('app_config').select('key, value');

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
            if (planPrice1Year.text == '250') planPrice1Year.text = value;
          case 'plan_price_6_months':
            planPrice6Months.text = value;
          case 'plan_price_1_year':
            planPrice1Year.text = value;
            subscriptionPrice.text = value;
          case 'plan_price_2_years':
            planPrice2Years.text = value;
          case 'plan_price_3_years':
            planPrice3Years.text = value;
          case 'plan_price_4_years':
            planPrice4Years.text = value;
          case 'telegram_link':
            telegramLink.text = value;
          case 'share_link':
            shareLink.text = value;
          case 'payment_extra_accounts':
            _parseExtraAccounts(value);
        }
      }

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
        'plan_price_6_months': planPrice6Months.text.trim(),
        'plan_price_1_year': planPrice1Year.text.trim(),
        'plan_price_2_years': planPrice2Years.text.trim(),
        'plan_price_3_years': planPrice3Years.text.trim(),
        'plan_price_4_years': planPrice4Years.text.trim(),
        'subscription_price': planPrice1Year.text.trim(),
        'telegram_link': telegramLink.text.trim(),
        'share_link': shareLink.text.trim(),
      });
      SnackbarHelper.success('Saved', 'App configuration and pricing updated.');
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
      pageIndex: 6,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _PaymentSection(controller),
          const SizedBox(height: AppSizes.spaceBtwSections),
          _AppConfigSection(controller),
          const SizedBox(height: AppSizes.spaceBtwSections),
          _WebhookSection(controller),
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
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: const Icon(Iconsax.wallet_2_copy, size: 16, color: AppColors.primary),
              ),
              const SizedBox(width: AppSizes.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment Receiving Accounts',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Account numbers and holder names displayed to students during checkout.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),
          _BuiltInMethodRow(
            icon: Iconsax.mobile_copy,
            label: 'Telebirr',
            color: const Color(0xFF005691),
            accountController: c.telebirr,
            holderController: c.telebirrHolder,
            accountHint: '09xxxxxxxx',
          ),
          const _Divider(),
          _BuiltInMethodRow(
            icon: Iconsax.bank_copy,
            label: 'Commercial Bank of Ethiopia (CBE Birr)',
            color: const Color(0xFF7A187B),
            accountController: c.cbeBirr,
            holderController: c.cbeBirrHolder,
            accountHint: '1000xxxxxxxx',
          ),
          const _Divider(),
          _BuiltInMethodRow(
            icon: Iconsax.bank_copy,
            label: 'Bank of Abyssinia',
            color: const Color(0xFFE89005),
            accountController: c.abyssinia,
            holderController: c.abyssiniaHolder,
            accountHint: '1800xxxxxxxx',
          ),
          const _Divider(),
          _BuiltInMethodRow(
            icon: Iconsax.mobile_copy,
            label: 'M-Pesa Safaricom',
            color: const Color(0xFF00A344),
            accountController: c.mpesa,
            holderController: c.mpesaHolder,
            accountHint: '07xxxxxxxx',
          ),
          const SizedBox(height: AppSizes.lg),

          // ── Extra accounts ────────────────────────────────────────
          Row(
            children: [
              const Text(
                'Additional Payment Gateways',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: c.addExtraAccount,
                icon: const Icon(Icons.add_rounded, size: 15),
                label: const Text('Add Account', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  'No additional custom accounts configured. Tap "Add Account" to configure one.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: c.isSavingPayment.value ? null : c.savePaymentNumbers,
                icon: c.isSavingPayment.value
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Payment Accounts', style: TextStyle(fontWeight: FontWeight.bold)),
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
    required this.color,
    required this.accountController,
    required this.holderController,
    required this.accountHint,
  });

  final IconData icon;
  final String label;
  final Color color;
  final TextEditingController accountController;
  final TextEditingController holderController;
  final String accountHint;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs + 2),
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 600;

              final accountField = TextFormField(
                controller: accountController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  labelText: 'Account / Phone Number',
                  hintText: accountHint,
                  isDense: true,
                  prefixIcon: const Icon(Iconsax.card_copy, size: 15),
                ),
              );

              final holderField = TextFormField(
                controller: holderController,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'Beneficiary Holder Name',
                  hintText: 'e.g. Matric Mate / Abebe Kebede',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.user_copy, size: 15),
                ),
              );

              if (isCompact) {
                return Column(
                  children: [
                    accountField,
                    const SizedBox(height: AppSizes.xs),
                    holderField,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: accountField),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(child: holderField),
                ],
              );
            },
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
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 650;

          final labelField = TextFormField(
            initialValue: account.label,
            onChanged: (v) => account.label = v,
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(
              labelText: 'Gateway / Bank Name',
              hintText: 'e.g. Awash Bank / BOA',
              isDense: true,
            ),
          );

          final accountField = TextFormField(
            initialValue: account.account,
            onChanged: (v) => account.account = v,
            keyboardType: TextInputType.phone,
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(
              labelText: 'Account Number',
              hintText: '1000xxxxxxxx',
              isDense: true,
            ),
          );

          final holderField = TextFormField(
            initialValue: account.holder,
            onChanged: (v) => account.holder = v,
            style: const TextStyle(fontSize: 12.5),
            decoration: const InputDecoration(
              labelText: 'Beneficiary Name',
              hintText: 'e.g. Abebe Kebede',
              isDense: true,
            ),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(child: labelField),
                    IconButton(
                      tooltip: 'Remove',
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.xs),
                accountField,
                const SizedBox(height: AppSizes.xs),
                holderField,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: labelField),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: accountField),
              const SizedBox(width: AppSizes.sm),
              Expanded(child: holderField),
              const SizedBox(width: AppSizes.xs),
              IconButton(
                tooltip: 'Remove',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error, size: 18),
                visualDensity: VisualDensity.compact,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) => const Divider(height: 16, thickness: 0.5);
}

// ── App config section ────────────────────────────────────────────────

class _AppConfigSection extends StatelessWidget {
  const _AppConfigSection(this.c);
  final SettingsController c;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: const Icon(Iconsax.tag_2_copy, size: 16, color: AppColors.success),
              ),
              const SizedBox(width: AppSizes.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Pricing & App Configuration',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Dynamic subscription pricing in Ethiopian Birr (ETB) and mobile app links.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),

          const Text(
            'Subscription Plan Rates (ETB)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSizes.sm),

          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final plan6m = TextFormField(
                controller: c.planPrice6Months,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: '6 Months Plan',
                  suffixText: 'ETB',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.calendar_1_copy, size: 15),
                ),
              );

              final plan1y = TextFormField(
                controller: c.planPrice1Year,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: '1 Year Plan (Featured)',
                  suffixText: 'ETB',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.star_1_copy, size: 15),
                ),
              );

              final plan2y = TextFormField(
                controller: c.planPrice2Years,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: '2 Years Plan',
                  suffixText: 'ETB',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.calendar_copy, size: 15),
                ),
              );

              final plan3y = TextFormField(
                controller: c.planPrice3Years,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: '3 Years Plan',
                  suffixText: 'ETB',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.calendar_copy, size: 15),
                ),
              );

              final plan4y = TextFormField(
                controller: c.planPrice4Years,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: '4 Years Plan',
                  suffixText: 'ETB',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.calendar_copy, size: 15),
                ),
              );

              final trialField = TextFormField(
                controller: c.trialCount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'Free Trial Questions Count',
                  hintText: '5',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.task_square_copy, size: 15),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    plan6m,
                    const SizedBox(height: AppSizes.sm),
                    plan1y,
                    const SizedBox(height: AppSizes.sm),
                    plan2y,
                    const SizedBox(height: AppSizes.sm),
                    plan3y,
                    const SizedBox(height: AppSizes.sm),
                    plan4y,
                    const SizedBox(height: AppSizes.sm),
                    trialField,
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: plan6m),
                      const SizedBox(width: AppSizes.md),
                      Expanded(child: plan1y),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(child: plan2y),
                      const SizedBox(width: AppSizes.md),
                      Expanded(child: plan3y),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(child: plan4y),
                      const SizedBox(width: AppSizes.md),
                      Expanded(child: trialField),
                    ],
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSizes.lg),

          const Text(
            'Support & App Links',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSizes.sm),

          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final telegram = TextFormField(
                controller: c.telegramLink,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'Telegram Support Link',
                  hintText: 'https://t.me/matric_mate',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.send_1_copy, size: 15),
                ),
              );

              final share = TextFormField(
                controller: c.shareLink,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'App Share Link',
                  hintText: 'https://matricmate.com/...',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.share_copy, size: 15),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    telegram,
                    const SizedBox(height: AppSizes.sm),
                    share,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: telegram),
                  const SizedBox(width: AppSizes.md),
                  Expanded(child: share),
                ],
              );
            },
          ),
          const SizedBox(height: AppSizes.lg),
          Align(
            alignment: Alignment.centerRight,
            child: Obx(
              () => FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: c.isSavingApp.value ? null : c.saveAppConfig,
                icon: c.isSavingApp.value
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Save Pricing & Links', style: TextStyle(fontWeight: FontWeight.bold)),
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
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: const Icon(Iconsax.security_safe_copy, size: 16, color: AppColors.warning),
              ),
              const SizedBox(width: AppSizes.sm),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Push Notification Webhook Security',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Secret token shared with edge functions to securely authenticate push notifications.',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Obx(
            () => TextFormField(
              controller: c.webhookSecret,
              obscureText: !c.showSecret.value,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              decoration: InputDecoration(
                labelText: 'Webhook Secret Key',
                isDense: true,
                prefixIcon: const Icon(Iconsax.key_copy, size: 15),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Copy to clipboard',
                      icon: const Icon(Icons.copy_rounded, size: 15),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: c.webhookSecret.text));
                        SnackbarHelper.success('Copied', 'Webhook secret copied to clipboard.');
                      },
                    ),
                    IconButton(
                      tooltip: c.showSecret.value ? 'Hide Secret' : 'Show Secret',
                      icon: Icon(
                        c.showSecret.value
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 15,
                      ),
                      onPressed: () => c.showSecret.value = !c.showSecret.value,
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
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                onPressed: c.isSavingWebhook.value ? null : c.saveWebhookSecret,
                icon: c.isSavingWebhook.value
                    ? const SizedBox.square(
                        dimension: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.save_rounded, size: 16),
                label: const Text('Update Webhook Secret', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
