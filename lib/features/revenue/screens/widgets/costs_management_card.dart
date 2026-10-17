import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/revenue/controllers/revenue_controller.dart';
import 'package:m_admin/features/revenue/models/revenue_cost_record.dart';
import 'package:m_admin/features/revenue/screens/widgets/add_cost_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Card for displaying and managing entered promotion and operational costs.
class CostsManagementCard extends StatelessWidget {
  const CostsManagementCard({super.key, required this.controller});

  final RevenueController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      child: Obx(() {
        final allCosts = controller.costRecords;
        final periodCosts = controller.periodCostRecords;
        final displayedCosts = controller.displayedCostRecords;
        final isAll = controller.costFilterMode.value == 'all';

        final periodCostsTotal = controller.primaryTotalCosts;
        final allTimeCostsTotal = controller.allTimeTotalCosts;

        final isPriceHidden = controller.isPriceHidden.value;
        final periodCostsStr = isPriceHidden
            ? 'ETB ••••••'
            : '- ETB ${NumberFormat('#,##0.00').format(periodCostsTotal)}';
        final allTimeCostsStr = isPriceHidden
            ? 'ETB ••••••'
            : '- ETB ${NumberFormat('#,##0.00').format(allTimeCostsTotal)}';
        final periodNetStr = isPriceHidden
            ? 'ETB ••••••'
            : 'ETB ${NumberFormat('#,##0.00').format(controller.primaryNetRevenue)}';
        final marginStr = '${controller.primaryProfitMargin.toStringAsFixed(1)}%';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Header Bar ─────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Iconsax.wallet_minus_copy,
                          size: 16,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    'Promotion & Cost Deductions',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: dark
                                          ? Colors.white
                                          : AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444)
                                        .withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${isAll ? allCosts.length : periodCosts.length}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFFEF4444),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              'Costs automatically subtracted from your revenue',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10.5,
                                color: dark
                                    ? Colors.white60
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => AddCostDialog.show(context, controller),
                  icon: const Icon(Iconsax.add_copy, size: 15),
                  label: const Text('Add Cost'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),

