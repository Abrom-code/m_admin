import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:m_admin/utils/constants/colors.dart';

/// A data point for the line chart.
class LinePoint {
  const LinePoint(this.x, this.y);
  final double x; // 0..1 normalised
  final double y;
}

/// Hand-rolled line chart that matches the parent MatricMate app spec exactly:
/// 130 px tall, cubic midpoint smoothing, gradient fill, last-point dot.
class LineChartPainter extends CustomPainter {
  LineChartPainter({
    required this.points,
    this.color = AppColors.primary,
    this.strokeWidth = 2.5,
  });

  final List<LinePoint> points;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final minY = points.map((p) => p.y).reduce(math.min);
    final maxY = points.map((p) => p.y).reduce(math.max);
    final range = (maxY - minY).clamp(1.0, 100.0);

    // Map a data value to canvas coordinates.
    Offset toOffset(LinePoint p) {
      final dx = p.x * size.width;
      final dy = size.height - ((p.y - minY) / range) * size.height;
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
        color.withValues(alpha: 0.2),
        color.withValues(alpha: 0.0),
      ],
    );
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = gradient.createShader(Rect.fromLTWH(0, 0, size.width, size.height))
        ..style = PaintingStyle.fill,
    );

    // Line stroke.
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke,
    );

    // Last-point dot: outer circle (r=5, primary) + inner circle (r=3, white).
    final last = offsets.last;
    canvas.drawCircle(last, 5, Paint()..color = color);
    canvas.drawCircle(last, 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(LineChartPainter old) =>
      old.points != points || old.color != color;
}

/// A ready-to-use line chart widget with a 130 px fixed height.
class AdminLineChart extends StatelessWidget {
  const AdminLineChart({
    super.key,
    required this.points,
    this.color = AppColors.primary,
    this.height = 130,
  });

  final List<LinePoint> points;
  final Color color;
  final double height;

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

    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: LineChartPainter(points: points, color: color),
        size: Size.infinite,
      ),
    );
  }
}
