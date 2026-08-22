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
                    'Loading dashboard...',
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
            // ── 1. Top Header Bar (Clean, Minimal, No Welcome Box) ──
            _DashboardTopBar(
              pendingCount: stats.pendingPayments,
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── 2. Content-Driven KPI Metrics Row ──────────────────
            _ContentKpiGrid(stats: stats),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── 3. Executive Layout ────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 1050;

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Left Column (Main Growth Chart & Exam Coverage) ──
                      const Expanded(
                        flex: 6,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SignupChartCard(),
                            SizedBox(height: AppSizes.spaceBtwItems),
                            SubjectTestCountCard(),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSizes.spaceBtwItems),

                      // ── Right Column (Receipts, Funnel, Distribution) ────
                      Expanded(
                        flex: 5,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _RecentReceiptsQueue(rows: stats.recentReceipts),
                            const SizedBox(height: AppSizes.spaceBtwItems),
                            const FunnelCard(),
                            const SizedBox(height: AppSizes.spaceBtwItems),
                            const PaidUnpaidDonutCard(),
                            const SizedBox(height: AppSizes.spaceBtwItems),
                            const StreamSplitCard(),
                          ],
                        ),
                      ),
                    ],
                  );
                }

                // ── Single Column for Narrow Screens ────────────────
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SignupChartCard(),
                    const SizedBox(height: AppSizes.spaceBtwItems),
                    _RecentReceiptsQueue(rows: stats.recentReceipts),
                    const SizedBox(height: AppSizes.spaceBtwItems),
                    const FunnelCard(),
                    const SizedBox(height: AppSizes.spaceBtwItems),
                    LayoutBuilder(
                      builder: (context, innerConstraints) {
                        if (innerConstraints.maxWidth >= 650) {
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
                    const SubjectTestCountCard(),
                  ],
                );
              },
            ),
          ],
        );
      }),
    );
  }
}

// ── 1. Minimal Header Bar ──────────────────────────────────────────────────

class _DashboardTopBar extends StatelessWidget {
  const _DashboardTopBar({
    required this.pendingCount,
  });

  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 520;

        final titleRow = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Dashboard Overview',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: dark ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.circle, size: 6, color: AppColors.success),
                  SizedBox(width: 4),
                  Text(
                    'Live',
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
        );

        final actionsRow = pendingCount > 0
            ? InkWell(
                onTap: () => AdminNavController.instance.changePage(1),
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.12),
                    borderRadius:
                        BorderRadius.circular(AppSizes.borderRadiusSm),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Iconsax.warning_2_copy,
                        size: 13,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$pendingCount Pending',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : const SizedBox.shrink();

        if (isNarrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleRow,
              if (pendingCount > 0) ...[
                const SizedBox(height: 6),
                actionsRow,
              ],
            ],
          );
        }

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            titleRow,
            actionsRow,
          ],
        );
      },
    );
  }
}

// ── 2. Content-Driven KPI Grid (No Big Icons) ──────────────────────────────

class _ContentKpiGrid extends StatelessWidget {
  const _ContentKpiGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final conversionRate = stats.totalUsers > 0
        ? (stats.paidUsers / stats.totalUsers * 100).toStringAsFixed(1)
        : '0.0';

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = constraints.maxWidth >= 1050
            ? 5
            : (constraints.maxWidth >= 650 ? 3 : 2);

