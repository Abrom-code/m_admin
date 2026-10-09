import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/charts/line_chart_painter.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/features/dashboard/controllers/dashboard_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class SignupChartCard extends StatefulWidget {
  const SignupChartCard({super.key});

  @override
  State<SignupChartCard> createState() => _SignupChartCardState();
}

class _SignupChartCardState extends State<SignupChartCard> {
  int? _selectedIndex;

  Future<void> _pickDateRange(
    BuildContext context,
    DashboardController controller,
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
      helpText: 'Select Dates',
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

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Controls ─────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 620;

              final titleWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.info.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                    ),
                    child: const Icon(
                      Iconsax.user_cirlce_add_copy,
                      size: 16,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Student Signups & Growth',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: dark ? AppColors.white : AppColors.textPrimary,
                    ),
                  ),
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
                    titleWidget,
                    const SizedBox(height: AppSizes.sm),
                    rangeSelector,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  titleWidget,
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
            final series = controller.signupSeries;
            const chartColor = AppColors.info;
            final days = controller.rangeDays.value;

            final customRange = controller.customDateRange.value;
            final rangeLabel = customRange != null
                ? '${DateFormat('d MMM yyyy').format(customRange.start)} - ${DateFormat('d MMM yyyy').format(customRange.end)}'
                : '$days-day window';

            if (controller.isChartLoading.value ||
                (controller.isLoading.value && series.isEmpty)) {
              return SizedBox(
                height: 220,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(chartColor),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Updating chart data...',
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

            if (series.length < 2) {
              return SizedBox(
                height: 190,
                child: Center(
                  child: Text(
                    'No data recorded for $rangeLabel',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              );
            }

            final total = series.fold(0.0, (sum, p) => sum + p.value);
            final peak = series.map((p) => p.value).reduce(math.max);
            final daysCount = series.length > 1 ? series.length : days;
            final avg = total / (daysCount > 0 ? daysCount : 1);

            final points = <LinePoint>[
              for (int i = 0; i < series.length; i++)
                LinePoint(i / (series.length - 1), series[i].value),
            ];

            // If selectedIndex is out of bounds, clamp it
            if (_selectedIndex != null && _selectedIndex! >= series.length) {
              _selectedIndex = series.length - 1;
            }

            Widget? tooltipWidget;
            if (_selectedIndex != null && _selectedIndex! < series.length) {
              final selPoint = series[_selectedIndex!];
              final formattedAmount =
                  '${NumberFormat('#,##0').format(selPoint.value.round())} students';
              final formattedDate =
                  DateFormat('MMM d, yyyy').format(selPoint.day);

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
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: chartColor,
                      ),
                    ),
                  ],
                ),
              );
            }

            final String totalValue = NumberFormat('#,##0').format(total.round());
            final String peakValue = '${peak.round()}';
            final String avgValue = avg.toStringAsFixed(1);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Sleek Content Metrics Bar ──────────────────────
                Wrap(
                  spacing: AppSizes.lg,
                  runSpacing: AppSizes.sm,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _MetricStatItem(
                      label: 'TOTAL IN RANGE',
                      value: totalValue,
                      unit: 'students',
                      color: chartColor,
                    ),
                    _MetricStatItem(
                      label: 'PEAK DAY',
                      value: peakValue,
                      unit: 'students / day',
                      color: AppColors.textSecondary,
                    ),
                    _MetricStatItem(
                      label: 'DAILY AVERAGE',
                      value: avgValue,
                      unit: 'per day pace',
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),

                // ── Chart Canvas (Line for Signups) ────────────────
                AdminLineChart(
                  points: points,
                  color: chartColor,
                  height: 175,
                  selectedIndex: _selectedIndex,
                  onPointSelected: (idx) {
                    setState(() => _selectedIndex = idx);
                  },
                  tooltipContent: tooltipWidget,
                ),
                const SizedBox(height: 6),

                // ── Date Axis Labels ───────────────────────────────
                _XAxisLabels(series: series),
              ],
            );
          }),
        ],
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
