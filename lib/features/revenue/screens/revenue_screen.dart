import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/charts/bar_chart_painter.dart';
import 'package:m_admin/common/widgets/charts/line_chart_painter.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/revenue/controllers/revenue_controller.dart';
import 'package:m_admin/features/revenue/screens/widgets/add_cost_dialog.dart';
import 'package:m_admin/features/revenue/screens/widgets/costs_management_card.dart';
import 'package:m_admin/features/security/controllers/app_lock_controller.dart';
import 'package:m_admin/features/security/screens/passcode_setup_dialog.dart';
import 'package:m_admin/features/security/widgets/pin_pad_view.dart';
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
  int? _comparisonSelectedIndex;

  Future<void> _pickDateRange(
    BuildContext context,
    RevenueController controller,
  ) async {
    final dark = AppHelperFunctions.isDark(context);
    final now = DateTime.now();
    final initial =
        controller.customDateRange.value ??
        DateTimeRange(
          start: now.subtract(
            Duration(
              days: controller.rangeDays.value > 1
                  ? controller.rangeDays.value - 1
                  : 0,
            ),
          ),
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
                    secondaryContainer: AppColors.primary.withValues(
                      alpha: 0.2,
                    ),
                    onSecondaryContainer: AppColors.primary,
                  )
                : ColorScheme.light(
                    primary: AppColors.primary,
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                    secondaryContainer: AppColors.primary.withValues(
                      alpha: 0.12,
                    ),
                    onSecondaryContainer: AppColors.primary,
                  ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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

  Future<void> _pickComparisonDateRange(
    BuildContext context,
    RevenueController controller,
  ) async {
    final dark = AppHelperFunctions.isDark(context);
    final now = DateTime.now();
    final initial =
        controller.comparisonCustomRange.value ??
        controller.getComparisonDateRange();

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023, 1, 1),
      lastDate: now,
      initialDateRange: initial,
      helpText: 'Select Comparison Range',
      cancelText: 'Cancel',
      confirmText: 'Apply',
      builder: (context, child) {
        final base = dark ? ThemeData.dark() : ThemeData.light();
        return Theme(
          data: base.copyWith(
            colorScheme: dark
                ? ColorScheme.dark(
                    primary: const Color(0xFF8B5CF6),
                    onPrimary: Colors.white,
                    surface: AppColors.darkCard,
                    onSurface: AppColors.white,
                    secondaryContainer: const Color(
                      0xFF8B5CF6,
                    ).withValues(alpha: 0.2),
                    onSecondaryContainer: const Color(0xFF8B5CF6),
                  )
                : ColorScheme.light(
                    primary: const Color(0xFF8B5CF6),
                    onPrimary: Colors.white,
                    surface: Colors.white,
                    onSurface: Colors.black87,
                    secondaryContainer: const Color(
                      0xFF8B5CF6,
                    ).withValues(alpha: 0.12),
                    onSecondaryContainer: const Color(0xFF8B5CF6),
                  ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF8B5CF6),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedIndex = null);
      controller.setComparisonCustomRange(picked);
    }
  }

  Widget _buildMethodTabs(RevenueController controller, bool dark) {
    return Obx(() {
      final activeMethod = controller.selectedMethodFilter.value;

      final tabs = [
        (
          key: null,
          label: 'All',
          color: AppColors.success,
          icon: Iconsax.category_2_copy,
        ),
        (
          key: 'telebirr',
          label: 'Telebirr',
          color: AppColors.primary,
          icon: Iconsax.wallet_2_copy,
        ),
        (
          key: 'cbe',
          label: 'CBE',
          color: AppColors.info,
          icon: Iconsax.card_copy,
        ),
        (
          key: 'abyssinia',
          label: 'Abyssinia',
          color: AppColors.amberAccent,
          icon: Iconsax.bank_copy,
        ),
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
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
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(RevenueController());
    final dark = AppHelperFunctions.isDark(context);

    return Obx(() {
      final lockCtrl = Get.isRegistered<AppLockController>()
          ? AppLockController.instance
          : null;
      final hasPasscode = lockCtrl?.isPasscodeEnabled.value ?? false;
      final isLocked = controller.isRevenueLocked.value && hasPasscode;

      if (isLocked) {
        return AdminScaffold(
          scrollable: false,
          body: _RevenueLockedView(
            controller: controller,
            lockController: lockCtrl!,
          ),
        );
      }

      return AdminScaffold(
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
                    const Icon(
                      Iconsax.warning_2_copy,
                      color: AppColors.error,
                      size: 40,
                    ),
                    const SizedBox(height: AppSizes.md),
                    Text(
                      controller.errorMessage.value!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 14,
                      ),
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
                                color: dark
                                    ? Colors.white60
                                    : AppColors.textSecondary,
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
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  padding: WidgetStateProperty.all(
                                    const EdgeInsets.symmetric(horizontal: 10),
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () =>
                                    _pickDateRange(context, controller),
                                borderRadius: BorderRadius.circular(
                                  AppSizes.borderRadiusSm,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 6.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isCustom
                                        ? AppColors.primary.withValues(
                                            alpha: 0.15,
                                          )
                                        : (dark
                                              ? AppColors.darkSurface
                                              : AppColors.lightGrey),
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.borderRadiusSm,
                                    ),
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
                                            setState(
                                              () => _selectedIndex = null,
                                            );
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
                              InkWell(
                                onTap: () {
                                  setState(() => _selectedIndex = null);
                                  controller.toggleCompare();
                                },
                                borderRadius: BorderRadius.circular(
                                  AppSizes.borderRadiusSm,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 6.5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: controller.isCompareEnabled.value
                                        ? const Color(
                                            0xFF8B5CF6,
                                          ).withValues(alpha: 0.15)
                                        : (dark
                                              ? AppColors.darkSurface
                                              : AppColors.lightGrey),
                                    borderRadius: BorderRadius.circular(
                                      AppSizes.borderRadiusSm,
                                    ),
                                    border: Border.all(
                                      color: controller.isCompareEnabled.value
                                          ? const Color(0xFF8B5CF6)
                                          : (dark
                                                ? AppColors.darkBorder
                                                : AppColors.borderPrimary),
                                      width: controller.isCompareEnabled.value
                                          ? 1.2
                                          : 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Iconsax.arrow_swap_horizontal_copy,
                                        size: 14,
                                        color: controller.isCompareEnabled.value
                                            ? const Color(0xFF8B5CF6)
                                            : AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        controller.isCompareEnabled.value
                                            ? 'Comparing 2 Gaps'
                                            : 'Compare 2 Gaps',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight:
                                              controller.isCompareEnabled.value
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color:
                                              controller.isCompareEnabled.value
                                              ? const Color(0xFF8B5CF6)
                                              : (dark
                                                    ? Colors.white70
                                                    : AppColors.textPrimary),
                                        ),
                                      ),
                                      if (controller
                                          .isCompareEnabled
                                          .value) ...[
                                        const SizedBox(width: 5),
                                        GestureDetector(
                                          onTap: () {
                                            setState(
                                              () => _selectedIndex = null,
                                            );
                                            controller.toggleCompare();
                                          },
                                          child: const Icon(
                                            Icons.close_rounded,
                                            size: 14,
                                            color: Color(0xFF8B5CF6),
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

                        final viewModeSelector = Obx(() {
                          final currentMode = controller.chartViewMode.value;
                          return SegmentedButton<String>(
                            showSelectedIcon: false,
                            segments: const [
                              ButtonSegment(
                                value: 'net',
                                label: Text('Net (After Costs)'),
                              ),
                              ButtonSegment(
                                value: 'gross',
                                label: Text('Gross'),
                              ),
                            ],
                            selected: {currentMode},
                            onSelectionChanged: (s) {
                              if (s.isNotEmpty) {
                                setState(() => _selectedIndex = null);
                                controller.setChartViewMode(s.first);
                              }
                            },
                            style: ButtonStyle(
                              visualDensity: VisualDensity.compact,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: WidgetStateProperty.all(
                                const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              textStyle: WidgetStateProperty.all(
                                const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          );
                        });

                        if (isCompact) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              rangeSelector,
                              const SizedBox(height: AppSizes.sm),
                              methodSection,
                              const SizedBox(height: AppSizes.sm),
                              Row(
                                children: [
                                  Text(
                                    'VIEW:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: dark
                                          ? Colors.white60
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  viewModeSelector,
                                ],
                              ),
                            ],
                          );
                        }

                        return Column(
                          children: [
                            Row(
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
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'VIEW:',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.6,
                                      color: dark
                                          ? Colors.white60
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  viewModeSelector,
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSizes.md),

                    // ── Chart Content & Summaries ───────────────────────────
                    Obx(() {
                      final rawSeries = controller.revenueSeries;
                      final series = controller.effectiveRevenueSeries;
                      final isNetView = controller.chartViewMode.value == 'net';
                      final activeMethod =
                          controller.selectedMethodFilter.value;
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
                          (controller.isLoading.value && rawSeries.isEmpty)) {
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      chartColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Updating revenue chart...',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: dark
                                        ? Colors.white60
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final hasAnyActivity = rawSeries.any((p) => p.value > 0) ||
                          series.any((p) => p.value != 0) ||
                          controller.periodIncomeRecords.isNotEmpty ||
                          (isNetView && controller.periodCostRecords.isNotEmpty);
                      if (series.isEmpty || !hasAnyActivity) {
                        return SizedBox(
                          height: 220,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Iconsax.chart_fail_copy,
                                  size: 36,
                                  color: AppColors.textSecondary,
                                ),
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

                      final totalGross = controller.primaryTotal;
                      final totalCosts = controller.primaryTotalCosts;
                      final netRevenue = controller.primaryNetRevenue;
                      final profitMargin = controller.primaryProfitMargin;

                      final allTimeNet = controller.allTimeNetRevenue;

                      final peak = series.isNotEmpty
                          ? series.map((p) => p.value).reduce(math.max)
                          : (rawSeries.isNotEmpty
                              ? rawSeries.map((p) => p.value).reduce(math.max)
                              : 0.0);
                      final daysCount = series.length > 1
                          ? series.length
                          : (rawSeries.length > 1 ? rawSeries.length : days);
                      final avg = isNetView
                          ? (netRevenue / (daysCount > 0 ? daysCount : 1))
                          : (totalGross / (daysCount > 0 ? daysCount : 1));

                      // Clamp selectedIndex for main series
                      if (_selectedIndex != null &&
                          _selectedIndex! >= series.length) {
                        _selectedIndex = series.isNotEmpty
                            ? series.length - 1
                            : null;
                      }

                      Widget? tooltipWidget;
                      if (_selectedIndex != null &&
                          _selectedIndex! < series.length) {
                        final selPoint = series[_selectedIndex!];
                        final dayCost = controller.getCostForDay(selPoint.day);
                        final dayIncome = controller.getIncomeForDay(selPoint.day);
                        final isDeficit = isNetView && selPoint.value < 0;

                        final String formattedAmount;
                        if (controller.isPriceHidden.value) {
                          formattedAmount = 'ETB ••••••';
                        } else {
                          final base = isNetView
                              ? (isDeficit
                                  ? 'Deficit: -ETB ${NumberFormat('#,##0.00').format(selPoint.value.abs())}'
                                  : 'Net: ETB ${NumberFormat('#,##0.00').format(selPoint.value)}')
                              : 'ETB ${NumberFormat('#,##0.00').format(selPoint.value)}';
                          formattedAmount = activeMethod != null
                              ? '$base (${PaymentMethodInfo.labelOf(activeMethod)})'
                              : base;
                        }
                        final formattedDate = DateFormat(
                          'MMM d, yyyy',
                        ).format(selPoint.day);

                        final hasBreakdown =
                            activeMethod == null &&
                            selPoint.methodBreakdown.isNotEmpty;

                        final Color tooltipAccentColor = isDeficit
                            ? const Color(0xFFEF4444)
                            : (isNetView && dayCost > 0
                                ? AppColors.success
                                : chartColor);

                        tooltipWidget = Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: dark
                                ? AppColors.darkSurface
                                : AppColors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: tooltipAccentColor.withValues(alpha: 0.8),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: dark ? 0.35 : 0.12,
                                ),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Text(
                                  formattedDate,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (isDeficit) ...[
                                const SizedBox(height: 2),
                                Center(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 5,
                                      vertical: 1.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444)
                                          .withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'DEFICIT (COST > REVENUE)',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w800,
                                        color: Color(0xFFEF4444),
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 2),
                              Center(
                                child: Text(
                                  formattedAmount,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    color: tooltipAccentColor,
                                  ),
                                ),
                              ),
                              if ((dayCost > 0 || dayIncome > 0) && !controller.isPriceHidden.value) ...[
                                const SizedBox(height: 4),
                                Divider(
                                  height: 1,
                                  color: dark ? Colors.white12 : Colors.black12,
                                ),
                                const SizedBox(height: 4),
                                if (dayIncome > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Added: ',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: AppColors.success,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '+ETB ${NumberFormat('#,##0').format(dayIncome)}',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.success,
                                        ),
                                      ),
                                    ],
                                  ),
                                if (dayCost > 0)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'Cost: ',
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          color: Color(0xFFEF4444),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '-ETB ${NumberFormat('#,##0').format(dayCost)}',
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFFEF4444),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                              if (hasBreakdown &&
                                  !controller.isPriceHidden.value) ...[
                                const SizedBox(height: 4),
                                Divider(
                                  height: 1,
                                  color: dark ? Colors.white12 : Colors.black12,
                                ),
                                const SizedBox(height: 4),
                                for (final entry
                                    in selPoint.methodBreakdown.entries)
                                  if (entry.value > 0)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 0.5,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            PaymentMethodInfo.labelOf(
                                              entry.key,
                                            ),
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
                                              color: dark
                                                  ? Colors.white
                                                  : AppColors.textPrimary,
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

                      final String netLabel = activeMethod != null
                          ? 'NET (${PaymentMethodInfo.labelOf(activeMethod).toUpperCase()})'
                          : 'NET REVENUE (PROFIT)';

                      final String netValue = controller.isPriceHidden.value
                          ? 'ETB ••••••'
                          : (netRevenue < 0
                              ? '- ETB ${NumberFormat('#,##0.00').format(netRevenue.abs())}'
                              : 'ETB ${NumberFormat('#,##0.00').format(netRevenue)}');

                      final String grossValue = controller.isPriceHidden.value
                          ? 'ETB ••••••'
                          : 'ETB ${NumberFormat('#,##0.00').format(totalGross)}';

                      final String costsValue = controller.isPriceHidden.value
                          ? 'ETB ••••••'
                          : '- ETB ${NumberFormat('#,##0.00').format(totalCosts)}';

                      final String marginValue = controller.isPriceHidden.value
                          ? '••••'
                          : '${profitMargin.toStringAsFixed(1)}%';

                      final String allTimeNetValue = controller.isPriceHidden.value
                          ? 'ETB ••••••'
                          : (allTimeNet < 0
                              ? '- ETB ${NumberFormat('#,##0.00').format(allTimeNet.abs())}'
                              : 'ETB ${NumberFormat('#,##0.00').format(allTimeNet)}');

                      final String peakValue = controller.isPriceHidden.value
                          ? 'ETB ••••••'
                          : 'ETB ${NumberFormat.compact().format(peak)}';

                      final String avgValue = controller.isPriceHidden.value
                          ? 'ETB ••••••'
                          : (avg < 0
                              ? '- ETB ${NumberFormat('#,##0').format(avg.abs().round())}'
                              : 'ETB ${NumberFormat('#,##0').format(avg.round())}');

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
                                label: netLabel,
                                value: netValue,
                                unit: '',
                                color: netRevenue >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              _MetricStatItem(
                                label: 'GROSS REVENUE',
                                value: grossValue,
                                unit: '',
                                color: chartColor,
                              ),
                              _MetricStatItem(
                                label: 'PROMO & COSTS',
                                value: costsValue,
                                unit: '',
                                color: const Color(0xFFEF4444),
                              ),
                              _MetricStatItem(
                                label: 'NET MARGIN',
                                value: marginValue,
                                unit: '',
                                color: profitMargin >= 50
                                    ? AppColors.success
                                    : (profitMargin >= 0
                                        ? AppColors.amberAccent
                                        : AppColors.error),
                              ),
                              _MetricStatItem(
                                label: 'ALL-TIME NET',
                                value: allTimeNetValue,
                                unit: '',
                                color: allTimeNet >= 0
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                              _MetricStatItem(
                                label: 'PEAK DAY',
                                value: peakValue,
                                unit: '',
                                color: AppColors.textSecondary,
                              ),
                              _MetricStatItem(
                                label: 'DAILY AVERAGE',
                                value: avgValue,
                                unit: '',
                                color: avg >= 0
                                    ? AppColors.textSecondary
                                    : AppColors.error,
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.md),

                          // ── Chart Canvas (Main Standalone Single-Series Graph) ──
                          AdminBarChart(
                            points: series,
                            color: isNetView ? AppColors.success : chartColor,
                            height: 240,
                            selectedIndex: _selectedIndex,
                            showBreakdown: !isNetView && activeMethod == null,
                            onPointSelected: (idx) {
                              setState(() => _selectedIndex = idx);
                            },
                            tooltipContent: tooltipWidget,
                          ),
                          const SizedBox(height: 6),

                          // ── Date Axis Labels ─────────────────────────────
                          _XAxisLabels(series: series),

                          // ── Selected Day Price & Details Banner ──────────
                          if (_selectedIndex != null &&
                              _selectedIndex! < series.length) ...[
                            const SizedBox(height: AppSizes.sm),
                            _SelectedDayBanner(
                              point: series[_selectedIndex!],
                              activeMethod: activeMethod,
                              isNetView: isNetView,
                              chartColor: chartColor,
                              dayCost: controller.getCostForDay(series[_selectedIndex!].day),
                              dayIncome: controller.getIncomeForDay(series[_selectedIndex!].day),
                              isPriceHidden: controller.isPriceHidden.value,
                              onClose: () => setState(() => _selectedIndex = null),
                            ),
                          ],
                        ],
                      );
                    }),
                  ],
                ),
              ),

              // ── 3. Promotion & Operational Costs Card ───────────────────────
              const SizedBox(height: AppSizes.spaceBtwItems),
              CostsManagementCard(controller: controller),

              // ── 4. Dedicated Time Length Comparison Box with its own Graph ──
              Obx(() {
                if (!controller.isCompareEnabled.value) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: AppSizes.spaceBtwItems),
                  child: RevenueComparisonCard(
                    controller: controller,
                    selectedIndex: _comparisonSelectedIndex,
                    onPointSelected: (idx) {
                      setState(() => _comparisonSelectedIndex = idx);
                    },
                    onClose: () {
                      setState(() => _comparisonSelectedIndex = null);
                      controller.toggleCompare();
                    },
                    onPickGap1Range: () => _pickDateRange(context, controller),
                    onPickGap2Range: () =>
                        _pickComparisonDateRange(context, controller),
                    onPickCustomRange: () =>
                        _pickComparisonDateRange(context, controller),
                  ),
                );
              }),
            ],
          );
        }),
      );
    });
  }
}

// ── Dedicated Time Length Comparison Box with its own Graph ─────────────────

class RevenueComparisonCard extends StatelessWidget {
  const RevenueComparisonCard({
    super.key,
    required this.controller,
    required this.selectedIndex,
    required this.onPointSelected,
    required this.onClose,
    this.onPickGap1Range,
    this.onPickGap2Range,
    this.onPickCustomRange,
  });

  final RevenueController controller;
  final int? selectedIndex;
  final ValueChanged<int?> onPointSelected;
  final VoidCallback onClose;
  final VoidCallback? onPickGap1Range;
  final VoidCallback? onPickGap2Range;
  final VoidCallback? onPickCustomRange;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      child: Obx(() {
        final isNet = controller.chartViewMode.value == 'net';
        final series = controller.effectiveRevenueSeries;
        final compSeries = controller.effectiveComparisonSeries;
        final activeMethod = controller.selectedMethodFilter.value;

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
        const compColor = Color(0xFF8B5CF6);

        final primRange = controller.getPrimaryDateRange();
        final compRange = controller.getComparisonDateRange();
        final primDays = primRange.end.difference(primRange.start).inDays + 1;
        final compDays = compRange.end.difference(compRange.start).inDays + 1;
        final selectedOption = controller.compareOption.value;

        // Gap 1 active preset calculation
        final String gap1Current;
        if (controller.customDateRange.value != null) {
          gap1Current = 'custom';
        } else if (controller.rangeDays.value == 7) {
          gap1Current = '7d';
        } else if (controller.rangeDays.value == 14) {
          gap1Current = '14d';
        } else if (controller.rangeDays.value == 30) {
          gap1Current = '30d';
        } else if (controller.rangeDays.value == 90) {
          gap1Current = '90d';
        } else {
          gap1Current = '${controller.rangeDays.value}d';
        }

        final total = isNet ? controller.primaryNetRevenue : controller.primaryTotal;
        final compTotal = isNet ? controller.comparisonNetRevenue : controller.comparisonTotal;
        final growthPct = isNet ? controller.netRevenueGrowthPercentage : controller.revenueGrowthPercentage;
        final growthAbs = isNet ? controller.netRevenueGrowthAbsolute : controller.revenueGrowthAbsolute;
        final isPosGrowth = growthAbs >= 0;

        final String totalValue = controller.isPriceHidden.value
            ? 'ETB ••••••'
            : 'ETB ${NumberFormat('#,##0.00').format(total)}';
        final String compTotalValue = controller.isPriceHidden.value
            ? 'ETB ••••••'
            : 'ETB ${NumberFormat('#,##0.00').format(compTotal)}';

        // Convert series to LinePoints for AdminLineChart
        final totalSlots = math.max(series.length, compSeries.length);
        final List<LinePoint> linePoints = [];
        final List<LinePoint> compLinePoints = [];

        for (int i = 0; i < totalSlots; i++) {
          final normX = totalSlots > 1 ? (i / (totalSlots - 1)) : 0.0;
          if (i < series.length) {
            linePoints.add(LinePoint(normX, series[i].value));
          }
          if (i < compSeries.length) {
            compLinePoints.add(
              LinePoint(normX, compSeries[i].value),
            );
          }
        }

        // Active point inspection data (when hovering or tapping on chart)
        String? p1Str;
        String? p2Str;
        String? date1;
        String? date2;
        double diffVal = 0;
        double diffPct = 0;
        bool isPos = true;

        if (selectedIndex != null &&
            (series.isNotEmpty || compSeries.isNotEmpty)) {
          final selIdx = selectedIndex!;
          final selPoint = selIdx < series.length ? series[selIdx] : null;
          final compPoint = selIdx < compSeries.length
              ? compSeries[selIdx]
              : null;

          final double val1 = selPoint?.value ?? 0;
          final double val2 = compPoint?.value ?? 0;

          p1Str = controller.isPriceHidden.value
              ? 'ETB ••••••'
              : (val1 < 0
                  ? '-ETB ${NumberFormat('#,##0.00').format(val1.abs())}'
                  : 'ETB ${NumberFormat('#,##0.00').format(val1)}');
          p2Str = controller.isPriceHidden.value
              ? 'ETB ••••••'
              : (val2 < 0
                  ? '-ETB ${NumberFormat('#,##0.00').format(val2.abs())}'
                  : 'ETB ${NumberFormat('#,##0.00').format(val2)}');

          diffVal = val1 - val2;
          diffPct = val2.abs() > 0
              ? (diffVal / val2.abs()) * 100
              : (val1 != 0 ? 100.0 : 0.0);
          isPos = diffVal >= 0;

          date1 = selPoint != null
              ? DateFormat('MMM d').format(selPoint.day)
              : '—';
          date2 = compPoint != null
              ? DateFormat('MMM d').format(compPoint.day)
              : '—';
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Clean Compare Header ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: compColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(7),
                        ),
                        child: const Icon(
                          Iconsax.arrow_swap_horizontal_copy,
                          size: 15,
                          color: compColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Compare Revenue Gaps',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: dark ? Colors.white : AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: 'Close comparison',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),

            // ── Two Picking Boxes (Time Gap 1 & Time Gap 2) ───────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final isTwoColumn = constraints.maxWidth >= 600;

                final gap1Box = _PickingBox(
                  title: 'Time Gap 1',
                  accentColor: chartColor,
                  dateRangeText:
                      '${DateFormat('d MMM yyyy').format(primRange.start)} – ${DateFormat('d MMM yyyy').format(primRange.end)}',
                  days: primDays,
                  totalAmount: totalValue,
                  dark: dark,
                  chips: [
                    _buildCompareChip(
                      label: '7 Days',
                      value: '7d',
                      current: gap1Current,
                      onTap: () => controller.setPresetDays(7),
                      dark: dark,
                      activeColor: chartColor,
                    ),
                    _buildCompareChip(
                      label: '14 Days',
                      value: '14d',
                      current: gap1Current,
                      onTap: () => controller.setPresetDays(14),
                      dark: dark,
                      activeColor: chartColor,
                    ),
                    _buildCompareChip(
                      label: '30 Days',
                      value: '30d',
                      current: gap1Current,
                      onTap: () => controller.setPresetDays(30),
                      dark: dark,
                      activeColor: chartColor,
                    ),
                    _buildCompareChip(
                      label: '90 Days',
                      value: '90d',
                      current: gap1Current,
                      onTap: () => controller.setPresetDays(90),
                      dark: dark,
                      activeColor: chartColor,
                    ),
                    _buildCompareChip(
                      label: gap1Current == 'custom' &&
                              controller.customDateRange.value != null
                          ? '${DateFormat('d MMM').format(controller.customDateRange.value!.start)} - ${DateFormat('d MMM').format(controller.customDateRange.value!.end)}'
                          : 'Custom Range...',
                      value: 'custom',
                      current: gap1Current,
                      onTap: () => onPickGap1Range?.call(),
                      dark: dark,
                      activeColor: chartColor,
                      icon: Iconsax.calendar_1_copy,
                    ),
                  ],
                );

                final gap2Box = _PickingBox(
                  title: 'Time Gap 2',
                  accentColor: compColor,
                  dateRangeText:
                      '${DateFormat('d MMM yyyy').format(compRange.start)} – ${DateFormat('d MMM yyyy').format(compRange.end)}',
                  days: compDays,
                  totalAmount: compTotalValue,
                  dark: dark,
                  chips: [
                    _buildCompareChip(
                      label: 'Previous Period',
                      value: 'previous',
                      current: selectedOption,
                      onTap: () => controller.setCompareOption('previous'),
                      dark: dark,
                      activeColor: compColor,
                    ),
                    _buildCompareChip(
                      label: '7 Days',
                      value: '7d',
                      current: selectedOption,
                      onTap: () => controller.setCompareOption('7d'),
                      dark: dark,
                      activeColor: compColor,
                    ),
                    _buildCompareChip(
                      label: '14 Days',
                      value: '14d',
                      current: selectedOption,
                      onTap: () => controller.setCompareOption('14d'),
                      dark: dark,
                      activeColor: compColor,
                    ),
                    _buildCompareChip(
                      label: '30 Days',
                      value: '30d',
                      current: selectedOption,
                      onTap: () => controller.setCompareOption('30d'),
                      dark: dark,
                      activeColor: compColor,
                    ),
                    _buildCompareChip(
                      label: '90 Days',
                      value: '90d',
                      current: selectedOption,
                      onTap: () => controller.setCompareOption('90d'),
                      dark: dark,
                      activeColor: compColor,
                    ),
                    _buildCompareChip(
                      label: selectedOption == 'custom' &&
                              controller.comparisonCustomRange.value != null
                          ? '${DateFormat('d MMM').format(controller.comparisonCustomRange.value!.start)} - ${DateFormat('d MMM').format(controller.comparisonCustomRange.value!.end)}'
                          : 'Custom Range...',
                      value: 'custom',
                      current: selectedOption,
                      onTap: () =>
                          (onPickGap2Range ?? onPickCustomRange)?.call(),
                      dark: dark,
                      activeColor: compColor,
                      icon: Iconsax.calendar_1_copy,
                    ),
                  ],
                );

                if (isTwoColumn) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: gap1Box),
                      const SizedBox(width: AppSizes.md),
                      Expanded(child: gap2Box),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    gap1Box,
                    const SizedBox(height: AppSizes.sm),
                    gap2Box,
                  ],
                );
              },
            ),

            // ── Inspection & Difference Strip (Placed ABOVE graph to avoid covering curves) ──
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkCard : Colors.white,
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                border: Border.all(
                  color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  width: 1.0,
                ),
              ),
              child: selectedIndex != null &&
                      (series.isNotEmpty || compSeries.isNotEmpty)
                  ? Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Day ${(selectedIndex! + 1)} ($date1 vs $date2):',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: chartColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Gap 1: $p1Str',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: chartColor,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 7,
                                  height: 7,
                                  decoration: const BoxDecoration(
                                    color: compColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Gap 2: $p2Str',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: compColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2.5,
                          ),
                          decoration: BoxDecoration(
                            color: (isPos ? AppColors.success : AppColors.error)
                                .withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${isPos ? '+' : ''}${diffPct.toStringAsFixed(1)}% (${isPos ? '+' : '-'}ETB ${NumberFormat('#,##0').format(diffVal.abs().round())})',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: isPos ? AppColors.success : AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Wrap(
                          spacing: 5,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Icon(
                              isPosGrowth
                                  ? Icons.trending_up_rounded
                                  : Icons.trending_down_rounded,
                              size: 15,
                              color: isPosGrowth
                                  ? AppColors.success
                                  : AppColors.error,
                            ),
                            Text(
                              'Diff: ${growthPct >= 0 ? '+' : ''}${growthPct.toStringAsFixed(1)}% (${isPosGrowth ? '+' : '-'}ETB ${NumberFormat('#,##0.00').format(growthAbs.abs())})',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isPosGrowth
                                    ? AppColors.success
                                    : AppColors.error,
                              ),
                            ),
                          ],
                        ),
                        const Text(
                          'Tap line to inspect day',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
            ),

            // ── Comparison Line Graph Canvas (Unobscured) ──────────────────
            if (controller.isComparisonLoading.value)
              SizedBox(
                height: 240,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(compColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Fetching Time Gap 2 analytics...',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: dark
                              ? Colors.white60
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else if (compSeries.isEmpty)
              const SizedBox(
                height: 200,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.chart_fail_copy,
                        size: 32,
                        color: AppColors.textSecondary,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No revenue records found for Time Gap 2',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              AdminLineChart(
                points: linePoints,
                comparisonPoints: compLinePoints,
                color: chartColor,
                comparisonColor: compColor,
                height: 240,
                selectedIndex: selectedIndex,
                onPointSelected: onPointSelected,
                tooltipContent: null, // Outlined box removed from graph canvas so lines are 100% visible!
              ),
              const SizedBox(height: 8),
              // Line Graph Legend
              Wrap(
                spacing: 16,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _LineLegendIndicator(
                    color: chartColor,
                    label:
                        'Time Gap 1 (${primDays}d): ${DateFormat('d MMM').format(primRange.start)} – ${DateFormat('d MMM').format(primRange.end)}',
                  ),
                  _LineLegendIndicator(
                    color: compColor,
                    label:
                        'Time Gap 2 (${compDays}d): ${DateFormat('d MMM').format(compRange.start)} – ${DateFormat('d MMM').format(compRange.end)}',
                  ),
                ],
              ),
              const SizedBox(height: 6),
              _XAxisLabels(series: series, comparisonSeries: compSeries),
            ],
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
      children: [
        Text(
          'Revenue Analytics',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: dark ? AppColors.white : AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),

        // Lock icon button (no text)
        Obx(() {
          final lockCtrl = Get.isRegistered<AppLockController>()
              ? AppLockController.instance
              : null;
          final hasPasscode = lockCtrl?.isPasscodeEnabled.value ?? false;

          return IconButton(
            tooltip: hasPasscode ? 'Lock Revenue' : 'Set Up PIN',
            icon: Icon(
              hasPasscode ? Iconsax.lock_copy : Iconsax.security_safe_copy,
              size: 18,
              color: dark ? Colors.white70 : AppColors.textSecondary,
            ),
            onPressed: () {
              if (hasPasscode) {
                controller.lockRevenue();
              } else {
                PasscodeSetupDialog.show(context);
              }
            },
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            splashRadius: 18,
          );
        }),
        const SizedBox(width: 4),

        // Hide / Show amounts icon button (no text)
        Obx(
          () => IconButton(
            tooltip: controller.isPriceHidden.value
                ? 'Show Amounts'
                : 'Hide Amounts',
            icon: Icon(
              controller.isPriceHidden.value
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              size: 18,
              color: controller.isPriceHidden.value
                  ? AppColors.primary
                  : (dark ? Colors.white70 : AppColors.textSecondary),
            ),
            onPressed: controller.togglePriceVisibility,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(),
            splashRadius: 18,
          ),
        ),
        const Spacer(),

        FilledButton.icon(
          onPressed: () => AddCostDialog.show(context, controller),
          icon: const Icon(Iconsax.wallet_minus_copy, size: 15),
          label: const Text('Add Cost'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFEF4444),
            foregroundColor: Colors.white,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
            textStyle: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
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
            if (unit.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                unit,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

// ── Comparison Helper Widgets ───────────────────────────────────────────────

class _LineLegendIndicator extends StatelessWidget {
  const _LineLegendIndicator({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

class _PickingBox extends StatelessWidget {
  const _PickingBox({
    required this.title,
    required this.accentColor,
    required this.dateRangeText,
    required this.days,
    required this.totalAmount,
    required this.chips,
    required this.dark,
  });

  final String title;
  final Color accentColor;
  final String dateRangeText;
  final int days;
  final String totalAmount;
  final List<Widget> chips;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: dark
            ? accentColor.withValues(alpha: 0.06)
            : accentColor.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  totalAmount,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '$dateRangeText ($days Days)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: chips),
        ],
      ),
    );
  }
}

Widget _buildCompareChip({
  required String label,
  required String value,
  required String current,
  required VoidCallback onTap,
  required bool dark,
  Color activeColor = const Color(0xFF8B5CF6),
  IconData? icon,
}) {
  final isSelected = value == current;
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(6),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
      decoration: BoxDecoration(
        color: isSelected
            ? activeColor.withValues(alpha: 0.18)
            : (dark ? AppColors.darkCard : Colors.white),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isSelected
              ? activeColor
              : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
          width: isSelected ? 1.2 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: isSelected ? activeColor : AppColors.textSecondary,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? activeColor
                  : (dark ? Colors.white70 : AppColors.textPrimary),
            ),
          ),
        ],
      ),
    ),
  );
}

