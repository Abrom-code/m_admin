import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:m_admin/utils/constants/colors.dart';

/// A single segment in the donut chart.
class DonutSegment {
  const DonutSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// Hand-rolled donut chart — matches the MatricMate spec exactly:
/// strokeWidth 18, radius = size.width/2 - 8, gap = 0.03 rad,
/// start at -π/2, laid out 110×110 beside a dot legend.
class DonutChartPainter extends CustomPainter {
  DonutChartPainter({required this.segments});

  final List<DonutSegment> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    if (total == 0) return;

    const strokeWidth = 18.0;
    const gap = 0.03; // radians between segments
    final radius = size.width / 2 - 8;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);

    var startAngle = -math.pi / 2;

    for (final seg in segments) {
      final sweep = (seg.value / total) * (2 * math.pi) - gap;
      if (sweep <= 0) continue;

      canvas.drawArc(
        rect,
        startAngle + gap / 2,
        sweep,
        false,
        Paint()
          ..color = seg.color
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.butt,
      );

      startAngle += sweep + gap;
    }
  }

  @override
  bool shouldRepaint(DonutChartPainter old) => old.segments != segments;
}

/// A 110×110 donut with a legend beside it.
class AdminDonutChart extends StatelessWidget {
  const AdminDonutChart({
    super.key,
    required this.segments,
    this.size = 110,
  });

  final List<DonutSegment> segments;
  final double size;

  @override
  Widget build(BuildContext context) {
    final total = segments.fold<double>(0, (s, e) => s + e.value);
    final hasData = total > 0;

    final chart = SizedBox(
      width: size,
      height: size,
      child: hasData
          ? CustomPaint(painter: DonutChartPainter(segments: segments))
          : const Center(
              child: Text(
                'No data',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final seg in segments)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: seg.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  hasData
                      ? '${seg.label} '
                            '${(seg.value / total * 100).toStringAsFixed(0)}%'
                      : seg.label,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    // Minimum width to fit circle + 16 gap + ~120 px legend side-by-side.
    // Below that threshold the legend drops below the circle.
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < size + 16 + 120) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [chart, const SizedBox(height: 12), legend],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [chart, const SizedBox(width: 16), legend],
        );
      },
    );
  }
}
