import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/utils/constants/colors.dart';

/// Hand-rolled interactive Bar Chart with rounded bars, subtle gradients,
/// optional payment method stacked breakdown, and interactive hover/selection.
class BarChartPainter extends CustomPainter {
  BarChartPainter({
    required this.points,
    this.color = AppColors.success,
    this.selectedIndex,
    this.isDark = false,
    this.showBreakdown = false,
  });

  final List<DailyPoint> points;
  final Color color;
  final int? selectedIndex;
  final bool isDark;
  final bool showBreakdown;

  static const _methodColors = <String, Color>{
    'telebirr': AppColors.primary,
    'cbe': AppColors.info,
    'abyssinia': AppColors.amberAccent,
    'other': AppColors.darkGrey,
  };

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final maxY = points.map((p) => p.value).fold<double>(0.0, math.max);
    final effectiveMax = maxY > 0 ? maxY : 1.0;

    const topPadding = 16.0;
    const bottomPadding = 4.0;
    final usableHeight = math.max(size.height - topPadding - bottomPadding, 10.0);

    // ── Background Faint Horizontal Grid Lines ──────────────────────────
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 3; i++) {
      final y = size.height - bottomPadding - (usableHeight * (i / 4.0));
      _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Baseline
    final baseLinePaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, size.height - bottomPadding),
      Offset(size.width, size.height - bottomPadding),
      baseLinePaint,
    );

    final count = points.length;
    final slotWidth = size.width / count;
    final barWidth = math.max(2.5, math.min(slotWidth * 0.72, 28.0));

    for (int i = 0; i < count; i++) {
      final p = points[i];
      final cx = (i + 0.5) * slotWidth;
      final left = cx - (barWidth / 2);
      final right = cx + (barWidth / 2);
      final isSelected = selectedIndex == i;
      final isAnySelected = selectedIndex != null;
      final dimAlpha = (isAnySelected && !isSelected) ? 0.38 : 1.0;

      // Draw subtle selection guide behind active bar
      if (isSelected) {
        final guidePaint = Paint()
          ..color = color.withValues(alpha: isDark ? 0.12 : 0.08);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left - 3, topPadding / 2, right + 3, size.height - bottomPadding),
            const Radius.circular(6),
          ),
          guidePaint,
        );
      }

      final barHeight = (p.value / effectiveMax) * usableHeight;

      if (p.value <= 0 || barHeight < 1.0) {
        // Zero or near-zero pill indicator
        final zeroPaint = Paint()
          ..color = (isDark ? Colors.white30 : Colors.black26)
              .withValues(alpha: (isAnySelected && !isSelected) ? 0.15 : 0.4);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTRB(left, size.height - bottomPadding - 2, right, size.height - bottomPadding),
            const Radius.circular(1.5),
          ),
          zeroPaint,
        );
        continue;
      }

      final barTop = size.height - bottomPadding - barHeight;
      final barBottom = size.height - bottomPadding;

      if (showBreakdown && p.methodBreakdown.isNotEmpty && p.value > 0) {
        // ── Stacked Bar by Payment Method ───────────────────────────────
        double currentBottom = barBottom;
        final entries = p.methodBreakdown.entries.toList();

        for (int m = 0; m < entries.length; m++) {
          final entry = entries[m];
          final amt = entry.value;
          if (amt <= 0) continue;

          final segHeight = (amt / p.value) * barHeight;
          final segTop = currentBottom - segHeight;
          final isTopSegment = m == entries.length - 1 || segTop <= barTop + 0.5;
          final mColor = _methodColors[entry.key] ?? AppColors.primary;

          final segPaint = Paint()
            ..color = mColor.withValues(alpha: dimAlpha)
            ..style = PaintingStyle.fill;

          final segRect = Rect.fromLTRB(left, segTop, right, currentBottom);
          if (isTopSegment) {
            canvas.drawRRect(
              RRect.fromRectAndCorners(
                segRect,
                topLeft: const Radius.circular(3.5),
                topRight: const Radius.circular(3.5),
              ),
              segPaint,
            );
          } else {
            canvas.drawRect(segRect, segPaint);
          }

          currentBottom = segTop;
        }

        if (isSelected) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTRB(left, barTop, right, barBottom),
              topLeft: const Radius.circular(3.5),
              topRight: const Radius.circular(3.5),
            ),
            Paint()
              ..color = Colors.white
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
      } else {
        // ── Single Gradient Bar ─────────────────────────────────────────
        final barRect = Rect.fromLTRB(left, barTop, right, barBottom);
        final rrect = RRect.fromRectAndCorners(
          barRect,
          topLeft: const Radius.circular(3.5),
          topRight: const Radius.circular(3.5),
        );

        final gradient = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.95 * dimAlpha),
            color.withValues(alpha: 0.60 * dimAlpha),
          ],
        );

        final fillPaint = Paint()
          ..shader = gradient.createShader(barRect)
          ..style = PaintingStyle.fill;

        canvas.drawRRect(rrect, fillPaint);

        if (isSelected) {
          canvas.drawRRect(
            rrect,
            Paint()
              ..color = Colors.white.withValues(alpha: isDark ? 0.9 : 0.8)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 1.2,
          );
        }
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
  bool shouldRepaint(BarChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.selectedIndex != selectedIndex ||
      oldDelegate.isDark != isDark ||
      oldDelegate.showBreakdown != showBreakdown;
}

/// Interactive Bar Chart Widget with mouse hover & tap support,
/// highlighted bars, and positioned tooltips.
class AdminBarChart extends StatelessWidget {
  const AdminBarChart({
    super.key,
    required this.points,
    this.color = AppColors.success,
    this.height = 175,
    this.selectedIndex,
    this.onPointSelected,
    this.tooltipContent,
    this.showBreakdown = false,
  });

  final List<DailyPoint> points;
  final Color color;
  final double height;
  final int? selectedIndex;
  final ValueChanged<int?>? onPointSelected;
  final Widget? tooltipContent;
  final bool showBreakdown;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text(
            'No data yet',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void handlePosition(Offset localPosition) {
          if (points.isEmpty || width <= 0) return;
          final slotWidth = width / points.length;
          final index = (localPosition.dx / slotWidth).floor().clamp(0, points.length - 1);
          if (index != selectedIndex) {
            onPointSelected?.call(index);
          }
        }

        // Calculate tooltip position
        Widget? tooltipWidget;
        if (tooltipContent != null &&
            selectedIndex != null &&
            selectedIndex! >= 0 &&
            selectedIndex! < points.length &&
            width > 0) {
          final slotWidth = width / points.length;
          final x = (selectedIndex! + 0.5) * slotWidth;

          const tooltipWidth = 145.0;
          double left = x - (tooltipWidth / 2);
          if (left < 6) left = 6;
          if (left + tooltipWidth > width - 6) left = width - tooltipWidth - 6;

          tooltipWidget = Positioned(
            left: left,
            top: 0,
            width: tooltipWidth,
            child: tooltipContent!,
          );
        }

        return SizedBox(
          height: height,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) => handlePosition(event.localPosition),
            onPointerMove: (event) => handlePosition(event.localPosition),
            onPointerHover: (event) => handlePosition(event.localPosition),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BarChartPainter(
                        points: points,
                        color: color,
                        selectedIndex: selectedIndex,
                        isDark: isDark,
                        showBreakdown: showBreakdown,
                      ),
                      size: Size.infinite,
                    ),
                  ),
                  ?tooltipWidget,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
