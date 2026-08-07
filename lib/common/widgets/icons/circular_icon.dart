import 'package:flutter/material.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class CircularIcon extends StatelessWidget {
  const CircularIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = 40,
    this.radius = 50,
    this.isTransparent = false,
    this.isCustomColor = false,
    this.background,
    this.onPressed,
    this.borderColor = Colors.transparent,
    this.iconWeight,
  });

  final IconData icon;
  final double size;
  final double radius;
  final Color color;
  final bool isTransparent;
  final bool isCustomColor;
  final Color? background;
  final VoidCallback? onPressed;
  final Color borderColor;
  final FontWeight? iconWeight;

  @override
  Widget build(BuildContext context) {
    final bool dark = AppHelperFunctions.isDark(context);

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: borderColor),
        color: isTransparent
            ? Colors.transparent
            : isCustomColor
            ? (background ?? Colors.grey)
            : dark
            ? AppColors.darkCard.withValues(alpha: 0.9)
            : AppColors.white.withValues(alpha: 0.9),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: color, fontWeight: iconWeight),
      ),
    );
  }
}
