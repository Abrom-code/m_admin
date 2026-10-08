import 'package:m_admin/common/widgets/admin_date_filter_pill.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/payments/controllers/payments_controller.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/screens/payment_detail_screen.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_chips.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// The modern payment review queue and audit console.
class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<PaymentsController>();

    return AdminScaffold(
      pageIndex: 1,
      onRefresh: controller.refreshAll,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── 1. Content-Driven Metric Summary Strip ─────────────
          _PaymentMetricRibbon(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),

          // ── 2. Filter & Search Controls ─────────────────────────
          _ModernFilterBar(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),

          // ── 3. Data Table ───────────────────────────────────────
          Expanded(child: _ModernTable(controller: controller)),
        ],
      ),
    );
  }
}

// ── 1. Compact Metric Row (All 4 in a Single Row) ──────────────────────────

class _PaymentMetricRibbon extends StatelessWidget {
  const _PaymentMetricRibbon({required this.controller});

  final PaymentsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final pendingCount = controller.counts['pending'] ?? 0;
      final approvedCount = controller.counts['approved'] ?? 0;
      final rejectedCount = controller.counts['rejected'] ?? 0;
      final allCount = controller.counts['all'] ?? 0;
      final active = controller.activeTab.value;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _CompactRibbonCard(
              label: 'Pending',
              value: '$pendingCount',
              dotColor: AppColors.warning,
              isSelected: active == 'pending',
              onTap: () => controller.changeTab('pending'),
            ),
            const SizedBox(width: 8),
            _CompactRibbonCard(
              label: 'Approved',
              value: NumberFormat('#,##0').format(approvedCount),
              dotColor: AppColors.success,
              isSelected: active == 'approved',
              onTap: () => controller.changeTab('approved'),
            ),
            const SizedBox(width: 8),
            _CompactRibbonCard(
              label: 'Rejected',
              value: NumberFormat('#,##0').format(rejectedCount),
              dotColor: AppColors.error,
              isSelected: active == 'rejected',
              onTap: () => controller.changeTab('rejected'),
            ),
            const SizedBox(width: 8),
            _CompactRibbonCard(
              label: 'All Receipts',
              value: NumberFormat('#,##0').format(allCount),
              dotColor: AppColors.primary,
              isSelected: active == 'all',
              onTap: () => controller.changeTab('all'),
            ),
          ],
        ),
      );
    });
  }
}

class _CompactRibbonCard extends StatelessWidget {
  const _CompactRibbonCard({
    required this.label,
    required this.value,
    required this.dotColor,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color dotColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? dotColor.withValues(alpha: dark ? 0.18 : 0.08)
              : (dark ? AppColors.darkCard : AppColors.white),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
          border: Border.all(
            color: isSelected
                ? dotColor
                : (dark
                    ? AppColors.darkGrey.withValues(alpha: 0.25)
                    : AppColors.borderPrimary.withValues(alpha: 0.7)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (dark ? AppColors.white : AppColors.textPrimary)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  color: dotColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 2. Modern Filter & Search Bar ──────────────────────────────────────────

// ── 2. Modern Filter & Search Bar ──────────────────────────────────────────

class _ModernFilterBar extends StatelessWidget {
  const _ModernFilterBar({required this.controller});
  final PaymentsController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: AppSizes.xs),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 650;

          final searchInput = Container(
            height: 36,
            decoration: BoxDecoration(
              color: dark
                  ? AppColors.darkGrey.withValues(alpha: 0.3)
                  : AppColors.grey.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
            ),
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.onSearchChanged,
              onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Search student name, email...',
                hintStyle: TextStyle(
                  color: AppColors.textSecondary.withValues(alpha: 0.6),
                  fontSize: 12.5,
                ),
                prefixIcon: const Icon(
                  Iconsax.search_normal_copy,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                suffixIcon: ValueListenableBuilder<TextEditingValue>(
                  valueListenable: controller.searchController,
                  builder: (_, value, _) {
                    if (value.text.isEmpty) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: AppColors.textSecondary,
                      ),
                      onPressed: () {
                        controller.searchController.clear();
                        controller.onSearchChanged('');
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      visualDensity: VisualDensity.compact,
                    );
                  },
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          );

          final filterRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Payment Method Dropdown
              Obx(
                () => _FilterDropdown<String?>(
                  borderColor: borderColor,
                  icon: Iconsax.card_copy,
                  hint: 'Method',
                  value: controller.methodFilter.value,
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All methods', style: TextStyle(fontSize: 12)),
                    ),
                    ...PaymentMethodInfo.filterableMethods.map(
                      (m) => DropdownMenuItem(
                        value: m.key,
                        child: Text(m.label, style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                  onChanged: controller.setMethodFilter,
                ),
              ),
              const SizedBox(width: AppSizes.xs),

              // Date Range Pill
              Obx(
                () => AdminDateFilterPill(
                  selectedRange: controller.dateRange.value,
                  onRangeChanged: controller.setDateRange,
                  defaultLabel: 'Payment Date',
                ),
              ),
              const SizedBox(width: AppSizes.xs),

              // Clear Filters Button
              Obx(() {
                final active = controller.methodFilter.value != null ||
                    controller.dateRange.value != null ||
                    controller.searchController.text.isNotEmpty;
                if (!active) return const SizedBox.shrink();
                return IconButton(
                  tooltip: 'Reset filters',
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.clearFilters,
                  icon: const Icon(
                    Icons.filter_alt_off_rounded,
                    size: AppSizes.iconSm,
                    color: AppColors.error,
                  ),
                );
              }),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchInput,
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: filterRow,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchInput),
              const SizedBox(width: AppSizes.sm),
              filterRow,
            ],
          );
        },
      ),
    );
  }
}

