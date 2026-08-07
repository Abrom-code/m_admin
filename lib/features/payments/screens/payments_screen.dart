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
    final controller = Get.put(PaymentsController(), permanent: true);

    return AdminScaffold(
      title: 'Payments',
      subtitle: 'Review receipts and grant or withhold premium access',
      scrollable: false,
      actions: [
        Obx(
          () => IconButton(
            tooltip: 'Refresh',
            onPressed: controller.isLoading.value
                ? null
                : controller.refreshAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: AppSizes.sm,
        children: [
          for (final tab in kPaymentTabs)
            ChoiceChip(
              selected: controller.activeTab.value == tab,
              onSelected: (_) => controller.changeTab(tab),
              label: Text(
                controller.counts[tab] == null
                    ? _label(tab)
                    : '${_label(tab)} (${controller.counts[tab]})',
              ),
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

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});

  final PaymentsController controller;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(AppSizes.sm),
      child: Wrap(
        spacing: AppSizes.sm,
        runSpacing: AppSizes.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.onSearchChanged,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search name or email',
                prefixIcon: Icon(Icons.search_rounded, size: AppSizes.iconSm),
              ),
            ),
          ),
          Obx(
            () => SizedBox(
              width: 170,
              child: DropdownButtonFormField<String?>(
                initialValue: controller.methodFilter.value,
                isDense: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Method',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All')),
                  ...PaymentMethodInfo.byKey.entries.map(
                    (e) => DropdownMenuItem(
                      value: e.key,
                      child: Text(e.value.label),
                    ),
                  ),
                ],
                onChanged: controller.setMethodFilter,
              ),
            ),
          ),
          Obx(() {
            final range = controller.dateRange.value;
            return OutlinedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 1)),
                  initialDateRange: range,
                );
                if (picked != null) controller.setDateRange(picked);
              },
              icon: const Icon(
                Icons.calendar_today_rounded,
                size: AppSizes.iconSm,
              ),
              label: Text(
                range == null
                    ? 'Any date'
                    : '${DateFormat('d MMM').format(range.start)} – '
                          '${DateFormat('d MMM').format(range.end)}',
              ),
            );
          }),
          TextButton(
            onPressed: controller.clearFilters,
            child: const Text('Clear'),
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
            label: 'DATE',
            flex: 2,
            cell: (context, row) => Text(
              row.createdAt == null
                  ? '—'
                  : DateFormat('d MMM yyyy, HH:mm').format(row.createdAt!),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          AdminColumn(
            label: 'STUDENT',
            flex: 3,
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
            label: 'METHOD',
            flex: 2,
            cell: (context, row) => PaymentMethodChip(method: row.paymentMethod),
          ),
          AdminColumn(
            label: 'AMOUNT',
            flex: 1,
            numeric: true,
            cell: (context, row) => Text(
              row.amountLabel,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          AdminColumn(
            label: 'STATUS',
            flex: 1,
            cell: (context, row) => PaymentStatusPill(status: row.status),
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
