import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/charts/bar_chart_painter.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/revenue/controllers/revenue_controller.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Dedicated Revenue Analytics Screen featuring interactive revenue graph,
/// method breakdown, and date range filters.
class RevenueScreen extends StatefulWidget {
  const RevenueScreen({super.key});

  @override
  State<RevenueScreen> createState() => _RevenueScreenState();
}

class _RevenueScreenState extends State<RevenueScreen> {
  int? _selectedIndex;

  Future<void> _pickDateRange(
    BuildContext context,
    RevenueController controller,
  ) async {
    final dark = AppHelperFunctions.isDark(context);
    final now = DateTime.now();
    final initial = controller.customDateRange.value ??
        DateTimeRange(
          start: now.subtract(Duration(
              days: controller.rangeDays.value > 1
                  ? controller.rangeDays.value - 1
                  : 0)),
          end: now,
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: now,
      initialDateRange: initial,
      helpText: 'Select Revenue Dates',
      cancelText: 'Cancel',
      confirmText: 'Apply',
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

    if (picked != null) {
      setState(() => _selectedIndex = null);
      controller.setCustomDateRange(picked);
    }
  }

  Widget _buildMethodTabs(RevenueController controller, bool dark) {
    return Obx(() {
      final activeMethod = controller.selectedMethodFilter.value;

      final tabs = [
        (key: null, label: 'All', color: AppColors.success, icon: Iconsax.category_2_copy),
        (key: 'telebirr', label: 'Telebirr', color: AppColors.primary, icon: Iconsax.wallet_2_copy),
        (key: 'cbe', label: 'CBE', color: AppColors.info, icon: Iconsax.card_copy),
        (key: 'abyssinia', label: 'Abyssinia', color: AppColors.amberAccent, icon: Iconsax.bank_copy),
      ];

      return Container(
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          color: dark
              ? AppColors.darkSurface
              : AppColors.grey.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
          border: Border.all(
            color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
            width: 0.8,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: tabs.map((t) {
            final isSelected = activeMethod == t.key;
            return _MethodTabPill(
              label: t.label,
              icon: t.icon,
              isSelected: isSelected,
              activeColor: t.color,
              onTap: () {
                setState(() => _selectedIndex = null);
                controller.setMethodFilter(t.key);
              },
            );
          }).toList(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RevenueController());
    final dark = AppHelperFunctions.isDark(context);

    return AdminScaffold(
      pageIndex: AdminNavPage.revenue,
      onRefresh: controller.load,
      body: Obx(() {
        if (controller.isLoading.value && controller.revenueSeries.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(AppSizes.xl),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: AppSizes.md),
                  Text(
                    'Loading revenue analytics...',
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
            controller.revenueSeries.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.xl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Iconsax.warning_2_copy, color: AppColors.error, size: 40),
                  const SizedBox(height: AppSizes.md),
                  Text(
                    controller.errorMessage.value!,
                    style: const TextStyle(color: AppColors.error, fontSize: 14),
                  ),
                  const SizedBox(height: AppSizes.md),
                  ElevatedButton(
                    onPressed: controller.load,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── 1. Top Header Bar with Privacy Eye Toggle ───────────────
            _RevenueTopBar(controller: controller),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── 2. The Hero Revenue Graph Card ──────────────────────────
            AdminCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Header Controls ─────────────────────────────────────
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 750;

                      final methodSection = Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'METHOD:',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: dark ? Colors.white60 : AppColors.textSecondary,
                            ),
                          ),
                          _buildMethodTabs(controller, dark),
                        ],
                      );

                      final rangeSelector = Obx(() {
                        final customRange = controller.customDateRange.value;
                        final isCustom = customRange != null;
                        final currentDays = controller.rangeDays.value;

                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            SegmentedButton<int>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(value: 7, label: Text('7d')),
                                ButtonSegment(value: 30, label: Text('30d')),
                                ButtonSegment(value: 90, label: Text('90d')),
                              ],
                              selected: isCustom ? <int>{} : {currentDays},
                              emptySelectionAllowed: true,
                              onSelectionChanged: (s) {
                                if (s.isNotEmpty) {
                                  setState(() => _selectedIndex = null);
                                  controller.setPresetDays(s.first);
                                }
                              },
                              style: ButtonStyle(
                                visualDensity: VisualDensity.compact,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                padding: WidgetStateProperty.all(
                                  const EdgeInsets.symmetric(horizontal: 10),
                                ),
                              ),
                            ),
                            InkWell(
                              onTap: () => _pickDateRange(context, controller),
                              borderRadius:
                                  BorderRadius.circular(AppSizes.borderRadiusSm),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9, vertical: 6.5),
                                decoration: BoxDecoration(
                                  color: isCustom
                                      ? AppColors.primary.withValues(alpha: 0.15)
                                      : (dark
                                          ? AppColors.darkSurface
                                          : AppColors.lightGrey),
                                  borderRadius:
                                      BorderRadius.circular(AppSizes.borderRadiusSm),
                                  border: Border.all(
                                    color: isCustom
                                        ? AppColors.primary
                                        : (dark
                                            ? AppColors.darkBorder
                                            : AppColors.borderPrimary),
                                    width: isCustom ? 1.2 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Iconsax.calendar_1_copy,
                                      size: 14,
                                      color: isCustom
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      isCustom
                                          ? '${DateFormat('d MMM').format(customRange.start)} - ${DateFormat('d MMM').format(customRange.end)}'
                                          : 'Pick Dates',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        fontWeight: isCustom
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        color: isCustom
                                            ? AppColors.primary
                                            : (dark
                                                ? Colors.white70
                                                : AppColors.textPrimary),
                                      ),
                                    ),
                                    if (isCustom) ...[
                                      const SizedBox(width: 5),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() => _selectedIndex = null);
                                          controller.setPresetDays(30);
                                        },
                                        child: const Icon(
                                          Icons.close_rounded,
                                          size: 14,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        );
                      });

                      if (isCompact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            rangeSelector,
                            const SizedBox(height: AppSizes.sm),
                            methodSection,
                          ],
                        );
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          methodSection,
                          const SizedBox(width: 8),
                          Flexible(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: rangeSelector,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: AppSizes.md),

                  // ── Chart Content & Summaries ───────────────────────────
                  Obx(() {
                    final series = controller.revenueSeries;
                    final activeMethod = controller.selectedMethodFilter.value;
                    final days = controller.rangeDays.value;

                    final Color chartColor;
                    switch (activeMethod) {
                      case 'telebirr':
                        chartColor = AppColors.primary;
                        break;
                      case 'cbe':
                        chartColor = AppColors.info;
                        break;
                      case 'abyssinia':
                        chartColor = AppColors.amberAccent;
                        break;
                      default:
                        chartColor = AppColors.success;
                    }

                    final customRange = controller.customDateRange.value;
                    final rangeLabel = customRange != null
                        ? '${DateFormat('d MMM yyyy').format(customRange.start)} - ${DateFormat('d MMM yyyy').format(customRange.end)}'
                        : '$days-day window';

                    if (controller.isChartLoading.value ||
                        (controller.isLoading.value && series.isEmpty)) {
                      return SizedBox(
                        height: 240,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(chartColor),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'Updating revenue chart...',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: dark ? Colors.white60 : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    if (series.isEmpty || series.every((p) => p.value == 0)) {
                      return SizedBox(
                        height: 220,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Iconsax.chart_fail_copy, size: 36, color: AppColors.textSecondary),
                              const SizedBox(height: 8),
                              Text(
                                'No approved revenue recorded for $rangeLabel',
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final total = series.fold(0.0, (sum, p) => sum + p.value);
                    final peak = series.map((p) => p.value).reduce(math.max);
                    final daysCount = series.length > 1 ? series.length : days;
                    final avg = total / (daysCount > 0 ? daysCount : 1);

                    // Clamp selectedIndex
                    if (_selectedIndex != null && _selectedIndex! >= series.length) {
                      _selectedIndex = series.length - 1;
                    }

                    Widget? tooltipWidget;
                    if (_selectedIndex != null && _selectedIndex! < series.length) {
                      final selPoint = series[_selectedIndex!];
                      final String formattedAmount;
                      if (controller.isPriceHidden.value) {
                        formattedAmount = 'ETB ••••••';
                      } else {
                        final base = 'ETB ${NumberFormat('#,##0.00').format(selPoint.value)}';
                        formattedAmount = activeMethod != null
                            ? '$base (${PaymentMethodInfo.labelOf(activeMethod)})'
                            : base;
                      }
                      final formattedDate =
                          DateFormat('MMM d, yyyy').format(selPoint.day);

                      final hasBreakdown = activeMethod == null &&
                          selPoint.methodBreakdown.isNotEmpty;

                      tooltipWidget = Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkSurface : AppColors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: chartColor.withValues(alpha: 0.6),
                            width: 1.2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: dark ? 0.35 : 0.12),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              formattedDate,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              formattedAmount,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: chartColor,
                              ),
                            ),
                            if (hasBreakdown && !controller.isPriceHidden.value) ...[
                              const SizedBox(height: 4),
                              Divider(height: 1, color: dark ? Colors.white12 : Colors.black12),
                              const SizedBox(height: 4),
                              for (final entry in selPoint.methodBreakdown.entries)
                                if (entry.value > 0)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 0.5),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          PaymentMethodInfo.labelOf(entry.key),
                                          style: const TextStyle(
                                            fontSize: 9.5,
                                            color: AppColors.textSecondary,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'ETB ${NumberFormat('#,##0').format(entry.value)}',
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: FontWeight.w700,
                                            color: dark ? Colors.white : AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                            ],
                          ],
                        ),
                      );
                    }

                    final String totalLabel = activeMethod != null
                        ? 'TOTAL (${PaymentMethodInfo.labelOf(activeMethod).toUpperCase()})'
                        : 'TOTAL GROSS REVENUE';

                    final String totalValue = controller.isPriceHidden.value
                        ? 'ETB ••••••'
                        : 'ETB ${NumberFormat('#,##0.00').format(total)}';

                    final String peakValue = controller.isPriceHidden.value
                        ? 'ETB ••••••'
                        : 'ETB ${NumberFormat.compact().format(peak)}';

                    final String avgValue = controller.isPriceHidden.value
                        ? 'ETB ••••••'
                        : 'ETB ${NumberFormat('#,##0').format(avg.round())}';

                    final String allTimeValue = controller.isPriceHidden.value
                        ? 'ETB ••••••'
                        : 'ETB ${NumberFormat('#,##0.00').format(controller.totalRevenueAllTime.value)}';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Content Metrics Bar ──────────────────────────
                        Wrap(
                          spacing: AppSizes.lg,
                          runSpacing: AppSizes.sm,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _MetricStatItem(
                              label: totalLabel,
                              value: totalValue,
                              unit: 'in range',
                              color: chartColor,
                            ),
                            _MetricStatItem(
                              label: 'PEAK DAY',
                              value: peakValue,
                              unit: 'highest day',
                              color: AppColors.textSecondary,
                            ),
                            _MetricStatItem(
                              label: 'DAILY AVERAGE',
                              value: avgValue,
                              unit: 'pace / day',
                              color: AppColors.textSecondary,
                            ),
                            _MetricStatItem(
                              label: 'ALL-TIME REVENUE',
                              value: allTimeValue,
                              unit: 'cumulative',
                              color: AppColors.success,
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.md),

                        // ── Chart Canvas ─────────────────────────────────
                        AdminBarChart(
                          points: series,
                          color: chartColor,
                          height: 240,
                          selectedIndex: _selectedIndex,
                          showBreakdown: activeMethod == null,
                          onPointSelected: (idx) {
                            setState(() => _selectedIndex = idx);
                          },
                          tooltipContent: tooltipWidget,
                        ),
                        const SizedBox(height: 6),

                        // ── Date Axis Labels ─────────────────────────────
                        _XAxisLabels(series: series),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // ── 3. Payment Method Breakdown & Queue Link ────────────────
            _RevenueBreakdownCard(controller: controller),
          ],
        );
      }),
    );
  }
}

