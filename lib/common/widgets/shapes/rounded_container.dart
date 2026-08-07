import 'package:flutter/material.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class RoundedContainer extends StatelessWidget {
  const RoundedContainer({
    super.key,
    required this.child,
    this.radius,
    this.padding,
    this.width,
    this.height,
  });

  final Widget child;
  final double? radius;
  final EdgeInsets? padding;
  final double? width, height;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      width: width,
      height: height,
      padding:
          padding ??
          const EdgeInsets.symmetric(
            vertical: AppSizes.defaultSpace / 1.5,
            horizontal: AppSizes.sm * 1.5,
          ),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(radius ?? AppSizes.sm),
        boxShadow: dark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  spreadRadius: -2,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: child,
    );
  }
}
