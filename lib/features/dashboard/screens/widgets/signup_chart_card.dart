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

enum ChartMetricMode { signups, revenue }

class SignupChartCard extends StatefulWidget {
  const SignupChartCard({super.key});

  @override
  State<SignupChartCard> createState() => _SignupChartCardState();
}

class _SignupChartCardState extends State<SignupChartCard> {
  ChartMetricMode _metricMode = ChartMetricMode.signups;

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Bar ──────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 550;
              final headerContent = [
                // Title and Metric Toggle
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: (_metricMode == ChartMetricMode.signups
                                ? AppColors.info
                                : AppColors.success)
                            .withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppSizes.borderRadiusSm),
                      ),
                      child: Icon(
                        _metricMode == ChartMetricMode.signups
                            ? Iconsax.user_add_copy
                            : Iconsax.money_recive_copy,
                        size: 16,
                        color: _metricMode == ChartMetricMode.signups
                            ? AppColors.info
                            : AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _metricMode == ChartMetricMode.signups
                          ? 'Student Signups'
                          : 'Revenue Trajectory',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(width: 12),
                    // Metric Switcher Chips
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: dark
                            ? AppColors.darkSurface
                            : AppColors.grey.withValues(alpha: 0.25),
                        borderRadius:
                            BorderRadius.circular(AppSizes.borderRadiusMd),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _MetricToggleChip(
                            label: 'Signups',
                            icon: Iconsax.profile_2user_copy,
                            isSelected:
                                _metricMode == ChartMetricMode.signups,
                            color: AppColors.info,
                            onTap: () {
                              setState(() =>
                                  _metricMode = ChartMetricMode.signups);
                            },
                          ),
                          _MetricToggleChip(
                            label: 'Revenue',
                            icon: Iconsax.dollar_circle_copy,
                            isSelected:
                                _metricMode == ChartMetricMode.revenue,
                            color: AppColors.success,
                            onTap: () {
                              setState(() =>
                                  _metricMode = ChartMetricMode.revenue);
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Range Selector (7d, 30d, 90d)
                Obx(
                  () => SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 7, label: Text('7d')),
                      ButtonSegment(value: 30, label: Text('30d')),
                      ButtonSegment(value: 90, label: Text('90d')),
                    ],
                    selected: {controller.rangeDays.value},
                    onSelectionChanged: (s) =>
                        controller.rangeDays.value = s.first,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ),
              ];

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    headerContent[0],
                    const SizedBox(height: AppSizes.sm),
                    headerContent[1],
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: headerContent,
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
                height: 180,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Iconsax.chart_2_copy,
                        size: 32,
                        color: AppColors.textSecondary.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No ${isSignups ? 'signup' : 'revenue'} data for the selected period',
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
            final avg = total / days;

            final points = <LinePoint>[
              for (int i = 0; i < series.length; i++)
                LinePoint(i / (series.length - 1), series[i].value),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── KPI Summary Cards ──────────────────────────────
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.sm,
                  children: [
                    _SummaryChip(
                      label: 'Total in $days Days',
                      value: isSignups
                          ? NumberFormat('#,##0').format(total.round())
                          : 'ETB ${NumberFormat.compact().format(total)}',
                      subtext: isSignups ? 'new students' : 'gross revenue',
                      color: chartColor,
                      icon: isSignups
                          ? Iconsax.people_copy
                          : Iconsax.wallet_3_copy,
                    ),
                    _SummaryChip(
                      label: 'Peak Single Day',
                      value: isSignups
                          ? '${peak.round()} users'
                          : 'ETB ${NumberFormat.compact().format(peak)}',
                      subtext: 'highest activity',
                      color: AppColors.primary,
                      icon: Iconsax.trend_up_copy,
                    ),
                    _SummaryChip(
                      label: 'Daily Average',
                      value: isSignups
                          ? avg.toStringAsFixed(1)
                          : 'ETB ${avg.toStringAsFixed(0)}',
                      subtext: 'per day pace',
                      color: AppColors.amberAccent,
                      icon: Iconsax.timer_1_copy,
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.md),

                // ── Smooth Line Chart ──────────────────────────────
                AdminLineChart(
                  points: points,
                  color: chartColor,
                  height: 180,
                ),
                const SizedBox(height: AppSizes.xs),

                // ── X-Axis Dates ───────────────────────────────────
                _XAxisLabels(series: series),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Toggle Chip ─────────────────────────────────────────────────────────────

class _MetricToggleChip extends StatelessWidget {
  const _MetricToggleChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? (dark ? AppColors.darkCard : AppColors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
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
              color: isSelected ? color : AppColors.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (dark ? AppColors.white : AppColors.textPrimary)
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Summary Chip ───────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.subtext,
    required this.color,
    required this.icon,
  });

  final String label;
  final String value;
  final String subtext;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.md,
        vertical: AppSizes.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.08 : 0.05),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: color.withValues(alpha: dark ? 0.25 : 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: dark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '· $subtext',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
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