// ── 1. Minimal Header Bar ──────────────────────────────────────────────────

class _RevenueTopBar extends StatelessWidget {
  const _RevenueTopBar({required this.controller});

  final RevenueController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Gross Revenue',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: dark ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Financial',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.success,
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Obx(() => OutlinedButton.icon(
              onPressed: controller.togglePriceVisibility,
              icon: Icon(
                controller.isPriceHidden.value
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 16,
              ),
              label: Text(
                controller.isPriceHidden.value ? 'Show Amounts' : 'Hide Amounts',
                style: const TextStyle(fontSize: 12),
              ),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              ),
            )),
          ],
        ),
      ],
    );
  }
}

// ── 3. Breakdown by Payment Method ─────────────────────────────────────────

class _RevenueBreakdownCard extends StatelessWidget {
  const _RevenueBreakdownCard({required this.controller});

  final RevenueController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Obx(() {
      final series = controller.revenueSeries;
      final total = series.fold(0.0, (sum, p) => sum + p.value);
      final priceHidden = controller.isPriceHidden.value;

      final methodTotals = <String, double>{
        'telebirr': 0.0,
        'cbe': 0.0,
        'abyssinia': 0.0,
      };

      for (final p in series) {
        for (final entry in p.methodBreakdown.entries) {
          methodTotals[entry.key] = (methodTotals[entry.key] ?? 0.0) + entry.value;
        }
      }

      final methods = [
        (
          key: 'telebirr',
          label: 'Telebirr',
          color: AppColors.primary,
          icon: Iconsax.wallet_2_copy,
          amt: methodTotals['telebirr'] ?? 0.0,
        ),
        (
          key: 'cbe',
          label: 'Commercial Bank of Ethiopia (CBE)',
          color: AppColors.info,
          icon: Iconsax.card_copy,
          amt: methodTotals['cbe'] ?? 0.0,
        ),
        (
          key: 'abyssinia',
          label: 'Bank of Abyssinia',
          color: AppColors.amberAccent,
          icon: Iconsax.bank_copy,
          amt: methodTotals['abyssinia'] ?? 0.0,
        ),
      ];

      return AdminCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'PAYMENT METHOD BREAKDOWN (SELECTED WINDOW)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                TextButton.icon(
                  onPressed: () =>
                      AdminNavController.instance.changePage(AdminNavPage.payments),
                  icon: const Icon(Iconsax.receipt_item_copy, size: 14),
                  label: const Text('View Payments Queue', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;

                final cards = methods.map((m) {
                  final pct = total > 0 ? (m.amt / total * 100) : 0.0;
                  final formattedAmt = priceHidden
                      ? 'ETB ••••••'
                      : 'ETB ${NumberFormat('#,##0.00').format(m.amt)}';

                  return Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: dark
                          ? AppColors.darkSurface
                          : AppColors.grey.withValues(alpha: 0.2),
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadiusMd),
                      border: Border.all(
                        color: dark
                            ? AppColors.darkBorder
                            : AppColors.borderPrimary,
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: m.color.withValues(alpha: 0.15),
                                borderRadius:
                                    BorderRadius.circular(AppSizes.borderRadiusSm),
                              ),
                              child: Icon(m.icon, size: 16, color: m.color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                m.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: m.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: m.color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSizes.sm),
                        Text(
                          formattedAmt,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList();

                if (isWide) {
                  return Row(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: AppSizes.sm),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  );
                }

                return Column(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(height: AppSizes.sm),
                      cards[i],
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      );
    });
  }
}

// ── Payment Method Tab Pill ─────────────────────────────────────────────────

class _MethodTabPill extends StatelessWidget {
  const _MethodTabPill({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.activeColor,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm - 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5.5),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm - 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 1.5),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 13,
              color: isSelected ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 4.5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Metric Stat Item ────────────────────────────────────────────────────────

class _MetricStatItem extends StatelessWidget {
  const _MetricStatItem({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 2),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color == AppColors.textSecondary
                      ? (dark ? Colors.white : AppColors.textPrimary)
                      : color,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              unit,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── X-axis Labels ───────────────────────────────────────────────────────────

class _XAxisLabels extends StatelessWidget {
  const _XAxisLabels({required this.series});

  final List<DailyPoint> series;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLabels = constraints.maxWidth < 360
            ? 3
            : (constraints.maxWidth < 500 ? 4 : 6);
        final count = series.length < maxLabels ? series.length : maxLabels;
        final step = (series.length - 1) / (count > 1 ? count - 1 : 1);

        final labels = List.generate(count, (i) {
          final idx = (i * step).round().clamp(0, series.length - 1);
          return DateFormat('d MMM').format(series[idx].day);
        });

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map(
                (l) => Text(
                  l,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}
