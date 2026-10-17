import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:m_admin/utils/constants/colors.dart';

/// A data point for the line chart.
class LinePoint {
  const LinePoint(this.x, this.y);
  final double x; // 0..1 normalised
  final double y;
}

/// Hand-rolled line chart with cubic midpoint smoothing, gradient fill,
/// and interactive touch/click position highlight.
class LineChartPainter extends CustomPainter {
  LineChartPainter({
    required this.points,
    this.comparisonPoints,
    this.color = AppColors.primary,
    this.comparisonColor = const Color(0xFF8B5CF6),
    this.strokeWidth = 2.5,
    this.selectedIndex,
    this.showLastDot = true,
  });

  final List<LinePoint> points;
  final List<LinePoint>? comparisonPoints;
  final Color color;
  final Color comparisonColor;
  final double strokeWidth;
  final int? selectedIndex;
  final bool showLastDot;

  @override
  void paint(Canvas canvas, Size size) {
    final hasComparison =
        comparisonPoints != null && comparisonPoints!.isNotEmpty;
    if (points.length < 2 && (!hasComparison || comparisonPoints!.length < 2)) {
      return;
    }

    final allY = [
      ...points.map((p) => p.y),
      if (hasComparison) ...comparisonPoints!.map((p) => p.y),
    ];
    if (allY.isEmpty) return;

    final minY = allY.reduce(math.min);
    final maxY = allY.reduce(math.max);

    final totalSlots = hasComparison
        ? math.max(points.length, comparisonPoints!.length)
        : points.length;

    // Horizontal & vertical padding so curve endpoints & halo circles never bleed outside canvas
    const horizontalPadding = 8.0;
    const verticalPadding = 16.0;
    final usableWidth = math.max(size.width - (horizontalPadding * 2), 10.0);
    final usableHeight = math.max(size.height - (verticalPadding * 2), 10.0);
    final range = math.max(maxY - minY, 1.0);

    // Map a data value to canvas coordinates.
    Offset toOffset(LinePoint p) {
      final double normX = (p.x > 1.0 && totalSlots > 1)
          ? (p.x / (totalSlots - 1)).clamp(0.0, 1.0)
          : p.x.clamp(0.0, 1.0);
      final dx = horizontalPadding + (normX * usableWidth);
      final dy = (maxY == minY)
          ? size.height / 2
          : size.height - verticalPadding - ((p.y - minY) / range) * usableHeight;
      return Offset(dx.clamp(0.0, size.width), dy.clamp(0.0, size.height));
    }

    // ── 0. Draw Zero Baseline if Data Crosses Zero (Deficit Mode) ─────
    if (minY < 0 && maxY > 0) {
      final zeroY = size.height - verticalPadding - ((0.0 - minY) / range) * usableHeight;
      final zeroPaint = Paint()
        ..color = (Colors.white).withValues(alpha: 0.20)
        ..strokeWidth = 1.0;
      const dashW = 4.0;
      const dashS = 3.0;
      double startX = horizontalPadding;
      final endX = size.width - horizontalPadding;
      while (startX < endX) {
        canvas.drawLine(
          Offset(startX, zeroY),
          Offset(math.min(startX + dashW, endX), zeroY),
          zeroPaint,
        );
        startX += dashW + dashS;
      }
    }

    // ── 1. Draw Comparison Curve (if present) ──────────────────────────
    if (hasComparison && comparisonPoints!.length >= 2) {
      final compOffsets = comparisonPoints!.map(toOffset).toList();
      final compPath = Path()..moveTo(compOffsets.first.dx, compOffsets.first.dy);
      for (int i = 1; i < compOffsets.length; i++) {
        final prev = compOffsets[i - 1];
        final o = compOffsets[i];
        final midX = (prev.dx + o.dx) / 2;
        compPath.cubicTo(midX, prev.dy, midX, o.dy, o.dx, o.dy);
      }

      // Gradient fill under comparison curve
      final compFillPath = Path.from(compPath)
        ..lineTo(compOffsets.last.dx, size.height)
        ..lineTo(compOffsets.first.dx, size.height)
        ..close();

      canvas.drawPath(
        compFillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              comparisonColor.withValues(alpha: 0.14),
              comparisonColor.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill,
      );

      // Line stroke
      canvas.drawPath(
        compPath,
        Paint()
          ..color = comparisonColor
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    // ── 2. Draw Primary Curve (if present) ─────────────────────────────
    if (points.length >= 2) {
      final offsets = points.map(toOffset).toList();
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (int i = 1; i < offsets.length; i++) {
        final prev = offsets[i - 1];
        final o = offsets[i];
        final midX = (prev.dx + o.dx) / 2;
        path.cubicTo(midX, prev.dy, midX, o.dy, o.dx, o.dy);
      }

      // Gradient fill under primary curve
      final fillPath = Path.from(path)
        ..lineTo(offsets.last.dx, size.height)
        ..lineTo(offsets.first.dx, size.height)
        ..close();

      canvas.drawPath(
        fillPath,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              color.withValues(alpha: 0.22),
              color.withValues(alpha: 0.0),
            ],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
          ..style = PaintingStyle.fill,
      );

      // Line stroke
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..style = PaintingStyle.stroke,
      );
    }

    // ── 3. Crosshair & Point Indicators on Selection ───────────────────
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < totalSlots &&
        totalSlots > 1) {
      final selRatio = selectedIndex! / (totalSlots - 1);
      final selX = horizontalPadding + (selRatio * usableWidth);

      // Vertical dashed line across the chart height
      final linePaint = Paint()
        ..color = (hasComparison ? comparisonColor : color).withValues(alpha: 0.40)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      const dashHeight = 4.0;
      const dashSpace = 3.0;
      double startY = 0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(selX, startY),
          Offset(selX, math.min(startY + dashHeight, size.height)),
          linePaint,
        );
        startY += dashHeight + dashSpace;
      }

      // Halo on comparison point
      if (hasComparison && selectedIndex! < comparisonPoints!.length) {
        final compSel = toOffset(comparisonPoints![selectedIndex!]);
        canvas.drawCircle(
          compSel,
          10,
          Paint()..color = comparisonColor.withValues(alpha: 0.25),
        );
        canvas.drawCircle(compSel, 6, Paint()..color = comparisonColor);
        canvas.drawCircle(compSel, 2.5, Paint()..color = Colors.white);
      }

      // Halo on primary point
      if (selectedIndex! < points.length) {
        final primSel = toOffset(points[selectedIndex!]);
        canvas.drawCircle(
          primSel,
          10,
          Paint()..color = color.withValues(alpha: 0.25),
        );
        canvas.drawCircle(primSel, 6, Paint()..color = color);
        canvas.drawCircle(primSel, 2.5, Paint()..color = Colors.white);
      }
    } else if (showLastDot) {
      if (points.isNotEmpty) {
        final last = toOffset(points.last);
        canvas.drawCircle(last, 5, Paint()..color = color);
        canvas.drawCircle(last, 3, Paint()..color = Colors.white);
      }
      if (hasComparison && comparisonPoints!.isNotEmpty) {
        final compLast = toOffset(comparisonPoints!.last);
        canvas.drawCircle(compLast, 5, Paint()..color = comparisonColor);
        canvas.drawCircle(compLast, 3, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(LineChartPainter old) =>
      old.points != points ||
      old.comparisonPoints != comparisonPoints ||
      old.color != color ||
      old.comparisonColor != comparisonColor ||
      old.selectedIndex != selectedIndex ||
      old.showLastDot != showLastDot;
}

/// An interactive line chart widget with tap/drag/click amount inspection
/// and optional comparative series support.
class AdminLineChart extends StatelessWidget {
  const AdminLineChart({
    super.key,
    required this.points,
    this.comparisonPoints,
    this.color = AppColors.primary,
    this.comparisonColor = const Color(0xFF8B5CF6),
    this.height = 175,
    this.selectedIndex,
    this.onPointSelected,
    this.tooltipContent,
  });

  final List<LinePoint> points;
  final List<LinePoint>? comparisonPoints;
  final Color color;
  final Color comparisonColor;
  final double height;
  final int? selectedIndex;
  final ValueChanged<int?>? onPointSelected;
  final Widget? tooltipContent;

  @override
  Widget build(BuildContext context) {
    final hasComparison =
        comparisonPoints != null && comparisonPoints!.isNotEmpty;
    final totalCount = hasComparison
        ? math.max(points.length, comparisonPoints!.length)
        : points.length;

    if (totalCount < 2) {
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        void handlePosition(Offset localPosition) {
          if (totalCount < 2 || width <= 0) return;
          final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
          final index =
              (ratio * (totalCount - 1)).round().clamp(0, totalCount - 1);
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
          final ratio = totalCount > 1
              ? (selectedIndex! / (totalCount - 1))
              : 0.5;
          final x = ratio * width;

          final baseTooltipWidth = hasComparison ? 245.0 : 135.0;
          final tooltipWidth =
              math.min(baseTooltipWidth, math.max(120.0, width - 12));
          double left = x - (tooltipWidth / 2);
          if (left < 6) left = 6;
          if (left + tooltipWidth > width - 6) left = width - tooltipWidth - 6;

          tooltipWidget = Positioned(
            left: left,
            top: 2,
            width: tooltipWidth,
            child: tooltipContent!,
          );
        }

        return ClipRect(
          child: SizedBox(
            height: height,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) => handlePosition(event.localPosition),
              onPointerMove: (event) => handlePosition(event.localPosition),
              onPointerHover: (event) => handlePosition(event.localPosition),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: LineChartPainter(
                          points: points,
                          comparisonPoints: comparisonPoints,
                          color: color,
                          comparisonColor: comparisonColor,
                          selectedIndex: selectedIndex,
                        ),
                        size: Size.infinite,
                      ),
                    ),
                    ?tooltipWidget,
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