            // ── Mini Cost Summary Metrics Strip ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: dark
                    ? AppColors.darkSurface
                    : AppColors.grey.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                border: Border.all(
                  color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  width: 0.8,
                ),
              ),
              child: Wrap(
                spacing: AppSizes.lg,
                runSpacing: AppSizes.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _CostMiniStat(
                    label: 'PERIOD COSTS',
                    value: periodCostsStr,
                    color: const Color(0xFFEF4444),
                    dark: dark,
                  ),
                  _CostMiniStat(
                    label: 'PERIOD NET REVENUE',
                    value: periodNetStr,
                    color: AppColors.success,
                    dark: dark,
                  ),
                  _CostMiniStat(
                    label: 'NET MARGIN',
                    value: marginStr,
                    color: controller.primaryProfitMargin >= 50
                        ? AppColors.success
                        : AppColors.amberAccent,
                    dark: dark,
                  ),
                  _CostMiniStat(
                    label: 'ALL-TIME COSTS',
                    value: allTimeCostsStr,
                    color: AppColors.textSecondary,
                    dark: dark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.md),

            // ── Segmented Scope Filter ──────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: 'period',
                      label: Text('In Period (${periodCosts.length})'),
                    ),
                    ButtonSegment(
                      value: 'all',
                      label: Text('All Costs (${allCosts.length})'),
                    ),
                  ],
                  selected: {controller.costFilterMode.value},
                  onSelectionChanged: (s) {
                    if (s.isNotEmpty) {
                      controller.setCostFilterMode(s.first);
                    }
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 10),
                    ),
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                if (displayedCosts.isNotEmpty)
                  Text(
                    '${displayedCosts.length} ${displayedCosts.length == 1 ? 'record' : 'records'}',
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),

            // ── Cost Entries List / Empty State ────────────────────────────
            if (displayedCosts.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: dark
                      ? AppColors.darkSurface.withValues(alpha: 0.5)
                      : AppColors.lightGrey.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                  border: Border.all(
                    color: dark
                        ? AppColors.darkBorder.withValues(alpha: 0.5)
                        : AppColors.borderPrimary.withValues(alpha: 0.5),
                    strokeAlign: BorderSide.strokeAlignInside,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Iconsax.receipt_discount_copy,
                      size: 32,
                      color: dark ? Colors.white38 : AppColors.textSecondary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isAll
                          ? 'No promotional or operational costs entered yet.'
                          : 'No costs recorded in this selected period.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: dark ? Colors.white70 : AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Enter advertising, Telegram promo, or hosting fees to decrease them from revenue.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => AddCostDialog.show(context, controller),
                      icon: const Icon(Iconsax.add_copy, size: 14),
                      label: const Text('Enter Cost'),
                      style: OutlinedButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        textStyle: const TextStyle(fontSize: 11.5),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedCosts.length,
                separatorBuilder: (context, index) => const SizedBox(height: 6),
                itemBuilder: (context, index) {
                  final cost = displayedCosts[index];
                  final catColor = RevenueCostRecord.getCategoryColor(cost.category);
                  final catIcon = RevenueCostRecord.getCategoryIcon(cost.category);
                  final catLabel = RevenueCostRecord.getCategoryLabel(cost.category);

                  final costStr = isPriceHidden
                      ? 'ETB ••••••'
                      : '- ETB ${NumberFormat('#,##0.00').format(cost.amount)}';

                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSurface : AppColors.white,
                      borderRadius: BorderRadius.circular(
                        AppSizes.borderRadiusSm,
                      ),
                      border: Border.all(
                        color: dark
                            ? AppColors.darkBorder
                            : AppColors.borderPrimary,
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Category Icon
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(catIcon, size: 16, color: catColor),
                        ),
                        const SizedBox(width: 10),

                        // Title, Category, Date, Notes
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      cost.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                        color: dark
                                            ? Colors.white
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1,
                                    ),
                                    decoration: BoxDecoration(
                                      color: catColor.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      catLabel,
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: catColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    DateFormat('MMM d, yyyy').format(cost.date),
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (cost.notes?.isNotEmpty == true) ...[
                                    const Text(
                                      ' • ',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    Flexible(
                                      child: Text(
                                        cost.notes!,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontStyle: FontStyle.italic,
                                          color: dark
                                              ? Colors.white60
                                              : AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Amount (Deducted)
                        Text(
                          costStr,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                        const SizedBox(width: 4),

                        // Action Menu (Edit / Delete)
                        PopupMenuButton<String>(
                          icon: const Icon(
                            Icons.more_vert_rounded,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          tooltip: 'Options',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          onSelected: (val) async {
                            if (val == 'edit') {
                              AddCostDialog.show(
                                context,
                                controller,
                                recordToEdit: cost,
                              );
                            } else if (val == 'delete') {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete Cost?'),
                                  content: Text(
                                    'Delete "${cost.title}" (-ETB ${cost.amount.toStringAsFixed(0)}) and restore revenue?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.error,
                                      ),
                                      onPressed: () =>
                                          Navigator.of(ctx).pop(true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await controller.deleteCostRecord(cost.id);
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Iconsax.edit_2_copy, size: 14),
                                  SizedBox(width: 8),
                                  Text('Edit', style: TextStyle(fontSize: 12)),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(
                                    Iconsax.trash_copy,
                                    size: 14,
                                    color: AppColors.error,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.error,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        );
      }),
    );
  }
}

class _CostMiniStat extends StatelessWidget {
  const _CostMiniStat({
    required this.label,
    required this.value,
    required this.color,
    required this.dark,
  });

  final String label;
  final String value;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: color == AppColors.textSecondary
                ? (dark ? Colors.white : AppColors.textPrimary)
                : color,
          ),
        ),
      ],
    );
  }
}
