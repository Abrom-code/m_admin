import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/features/dashboard/controllers/dashboard_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

enum HourlyViewMode { all, am, pm }

class HourlySignupsChartCard extends StatefulWidget {
  const HourlySignupsChartCard({super.key});

  @override
  State<HourlySignupsChartCard> createState() => _HourlySignupsChartCardState();
}

class _HourlySignupsChartCardState extends State<HourlySignupsChartCard> {
  int? _hoveredHour;
  HourlyViewMode _viewMode = HourlyViewMode.all;

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header Bar ───────────────────────────────────────────
          LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 650;

              final titleWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                    ),
                    child: const Icon(
                      Iconsax.clock_copy,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Signups by Time of Day',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: dark ? AppColors.white : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                                width: 0.8,
                              ),
                            ),
                            child: const Text(
                              '12-HR FORMAT',
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Hourly registration patterns (12 AM – 11 PM)',
                        style: TextStyle(
                          fontSize: 11,
                          color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              );

              final filterControls = Obx(() {
                final currentFilter = controller.hourlyFilter.value;
                return Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    // Preset range: Today, Yesterday, 7D, 30D
                    SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'today', label: Text('Today')),
                        ButtonSegment(value: 'yesterday', label: Text('Yesterday')),
                        ButtonSegment(value: '7d', label: Text('7D')),
                        ButtonSegment(value: '30d', label: Text('30D')),
                      ],
                      selected: {currentFilter},
                      onSelectionChanged: (s) {
                        if (s.isNotEmpty) {
                          setState(() => _hoveredHour = null);
                          controller.setHourlyFilter(s.first);
                        }
                      },
                      style: ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: WidgetStateProperty.all(
                          const EdgeInsets.symmetric(horizontal: 8),
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
                    const SizedBox(height: 12),
                    filterControls,
                  ],
                );
              }

              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  titleWidget,
                  filterControls,
                ],
              );
            },
          ),
          const SizedBox(height: AppSizes.spaceBtwItems),

          // ── KPI Summary Ribbon ───────────────────────────────────
          Obx(() {
            final total = controller.hourlyTotalSignups;
            final peak = controller.hourlyPeakHour;
            final amCount = controller.hourlyAmSignups;
            final pmCount = controller.hourlyPmSignups;
            final amPct = total > 0 ? (amCount / total * 100).toStringAsFixed(0) : '0';
            final pmPct = total > 0 ? (pmCount / total * 100).toStringAsFixed(0) : '0';

            return Wrap(
              spacing: 10,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _metricBadge(
                  label: 'Total Signups',
                  value: '$total',
                  icon: Iconsax.user_cirlce_add_copy,
                  color: AppColors.primary,
                  dark: dark,
                ),
                _metricBadge(
                  label: 'Peak Hour',
                  value: peak != null ? '${peak.label12h} (${peak.count})' : 'None',
                  icon: Iconsax.chart_2_copy,
                  color: AppColors.success,
                  dark: dark,
                ),
                _metricBadge(
                  label: 'Morning (12 AM - 11 AM)',
                  value: '$amCount ($amPct%)',
                  icon: Icons.wb_sunny_outlined,
                  color: AppColors.warning,
                  dark: dark,
                ),
                _metricBadge(
                  label: 'Afternoon / Night (12 PM - 11 PM)',
                  value: '$pmCount ($pmPct%)',
                  icon: Icons.nightlight_round,
                  color: AppColors.info,
                  dark: dark,
                ),
              ],
            );
          }),
          const SizedBox(height: AppSizes.sm),

          // ── View Mode Filter (All / AM / PM) ──────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TIME DISTRIBUTION',
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _viewModeChip('ALL (24h)', HourlyViewMode.all, dark),
                  const SizedBox(width: 6),
                  _viewModeChip('AM ONLY', HourlyViewMode.am, dark),
                  const SizedBox(width: 6),
                  _viewModeChip('PM ONLY', HourlyViewMode.pm, dark),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Graph Area ───────────────────────────────────────────
          Obx(() {
            if (controller.isHourlyLoading.value) {
              return const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              );
            }

            final allPoints = controller.hourlySignups;
            if (allPoints.isEmpty) {
              return const SizedBox(
                height: 220,
                child: Center(
                  child: Text(
                    'No signup data available for this period',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              );
            }

            // Filter points based on view mode (All, AM, PM)
            final visiblePoints = switch (_viewMode) {
              HourlyViewMode.all => allPoints,
              HourlyViewMode.am => allPoints.where((p) => p.isAm).toList(),
              HourlyViewMode.pm => allPoints.where((p) => p.isPm).toList(),
            };

            return LayoutBuilder(
              builder: (context, constraints) {
                return MouseRegion(
                  onHover: (e) {
                    final boxWidth = constraints.maxWidth;
                    final slotWidth = boxWidth / visiblePoints.length;
                    final idx = (e.localPosition.dx / slotWidth).floor().clamp(0, visiblePoints.length - 1);
                    if (_hoveredHour != visiblePoints[idx].hour) {
                      setState(() => _hoveredHour = visiblePoints[idx].hour);
                    }
                  },
                  onExit: (_) {
                    if (_hoveredHour != null) {
                      setState(() => _hoveredHour = null);
                    }
                  },
                  child: Column(
                    children: [
                      // Active Selection Banner
                      _buildHoverBanner(allPoints, dark),
                      const SizedBox(height: 6),

                      // Chart Painter
                      SizedBox(
                        height: 190,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _HourlyBarChartPainter(
                            points: visiblePoints,
                            hoveredHour: _hoveredHour,
                            isDark: dark,
                            primaryColor: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHoverBanner(List<HourlySignupPoint> allPoints, bool dark) {
    if (_hoveredHour == null) {
      return Container(
        height: 28,
        alignment: Alignment.centerLeft,
        child: Text(
          'Hover over any 12-hour slot to view precise signup counts and percentages.',
          style: TextStyle(
            fontSize: 11,
            color: dark ? AppColors.darkGrey : AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    final point = allPoints.firstWhere(
      (p) => p.hour == _hoveredHour,
      orElse: () => allPoints.first,
    );
    final rangeLabel = HourlySignupPoint.formatHourRange12(point.hour);

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: dark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            point.isAm ? Icons.wb_sunny_outlined : Icons.nightlight_round,
            size: 13,
            color: point.isAm ? AppColors.warning : AppColors.info,
          ),
          const SizedBox(width: 6),
          Text(
            rangeLabel,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${point.count} student signup${point.count == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.bold,
              color: dark ? AppColors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '(${point.percentage.toStringAsFixed(1)}% of period)',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewModeChip(String label, HourlyViewMode mode, bool dark) {
    final isSelected = _viewMode == mode;
    return InkWell(
      onTap: () => setState(() => _viewMode = mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: dark ? 0.25 : 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
            width: isSelected ? 1.2 : 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            color: isSelected
                ? AppColors.primary
                : (dark ? AppColors.white : AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _metricBadge({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 11,
              color: dark ? AppColors.darkGrey : AppColors.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Custom painter rendering 12-hour column bars with AM/PM indicators and labels
class _HourlyBarChartPainter extends CustomPainter {
  _HourlyBarChartPainter({
    required this.points,
    required this.hoveredHour,
    required this.isDark,
    required this.primaryColor,
  });

  final List<HourlySignupPoint> points;
  final int? hoveredHour;
  final bool isDark;
  final Color primaryColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxVal = points.map((p) => p.count.toDouble()).fold<double>(0.0, math.max);
    final effectiveMax = maxVal > 0 ? maxVal : 1.0;

    const labelHeight = 26.0;
    const topMargin = 16.0;
    final usableHeight = size.height - labelHeight - topMargin;
    final baselineY = size.height - labelHeight;

    // ── Dashed Horizontal Grid Lines ─────────────────────────────────
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = baselineY - (usableHeight * (i / 4.0));
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Baseline
    final baseLinePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(0, baselineY), Offset(size.width, baselineY), baseLinePaint);

    final count = points.length;
    final slotWidth = size.width / count;
    final barWidth = math.max(3.0, math.min(slotWidth * 0.72, 22.0));

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < count; i++) {
      final p = points[i];
      final cx = (i + 0.5) * slotWidth;
      final left = cx - (barWidth / 2);
      final right = cx + (barWidth / 2);
      final isHovered = hoveredHour == p.hour;
      final isAnyHovered = hoveredHour != null;

      final barH = (p.count / effectiveMax) * usableHeight;
      final barTop = baselineY - barH;

      // Color scheme: AM is warm gold/amber, PM is deep violet/cyan
      final barColor = p.isAm ? AppColors.warning : primaryColor;

      // Draw hover guide behind bar
      if (isHovered) {
        final guidePaint = Paint()
          ..color = barColor.withValues(alpha: isDark ? 0.18 : 0.1);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left - 3, topMargin / 2, right + 3, baselineY),
            const Radius.circular(5),
          ),
          guidePaint,
        );
      }

      if (p.count > 0 && barH >= 1.0) {
        final barRect = Rect.fromLTRB(left, barTop, right, baselineY);
        final dimAlpha = (isAnyHovered && !isHovered) ? 0.4 : 1.0;

        final shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            barColor.withValues(alpha: isHovered ? 1.0 : 0.85 * dimAlpha),
            barColor.withValues(alpha: isHovered ? 0.75 : 0.45 * dimAlpha),
          ],
        ).createShader(barRect);

        final barPaint = Paint()..shader = shader;
        canvas.drawRRect(
          RRect.fromRectAndRadius(barRect, const Radius.circular(3.5)),
          barPaint,
        );

        // Value text above bar if space permits or if hovered
        if (isHovered || (count <= 12 && barH > 20)) {
          textPainter.text = TextSpan(
            text: '${p.count}',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.bold,
              color: isHovered ? barColor : (isDark ? Colors.white70 : AppColors.textSecondary),
            ),
          );
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(cx - (textPainter.width / 2), barTop - textPainter.height - 2),
          );
        }
      } else {
        // Zero bar pip indicator
        final zeroPaint = Paint()
          ..color = (isDark ? Colors.white24 : Colors.black12);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left, baselineY - 2, right, baselineY),
            const Radius.circular(1),
          ),
          zeroPaint,
        );
      }

      // ── 12-Hour Label Below Baseline ───────────────────────────────
      // If full 24h view and narrow screen, display every 2nd or 3rd label, or compact format
      final shouldShowLabel = count <= 12 || (size.width > 550) || (i % 2 == 0) || isHovered;

      if (shouldShowLabel) {
        textPainter.text = TextSpan(
          text: p.label12h,
          style: TextStyle(
            fontSize: isHovered ? 9.5 : 8.5,
            fontWeight: isHovered ? FontWeight.bold : FontWeight.w500,
            color: isHovered
                ? barColor
                : (isDark ? AppColors.darkGrey : AppColors.textSecondary),
          ),
        );
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(cx - (textPainter.width / 2), baselineY + 6),
        );
      }
    }
  }

  void _drawDashedLine(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dashWidth = 4.0;
    const dashSpace = 4.0;
    double startX = p1.dx;
    while (startX < p2.dx) {
      canvas.drawLine(
        Offset(startX, p1.dy),
        Offset(math.min(startX + dashWidth, p2.dx), p1.dy),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _HourlyBarChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.hoveredHour != hoveredHour ||
        oldDelegate.isDark != isDark;
  }
}
