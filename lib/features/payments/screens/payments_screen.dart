import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/payments/controllers/payments_controller.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/screens/payment_detail_screen.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_chips.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

/// The payment review queue.
///
/// This is the highest-stakes screen in the console: it moves money and flips
/// premium access, so it favours correctness over polish. Every action is
/// confirmed, atomic and audited.
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
          _StatusTabs(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          _FilterBar(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          Expanded(child: _Table(controller: controller)),
        ],
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.controller});

  final PaymentsController controller;

  static const _tabs = ['all', 'pending', 'approved', 'rejected'];

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: AppSizes.xs,
        runSpacing: AppSizes.xs,
        children: [
          for (final tab in _tabs)
            ChoiceChip(
              showCheckmark: false,
              selected: controller.activeTab.value == tab,
              onSelected: (_) => controller.changeTab(tab),
              label: Text(
                () {
                  final label = _label(tab);
                  final count = controller.counts[tab];
                  return count == null ? label : '$label ($count)';
                }(),
                style: const TextStyle(fontSize: 11),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }

  String _label(String tab) => switch (tab) {
        'pending' => 'Pending',
        'approved' => 'Approved',
        'rejected' => 'Rejected',
        _ => 'All',
      };
}

class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.controller});
  final PaymentsController controller;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
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
      child: Row(
        children: [
          // ── Search field (collapsed = icon only, expanded = full field) ──
          GestureDetector(
            onTap: _searchExpanded ? null : _expand,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              width: _searchExpanded ? 220 : 34,
              height: 34,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                color: _searchExpanded ? bgColor : Colors.transparent,
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
              ),
              child: AbsorbPointer(
                absorbing: !_searchExpanded,
                child: TextField(
                  controller: widget.controller.searchController,
                  focusNode: _focus,
                  onChanged: widget.controller.onSearchChanged,
                  style: const TextStyle(fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Search by name or email...',
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withValues(alpha: 0.6),
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: widget.controller.searchController,
                      builder: (_, value, _) {
                        if (value.text.isEmpty) return const SizedBox.shrink();
                        return IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 16,
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
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          // ── Filter pills — scrollable so they never overflow the row ────
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Method dropdown pill
                  Obx(
                    () => _FilterDropdown<String?>(
                      borderColor: borderColor,
                      icon: Icons.credit_card_rounded,
                      hint: 'Method',
                      value: widget.controller.methodFilter.value,
                      items: [
                        const DropdownMenuItem(
                            value: null, child: Text('All methods')),
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
                  // Date range pill
                  _DatePill(controller: widget.controller),
                  const SizedBox(width: AppSizes.sm),
                  // Clear (only when a filter is active)
                  Obx(() {
                    final active =
                        widget.controller.methodFilter.value != null ||
                            widget.controller.dateRange.value != null ||
                            widget.controller.searchController.text.isNotEmpty;
                    if (!active) return const SizedBox.shrink();
                    return IconButton(
                      tooltip: 'Clear filters',
                      visualDensity: VisualDensity.compact,
                      onPressed: widget.controller.clearFilters,
                      icon: const Icon(
                        Icons.filter_alt_off_rounded,
                        size: AppSizes.iconSm,
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.controller});

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
        emptyTitle: 'No receipts here',
        emptyMessage: controller.activeTab.value == 'pending'
            ? 'Nothing is waiting for review.'
            : 'No receipts match the current filters.',
        page: controller.page.value,
        pageSize: PaymentsController.pageSize,
        totalCount: controller.counts[controller.activeTab.value],
        onPageChanged: controller.changePage,
        onRowTap: (row) => _openDetail(context, row),
        columns: [
          AdminColumn(
            label: 'STUDENT',
            flex: 2,
            cell: (context, row) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  row.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  row.userEmail,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          AdminColumn(
            label: 'STATUS',
            flex: 1,
            cell: (context, row) => PaymentStatusPill(status: row.status),
          ),
          AdminColumn(
            label: 'METHOD',
            flex: 1,
            cell: (context, row) => PaymentMethodChip(method: row.paymentMethod),
          ),
          AdminColumn(
            label: 'DATE',
            width: 110,
            cell: (context, row) => Text(
              row.createdAt == null
                  ? '—'
                  : DateFormat('d MMM yy, HH:mm').format(row.createdAt!),
              style: const TextStyle(fontSize: 11),
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

          return TextButton(
            onPressed: () => _openDetail(context, row),
            child: Text(row.isPending ? 'Review' : 'View'),
          );
        }),
      ),
    );
  }

  /// A side sheet on wide screens, a full route below — a reviewer on a
  /// desktop keeps the queue in view while working an item.
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

// ── Shared filter pill widgets ───────────────────────────────────────────────

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
      padding: const EdgeInsets.symmetric(horizontal: 10),
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
              const SizedBox(width: 5),
              Text(hint, style: const TextStyle(fontSize: 12)),
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
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
            border: Border.all(color: borderColor),
            color: range != null ? primary.withValues(alpha: 0.06) : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: range != null ? primary : null,
              ),
              const SizedBox(width: 5),
              Text(
                range == null
                    ? 'Any date'
                    : '${DateFormat('d MMM').format(range.start)} – '
                        '${DateFormat('d MMM').format(range.end)}',
                style: TextStyle(
                  fontSize: 12,
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
