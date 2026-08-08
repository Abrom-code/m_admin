import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/features/dashboard/controllers/dashboard_controller.dart';
import 'package:m_admin/features/dashboard/screens/widgets/dashboard_chart_cards.dart';
import 'package:m_admin/features/dashboard/screens/widgets/signup_chart_card.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_chips.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DashboardController());

    return AdminScaffold(
      pageIndex: 0,
      onRefresh: controller.load,
      body: Obx(() {
        if (controller.isLoading.value && controller.stats.value == null) {
          return const Padding(
            padding: EdgeInsets.all(AppSizes.xl),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (controller.errorMessage.value != null &&
            controller.stats.value == null) {
          return _ErrorView(
            message: controller.errorMessage.value!,
            onRetry: controller.load,
          );
        }

        final s = controller.stats.value;
        if (s == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _StatGrid(stats: s),
            const SizedBox(height: AppSizes.spaceBtwItems),
            if (s.pendingPayments > 0) _PendingBanner(count: s.pendingPayments),
            if (s.pendingPayments > 0)
              const SizedBox(height: AppSizes.spaceBtwItems),
            const SignupChartCard(),
            const SizedBox(height: AppSizes.spaceBtwItems),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: PaidUnpaidDonutCard()),
                SizedBox(width: AppSizes.spaceBtwItems),
                Expanded(child: StreamSplitCard()),
              ],
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),
            const FunnelCard(),
            const SizedBox(height: AppSizes.spaceBtwItems),
            const SubjectTestCountCard(),
            const SizedBox(height: AppSizes.spaceBtwItems),
            _RecentTable(rows: s.recentReceipts),
          ],
        );
      }),
    );
  }
}

// ── Stat grid ──────────────────────────────────────────────────────────

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 700 ? 3 : 2;
        // Fixed mainAxisExtent prevents overflow when card width is small on
        // narrow screens; childAspectRatio would produce cards shorter than
        // the 44px icon + 32px padding minimum.
        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: AppSizes.spaceBtwItems,
            mainAxisSpacing: AppSizes.spaceBtwItems,
            mainAxisExtent: 90,
          ),
          shrinkWrap: true,
          primary: false,
          children: [
            _StatCard(
              icon: Iconsax.people_copy,
              label: 'Total students',
              value: _fmtInt(stats.totalUsers),
              color: AppColors.primary,
            ),
            _StatCard(
              icon: Iconsax.crown_copy,
              label: 'Paid (active)',
              value: _fmtInt(stats.paidUsers),
              color: AppColors.success,
            ),
            _StatCard(
              icon: Iconsax.profile_delete_copy,
              label: 'Unpaid',
              value: _fmtInt(stats.unpaidUsers),
              color: stats.unpaidUsers > 0
                  ? AppColors.textSecondary
                  : AppColors.darkGrey,
            ),
            _StatCard(
              icon: Iconsax.receipt_copy,
              label: 'Pending review',
              value: _fmtInt(stats.pendingPayments),
              color: stats.pendingPayments > 0
                  ? AppColors.warning
                  : AppColors.darkGrey,
              onTap: stats.pendingPayments > 0
                  ? () => AdminNavController.instance.changePage(1)
                  : null,
            ),
            _StatCard(
              icon: Iconsax.user_add_copy,
              label: 'New this week',
              value: _fmtInt(stats.newUsersThisWeek),
              color: AppColors.info,
            ),
            _StatCard(
              icon: Iconsax.money_recive_copy,
              label: 'Total revenue',
              value: _fmtRevenue(stats.totalRevenue),
              color: AppColors.success,
            ),
          ],
        );
      },
    );
  }

  String _fmtInt(int n) => NumberFormat.compact().format(n);

  String _fmtRevenue(double amount) {
    if (amount >= 1000) {
      return 'ETB ${NumberFormat.compact().format(amount)}';
    }
    return 'ETB ${NumberFormat('#,##0').format(amount)}';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      onTap: onTap,
      child: Row(
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
            ),
            child: Icon(icon, color: color, size: AppSizes.iconMd),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: dark ? AppColors.white : AppColors.textPrimary,
                  ),
                ),
                Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pending banner ─────────────────────────────────────────────────────

class _PendingBanner extends StatelessWidget {
  const _PendingBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AdminNoticeCard(
      color: AppColors.warning,
      icon: Icons.pending_actions_rounded,
      message: '$count receipt${count == 1 ? '' : 's'} waiting for review.',
      action: TextButton(
        onPressed: () => AdminNavController.instance.changePage(1),
        child: const Text('Review now'),
      ),
    );
  }
}

// ── Recent receipts horizontal scroll ─────────────────────────────────

class _RecentTable extends StatelessWidget {
  const _RecentTable({required this.rows});

  final List<RecentReceiptRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            'Recent receipts',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: AppSizes.spaceBtwItems),
        rows.isEmpty
            ? AdminCard(
                child: const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.md),
                    child: Text(
                      'No receipts yet.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              )
            : SizedBox(
                height: 140,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: AppSizes.sm),
                  itemBuilder: (context, i) => _ReceiptCard(row: rows[i]),
                ),
              ),
      ],
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  const _ReceiptCard({required this.row});

  final RecentReceiptRow row;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      width: 220,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        border: Border.all(
          color: dark
              ? AppColors.darkGrey.withValues(alpha: 0.3)
              : AppColors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      row.displayName,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: dark ? AppColors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  PaymentStatusPill(status: row.status),
                ],
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                row.userEmail,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PaymentMethodChip(method: row.paymentMethod),
              if (PaymentMethodInfo.of(row.paymentMethod) case final info?)
                Padding(
                  padding: const EdgeInsets.only(top: AppSizes.xs),
                  child: Text(
                    '${info.account} · ${info.holder}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          Row(
            children: [
              Icon(
                Iconsax.clock_copy,
                size: 12,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  row.createdAt == null
                      ? '—'
                      : DateFormat('d MMM, HH:mm').format(row.createdAt!),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Error view ─────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: AppColors.error,
              size: AppSizes.iconLg,
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: AppSizes.iconSm),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
