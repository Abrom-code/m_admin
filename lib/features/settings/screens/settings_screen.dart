import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/utils/constants/app_env.dart';
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

  // Database health & counts
  final isCheckingDb = false.obs;
  final dbPingMs = (-1).obs;
  final dbError = ''.obs;
  final dbCounts = <String, int>{}.obs;

  String get supabaseUrl => AppEnv.supabaseUrl;

  String get supabaseProjectRef {
    try {
      final uri = Uri.parse(AppEnv.supabaseUrl);
      final host = uri.host;
      if (host.isNotEmpty && host.contains('.')) {
        return host.split('.').first;
      }
      return 'gcscoitnhdrqsibkxrit';
    } catch (_) {
      return 'gcscoitnhdrqsibkxrit';
    }
  }

  // Payment config – 3 official built-in methods (matching student app)
  final isSavingPayment = false.obs;
  final telebirr = TextEditingController(text: '0960586811');
  final telebirrHolder = TextEditingController(text: 'Abrham Teramed');
  final cbeBirr = TextEditingController(text: '1000435011237');
  final cbeBirrHolder = TextEditingController(text: 'Abrham Teramed');
  final abyssinia = TextEditingController(text: '165093089');
  final abyssiniaHolder = TextEditingController(text: 'Abrham Teramed');

  // Extra accounts
  final extraAccounts = <ExtraPaymentAccount>[].obs;

  // Webhook
  final isSavingWebhook = false.obs;
  final webhookSecret = TextEditingController(
      text: 'c00133849321c6b406e2dba06da9a8876b906fa10253277c005a1b6f00bff4ab');
  final showSecret = false.obs;

  // App config & Subscription plan pricing (Single 1-year 200 ETB plan)
  final isSavingApp = false.obs;
  final planPrice1Year = TextEditingController(text: '200');
  final telegramSupportLink =
      TextEditingController(text: 'https://t.me/matericetbot');
  final telegramChannelLink =
      TextEditingController(text: 'https://t.me/MatricET');
  final shareLink = TextEditingController(text: 'https://t.me/matricet');
  final supportEmail = TextEditingController(text: 'abopiatech@gmail.com');
  final privacyPolicyUrl =
      TextEditingController(text: 'https://matricet-privacy.vercel.app/');

  @override
  void onInit() {
    super.onInit();
    loadSettings();
    checkDatabaseHealth();
  }

  @override
  void onClose() {
    cbeBirr.dispose();
    cbeBirrHolder.dispose();
    telebirr.dispose();
    telebirrHolder.dispose();
    abyssinia.dispose();
    abyssiniaHolder.dispose();
    webhookSecret.dispose();
    planPrice1Year.dispose();
    telegramSupportLink.dispose();
    telegramChannelLink.dispose();
    shareLink.dispose();
    supportEmail.dispose();
    privacyPolicyUrl.dispose();
    super.onClose();
  }

  Future<void> checkDatabaseHealth() async {
    isCheckingDb.value = true;
    dbError.value = '';
    final sw = Stopwatch()..start();
    try {
      // Latency ping
      await _sb.from('app_config').select('key').limit(1);
      sw.stop();
      dbPingMs.value = sw.elapsedMilliseconds;

      // Table counts
      final tables = [
        'users',
        'payment_receipts',
        'questions',
        'tests',
        'notes',
        'pilot_exams',
        'leaderboard_challenges',
        'question_reports',
      ];

      final futures = tables.map((t) async {
        try {
          final res = await _sb.from(t).select('id').count(CountOption.exact);
          return MapEntry(t, (res as dynamic).count as int);
        } catch (_) {
          return MapEntry(t, 0);
        }
      });

      final entries = await Future.wait(futures);
      dbCounts.value = Map.fromEntries(entries);
    } catch (e) {
      dbError.value = e.toString();
      dbPingMs.value = -1;
    } finally {
      isCheckingDb.value = false;
    }
  }

  Future<void> loadSettings() async {
    try {
      final rows = await _sb.from('app_config').select('key, value');

      final cfg = <String, String>{};
      for (final row in rows) {
        final key = row['key']?.toString() ?? '';
        final value = row['value']?.toString() ?? '';
        if (key.isNotEmpty) cfg[key] = value;
      }

      // Accounts & Holders loaded directly from Supabase app_config
      if (cfg['payment_telebirr']?.isNotEmpty == true) {
        telebirr.text = cfg['payment_telebirr']!;
      }
      if (cfg['payment_telebirr_holder']?.isNotEmpty == true) {
        telebirrHolder.text = cfg['payment_telebirr_holder']!;
      }

      final cbeAcc = cfg['payment_cbe_birr'] ?? cfg['payment_cbe'];
      if (cbeAcc != null && cbeAcc.isNotEmpty) {
        cbeBirr.text = cbeAcc;
      }
      if (cfg['payment_cbe_birr_holder']?.isNotEmpty == true) {
        cbeBirrHolder.text = cfg['payment_cbe_birr_holder']!;
      }

      if (cfg['payment_abyssinia']?.isNotEmpty == true) {
        abyssinia.text = cfg['payment_abyssinia']!;
      }
      if (cfg['payment_abyssinia_holder']?.isNotEmpty == true) {
        abyssiniaHolder.text = cfg['payment_abyssinia_holder']!;
      }

      if (cfg['webhook_secret']?.isNotEmpty == true) {
        webhookSecret.text = cfg['webhook_secret']!;
      }

      // Subscription price (1-year plan priority, fallback subscription_price)
      final price = cfg['plan_price_1_year'] ??
          cfg['price_1_year'] ??
          cfg['subscription_price'];
      if (price != null && price.isNotEmpty) {
        planPrice1Year.text = price;
      }

      // Official links from Supabase
      final supLink = cfg['telegram_support_link'] ?? cfg['telegram_link'];
      if (supLink != null && supLink.isNotEmpty) {
        telegramSupportLink.text = supLink;
      }

      final chanLink =
          cfg['telegram_channel_link'] ?? cfg['telegram_community_link'];
      if (chanLink != null && chanLink.isNotEmpty) {
        telegramChannelLink.text = chanLink;
      }

      if (cfg['share_link']?.isNotEmpty == true) {
        shareLink.text = cfg['share_link']!;
      }
      if (cfg['support_email']?.isNotEmpty == true) {
        supportEmail.text = cfg['support_email']!;
      }
      if (cfg['privacy_policy_url']?.isNotEmpty == true) {
        privacyPolicyUrl.text = cfg['privacy_policy_url']!;
      }

      _parseExtraAccounts(cfg['payment_extra_accounts'] ?? '');
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
        'payment_telebirr': telebirr.text.trim().isNotEmpty
            ? telebirr.text.trim()
            : '0960586811',
        'payment_telebirr_holder': telebirrHolder.text.trim().isNotEmpty
            ? telebirrHolder.text.trim()
            : 'Abrham Teramed',
        'payment_cbe_birr': cbeBirr.text.trim().isNotEmpty
            ? cbeBirr.text.trim()
            : '1000435011237',
        'payment_cbe_birr_holder': cbeBirrHolder.text.trim().isNotEmpty
            ? cbeBirrHolder.text.trim()
            : 'Abrham Teramed',
        'payment_abyssinia': abyssinia.text.trim().isNotEmpty
            ? abyssinia.text.trim()
            : '165093089',
        'payment_abyssinia_holder': abyssiniaHolder.text.trim().isNotEmpty
            ? abyssiniaHolder.text.trim()
            : 'Abrham Teramed',
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
      final price = planPrice1Year.text.trim().isEmpty
          ? '200'
          : planPrice1Year.text.trim();

      await _upsertMany({
        'plan_price_1_year': price,
        'subscription_price': price,
        'telegram_support_link': telegramSupportLink.text.trim(),
        'telegram_link': telegramSupportLink.text.trim(),
        'telegram_channel_link': telegramChannelLink.text.trim(),
        'share_link': shareLink.text.trim(),
        'support_email': supportEmail.text.trim(),
        'privacy_policy_url': privacyPolicyUrl.text.trim(),
      });
      SnackbarHelper.success(
          'Saved', 'Subscription pricing and official links updated.');
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
      pageIndex: 10,
      onRefresh: () async {
        await controller.loadSettings();
        await controller.checkDatabaseHealth();
      },
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DatabaseOverviewSection(controller),
          const SizedBox(height: AppSizes.spaceBtwSections),
          _StudentAppSection(controller),
          const SizedBox(height: AppSizes.spaceBtwSections),
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

// ── Database Overview Section ─────────────────────────────────────────

class _DatabaseOverviewSection extends StatelessWidget {
  const _DatabaseOverviewSection(this.c);
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
          // Section header
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 540;
              final headerInfo = Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                    ),
                    child: const Icon(Icons.dns_rounded, size: 16, color: AppColors.primary),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  const Expanded(
                    child: Text(
                      'Supabase & Database',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              );

              final pingButton = Obx(
                () => OutlinedButton.icon(
                  onPressed: c.isCheckingDb.value ? null : c.checkDatabaseHealth,
                  icon: c.isCheckingDb.value
                      ? const SizedBox.square(
                          dimension: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 14),
                  label: const Text('Ping / Check Health', style: TextStyle(fontSize: 11.5)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerInfo,
                    const SizedBox(height: AppSizes.sm),
                    pingButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: headerInfo),
                  const SizedBox(width: AppSizes.sm),
                  pingButton,
                ],
              );
            },
          ),
          const SizedBox(height: AppSizes.md),

          // Connectivity & Status banner
          Obx(() {
            final isChecking = c.isCheckingDb.value;
            final ping = c.dbPingMs.value;
            final hasError = c.dbError.value.isNotEmpty;

            final statusColor = hasError
                ? AppColors.error
                : (ping >= 0 ? AppColors.success : AppColors.grey);
            final statusLabel = hasError
                ? 'Connection Error'
                : (isChecking
                    ? 'Testing connection...'
                    : (ping >= 0 ? 'Connected & Operational (${ping}ms latency)' : 'Not checked'));

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: dark ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                border: Border.all(color: statusColor.withValues(alpha: 0.3)),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 540;

                  final statusWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: statusColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );

                  final refWidget = Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          'Ref: ${c.supabaseProjectRef}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        tooltip: 'Copy Project Reference',
                        icon: const Icon(Icons.copy_rounded, size: 14),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: c.supabaseProjectRef));
                          SnackbarHelper.success('Copied', 'Project reference copied.');
                        },
                      ),
                    ],
                  );

                  if (isCompact) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        statusWidget,
                        const SizedBox(height: 6),
                        refWidget,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: statusWidget),
                      const SizedBox(width: AppSizes.sm),
                      refWidget,
                    ],
                  );
                },
              ),
            );
          }),
          const SizedBox(height: AppSizes.md),

          // Quick Console Links
          const Text(
            'Direct Supabase Console Shortcuts',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSizes.xs + 2),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ConsoleButton(
                label: 'Supabase Dashboard',
                icon: Iconsax.monitor_copy,
                onTap: () => AppHelperFunctions.openUrl(
                  'https://supabase.com/dashboard/project/${c.supabaseProjectRef}',
                ),
              ),
              _ConsoleButton(
                label: 'Table Editor',
                icon: Iconsax.grid_2_copy,
                onTap: () => AppHelperFunctions.openUrl(
                  'https://supabase.com/dashboard/project/${c.supabaseProjectRef}/editor',
                ),
              ),
              _ConsoleButton(
                label: 'SQL Query Editor',
                icon: Iconsax.code_copy,
                onTap: () => AppHelperFunctions.openUrl(
                  'https://supabase.com/dashboard/project/${c.supabaseProjectRef}/sql/new',
                ),
              ),
              _ConsoleButton(
                label: 'Storage Buckets',
                icon: Iconsax.folder_2_copy,
                onTap: () => AppHelperFunctions.openUrl(
                  'https://supabase.com/dashboard/project/${c.supabaseProjectRef}/storage/buckets',
                ),
              ),
              _ConsoleButton(
                label: 'Auth Users',
                icon: Iconsax.user_tag_copy,
                onTap: () => AppHelperFunctions.openUrl(
                  'https://supabase.com/dashboard/project/${c.supabaseProjectRef}/auth/users',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),

          // Table Counts Grid
          const Text(
            'Core Database Table Records',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSizes.xs + 2),
          Obx(() {
            final counts = c.dbCounts;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _TableCountPill(
                  label: 'Students',
                  count: counts['users'],
                  icon: Iconsax.people_copy,
                  color: const Color(0xFF007BFF),
                ),
                _TableCountPill(
                  label: 'Payment Receipts',
                  count: counts['payment_receipts'],
                  icon: Iconsax.receipt_copy,
                  color: const Color(0xFF28A745),
                ),
                _TableCountPill(
                  label: 'Questions',
                  count: counts['questions'],
                  icon: Iconsax.message_question_copy,
                  color: const Color(0xFF6F42C1),
                ),
                _TableCountPill(
                  label: 'Tests & Exams',
                  count: counts['tests'],
                  icon: Iconsax.task_copy,
                  color: const Color(0xFFFD7E14),
                ),
                _TableCountPill(
                  label: 'Study Notes',
                  count: counts['notes'],
                  icon: Iconsax.document_copy,
                  color: const Color(0xFF20C997),
                ),
                _TableCountPill(
                  label: 'Pilot Exams',
                  count: counts['pilot_exams'],
                  icon: Iconsax.award_copy,
                  color: const Color(0xFFE83E8C),
                ),
                _TableCountPill(
                  label: 'Challenges',
                  count: counts['leaderboard_challenges'],
                  icon: Iconsax.cup_copy,
                  color: const Color(0xFFFFC107),
                ),
                _TableCountPill(
                  label: 'Reported Questions',
                  count: counts['question_reports'],
                  icon: Iconsax.flag_copy,
                  color: const Color(0xFFDC3545),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ConsoleButton extends StatelessWidget {
  const _ConsoleButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14),
      label: Text(label, style: const TextStyle(fontSize: 11.5)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class _TableCountPill extends StatelessWidget {
  const _TableCountPill({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
  });

  final String label;
  final int? count;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.lightContainer,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        border: Border.all(color: dark ? AppColors.darkBorder : AppColors.borderSecondary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
              ),
              Text(
                count == null ? '—' : '$count rows',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Student App Section ───────────────────────────────────────────────

class _StudentAppSection extends StatelessWidget {
  const _StudentAppSection(this.c);
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
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: const Icon(Iconsax.mobile_copy, size: 16, color: AppColors.info),
              ),
              const SizedBox(width: AppSizes.sm),
              const Expanded(
                child: Text(
                  'MatricMate Student App',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'com.matricmate.app',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.info, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),

          // Overview cards
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              const _AppInfoBadge(
                label: 'Platform',
                value: 'Android (Google Play)',
                icon: Icons.android_rounded,
                color: Colors.green,
              ),
              const _AppInfoBadge(
                label: 'Package ID',
                value: 'com.abopia.matricet',
                icon: Iconsax.mobile_copy,
                color: Colors.teal,
              ),
              const _AppInfoBadge(
                label: 'Audience',
                value: 'Grade 9–12 & Matric',
                icon: Iconsax.book_1_copy,
                color: Colors.blue,
              ),
              AnimatedBuilder(
                animation: c.planPrice1Year,
                builder: (context, _) => _AppInfoBadge(
                  label: '1-Year Subscription',
                  value: 'ETB ${c.planPrice1Year.text.isEmpty ? "200" : c.planPrice1Year.text}',
                  icon: Iconsax.verify_copy,
                  color: AppColors.primary,
                ),
              ),
              const _AppInfoBadge(
                label: 'Payment Methods',
                value: '3 Active (Telebirr, CBE, Abyssinia)',
                icon: Iconsax.wallet_3_copy,
                color: Colors.indigo,
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),

          // Action buttons to test student links
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: () {
                  final link = c.shareLink.text.trim();
                  if (link.isNotEmpty) {
                    AppHelperFunctions.openUrl(link);
                  } else {
                    SnackbarHelper.warning('Missing', 'No app share link configured yet.');
                  }
                },
                icon: const Icon(Icons.open_in_new_rounded, size: 14),
                label: const Text('Play Store / Share Link', style: TextStyle(fontSize: 11.5)),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final t = c.telegramSupportLink.text.trim();
                  if (t.isNotEmpty) {
                    AppHelperFunctions.openUrl(t);
                  } else {
                    SnackbarHelper.warning('Missing', 'No Telegram support bot link configured.');
                  }
                },
                icon: const Icon(Iconsax.message_copy, size: 14),
                label: const Text('Support Bot (@matericetbot)', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final t = c.telegramChannelLink.text.trim();
                  if (t.isNotEmpty) {
                    AppHelperFunctions.openUrl(t);
                  } else {
                    SnackbarHelper.warning('Missing', 'No Telegram channel link configured yet.');
                  }
                },
                icon: const Icon(Iconsax.send_1_copy, size: 14),
                label: const Text('Channel (@MatricET)', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  final p = c.privacyPolicyUrl.text.trim();
                  if (p.isNotEmpty) {
                    AppHelperFunctions.openUrl(p);
                  } else {
                    SnackbarHelper.warning('Missing', 'No privacy policy URL configured.');
                  }
                },
                icon: const Icon(Icons.policy_outlined, size: 14),
                label: const Text('Privacy Policy', style: TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppInfoBadge extends StatelessWidget {
  const _AppInfoBadge({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.lightContainer,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        border: Border.all(color: dark ? AppColors.darkBorder : AppColors.borderSecondary),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontSize: 9.5, color: AppColors.textSecondary)),
              Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
            ],
          ),
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
                child: Text(
                  'Payment Receiving Accounts',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
            accountHint: '0960586811',
          ),
          const _Divider(),
          _BuiltInMethodRow(
            icon: Iconsax.bank_copy,
            label: 'Commercial Bank of Ethiopia (CBE)',
            color: const Color(0xFF7A187B),
            accountController: c.cbeBirr,
            holderController: c.cbeBirrHolder,
            accountHint: '1000435011237',
          ),
          const _Divider(),
          _BuiltInMethodRow(
            icon: Iconsax.bank_copy,
            label: 'Bank of Abyssinia',
            color: const Color(0xFFE89005),
            accountController: c.abyssinia,
            holderController: c.abyssiniaHolder,
            accountHint: '165093089',
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
                  hintText: 'e.g. Abrham Teramed',
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
                child: Text(
                  'Subscription Pricing',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.lg),

          // ── Active Subscription Plan Card ───────────────────────────
          Container(
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: dark ? 0.08 : 0.04),
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Iconsax.star_1_copy, size: 12, color: Colors.white),
                          SizedBox(width: 4),
                          Text(
                            'CURRENT PLAN',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '1-Year Subscription',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 360),
                  child: TextFormField(
                    controller: c.planPrice1Year,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    decoration: const InputDecoration(
                      labelText: 'Subscription Price (ETB)',
                      hintText: '200',
                      suffixText: 'ETB',
                      isDense: true,
                      prefixIcon: Icon(Iconsax.empty_wallet_copy, size: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),

          // ── Support & Official Channels ─────────────────────────────
          const Text(
            'Official Links & Support',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSizes.sm),

          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 650;

              final telegramSupport = TextFormField(
                controller: c.telegramSupportLink,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'Telegram Support Bot',
                  hintText: 'https://t.me/matericetbot',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.message_copy, size: 15),
                ),
              );

              final telegramChannel = TextFormField(
                controller: c.telegramChannelLink,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'Telegram Community Channel',
                  hintText: 'https://t.me/MatricET',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.send_1_copy, size: 15),
                ),
              );

              final share = TextFormField(
                controller: c.shareLink,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'Play Store / App Share Link',
                  hintText: 'https://play.google.com/store/apps/details?id=com.abopia.matricet',
                  isDense: true,
                  prefixIcon: Icon(Iconsax.share_copy, size: 15),
                ),
              );

              final email = TextFormField(
                controller: c.supportEmail,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'Official Support Email',
                  hintText: 'abopiatech@gmail.com',
                  isDense: true,
                  prefixIcon: Icon(Icons.email_outlined, size: 15),
                ),
              );

              final privacy = TextFormField(
                controller: c.privacyPolicyUrl,
                style: const TextStyle(fontSize: 12.5),
                decoration: const InputDecoration(
                  labelText: 'Privacy Policy URL',
                  hintText: 'https://abopia.github.io/matricmate/privacy_policy.html',
                  isDense: true,
                  prefixIcon: Icon(Icons.policy_outlined, size: 15),
                ),
              );

              if (isNarrow) {
                return Column(
                  children: [
                    telegramSupport,
                    const SizedBox(height: AppSizes.sm),
                    telegramChannel,
                    const SizedBox(height: AppSizes.sm),
                    share,
                    const SizedBox(height: AppSizes.sm),
                    email,
                    const SizedBox(height: AppSizes.sm),
                    privacy,
                  ],
                );
              }

              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: telegramSupport),
                      const SizedBox(width: AppSizes.md),
                      Expanded(child: telegramChannel),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      Expanded(child: share),
                      const SizedBox(width: AppSizes.md),
                      Expanded(child: email),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  privacy,
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
                label: const Text('Save Settings', style: TextStyle(fontWeight: FontWeight.bold)),
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
                child: Text(
                  'Webhook Security',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                label: const Text('Save Webhook Secret', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
