import 'package:flutter/material.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

// ── Full-screen page loader ───────────────────────────────────────────────────

class AppCircularLoading extends StatelessWidget {
  const AppCircularLoading({super.key, this.title = 'Loading...'});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppPulsingDots(),
          const SizedBox(height: AppSizes.spaceBtwItems),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Pulsing dots (reusable) ───────────────────────────────────────────────────

class AppPulsingDots extends StatefulWidget {
  const AppPulsingDots({
    super.key,
    this.dotSize = 7,
    this.dotSpacing = 4,
    this.color = AppColors.primary,
  });

  final double dotSize;
  final double dotSpacing;
  final Color color;

  @override
  State<AppPulsingDots> createState() => _AppPulsingDotsState();
}

class _AppPulsingDotsState extends State<AppPulsingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final delay = i * 0.2;
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (_, _) {
            final t = ((_ctrl.value - delay) % 1.0 + 1.0) % 1.0;
            final opacity = t < 0.4
                ? (t / 0.4)
                : t < 0.8
                    ? 1.0 - ((t - 0.4) / 0.4)
                    : 0.0;
            return Container(
              margin: EdgeInsets.symmetric(horizontal: widget.dotSpacing),
              width: widget.dotSize,
              height: widget.dotSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.3 + (opacity * 0.7)),
              ),
            );
          },
        );
      }),
    );
  }
}

// ── Small inline button loader ────────────────────────────────────────────────

class AppCircularButtonLoading extends StatelessWidget {
  const AppCircularButtonLoading({
    super.key,
    this.color = Colors.white,
    this.title = 'Loading...',
  });
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppPulsingDots(dotSize: 6, color: color);
  }
}
