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
import 'package:m_admin/features/payments/screens/payment_detail_screen.dart';
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
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: AppSizes.md),
                  Text(
                    'Loading executive dashboard...',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (controller.errorMessage.value != null &&
            controller.stats.value == null) {
          return _ErrorView(
            message: controller.errorMessage.value!,
            onRetry: controller.load,
          );
        }

        final stats = controller.stats.value;
        if (stats == null) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Modern Hero & Welcome Bar ───────────────────────
            _DashboardHeroHeader(
              pendingCount: stats.pendingPayments,
              onRefresh: controller.load,
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── 2. Pending Priority Notice (if any) ────────────────
            if (stats.pendingPayments > 0) ...[
              _PendingAlertBanner(count: stats.pendingPayments),
              const SizedBox(height: AppSizes.spaceBtwItems),
            ],

            // ── 3. Executive KPI Metrics Grid ──────────────────────
            _ExecutiveMetricGrid(stats: stats),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── 4. Main Growth & Revenue Analytics ─────────────────
            const SignupChartCard(),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── 5. Visual Distribution Hub ────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 750) {
                  return const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: PaidUnpaidDonutCard()),
                      SizedBox(width: AppSizes.spaceBtwItems),
                      Expanded(child: StreamSplitCard()),
                    ],
                  );
                }
                return const Column(
                  children: [
                    PaidUnpaidDonutCard(),
                    SizedBox(height: AppSizes.spaceBtwItems),
                    StreamSplitCard(),
                  ],
                );
              },
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── 6. Conversion Funnel ───────────────────────────────
            const FunnelCard(),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── 7. Subject Exam Matrix ─────────────────────────────
            const SubjectTestCountCard(),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── 8. Recent Payment Receipts Hub ─────────────────────
            _ModernRecentReceiptsHub(rows: stats.recentReceipts),
          ],
        );
      }),
    );
  }
}

// ── 1. Hero Header ─────────────────────────────────────────────────────────

class _DashboardHeroHeader extends StatelessWidget {
  const _DashboardHeroHeader({
    required this.pendingCount,
    required this.onRefresh,
  });

  final int pendingCount;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final now = DateTime.now();
    final dateStr = DateFormat('EEEE, d MMMM yyyy').format(now);

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? [
                  AppColors.primary.withValues(alpha: 0.15),
                  AppColors.darkCard,
                ]
              : [
                  AppColors.primary.withValues(alpha: 0.08),
                  AppColors.white,
                ],
        ),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        border: Border.all(
          color: dark
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.primary.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 650;

          final titleSection = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'Welcome back, Admin 👋',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: dark ? AppColors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 7,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Live Sync',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          );

          final quickActions = Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (pendingCount > 0)
                ActionChip(
                  avatar: const Icon(
                    Iconsax.receipt_item_copy,
                    size: 14,
                    color: AppColors.warning,
                  ),
                  label: Text(
                    'Review ($pendingCount)',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.warning,
                    ),
                  ),
                  backgroundColor: AppColors.warning.withValues(alpha: 0.12),
                  side: BorderSide(
                    color: AppColors.warning.withValues(alpha: 0.3),
                  ),
                  onPressed: () =>
                      AdminNavController.instance.changePage(1),
                ),
              ActionChip(
                avatar: const Icon(
                  Iconsax.user_copy,
                  size: 14,
                  color: AppColors.primary,
                ),
                label: const Text(
                  'Students',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () =>
                    AdminNavController.instance.changePage(3),
              ),
              ActionChip(
                avatar: const Icon(
                  Iconsax.book_copy,
                  size: 14,
                  color: AppColors.info,
                ),
                label: const Text(
                  'Tests',
                  style: TextStyle(fontSize: 11.5),
                ),
                onPressed: () =>
                    AdminNavController.instance.changePage(2),
              ),
              IconButton.outlined(
                tooltip: 'Refresh dashboard',
                visualDensity: VisualDensity.compact,
                onPressed: onRefresh,
                icon: const Icon(Iconsax.refresh_copy, size: 15),
              ),
            ],
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                titleSection,
                const SizedBox(height: AppSizes.sm),
                quickActions,
              ],
            );
          }

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              titleSection,
              quickActions,
            ],
          );
        },
      ),
    );
  }
}

// ── 2. Pending Priority Banner ─────────────────────────────────────────────

class _PendingAlertBanner extends StatelessWidget {
  const _PendingAlertBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm + 2,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Iconsax.warning_2_copy,
              color: AppColors.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count Payment Receipt${count == 1 ? '' : 's'} Pending Verification',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.warning,
                  ),
                ),
                const Text(
                  'Students are waiting for exam access approval.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            icon: const Icon(Icons.arrow_forward_rounded, size: 14),
            label: const Text('Review Now', style: TextStyle(fontSize: 11.5)),
            onPressed: () => AdminNavController.instance.changePage(1),
          ),
        ],
      ),
    );
  }
}