// ── X-axis Labels ───────────────────────────────────────────────────────────

class _XAxisLabels extends StatelessWidget {
  const _XAxisLabels({required this.series, this.comparisonSeries});

  final List<DailyPoint> series;
  final List<DailyPoint>? comparisonSeries;

  @override
  Widget build(BuildContext context) {
    final hasComp = comparisonSeries != null && comparisonSeries!.isNotEmpty;
    final totalCount = hasComp
        ? math.max(series.length, comparisonSeries!.length)
        : series.length;

    if (totalCount < 2) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxLabels = constraints.maxWidth < 300
            ? 2
            : (constraints.maxWidth < 440 ? 3 : (constraints.maxWidth < 600 ? 4 : 6));
        final count = totalCount < maxLabels ? totalCount : maxLabels;
        final step = (totalCount - 1) / (count > 1 ? count - 1 : 1);

        final labels = List.generate(count, (i) {
          final idx = (i * step).round().clamp(0, totalCount - 1);
          if (idx < series.length) {
            return DateFormat('d MMM').format(series[idx].day);
          } else if (hasComp && idx < comparisonSeries!.length) {
            return DateFormat('d MMM').format(comparisonSeries![idx].day);
          }
          return 'Day ${idx + 1}';
        });

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: labels
              .map(
                (l) => Flexible(
                  child: Text(
                    l,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

// ── Selected Day Banner Widget ──────────────────────────────────────────────

class _SelectedDayBanner extends StatelessWidget {
  const _SelectedDayBanner({
    required this.point,
    required this.activeMethod,
    required this.isNetView,
    required this.chartColor,
    required this.dayCost,
    required this.dayIncome,
    required this.isPriceHidden,
    required this.onClose,
  });

  final DailyPoint point;
  final String? activeMethod;
  final bool isNetView;
  final Color chartColor;
  final double dayCost;
  final double dayIncome;
  final bool isPriceHidden;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final isDeficit = isNetView && point.value < 0;
    final method = activeMethod;

    final formattedDate = DateFormat('EEEE, MMM d, yyyy').format(point.day);
    final String methodLabel = method != null
        ? PaymentMethodInfo.labelOf(method)
        : 'All Payment Methods';

    final String amountText;
    if (isPriceHidden) {
      amountText = 'ETB ••••••';
    } else {
      if (isNetView) {
        amountText = isDeficit
            ? '-ETB ${NumberFormat('#,##0.00').format(point.value.abs())}'
            : 'ETB ${NumberFormat('#,##0.00').format(point.value)}';
      } else {
        amountText = 'ETB ${NumberFormat('#,##0.00').format(point.value)}';
      }
    }

    final Color badgeColor = method != null
        ? chartColor
        : (isDeficit
            ? const Color(0xFFEF4444)
            : (isNetView && dayCost > 0 ? AppColors.success : chartColor));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.darkSurface.withValues(alpha: 0.9)
            : AppColors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: badgeColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.3 : 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(
                  Iconsax.calendar_1_copy,
                  size: 15,
                  color: badgeColor,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: dark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      method != null
                          ? '$methodLabel Revenue on this day'
                          : (isNetView ? 'Net Daily Revenue (Profit)' : 'Total Daily Revenue (All Methods)'),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
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
                    amountText,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDeficit
                          ? const Color(0xFFEF4444)
                          : (isNetView && point.value > 0
                              ? AppColors.success
                              : chartColor),
                    ),
                  ),
                  if (method != null)
                    Container(
                      margin: const EdgeInsets.only(top: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: chartColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        methodLabel,
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: chartColor,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 16),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Clear Selection',
                color: AppColors.textSecondary,
                onPressed: onClose,
              ),
            ],
          ),

          // Additional breakdown chips if All methods or if costs/income exist
          if (!isPriceHidden &&
              (point.methodBreakdown.isNotEmpty || dayIncome > 0 || dayCost > 0)) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (method == null)
                  for (final entry in point.methodBreakdown.entries)
                    if (entry.value > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: dark
                              ? AppColors.darkCard
                              : AppColors.grey.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${PaymentMethodInfo.labelOf(entry.key)}: ',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              'ETB ${NumberFormat('#,##0').format(entry.value)}',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: dark ? Colors.white : AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                      ),
                if (dayIncome > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: AppColors.success.withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.wallet_add_copy, size: 11, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text(
                          'Added: +ETB ${NumberFormat('#,##0').format(dayIncome)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (dayCost > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        width: 0.8,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Iconsax.wallet_minus_copy, size: 11, color: Color(0xFFEF4444)),
                        const SizedBox(width: 4),
                        Text(
                          'Cost: -ETB ${NumberFormat('#,##0').format(dayCost)}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Protected Locked View (Strictly PIN Only) ───────────────────────────────

class _RevenueLockedView extends StatefulWidget {
  const _RevenueLockedView({
    required this.controller,
    required this.lockController,
  });

  final RevenueController controller;
  final AppLockController lockController;

  @override
  State<_RevenueLockedView> createState() => _RevenueLockedViewState();
}

class _RevenueLockedViewState extends State<_RevenueLockedView> {
  final GlobalKey<PinPadViewState> _pinKey = GlobalKey<PinPadViewState>();

  void _onPinCompleted(String pin) {
    final valid = widget.lockController.checkPasscode(pin);
    if (valid) {
      widget.controller.unlockRevenue();
    } else {
      _pinKey.currentState?.triggerError();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: AdminCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Iconsax.lock_copy,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Revenue Protected',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Enter your ${widget.lockController.pinLength.value}-digit PIN to unlock',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                PinPadView(
                  key: _pinKey,
                  pinLength: widget.lockController.pinLength.value,
                  onCompleted: _onPinCompleted,
                  showBiometricButton: false,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