        return GridView(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: count,
            crossAxisSpacing: AppSizes.sm,
            mainAxisSpacing: AppSizes.sm,
            mainAxisExtent: 102,
          ),
          shrinkWrap: true,
          primary: false,
          children: [
            _ContentKpiCard(
              title: 'TOTAL STUDENTS',
              value: NumberFormat('#,##0').format(stats.totalUsers),
              tag: 'All Time',
              tagColor: AppColors.primary,
              subtext: '${stats.newUsersThisWeek} new this week',
              onTap: () => AdminNavController.instance.changePage(3),
            ),
            _ContentKpiCard(
              title: 'ACTIVE PREMIUM',
              value: NumberFormat('#,##0').format(stats.paidUsers),
              tag: '$conversionRate%',
              tagColor: AppColors.success,
              subtext: '${stats.unpaidUsers} free / unpaid',
              onTap: () => AdminNavController.instance.changePage(3),
            ),
            _ContentKpiCard(
              title: 'PENDING REVIEWS',
              value: '${stats.pendingPayments}',
              tag: stats.pendingPayments > 0 ? 'Requires Action' : 'Cleared',
              tagColor: stats.pendingPayments > 0
                  ? AppColors.warning
                  : AppColors.success,
              subtext: stats.pendingPayments > 0
                  ? 'Click to review queue'
                  : 'All verified',
              onTap: stats.pendingPayments > 0
                  ? () => AdminNavController.instance.changePage(1)
                  : null,
            ),
            _ContentKpiCard(
              title: 'NEW REGISTRATIONS',
              value: '+${NumberFormat('#,##0').format(stats.newUsersThisWeek)}',
              tag: '7-day pace',
              tagColor: AppColors.info,
              subtext: 'Weekly momentum',
              onTap: () => AdminNavController.instance.changePage(3),
            ),
            _ContentKpiCard(
              title: 'GROSS REVENUE',
              value: _fmtRevenue(stats.totalRevenue),
              tag: 'ETB Total',
              tagColor: AppColors.success,
              subtext: 'Click for breakdown ➔',
              onTap: () => _showRevenueDialog(Get.context!),
            ),
          ],
        );
      },
    );
  }

  String _fmtRevenue(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(2)}M';
    }
    if (amount >= 1000) {
      return NumberFormat('#,##0').format(amount);
    }
    return NumberFormat('#,##0.00').format(amount);
  }

  void _showRevenueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _RevenueDetailDialog(),
    );
  }
}

class _ContentKpiCard extends StatelessWidget {
  const _ContentKpiCard({
    required this.title,
    required this.value,
    required this.tag,
    required this.tagColor,
    required this.subtext,
    this.onTap,
  });

  final String title;
  final String value;
  final String tag;
  final Color tagColor;
  final String subtext;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
      child: Container(
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
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Category Title & Status Pill
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: tagColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: tagColor,
                    ),
                  ),
                ),
              ],
            ),
            // Middle: Big Clean Metric
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: dark ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            // Bottom: Subtitle info
            Text(
              subtext,
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
    );
  }
}

// ── 3. Recent Payment Receipts Queue ───────────────────────────────────────

class _RecentReceiptsQueue extends StatelessWidget {
  const _RecentReceiptsQueue({required this.rows});

  final List<RecentReceiptRow> rows;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'RECENT PAYMENT SUBMISSIONS',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              InkWell(
                onTap: () => AdminNavController.instance.changePage(1),
                child: const Text(
                  'View All Queue ➔',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          rows.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSizes.md),
                  child: Center(
                    child: Text(
                      'No receipts submitted yet.',
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.take(4).length,
                  separatorBuilder: (context, index) => Divider(
                    height: 12,
                    color: dark
                        ? AppColors.darkGrey.withValues(alpha: 0.15)
                        : AppColors.grey.withValues(alpha: 0.3),
                  ),
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    return InkWell(
                      onTap: () {
                        final review = PaymentReview(
                          id: row.id.toString(),
                          userId: '',
                          userName: row.displayName,
                          userEmail: row.userEmail,
                          userStream: '',
                          subscriptionStatus:
                              row.status == 'approved' ? 'active' : 'inactive',
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
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadiusSm),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    row.displayName,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: dark
                                          ? AppColors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                  Text(
                                    row.userEmail,
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '${row.amount.toStringAsFixed(0)} ETB',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: dark
                                        ? AppColors.white
                                        : AppColors.textPrimary,
                                  ),
                                ),
                                Text(
                                  row.createdAt == null
                                      ? '—'
                                      : DateFormat('d MMM, HH:mm')
                                          .format(row.createdAt!),
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            PaymentStatusPill(status: row.status),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ],
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
      final total =
          revenueData.fold<double>(0, (sum, point) => sum + point.value);

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
                    secondaryContainer:
                        AppColors.primary.withValues(alpha: 0.2),
                    onSecondaryContainer: AppColors.primary,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                    secondaryContainer:
                        AppColors.primary.withValues(alpha: 0.12),
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
        constraints: const BoxConstraints(maxWidth: 480),
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
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
                    'TOTAL REVENUE (ALL TIME)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
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
              'FILTER BY DATE RANGE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: AppColors.textSecondary,
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
                              'REVENUE IN SELECTED RANGE',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              'ETB ${NumberFormat('#,##0.00').format(_rangeRevenue ?? 0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: dark
                                    ? AppColors.white
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                AdminNavController.instance.changePage(1);
              },
              child: const Text('View Payments Queue'),
            ),
          ],
        ),
      ),
    );
  }
}