// ── 3. Executive KPI Metrics Grid ──────────────────────────────────────────

class _ExecutiveMetricGrid extends StatelessWidget {
  const _ExecutiveMetricGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final conversionRate = stats.totalUsers > 0
        ? (stats.paidUsers / stats.totalUsers * 100).toStringAsFixed(1)
        : '0.0';

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossCount = constraints.maxWidth >= 950
            ? 3
            : (constraints.maxWidth >= 580 ? 2 : 1);

        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossCount,
            crossAxisSpacing: AppSizes.spaceBtwItems,
            mainAxisSpacing: AppSizes.spaceBtwItems,
            mainAxisExtent: 104,
          ),
          shrinkWrap: true,
          primary: false,
          children: [
            _ExecutiveStatCard(
              icon: Iconsax.profile_2user_copy,
              label: 'Total Registered Students',
              value: NumberFormat('#,##0').format(stats.totalUsers),
              badgeText: 'All Time',
              color: AppColors.primary,
              onTap: () => AdminNavController.instance.changePage(3),
            ),
            _ExecutiveStatCard(
              icon: Iconsax.crown_copy,
              label: 'Active Premium Subscribers',
              value: NumberFormat('#,##0').format(stats.paidUsers),
              badgeText: '$conversionRate% of total',
              color: AppColors.success,
              onTap: () => AdminNavController.instance.changePage(3),
            ),
            _ExecutiveStatCard(
              icon: Iconsax.profile_delete_copy,
              label: 'Free / Unpaid Students',
              value: NumberFormat('#,##0').format(stats.unpaidUsers),
              badgeText: 'Upsell target',
              color: stats.unpaidUsers > 0
                  ? AppColors.textSecondary
                  : AppColors.darkGrey,
              onTap: stats.unpaidUsers > 0
                  ? () => AdminNavController.instance.changePage(3)
                  : null,
            ),
            _ExecutiveStatCard(
              icon: Iconsax.receipt_item_copy,
              label: 'Pending Receipt Review',
              value: '${stats.pendingPayments}',
              badgeText: stats.pendingPayments > 0 ? 'Requires Action' : 'Cleared',
              color: stats.pendingPayments > 0
                  ? AppColors.warning
                  : AppColors.success,
              onTap: stats.pendingPayments > 0
                  ? () => AdminNavController.instance.changePage(1)
                  : null,
            ),
            _ExecutiveStatCard(
              icon: Iconsax.user_add_copy,
              label: 'New Registrations This Week',
              value: '+${NumberFormat('#,##0').format(stats.newUsersThisWeek)}',
              badgeText: '7-day momentum',
              color: AppColors.info,
              onTap: () => AdminNavController.instance.changePage(3),
            ),
            _ExecutiveStatCard(
              icon: Iconsax.money_recive_copy,
              label: 'Total Gross Revenue',
              value: _fmtRevenue(stats.totalRevenue),
              badgeText: 'Detailed breakdown ➔',
              color: AppColors.success,
              onTap: () => _showRevenueDialog(Get.context!),
            ),
          ],
        );
      },
    );
  }

  String _fmtRevenue(double amount) {
    if (amount >= 1000000) {
      return 'ETB ${(amount / 1000000).toStringAsFixed(2)}M';
    }
    if (amount >= 1000) {
      return 'ETB ${NumberFormat('#,##0').format(amount)}';
    }
    return 'ETB ${NumberFormat('#,##0.00').format(amount)}';
  }

  void _showRevenueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _RevenueDetailDialog(),
    );
  }
}

class _ExecutiveStatCard extends StatelessWidget {
  const _ExecutiveStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.badgeText,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String badgeText;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.md,
          vertical: AppSizes.sm + 2,
        ),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          border: Border.all(
            color: dark
                ? color.withValues(alpha: 0.2)
                : AppColors.borderPrimary.withValues(alpha: 0.6),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: dark ? 0.15 : 0.1),
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                border: Border.all(
                  color: color.withValues(alpha: 0.25),
                ),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          value,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: dark ? AppColors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 8. Modern Recent Receipts Hub ──────────────────────────────────────────

class _ModernRecentReceiptsHub extends StatelessWidget {
  const _ModernRecentReceiptsHub({required this.rows});

  final List<RecentReceiptRow> rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                  ),
                  child: const Icon(
                    Iconsax.receipt_2_copy,
                    size: 16,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Recent Payment Receipts',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            TextButton.icon(
              onPressed: () {
                AdminNavController.instance.changePage(1); // Go to payments
              },
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('View All Queue'),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSizes.sm),
        rows.isEmpty
            ? const AdminCard(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
                    child: Column(
                      children: [
                        Icon(
                          Iconsax.receipt_item_copy,
                          size: 32,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No payment receipts submitted yet.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
            : SizedBox(
                height: 154,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: rows.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: AppSizes.sm),
                  itemBuilder: (context, i) =>
                      _ModernReceiptCard(row: rows[i]),
                ),
              ),
      ],
    );
  }
}

