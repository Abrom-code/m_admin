import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class PatternLockView extends StatefulWidget {
  const PatternLockView({
    super.key,
    required this.onCompleted,
    this.dimension = 280.0,
    this.minPoints = 4,
  });

  final ValueChanged<List<int>> onCompleted;
  final double dimension;
  final int minPoints;

  @override
  State<PatternLockView> createState() => PatternLockViewState();
}

class PatternLockViewState extends State<PatternLockView>
    with SingleTickerProviderStateMixin {
  final List<int> _selectedPoints = [];
  Offset? _currentTouch;
  bool _hasError = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void triggerError() {
    HapticFeedback.vibrate();
    setState(() {
      _hasError = true;
      _currentTouch = null;
    });

    _shakeController.forward(from: 0).then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          clear();
        }
      });
    });
  }

  void clear() {
    setState(() {
      _selectedPoints.clear();
      _currentTouch = null;
      _hasError = false;
    });
  }

  void _onPanStart(DragStartDetails details) {
    if (_hasError) return;
    _selectedPoints.clear();
    _handleTouch(details.localPosition);
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_hasError) return;
    _handleTouch(details.localPosition);
  }

  void _onPanEnd(DragEndDetails details) {
    if (_hasError) return;
    setState(() {
      _currentTouch = null;
    });

    if (_selectedPoints.isNotEmpty) {
      widget.onCompleted(List.unmodifiable(_selectedPoints));
    }
  }

  void _handleTouch(Offset localPos) {
    final size = widget.dimension;
    final step = size / 3;
    final radius = step * 0.38;

    setState(() {
      _currentTouch = localPos;
    });

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final pointIndex = row * 3 + col;
        if (_selectedPoints.contains(pointIndex)) continue;

        final center = Offset(
          col * step + step / 2,
          row * step + step / 2,
        );

        final distance = (localPos - center).distance;
        if (distance <= radius) {
          HapticFeedback.lightImpact();
          setState(() {
            _selectedPoints.add(pointIndex);
          });
          break;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(_shakeAnimation.value, 0),
          child: child,
        );
      },
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: widget.dimension,
            height: widget.dimension,
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                size: Size(widget.dimension, widget.dimension),
                painter: _PatternPainter(
                  selectedPoints: _selectedPoints,
                  currentTouch: _currentTouch,
                  hasError: _hasError,
                  isDark: dark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({
    required this.selectedPoints,
    required this.currentTouch,
    required this.hasError,
    required this.isDark,
  });

  final List<int> selectedPoints;
  final Offset? currentTouch;
  final bool hasError;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final step = size.width / 3;

    final baseNodeColor = isDark
        ? Colors.white.withValues(alpha: 0.18)
        : Colors.black.withValues(alpha: 0.15);

    final activeColor = hasError ? AppColors.error : AppColors.primary;

    final linePaint = Paint()
      ..color = activeColor.withValues(alpha: 0.85)
      ..strokeWidth = 3.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    // 1. Draw Connecting Lines between selected nodes
    if (selectedPoints.isNotEmpty) {
      final path = Path();
      final firstCenter = _getCenter(selectedPoints.first, step);
      path.moveTo(firstCenter.dx, firstCenter.dy);

      for (int i = 1; i < selectedPoints.length; i++) {
        final c = _getCenter(selectedPoints[i], step);
        path.lineTo(c.dx, c.dy);
      }

      canvas.drawPath(path, linePaint);

      // Draw live rubber band line to touch point
      if (currentTouch != null) {
        final lastCenter = _getCenter(selectedPoints.last, step);
        canvas.drawLine(lastCenter, currentTouch!, linePaint);
      }
    }

    // 2. Draw 3x3 Nodes
    for (int i = 0; i < 9; i++) {
      final center = _getCenter(i, step);
      final isSelected = selectedPoints.contains(i);

      if (isSelected) {
        // Outer glowing halo
        final haloPaint = Paint()
          ..color = activeColor.withValues(alpha: 0.22)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 24, haloPaint);

        // Outer ring
        final ringPaint = Paint()
          ..color = activeColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2;
        canvas.drawCircle(center, 24, ringPaint);

        // Solid inner dot
        final centerDotPaint = Paint()
          ..color = activeColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 7.5, centerDotPaint);
      } else {
        // Inactive default dot
        final dotPaint = Paint()
          ..color = baseNodeColor
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, 7.0, dotPaint);
      }
    }
  }

  Offset _getCenter(int index, double step) {
    final col = index % 3;
    final row = index ~/ 3;
    return Offset(
      col * step + step / 2,
      row * step + step / 2,
    );
  }

  @override
  bool shouldRepaint(covariant _PatternPainter oldDelegate) {
    return oldDelegate.selectedPoints != selectedPoints ||
        oldDelegate.currentTouch != currentTouch ||
        oldDelegate.hasError != hasError;
  }
}
