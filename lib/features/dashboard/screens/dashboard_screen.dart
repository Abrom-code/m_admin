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
              onTap: () => AdminNavController.instance.changePage(3),
            ),
            _StatCard(
              icon: Iconsax.crown_copy,
              label: 'Paid (active)',
              value: _fmtInt(stats.paidUsers),
              color: AppColors.success,
              onTap: () => AdminNavController.instance.changePage(3),
            ),
            _StatCard(
              icon: Iconsax.profile_delete_copy,
              label: 'Unpaid',
              value: _fmtInt(stats.unpaidUsers),
              color: stats.unpaidUsers > 0
                  ? AppColors.textSecondary
                  : AppColors.darkGrey,
              onTap: stats.unpaidUsers > 0
                  ? () => AdminNavController.instance.changePage(3)
                  : null,
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
              onTap: () => AdminNavController.instance.changePage(3),
            ),
            _StatCard(
              icon: Iconsax.money_recive_copy,
              label: 'Total revenue',
              value: _fmtRevenue(stats.totalRevenue),
              color: AppColors.success,
              onTap: () => _showRevenueDialog(Get.context!),
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

  void _showRevenueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const _RevenueDetailDialog(),
    );
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
            ? const AdminCard(
                child: Center(
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
                  separatorBuilder: (context, index) =>
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
              const Icon(
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

// ── Revenue detail dialog ──────────────────────────────────────────────

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
    // Default to last 30 days
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
                const Icon(
                  Iconsax.money_recive_copy,
                  color: AppColors.success,
                  size: AppSizes.iconMd,
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    'Revenue Details',
                    style: Theme.of(context).textTheme.titleLarge,
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
                      fontSize: 13,
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
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),
            const Text(
              'Revenue by Date Range',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSizes.sm),
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
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSizes.xs),
                            Text(
                              'ETB ${NumberFormat('#,##0.00').format(_rangeRevenue ?? 0)}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
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
              child: const Text('View Payments'),
            ),
          ],
        ),
      ),
    );
  }
}
