import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/utils/constants/colors.dart';

/// Hand-rolled interactive Bar Chart with rounded bars, subtle gradients,
/// optional payment method stacked breakdown, time comparison pairing, and interactive hover/selection.
class BarChartPainter extends CustomPainter {
  BarChartPainter({
    required this.points,
    this.comparisonPoints,
    this.color = AppColors.success,
    this.comparisonColor = const Color(0xFF8B5CF6),
    this.selectedIndex,
    this.isDark = false,
    this.showBreakdown = false,
  });

  final List<DailyPoint> points;
  final List<DailyPoint>? comparisonPoints;
  final Color color;
  final Color comparisonColor;
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
    final hasComparison =
        comparisonPoints != null && comparisonPoints!.isNotEmpty;
    final totalCount = hasComparison
        ? math.max(points.length, comparisonPoints!.length)
        : points.length;

    if (totalCount == 0) return;

    final maxY1 = points.isNotEmpty
        ? points.map((p) => p.value).fold<double>(0.0, math.max)
        : 0.0;
    final maxY2 = hasComparison
        ? comparisonPoints!.map((p) => p.value).fold<double>(0.0, math.max)
        : 0.0;
    final maxY = math.max(0.0, math.max(maxY1, maxY2));

    final minY1 = points.isNotEmpty
        ? points.map((p) => p.value).fold<double>(0.0, math.min)
        : 0.0;
    final minY2 = hasComparison
        ? comparisonPoints!.map((p) => p.value).fold<double>(0.0, math.min)
        : 0.0;
    final minY = math.min(0.0, math.min(minY1, minY2));

    final hasDeficit = minY < 0.0;
    final totalSpan = math.max(maxY - minY, 1.0);

    const topPadding = 16.0;
    final bottomPadding = hasDeficit ? 14.0 : 4.0;
    final usableHeight =
        math.max(size.height - topPadding - bottomPadding, 10.0);

    // Baseline y-coordinate:
    // When minY == 0, zeroFraction = 0, y0 is at the bottom (size.height - bottomPadding).
    // When minY < 0, y0 is proportionally positioned above the bottom.
    final zeroFraction = (0.0 - minY) / totalSpan;
    final y0 = (size.height - bottomPadding) - (zeroFraction * usableHeight);

