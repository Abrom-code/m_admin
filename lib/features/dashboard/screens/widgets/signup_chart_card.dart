import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/charts/line_chart_painter.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/features/dashboard/controllers/dashboard_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

enum ChartMetricMode { signups, revenue }

class SignupChartCard extends StatefulWidget {
  const SignupChartCard({super.key});

  @override
  State<SignupChartCard> createState() => _SignupChartCardState();
}

class _SignupChartCardState extends State<SignupChartCard> {
  ChartMetricMode _metricMode = ChartMetricMode.signups;
  int? _selectedIndex;

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
              final isCompact = constraints.maxWidth < 560;

              final switcher = Container(
                padding: const EdgeInsets.all(2.5),
                decoration: BoxDecoration(
                  color: dark
                      ? AppColors.darkSurface
                      : AppColors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TabPill(
                      label: 'Student Signups',
                      isSelected: _metricMode == ChartMetricMode.signups,
                      activeColor: AppColors.info,
                      onTap: () => setState(() {
                        _metricMode = ChartMetricMode.signups;
                      }),
                    ),
                    _TabPill(
                      label: 'Gross Revenue',
                      isSelected: _metricMode == ChartMetricMode.revenue,
                      activeColor: AppColors.success,
                      onTap: () => setState(() {
                        _metricMode = ChartMetricMode.revenue;
                      }),
                    ),
                  ],
                ),
              );

              final rangeSelector = Obx(
                () => SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(value: 7, label: Text('7d')),
                    ButtonSegment(value: 30, label: Text('30d')),
                    ButtonSegment(value: 90, label: Text('90d')),
                  ],
                  selected: {controller.rangeDays.value},
                  onSelectionChanged: (s) {
                    controller.rangeDays.value = s.first;
                    setState(() => _selectedIndex = null);
                  },
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: WidgetStateProperty.all(
                      const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                ),
              );

              if (isCompact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    switcher,
                    const SizedBox(height: AppSizes.sm),
                    rangeSelector,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  switcher,
                  rangeSelector,
                ],
              );
            },
          ),
          const SizedBox(height: AppSizes.md),

          // ── Chart Content & Summaries ───────────────────────────
          Obx(() {
            final isSignups = _metricMode == ChartMetricMode.signups;
            final series =
                isSignups ? controller.signupSeries : controller.revenueSeries;
            final days = controller.rangeDays.value;
            final chartColor = isSignups ? AppColors.info : AppColors.success;

            if (series.length < 2) {
              return SizedBox(
                height: 190,
                child: Center(
                  child: Text(
                    'No data recorded for the selected $days-day window',
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
            final avg = total / days;

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
              final formattedAmount = isSignups
                  ? '${NumberFormat('#,##0').format(selPoint.value.round())} students'
                  : 'ETB ${NumberFormat('#,##0.00').format(selPoint.value)}';
              final formattedDate = DateFormat('MMM d, yyyy').format(selPoint.day);

              tooltipWidget = Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                  ],
                ),
              );
            }

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
                      value: isSignups
                          ? NumberFormat('#,##0').format(total.round())
                          : 'ETB ${NumberFormat('#,##0').format(total)}',
                      unit: isSignups ? 'students' : 'revenue',
                      color: chartColor,
                    ),
                    _MetricStatItem(
                      label: 'PEAK DAY',
                      value: isSignups
                          ? '${peak.round()}'
                          : 'ETB ${NumberFormat.compact().format(peak)}',
                      unit: isSignups ? 'students / day' : 'highest day',
                      color: AppColors.textSecondary,
                    ),
                    _MetricStatItem(
                      label: 'DAILY AVERAGE',
                      value: isSignups
                          ? avg.toStringAsFixed(1)
                          : 'ETB ${avg.toStringAsFixed(0)}',
                      unit: 'per day pace',
                      color: AppColors.textSecondary,
                    ),
                    if (_selectedIndex != null && _selectedIndex! < series.length)
                      _SelectedDayCard(
                        date: DateFormat('EEE, MMM d').format(series[_selectedIndex!].day),
                        value: isSignups
                            ? '${NumberFormat('#,##0').format(series[_selectedIndex!].value.round())} students'
                            : 'ETB ${NumberFormat('#,##0.00').format(series[_selectedIndex!].value)}',
                        color: chartColor,
                        onClear: () => setState(() => _selectedIndex = null),
                      )
                    else
                      const _ClickHintBadge(),
                  ],
                ),
                const SizedBox(height: AppSizes.md),

                // ── Line Chart Canvas ──────────────────────────────
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

// ── Tab Pill Switcher ───────────────────────────────────────────────────────

class _TabPill extends StatelessWidget {
  const _TabPill({
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
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm - 1),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? (dark ? AppColors.darkCard : AppColors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm - 1),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.07),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? (dark ? AppColors.white : AppColors.textPrimary)
                : AppColors.textSecondary,
          ),
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
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: dark ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(width: 5),
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

    const maxLabels = 6;
    final count = series.length < maxLabels ? series.length : maxLabels;
    final step = (series.length - 1) / (count - 1);

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
  }
}

// ── Selected Day Card & Hint Badge ──────────────────────────────────────────

class _SelectedDayCard extends StatelessWidget {
  const _SelectedDayCard({
    required this.date,
    required this.value,
    required this.color,
    required this.onClear,
  });

  final String date;
  final String value;
  final Color color;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_rounded, size: 15, color: color),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SELECTED: $date',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                  letterSpacing: 0.4,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: dark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onClear,
            borderRadius: BorderRadius.circular(10),
            child: const Padding(
              padding: EdgeInsets.all(2.0),
              child: Icon(Icons.close_rounded,
                  size: 14, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClickHintBadge extends StatelessWidget {
  const _ClickHintBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.touch_app_outlined,
              size: 12, color: AppColors.textSecondary),
          SizedBox(width: 4),
          Text(
            'Click graph to inspect day',
            style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
