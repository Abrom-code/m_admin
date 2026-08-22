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

// ── 1. Compact Metric Summary Strip ────────────────────────────────────────

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

      return LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth >= 900
              ? 4
              : (constraints.maxWidth >= 500 ? 2 : 1);

          return GridView(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              crossAxisSpacing: AppSizes.sm,
              mainAxisSpacing: AppSizes.xs,
              mainAxisExtent: 44,
            ),
            shrinkWrap: true,
            primary: false,
            children: [
              _CompactRibbonCard(
                label: 'Pending',
                value: '$pendingCount',
                dotColor: AppColors.warning,
                isSelected: active == 'pending',
                onTap: () => controller.changeTab('pending'),
              ),
              _CompactRibbonCard(
                label: 'Approved',
                value: NumberFormat('#,##0').format(approvedCount),
                dotColor: AppColors.success,
                isSelected: active == 'approved',
                onTap: () => controller.changeTab('approved'),
              ),
              _CompactRibbonCard(
                label: 'Rejected',
                value: NumberFormat('#,##0').format(rejectedCount),
                dotColor: AppColors.error,
                isSelected: active == 'rejected',
                onTap: () => controller.changeTab('rejected'),
              ),
              _CompactRibbonCard(
                label: 'All Receipts',
                value: NumberFormat('#,##0').format(allCount),
                dotColor: AppColors.primary,
                isSelected: active == 'all',
                onTap: () => controller.changeTab('all'),
              ),
            ],
          );
        },
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
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? dotColor.withValues(alpha: dark ? 0.15 : 0.08)
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
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
                const SizedBox(width: 7),
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
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 12.5,
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

class _ModernFilterBar extends StatefulWidget {
  const _ModernFilterBar({required this.controller});
  final PaymentsController controller;

  @override
  State<_ModernFilterBar> createState() => _ModernFilterBarState();
}

class _ModernFilterBarState extends State<_ModernFilterBar> {
  final _focus = FocusNode();
  bool _searchExpanded = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocusChange);
    if (widget.controller.searchController.text.isNotEmpty) {
      _searchExpanded = true;
    }
  }

  void _onFocusChange() {
    if (!_focus.hasFocus && widget.controller.searchController.text.isEmpty) {
      setState(() => _searchExpanded = false);
    }
  }

  void _expand() {
    setState(() => _searchExpanded = true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _focus.removeListener(_onFocusChange);
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final borderColor =
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);
    final bgColor = dark
        ? AppColors.darkGrey.withValues(alpha: 0.3)
        : AppColors.grey.withValues(alpha: 0.1);

    return AdminCard(
      padding: const EdgeInsets.all(AppSizes.sm),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          return Row(
            children: [
              // ── Search Field ──
              GestureDetector(
                onTap: _searchExpanded ? null : _expand,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  width: isNarrow
                      ? (_searchExpanded ? 180 : 34)
                      : (_searchExpanded ? 240 : 34),
                  height: 34,
                  clipBehavior: Clip.hardEdge,
                  decoration: BoxDecoration(
                    color: _searchExpanded ? bgColor : Colors.transparent,
                    borderRadius:
                        BorderRadius.circular(AppSizes.borderRadiusMd),
                  ),
                  child: AbsorbPointer(
                    absorbing: !_searchExpanded,
                    child: TextField(
                      controller: widget.controller.searchController,
                      focusNode: _focus,
                      onChanged: widget.controller.onSearchChanged,
                      style: const TextStyle(fontSize: 12.5),
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: 'Search student name, email...',
                        hintStyle: TextStyle(
                          color: AppColors.textSecondary.withValues(alpha: 0.6),
                          fontSize: 12.5,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 17,
                          color: AppColors.textSecondary,
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: widget.controller.searchController,
                          builder: (_, value, _) {
                            if (value.text.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return IconButton(
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 15,
                                color: AppColors.textSecondary,
                              ),
                              onPressed: () {
                                widget.controller.searchController.clear();
                                widget.controller.onSearchChanged('');
                              },
                              visualDensity: VisualDensity.compact,
                            );
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.sm),

              // ── Filter Pills ──
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      // Payment Method Dropdown
                      Obx(
                        () => _FilterDropdown<String?>(
                          borderColor: borderColor,
                          icon: Iconsax.card_copy,
                          hint: 'Method',
                          value: widget.controller.methodFilter.value,
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All methods'),
                            ),
                            ...PaymentMethodInfo.byKey.entries.map(
                              (e) => DropdownMenuItem(
                                value: e.key,
                                child: Text(e.value.label),
                              ),
                            ),
                          ],
                          onChanged: widget.controller.setMethodFilter,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),

                      // Date Range Pill
                      _DatePill(controller: widget.controller),
                      const SizedBox(width: AppSizes.sm),

                      // Clear Filters Button
                      Obx(() {
                        final active =
                            widget.controller.methodFilter.value != null ||
                                widget.controller.dateRange.value != null ||
                                widget.controller.searchController.text.isNotEmpty;
                        if (!active) return const SizedBox.shrink();
                        return TextButton.icon(
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                          ),
                          onPressed: widget.controller.clearFilters,
                          icon: const Icon(
                            Icons.filter_alt_off_rounded,
                            size: 14,
                            color: AppColors.error,
                          ),
                          label: const Text(
                            'Reset',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: AppColors.error,
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
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
        totalCount: controller.counts[controller.activeTab.value],
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

class _DatePill extends StatelessWidget {
  const _DatePill({required this.controller});

  final PaymentsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final range = controller.dateRange.value;
      final primary = Theme.of(context).colorScheme.primary;
      final borderColor = range != null
          ? primary
          : Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);

      return InkWell(
        onTap: () async {
          final picked = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2024),
            lastDate: DateTime.now().add(const Duration(days: 1)),
            initialDateRange: range,
          );
          if (picked != null) controller.setDateRange(picked);
        },
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
            border: Border.all(color: borderColor),
            color: range != null ? primary.withValues(alpha: 0.06) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.calendar_copy,
                size: 13,
                color: range != null ? primary : null,
              ),
              const SizedBox(width: 4),
              Text(
                range == null
                    ? 'Date'
                    : '${DateFormat('d MMM').format(range.start)} – '
                        '${DateFormat('d MMM').format(range.end)}',
                style: TextStyle(
                  fontSize: 11.5,
                  color: range != null ? primary : null,
                ),
              ),
              if (range != null) ...[
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () => controller.setDateRange(null),
                  child: Icon(
                    Icons.close_rounded,
                    size: 12,
                    color: primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    });
  }
}
