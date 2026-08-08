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

class SignupChartCard extends StatelessWidget {
  const SignupChartCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header: title shrinks before the filter does ─────────
          Row(
            children: [
              Flexible(
                child: Text(
                  'Signups over time',
                  style: Theme.of(context).textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: AppSizes.sm),
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
            ],
          ),
          const SizedBox(height: AppSizes.spaceBtwItems),
          Obx(() {
        final series = controller.signupSeries;
        final days = controller.rangeDays.value;

        if (series.length < 2) {
          return const SizedBox(
            height: 160,
            child: Center(
              child: Text(
                'No signup data yet',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          );
        }

        final total =
            series.fold(0.0, (sum, p) => sum + p.value).round();
        final peak =
            series.map((p) => p.value).reduce(math.max).round();
        final avg = total / days;

        final points = <LinePoint>[
          for (int i = 0; i < series.length; i++)
            LinePoint(i / (series.length - 1), series[i].value),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Summary chips ────────────────────────────────────────
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              children: [
                _SummaryChip(
                  label: 'Total',
                  value: '$total',
                  color: AppColors.info,
                ),
                _SummaryChip(
                  label: 'Peak day',
                  value: '$peak',
                  color: AppColors.primary,
                ),
                _SummaryChip(
                  label: 'Avg / day',
                  value: avg.toStringAsFixed(1),
                  color: AppColors.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            // ── Line chart ───────────────────────────────────────────
            AdminLineChart(
              points: points,
              color: AppColors.info,
              height: 160,
            ),
            const SizedBox(height: AppSizes.xs),
            // ── X-axis labels ────────────────────────────────────────
            _XAxisLabels(series: series),
          ],
        );
      }),
        ],
      ),
    );
  }
}

// ── Summary chip ───────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color == AppColors.textSecondary
                  ? AppColors.textSecondary
                  : color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── X-axis labels ──────────────────────────────────────────────────────

class _XAxisLabels extends StatelessWidget {
  const _XAxisLabels({required this.series});

  final List<DailyPoint> series;

  @override
  Widget build(BuildContext context) {
    if (series.length < 2) return const SizedBox.shrink();

    // Up to 5 evenly-spaced date labels across the chart width.
    const maxLabels = 5;
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
                color: AppColors.textSecondary,
              ),
            ),
          )
          .toList(),
    );
  }
}