class _ModernReceiptCard extends StatelessWidget {
  const _ModernReceiptCard({required this.row});

  final RecentReceiptRow row;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      onTap: () {
        // Open review flow for this receipt
        final review = PaymentReview(
          id: row.id.toString(),
          userId: '',
          userName: row.displayName,
          userEmail: row.userEmail,
          userStream: '',
          subscriptionStatus: row.status == 'approved' ? 'active' : 'inactive',
          receiptPath: '',
          receiptUrl: '',
          verificationUrl: '',
          paymentMethod: row.paymentMethod,
          amount: row.amount,
          currency: 'ETB',
          status: row.status,
          createdAt: row.createdAt,
        );
        Get.to(() => PaymentDetailScreen(review: review));
      },
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(AppSizes.sm + 2),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          border: Border.all(
            color: dark
                ? AppColors.darkGrey.withValues(alpha: 0.25)
                : AppColors.borderPrimary.withValues(alpha: 0.7),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                  child: Text(
                    row.displayName.isNotEmpty
                        ? row.displayName[0].toUpperCase()
                        : 'S',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row.displayName,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: dark ? AppColors.white : AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        row.userEmail,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                PaymentStatusPill(status: row.status),
              ],
            ),
            const Divider(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PaymentMethodChip(method: row.paymentMethod),
                Text(
                  '${row.amount.toStringAsFixed(0)} ETB',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: dark ? AppColors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Iconsax.clock_copy,
                      size: 11,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      row.createdAt == null
                          ? '—'
                          : DateFormat('d MMM, HH:mm').format(row.createdAt!),
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
                const Row(
                  children: [
                    Text(
                      'Details',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error View ─────────────────────────────────────────────────────────────

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

// ── Revenue Detail Dialog ──────────────────────────────────────────────────

class _RevenueDetailDialog extends StatefulWidget {
  const _RevenueDetailDialog();

  @override
  State<_RevenueDetailDialog> createState() => _RevenueDetailDialogState();
}

class _RevenueDetailDialogState extends State<_RevenueDetailDialog> {
  DateTimeRange? _selectedRange;
  bool _isLoading = false;
  double? _rangeRevenue;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedRange = DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 30)),
      end: DateTime.now(),
    );
    _loadRevenue();
  }

  Future<void> _loadRevenue() async {
    if (_selectedRange == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repo = DashboardRepository();
      final days = _selectedRange!.end.difference(_selectedRange!.start).inDays;
      final revenueData = await repo.fetchRevenueDaily(days);
      final total = revenueData.fold<double>(0, (sum, point) => sum + point.value);

      setState(() {
        _rangeRevenue = total;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load revenue';
        _isLoading = false;
      });
    }
  }

  Future<void> _pickDateRange() async {
    final dark = AppHelperFunctions.isDark(context);

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
      saveText: 'Apply',
      builder: (context, child) {
        final base = dark ? ThemeData.dark() : ThemeData.light();
        return Theme(
          data: base.copyWith(
            colorScheme: dark
                ? ColorScheme.dark(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: AppColors.darkCard,
                    onSurface: AppColors.white,
                    secondaryContainer: AppColors.primary.withValues(alpha: 0.2),
                    onSecondaryContainer: AppColors.primary,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                    secondaryContainer: AppColors.primary.withValues(alpha: 0.12),
                    onSecondaryContainer: AppColors.primary,
                  ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (range != null) {
      setState(() => _selectedRange = range);
      _loadRevenue();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final controller = Get.find<DashboardController>();

    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                  ),
                  child: const Icon(
                    Iconsax.money_recive_copy,
                    color: AppColors.success,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    'Revenue Breakdown',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  iconSize: AppSizes.iconMd,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total Revenue (All Time)',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSizes.xs),
                  Obx(() {
                    final total = controller.stats.value?.totalRevenue ?? 0;
                    return Text(
                      'ETB ${NumberFormat('#,##0.00').format(total)}',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColors.success,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),
            const Text(
              'Filter by Date Range',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            OutlinedButton.icon(
              onPressed: _pickDateRange,
              icon: const Icon(Iconsax.calendar_copy, size: AppSizes.iconSm),
              label: Text(
                _selectedRange == null
                    ? 'Select date range'
                    : '${DateFormat('MMM d, y').format(_selectedRange!.start)} - ${DateFormat('MMM d, y').format(_selectedRange!.end)}',
              ),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.all(AppSizes.md),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            AdminCard(
              child: _isLoading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppSizes.md),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : _errorMessage != null
                      ? Padding(
                          padding: const EdgeInsets.all(AppSizes.md),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(
                              color: AppColors.error,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Revenue in Selected Range',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              'ETB ${NumberFormat('#,##0.00').format(_rangeRevenue ?? 0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: dark ? AppColors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                AdminNavController.instance.changePage(1); // Go to payments
              },
              child: const Text('View Payments Queue'),
            ),
          ],
        ),
      ),
    );
  }
}