// ── 3. Modern Data Table ───────────────────────────────────────────────────

class _ModernTable extends StatelessWidget {
  const _ModernTable({required this.controller});

  final PaymentsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AdminDataTable<PaymentReview>(
        rows: controller.rows.toList(),
        isLoading: controller.isLoading.value,
        error: controller.errorMessage.value,
        onRetry: controller.loadQueue,
        onRefresh: controller.refreshAll,
        emptyTitle: 'No payment receipts found',
        emptyMessage: controller.activeTab.value == 'pending'
            ? 'The review queue is completely cleared! 🎉'
            : 'No receipts match your selected filter criteria.',
        page: controller.page.value,
        pageSize: PaymentsController.pageSize,
        totalCount: controller.totalCount.value,
        onPageChanged: controller.changePage,
        onRowTap: (row) => _openDetail(context, row),
        columns: [
          AdminColumn(
            label: 'STUDENT',
            flex: 3,
            cell: (context, row) => Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              row.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (row.userStream.isNotEmpty) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: (row.userStream.toLowerCase() ==
                                            'natural'
                                        ? AppColors.primary
                                        : AppColors.amberAccent)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                row.userStream,
                                style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: row.userStream.toLowerCase() ==
                                          'natural'
                                      ? AppColors.primary
                                      : AppColors.amberAccent,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        row.userEmail,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AdminColumn(
            label: 'AMOUNT & PLAN',
            flex: 2,
            cell: (context, row) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.amount == null
                      ? '—'
                      : '${row.amount!.toStringAsFixed(0)} ${row.currency}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  row.planLabel,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AdminColumn(
            label: 'METHOD',
            flex: 2,
            cell: (context, row) =>
                PaymentMethodChip(method: row.paymentMethod),
          ),
          AdminColumn(
            label: 'STATUS',
            flex: 1,
            cell: (context, row) => PaymentStatusPill(status: row.status),
          ),
          AdminColumn(
            label: 'SUBMITTED',
            width: 120,
            cell: (context, row) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.createdAt == null
                      ? '—'
                      : DateFormat('d MMM yy').format(row.createdAt!),
                  style: const TextStyle(fontSize: 11),
                ),
                Text(
                  row.createdAt == null
                      ? ''
                      : DateFormat('HH:mm').format(row.createdAt!),
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
        rowActions: (context, row) => Obx(() {
          if (controller.isActing(row.id)) {
            return const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }

          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              backgroundColor: row.isPending
                  ? AppColors.primary
                  : AppColors.grey.withValues(alpha: 0.2),
              foregroundColor: row.isPending
                  ? Colors.white
                  : AppColors.textPrimary,
              elevation: 0,
            ),
            onPressed: () => _openDetail(context, row),
            child: Text(
              row.isPending ? 'Review' : 'View',
              style: const TextStyle(fontSize: 11),
            ),
          );
        }),
      ),
    );
  }

  void _openDetail(BuildContext context, PaymentReview row) {
    FocusManager.instance.primaryFocus?.unfocus();
    final wide = MediaQuery.sizeOf(context).width >= 1200;

    if (wide) {
      showGeneralDialog(
        context: context,
        barrierDismissible: true,
        barrierLabel: 'Payment detail',
        barrierColor: Colors.black54,
        transitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (context, _, _) => Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 900,
            height: double.infinity,
            child: Material(
              child: PaymentDetailScreen(review: row, isSideSheet: true),
            ),
          ),
        ),
        transitionBuilder: (context, animation, _, child) => SlideTransition(
          position: Tween(
            begin: const Offset(1, 0),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
          child: child,
        ),
      );
    } else {
      Get.to(() => PaymentDetailScreen(review: row));
    }
  }
}

// ── Dropdown & Date Filters ────────────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.borderColor,
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final Color borderColor;
  final IconData icon;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T?>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13),
              const SizedBox(width: 4),
              Text(hint, style: const TextStyle(fontSize: 11.5)),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
