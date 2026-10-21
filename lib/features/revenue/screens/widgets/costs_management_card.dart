import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/revenue/controllers/revenue_controller.dart';
import 'package:m_admin/features/revenue/models/revenue_cost_record.dart';
import 'package:m_admin/features/revenue/models/revenue_income_record.dart';
import 'package:m_admin/features/revenue/screens/widgets/add_cost_dialog.dart';
import 'package:m_admin/features/revenue/screens/widgets/add_revenue_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Card for displaying and managing entered costs/deductions and manual revenue/income.
class CostsManagementCard extends StatefulWidget {
  const CostsManagementCard({super.key, required this.controller});

  final RevenueController controller;

  @override
  State<CostsManagementCard> createState() => _CostsManagementCardState();
}

class _CostsManagementCardState extends State<CostsManagementCard> {
  String _activeTab = 'costs'; // 'costs' or 'income'

  Future<void> _showCostDetailModal(BuildContext context, RevenueCostRecord cost) async {
    final dark = AppHelperFunctions.isDark(context);
    final isPriceHidden = widget.controller.isPriceHidden.value;
    final catColor = RevenueCostRecord.getCategoryColor(cost.category);
    final catIcon = RevenueCostRecord.getCategoryIcon(cost.category);
    final catLabel = RevenueCostRecord.getCategoryLabel(cost.category);
    final amountStr = isPriceHidden
        ? 'ETB ••••••'
        : '- ETB ${NumberFormat('#,##0.00').format(cost.amount)}';

    await showDialog<void>(
      context: context,
      builder: (modalCtx) {
        return Dialog(
          backgroundColor: dark ? AppColors.darkSurface : AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Iconsax.wallet_minus_copy,
                          size: 18,
                          color: Color(0xFFEF4444),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Expense / Cost Details',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: dark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'Promotional & Operational Deduction',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: AppColors.textSecondary,
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Amount Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Deduction Amount',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                amountStr,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFEF4444),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: catColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: catColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(catIcon, size: 13, color: catColor),
                              const SizedBox(width: 5),
                              Text(
                                catLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: catColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Details List
                  _buildModalDetailRow('Title / Purpose', cost.title, Iconsax.text_copy, dark),
                  _buildModalDetailRow('Transaction Date', DateFormat('EEEE, MMMM d, yyyy').format(cost.date), Iconsax.calendar_1_copy, dark),
                  _buildModalDetailRow('Category', catLabel, Iconsax.category_copy, dark),
                  _buildModalDetailRow('Recorded At', DateFormat('MMM d, yyyy • h:mm a').format(cost.createdAt), Iconsax.clock_copy, dark),

                  // Notes Box
                  if (cost.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkCard : AppColors.lightGrey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Iconsax.note_2_copy, size: 13, color: AppColors.textSecondary),
                              SizedBox(width: 6),
                              Text(
                                'Notes & Remarks',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            cost.notes!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: dark ? Colors.white70 : AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Bottom Action Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Iconsax.trash_copy, size: 14),
                        label: const Text('Delete'),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Cost?'),
                              content: Text('Delete "${cost.title}" (-ETB ${cost.amount.toStringAsFixed(0)}) and restore revenue?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await widget.controller.deleteCostRecord(cost.id);
                            if (modalCtx.mounted) Navigator.of(modalCtx).pop();
                          }
                        },
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(modalCtx).pop(),
                            child: const Text('Close'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Iconsax.edit_2_copy, size: 14),
                            label: const Text('Edit Cost'),
                            onPressed: () {
                              Navigator.of(modalCtx).pop();
                              AddCostDialog.show(context, widget.controller, recordToEdit: cost);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showIncomeDetailModal(BuildContext context, RevenueIncomeRecord income) async {
    final dark = AppHelperFunctions.isDark(context);
    final isPriceHidden = widget.controller.isPriceHidden.value;
    final methodColor = RevenueIncomeRecord.getMethodColor(income.paymentMethod);
    final methodIcon = RevenueIncomeRecord.getMethodIcon(income.paymentMethod);
    final methodLabel = RevenueIncomeRecord.getMethodLabel(income.paymentMethod);
    final amountStr = isPriceHidden
        ? 'ETB ••••••'
        : '+ ETB ${NumberFormat('#,##0.00').format(income.amount)}';

    await showDialog<void>(
      context: context,
      builder: (modalCtx) {
        return Dialog(
          backgroundColor: dark ? AppColors.darkSurface : AppColors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Iconsax.wallet_add_copy,
                          size: 18,
                          color: AppColors.success,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Manual Revenue Details',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: dark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                            const Text(
                              'Direct Payment / Manually Recorded Income',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        color: AppColors.textSecondary,
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Amount Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Added Revenue',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                amountStr,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.success,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: methodColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: methodColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(methodIcon, size: 13, color: methodColor),
                              const SizedBox(width: 5),
                              Text(
                                methodLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: methodColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Details List
                  _buildModalDetailRow('Source / Title', income.title, Iconsax.text_copy, dark),
                  _buildModalDetailRow('Payment Date', DateFormat('EEEE, MMMM d, yyyy').format(income.date), Iconsax.calendar_1_copy, dark),
                  _buildModalDetailRow('Payment Method', methodLabel, Iconsax.card_copy, dark),
                  _buildModalDetailRow('Recorded At', DateFormat('MMM d, yyyy • h:mm a').format(income.createdAt), Iconsax.clock_copy, dark),

                  // Notes Box
                  if (income.notes?.isNotEmpty == true) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkCard : AppColors.lightGrey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Iconsax.note_2_copy, size: 13, color: AppColors.textSecondary),
                              SizedBox(width: 6),
                              Text(
                                'Notes & Remarks',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            income.notes!,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: dark ? Colors.white70 : AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // Bottom Action Buttons
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.error,
                          side: const BorderSide(color: AppColors.error),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        icon: const Icon(Iconsax.trash_copy, size: 14),
                        label: const Text('Delete'),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Revenue?'),
                              content: Text('Delete "${income.title}" (+ETB ${income.amount.toStringAsFixed(0)})?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await widget.controller.deleteIncomeRecord(income.id);
                            if (modalCtx.mounted) Navigator.of(modalCtx).pop();
                          }
                        },
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(modalCtx).pop(),
                            child: const Text('Close'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Iconsax.edit_2_copy, size: 14),
                            label: const Text('Edit Revenue'),
                            onPressed: () {
                              Navigator.of(modalCtx).pop();
                              AddRevenueDialog.show(context, widget.controller, recordToEdit: income);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModalDetailRow(String label, String value, IconData icon, bool dark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: dark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      child: Obx(() {
        final allCosts = widget.controller.costRecords;
        final periodCosts = widget.controller.periodCostRecords;
        final displayedCosts = widget.controller.displayedCostRecords;
        final isAll = widget.controller.costFilterMode.value == 'all';

        final allIncome = widget.controller.incomeRecords;
        final periodIncome = widget.controller.periodIncomeRecords;
        final displayedIncome = isAll ? allIncome : periodIncome;

        final periodCostsTotal = widget.controller.primaryTotalCosts;
        final allTimeCostsTotal = widget.controller.allTimeTotalCosts;

        final periodIncomeTotal = widget.controller.primaryManualIncome;
        final allTimeIncomeTotal = widget.controller.allTimeManualIncome;

        final isPriceHidden = widget.controller.isPriceHidden.value;
        final periodCostsStr = isPriceHidden
            ? 'ETB ••••••'
            : '- ETB ${NumberFormat('#,##0.00').format(periodCostsTotal)}';
        final allTimeCostsStr = isPriceHidden
            ? 'ETB ••••••'
            : '- ETB ${NumberFormat('#,##0.00').format(allTimeCostsTotal)}';
        final periodIncomeStr = isPriceHidden
            ? 'ETB ••••••'
            : '+ ETB ${NumberFormat('#,##0.00').format(periodIncomeTotal)}';
        final allTimeIncomeStr = isPriceHidden
            ? 'ETB ••••••'
            : '+ ETB ${NumberFormat('#,##0.00').format(allTimeIncomeTotal)}';
        final periodNetStr = isPriceHidden
            ? 'ETB ••••••'
            : 'ETB ${NumberFormat('#,##0.00').format(widget.controller.primaryNetRevenue)}';
        final marginStr = '${widget.controller.primaryProfitMargin.toStringAsFixed(1)}%';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Top Header Bar ─────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, headerConstraints) {
                final isNarrow = headerConstraints.maxWidth < 620;

                final infoBlock = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (_activeTab == 'income' ? AppColors.success : const Color(0xFFEF4444))
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _activeTab == 'income' ? Iconsax.wallet_add_copy : Iconsax.wallet_minus_copy,
                        size: 16,
                        color: _activeTab == 'income' ? AppColors.success : const Color(0xFFEF4444),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Promotion & Cost Deductions',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: dark ? Colors.white : AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${isAll ? allCosts.length : periodCosts.length} costs',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '${isAll ? allIncome.length : periodIncome.length} income',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.success,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Track manual income and operational expenses to determine net profit',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: dark ? Colors.white60 : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );

                final actionButtons = Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    FilledButton.icon(
                      onPressed: () => AddRevenueDialog.show(context, widget.controller),
                      icon: const Icon(Iconsax.add_copy, size: 14),
                      label: const Text('Add Revenue'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.success,
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: () => AddCostDialog.show(context, widget.controller),
                      icon: const Icon(Iconsax.minus_copy, size: 14),
                      label: const Text('Add Cost'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                );

                if (isNarrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      infoBlock,
                      const SizedBox(height: 10),
                      actionButtons,
                    ],
                  );
                }

                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: infoBlock),
                    const SizedBox(width: 12),
                    actionButtons,
                  ],
                );
              },
            ),
            const SizedBox(height: AppSizes.md),

            // ── Mini Cost Summary Metrics Strip ────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkSurface : AppColors.grey.withValues(alpha: 0.18),
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
                    label: 'MANUAL INCOME',
                    value: periodIncomeStr,
                    color: AppColors.success,
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
                    color: widget.controller.primaryProfitMargin >= 50
                        ? AppColors.success
                        : AppColors.amberAccent,
                    dark: dark,
                  ),
                  _CostMiniStat(
                    label: _activeTab == 'income' ? 'ALL-TIME INCOME' : 'ALL-TIME COSTS',
                    value: _activeTab == 'income' ? allTimeIncomeStr : allTimeCostsStr,
                    color: AppColors.textSecondary,
                    dark: dark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.md),

            // ── Tabs: Costs vs Manual Income ────────────────────────────────
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              alignment: WrapAlignment.spaceBetween,
              children: [
                // Segment for Costs vs Income
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _TabChip(
                      label: 'Costs / Expenses (${isAll ? allCosts.length : periodCosts.length})',
                      isSelected: _activeTab == 'costs',
                      activeColor: const Color(0xFFEF4444),
                      onTap: () => setState(() => _activeTab = 'costs'),
                    ),
                    _TabChip(
                      label: 'Manual Revenue (${isAll ? allIncome.length : periodIncome.length})',
                      isSelected: _activeTab == 'income',
                      activeColor: AppColors.success,
                      onTap: () => setState(() => _activeTab = 'income'),
                    ),
                  ],
                ),

                // Scope Filter (In Period vs All)
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 'period',
                      label: Text('In Period'),
                    ),
                    ButtonSegment(
                      value: 'all',
                      label: Text('All'),
                    ),
                  ],
                  selected: {widget.controller.costFilterMode.value},
                  onSelectionChanged: (s) {
                    if (s.isNotEmpty) {
                      widget.controller.setCostFilterMode(s.first);
                    }
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: WidgetStateProperty.all(
                      const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600),
                    ),
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),

            // ── Records List (Costs or Income) ──────────────────────────────
            if (_activeTab == 'costs') ...[
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
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: () => AddCostDialog.show(context, widget.controller),
                        icon: const Icon(Iconsax.add_copy, size: 14),
                        label: const Text('Enter Cost'),
                        style: OutlinedButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                        onTap: () => _showCostDetailModal(context, cost),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: dark ? AppColors.darkSurface : AppColors.white,
                            borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                            border: Border.all(
                              color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
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
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            cost.title,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: dark ? Colors.white : AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                                          const Text(' • ', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                                          Flexible(
                                            child: Text(
                                              cost.notes!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontStyle: FontStyle.italic,
                                                color: dark ? Colors.white60 : AppColors.textSecondary,
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
                              Text(
                                costStr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.textSecondary),
                                tooltip: 'Options',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onSelected: (val) async {
                                  if (val == 'edit') {
                                    AddCostDialog.show(context, widget.controller, recordToEdit: cost);
                                  } else if (val == 'delete') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Cost?'),
                                        content: Text('Delete "${cost.title}" (-ETB ${cost.amount.toStringAsFixed(0)}) and restore revenue?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await widget.controller.deleteCostRecord(cost.id);
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
                                        Icon(Iconsax.trash_copy, size: 14, color: AppColors.error),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(fontSize: 12, color: AppColors.error)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ] else ...[
              // ── Active Tab == 'income' ─────────────────────────────────────
              if (displayedIncome.isEmpty)
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
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.wallet_add_copy,
                        size: 32,
                        color: dark ? Colors.white38 : AppColors.textSecondary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        isAll
                            ? 'No manual revenue or income recorded yet.'
                            : 'No manual income recorded in this selected period.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: dark ? Colors.white70 : AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        'Record direct bank transfers, bulk subscriptions, or offline cash receipts to add them to revenue.',
                        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: () => AddRevenueDialog.show(context, widget.controller),
                        icon: const Icon(Iconsax.add_copy, size: 14),
                        label: const Text('Add Revenue'),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.success,
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                  itemCount: displayedIncome.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 6),
                  itemBuilder: (context, index) {
                    final income = displayedIncome[index];
                    final methodColor = RevenueIncomeRecord.getMethodColor(income.paymentMethod);
                    final methodIcon = RevenueIncomeRecord.getMethodIcon(income.paymentMethod);
                    final methodLabel = RevenueIncomeRecord.getMethodLabel(income.paymentMethod);

                    final incomeStr = isPriceHidden
                        ? 'ETB ••••••'
                        : '+ ETB ${NumberFormat('#,##0.00').format(income.amount)}';

                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                        onTap: () => _showIncomeDetailModal(context, income),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: dark ? AppColors.darkSurface : AppColors.white,
                            borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                            border: Border.all(
                              color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: methodColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(methodIcon, size: 16, color: methodColor),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            income.title,
                                            style: TextStyle(
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w700,
                                              color: dark ? Colors.white : AppColors.textPrimary,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                          decoration: BoxDecoration(
                                            color: methodColor.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            methodLabel,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: methodColor,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Text(
                                          DateFormat('MMM d, yyyy').format(income.date),
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        if (income.notes?.isNotEmpty == true) ...[
                                          const Text(' • ', style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary)),
                                          Flexible(
                                            child: Text(
                                              income.notes!,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10.5,
                                                fontStyle: FontStyle.italic,
                                                color: dark ? Colors.white60 : AppColors.textSecondary,
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
                              Text(
                                incomeStr,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.success,
                                ),
                              ),
                              const SizedBox(width: 4),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert_rounded, size: 16, color: AppColors.textSecondary),
                                tooltip: 'Options',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onSelected: (val) async {
                                  if (val == 'edit') {
                                    AddRevenueDialog.show(context, widget.controller, recordToEdit: income);
                                  } else if (val == 'delete') {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Delete Revenue?'),
                                        content: Text('Delete "${income.title}" (+ETB ${income.amount.toStringAsFixed(0)})?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
                                            onPressed: () => Navigator.of(ctx).pop(true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await widget.controller.deleteIncomeRecord(income.id);
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
                                        Icon(Iconsax.trash_copy, size: 14, color: AppColors.error),
                                        SizedBox(width: 8),
                                        Text('Delete', style: TextStyle(fontSize: 12, color: AppColors.error)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ],
        );
      }),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : (dark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.04)),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? activeColor : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? activeColor : (dark ? Colors.white70 : AppColors.textPrimary),
          ),
        ),
      ),
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