    // ── Background Horizontal Grid Lines & Baselines ────────────────────
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05)
      ..strokeWidth = 1.0;

    if (!hasDeficit) {
      // Standard positive grid lines
      for (int i = 1; i <= 3; i++) {
        final y = size.height - bottomPadding - (usableHeight * (i / 4.0));
        _drawDashedLine(canvas, Offset(0, y), Offset(size.width, y), gridPaint);
      }

      // Bottom baseline
      final baseLinePaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(0, size.height - bottomPadding),
        Offset(size.width, size.height - bottomPadding),
        baseLinePaint,
      );
    } else {
      // Mixed positive & negative deficit mode grid lines
      // 1. Positive upper dashed line (if maxY > 0)
      if (maxY > 0) {
        final yPositiveMid = y0 - ((y0 - topPadding) * 0.5);
        _drawDashedLine(canvas, Offset(0, yPositiveMid), Offset(size.width, yPositiveMid), gridPaint);
      }
      // 2. Negative lower dashed line
      final yNegativeMid = y0 + ((size.height - bottomPadding - y0) * 0.5);
      _drawDashedLine(canvas, Offset(0, yNegativeMid), Offset(size.width, yNegativeMid), gridPaint);

      // 3. Subtle bottom boundary
      final bottomBorderPaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(0, size.height - bottomPadding),
        Offset(size.width, size.height - bottomPadding),
        bottomBorderPaint,
      );

      // 4. Prominent Zero Baseline (Break-even line)
      final zeroLinePaint = Paint()
        ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.22)
        ..strokeWidth = 1.2;
      _drawDashedLine(canvas, Offset(0, y0), Offset(size.width, y0), zeroLinePaint);

      // Small break-even "0" label on the left edge
      final zeroTextPainter = TextPainter(
        text: TextSpan(
          text: '0',
          style: TextStyle(
            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.38),
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      zeroTextPainter.paint(canvas, Offset(3, y0 - zeroTextPainter.height - 2));
    }

    final slotWidth = size.width / totalCount;

    if (hasComparison) {
      // ── Comparative Paired Bars Mode ─────────────────────────────────
      final pairWidth = math.max(6.0, math.min(slotWidth * 0.82, 38.0));
      final subBarWidth = math.max(2.5, (pairWidth - 2.5) / 2.0);
      const deficitColor1 = Color(0xFFEF4444);
      const deficitColor2 = Color(0xFFF43F5E);

      for (int i = 0; i < totalCount; i++) {
        final p1 = i < points.length ? points[i] : null;
        final p2 = i < comparisonPoints!.length ? comparisonPoints![i] : null;
        final cx = (i + 0.5) * slotWidth;
        final isSelected = selectedIndex == i;
        final isAnySelected = selectedIndex != null;
        final dimAlpha = (isAnySelected && !isSelected) ? 0.38 : 1.0;

        // Selection guide behind active slot
        if (isSelected) {
          final guidePaint = Paint()
            ..color = color.withValues(alpha: isDark ? 0.12 : 0.08);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(
                cx - (pairWidth / 2) - 3,
                topPadding / 2,
                cx + (pairWidth / 2) + 3,
                size.height - bottomPadding,
              ),
              const Radius.circular(6),
            ),
            guidePaint,
          );
        }

        // Sub-bar 1: Primary period
        final left1 = cx - (pairWidth / 2);
        final right1 = left1 + subBarWidth;
        if (p1 != null && p1.value > 0) {
          final barHeight1 = (p1.value / totalSpan) * usableHeight;
          final barTop1 = y0 - barHeight1;
          final barRect1 = Rect.fromLTRB(left1, barTop1, right1, y0);
          final rrect1 = RRect.fromRectAndCorners(
            barRect1,
            topLeft: const Radius.circular(3.0),
            topRight: const Radius.circular(3.0),
          );

          final gradient1 = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.95 * dimAlpha),
              color.withValues(alpha: 0.60 * dimAlpha),
            ],
          );

          canvas.drawRRect(
            rrect1,
            Paint()
              ..shader = gradient1.createShader(barRect1)
              ..style = PaintingStyle.fill,
          );

          if (isSelected) {
            canvas.drawRRect(
              rrect1,
              Paint()
                ..color = Colors.white.withValues(alpha: isDark ? 0.9 : 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
          }
        } else if (p1 != null && p1.value < 0) {
          // Negative sub-bar 1 (Cost > Revenue Deficit)
          final barHeight1 = (p1.value.abs() / totalSpan) * usableHeight;
          final barBottom1 = y0 + barHeight1;
          final barRect1 = Rect.fromLTRB(left1, y0, right1, barBottom1);
          final rrect1 = RRect.fromRectAndCorners(
            barRect1,
            bottomLeft: const Radius.circular(3.0),
            bottomRight: const Radius.circular(3.0),
          );

          final gradient1 = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              deficitColor1.withValues(alpha: 0.95 * dimAlpha),
              deficitColor1.withValues(alpha: 0.60 * dimAlpha),
            ],
          );

          canvas.drawRRect(
            rrect1,
            Paint()
              ..shader = gradient1.createShader(barRect1)
              ..style = PaintingStyle.fill,
          );

          if (isSelected) {
            canvas.drawRRect(
              rrect1,
              Paint()
                ..color = Colors.white.withValues(alpha: isDark ? 0.9 : 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
          }
        } else {
          final zeroPaint = Paint()
            ..color = (isDark ? Colors.white30 : Colors.black26)
                .withValues(alpha: (isAnySelected && !isSelected) ? 0.15 : 0.4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(left1, y0 - 1.2, right1, y0 + 1.2),
              const Radius.circular(1.2),
            ),
            zeroPaint,
          );
        }

        // Sub-bar 2: Comparison period
        final left2 = right1 + 2.5;
        final right2 = left2 + subBarWidth;
        if (p2 != null && p2.value > 0) {
          final barHeight2 = (p2.value / totalSpan) * usableHeight;
          final barTop2 = y0 - barHeight2;
          final barRect2 = Rect.fromLTRB(left2, barTop2, right2, y0);
          final rrect2 = RRect.fromRectAndCorners(
            barRect2,
            topLeft: const Radius.circular(3.0),
            topRight: const Radius.circular(3.0),
          );

          final gradient2 = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              comparisonColor.withValues(alpha: 0.95 * dimAlpha),
              comparisonColor.withValues(alpha: 0.60 * dimAlpha),
            ],
          );

          canvas.drawRRect(
            rrect2,
            Paint()
              ..shader = gradient2.createShader(barRect2)
              ..style = PaintingStyle.fill,
          );

          if (isSelected) {
            canvas.drawRRect(
              rrect2,
              Paint()
                ..color = Colors.white.withValues(alpha: isDark ? 0.9 : 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
          }
        } else if (p2 != null && p2.value < 0) {
          // Negative sub-bar 2 (Comparison period deficit)
          final barHeight2 = (p2.value.abs() / totalSpan) * usableHeight;
          final barBottom2 = y0 + barHeight2;
          final barRect2 = Rect.fromLTRB(left2, y0, right2, barBottom2);
          final rrect2 = RRect.fromRectAndCorners(
            barRect2,
            bottomLeft: const Radius.circular(3.0),
            bottomRight: const Radius.circular(3.0),
          );

          final gradient2 = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              deficitColor2.withValues(alpha: 0.95 * dimAlpha),
              deficitColor2.withValues(alpha: 0.60 * dimAlpha),
            ],
          );

          canvas.drawRRect(
            rrect2,
            Paint()
              ..shader = gradient2.createShader(barRect2)
              ..style = PaintingStyle.fill,
          );

          if (isSelected) {
            canvas.drawRRect(
              rrect2,
              Paint()
                ..color = Colors.white.withValues(alpha: isDark ? 0.9 : 0.8)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
          }
        } else {
          final zeroPaint = Paint()
            ..color = (isDark ? Colors.white30 : Colors.black26)
                .withValues(alpha: (isAnySelected && !isSelected) ? 0.15 : 0.4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(left2, y0 - 1.2, right2, y0 + 1.2),
              const Radius.circular(1.2),
            ),
            zeroPaint,
          );
        }
      }
    } else {
      // ── Standard Single Series Mode ──────────────────────────────────
      final barWidth = math.max(2.5, math.min(slotWidth * 0.72, 28.0));
      const deficitColor = Color(0xFFEF4444);

      for (int i = 0; i < points.length; i++) {
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
            ..color = (p.value < 0 ? deficitColor : color)
                .withValues(alpha: isDark ? 0.12 : 0.08);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(
                left - 3,
                topPadding / 2,
                right + 3,
                size.height - bottomPadding,
              ),
              const Radius.circular(6),
            ),
            guidePaint,
          );
        }

        if (p.value == 0) {
          // Zero pill indicator resting on zero baseline
          final zeroPaint = Paint()
            ..color = (isDark ? Colors.white30 : Colors.black26)
                .withValues(alpha: (isAnySelected && !isSelected) ? 0.15 : 0.4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(left, y0 - 1.2, right, y0 + 1.2),
              const Radius.circular(1.2),
            ),
            zeroPaint,
          );
          continue;
        }

        if (p.value < 0) {
          // ── Negative Bar (Deficit: Cost > Revenue) ─────────────────────
          final barHeight = (p.value.abs() / totalSpan) * usableHeight;
          if (barHeight < 1.5) {
            final minDeficitPaint = Paint()
              ..color = deficitColor.withValues(alpha: 0.8 * dimAlpha);
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTRB(left, y0, right, y0 + 2.5),
                const Radius.circular(1.2),
              ),
              minDeficitPaint,
            );
            continue;
          }

          final barTop = y0;
          final barBottom = y0 + barHeight;
          final barRect = Rect.fromLTRB(left, barTop, right, barBottom);

          final rrect = RRect.fromRectAndCorners(
            barRect,
            bottomLeft: const Radius.circular(3.5),
            bottomRight: const Radius.circular(3.5),
          );

          final gradient = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              deficitColor.withValues(alpha: 0.95 * dimAlpha),
              deficitColor.withValues(alpha: 0.60 * dimAlpha),
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
          continue;
        }

        // ── Positive Bar (Revenue / Profit) ─────────────────────────────
        final barHeight = (p.value / totalSpan) * usableHeight;
        if (barHeight < 1.0) {
          final zeroPaint = Paint()
            ..color = (isDark ? Colors.white30 : Colors.black26)
                .withValues(alpha: (isAnySelected && !isSelected) ? 0.15 : 0.4);
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTRB(left, y0 - 2, right, y0),
              const Radius.circular(1.5),
            ),
            zeroPaint,
          );
          continue;
        }

        final barTop = y0 - barHeight;
        final barBottom = y0;

        if (showBreakdown && p.methodBreakdown.isNotEmpty) {
          // ── Stacked Bar by Payment Method ─────────────────────────────
          double currentBottom = barBottom;
          final entries = p.methodBreakdown.entries.toList();

          for (int m = 0; m < entries.length; m++) {
            final entry = entries[m];
            final amt = entry.value;
            if (amt <= 0) continue;

            final segHeight = (amt / p.value) * barHeight;
            final segTop = currentBottom - segHeight;
            final isTopSegment =
                m == entries.length - 1 || segTop <= barTop + 0.5;
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
          // ── Single Gradient Bar ───────────────────────────────────────
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
      oldDelegate.comparisonPoints != comparisonPoints ||
      oldDelegate.color != color ||
      oldDelegate.comparisonColor != comparisonColor ||
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
    this.comparisonPoints,
    this.color = AppColors.success,
    this.comparisonColor = const Color(0xFF8B5CF6),
    this.height = 175,
    this.selectedIndex,
    this.onPointSelected,
    this.tooltipContent,
    this.showBreakdown = false,
  });

  final List<DailyPoint> points;
  final List<DailyPoint>? comparisonPoints;
  final Color color;
  final Color comparisonColor;
  final double height;
  final int? selectedIndex;
  final ValueChanged<int?>? onPointSelected;
  final Widget? tooltipContent;
  final bool showBreakdown;

  @override
  Widget build(BuildContext context) {
    final hasComparison =
        comparisonPoints != null && comparisonPoints!.isNotEmpty;
    final totalCount = hasComparison
        ? math.max(points.length, comparisonPoints!.length)
        : points.length;

    if (totalCount == 0) {
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
          if (totalCount <= 0 || width <= 0) return;
          final slotWidth = width / totalCount;
          final index =
              (localPosition.dx / slotWidth).floor().clamp(0, totalCount - 1);
          if (index != selectedIndex) {
            onPointSelected?.call(index);
          }
        }

        // Calculate tooltip position
        Widget? tooltipWidget;
        if (tooltipContent != null &&
            selectedIndex != null &&
            selectedIndex! >= 0 &&
            selectedIndex! < totalCount &&
            width > 0) {
          final slotWidth = width / totalCount;
          final x = (selectedIndex! + 0.5) * slotWidth;

          final baseWidth = hasComparison ? 245.0 : 150.0;
          final tooltipWidth = math.min(baseWidth, math.max(120.0, width - 12));
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
                        comparisonPoints: comparisonPoints,
                        color: color,
                        comparisonColor: comparisonColor,
                        selectedIndex: selectedIndex,
                        isDark: isDark,
                        showBreakdown: showBreakdown && !hasComparison,
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
