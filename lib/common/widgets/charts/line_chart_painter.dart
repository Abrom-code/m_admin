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
    this.color = AppColors.primary,
    this.strokeWidth = 2.5,
    this.selectedIndex,
    this.showLastDot = true,
  });

  final List<LinePoint> points;
  final Color color;
  final double strokeWidth;
  final int? selectedIndex;
  final bool showLastDot;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minY = points.map((p) => p.y).reduce(math.min);
    final maxY = points.map((p) => p.y).reduce(math.max);

    // Vertical padding so extreme high/low values never clip off the canvas
    const verticalPadding = 14.0;
    final usableHeight = math.max(size.height - (verticalPadding * 2), 10.0);
    final range = math.max(maxY - minY, 1.0);

    // Map a data value to canvas coordinates.
    Offset toOffset(LinePoint p) {
      final dx = p.x * size.width;
      final dy = (maxY == minY)
          ? size.height / 2
          : size.height - verticalPadding - ((p.y - minY) / range) * usableHeight;
      return Offset(dx, dy.clamp(0.0, size.height));
    }

    final offsets = points.map(toOffset).toList();

    // Build the path with cubic midpoint smoothing.
    final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
    for (int i = 1; i < offsets.length; i++) {
      final prev = offsets[i - 1];
      final o = offsets[i];
      final midX = (prev.dx + o.dx) / 2;
      path.cubicTo(midX, prev.dy, midX, o.dy, o.dx, o.dy);
    }

    // Gradient fill under the curve.
    final fillPath = Path.from(path)
      ..lineTo(offsets.last.dx, size.height)
      ..lineTo(offsets.first.dx, size.height)
      ..close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color.withValues(alpha: 0.22),
        color.withValues(alpha: 0.0),
      ],
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        )
        ..style = PaintingStyle.fill,
    );

    // Line stroke.
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke,
    );

    // Highlight selected point if any is active
    if (selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < offsets.length) {
      final sel = offsets[selectedIndex!];

      // Vertical dashed line from top to bottom
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      const dashHeight = 4.0;
      const dashSpace = 3.0;
      double startY = 0;
      while (startY < size.height) {
        canvas.drawLine(
          Offset(sel.dx, startY),
          Offset(sel.dx, math.min(startY + dashHeight, size.height)),
          linePaint,
        );
        startY += dashHeight + dashSpace;
      }

      // Outer halo
      canvas.drawCircle(sel, 10, Paint()..color = color.withValues(alpha: 0.2));
      // Mid circle
      canvas.drawCircle(sel, 6, Paint()..color = color);
      // Center dot
      canvas.drawCircle(sel, 3, Paint()..color = Colors.white);
    } else if (showLastDot) {
      // Last-point dot when no point is selected: outer circle + inner circle.
      final last = offsets.last;
      canvas.drawCircle(last, 5, Paint()..color = color);
      canvas.drawCircle(last, 3, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(LineChartPainter old) =>
      old.points != points ||
      old.color != color ||
      old.selectedIndex != selectedIndex ||
      old.showLastDot != showLastDot;
}

/// An interactive line chart widget with tap/drag/click amount inspection.
class AdminLineChart extends StatelessWidget {
  const AdminLineChart({
    super.key,
    required this.points,
    this.color = AppColors.primary,
    this.height = 175,
    this.selectedIndex,
    this.onPointSelected,
    this.tooltipContent,
  });

  final List<LinePoint> points;
  final Color color;
  final double height;
  final int? selectedIndex;
  final ValueChanged<int?>? onPointSelected;
  final Widget? tooltipContent;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
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
          if (points.length < 2 || width <= 0) return;
          final ratio = (localPosition.dx / width).clamp(0.0, 1.0);
          final index = (ratio * (points.length - 1)).round().clamp(0, points.length - 1);
          onPointSelected?.call(index);
        }

        // Calculate tooltip position
        Widget? tooltipWidget;
        if (tooltipContent != null &&
            selectedIndex != null &&
            selectedIndex! >= 0 &&
            selectedIndex! < points.length &&
            width > 0) {
          final ratio = points[selectedIndex!].x;
          final x = ratio * width;

          const tooltipWidth = 140.0;
          double left = x - (tooltipWidth / 2);
          if (left < 6) left = 6;
          if (left + tooltipWidth > width - 6) left = width - tooltipWidth - 6;

          tooltipWidget = Positioned(
            left: left,
            top: 2,
            width: tooltipWidth,
            child: IgnorePointer(
              child: tooltipContent,
            ),
          );
        }

        return SizedBox(
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => handlePosition(details.localPosition),
            onPanUpdate: (details) => handlePosition(details.localPosition),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onHover: (event) => handlePosition(event.localPosition),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: CustomPaint(
                      painter: LineChartPainter(
                        points: points,
                        color: color,
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
        );
      },
    );
  }
}
