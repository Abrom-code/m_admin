import 'package:flutter/material.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Temporary stand-in for a feature screen that has not been built yet.
///
/// It states plainly that the screen is unimplemented rather than rendering an
/// empty page — an admin should never be unsure whether they are looking at a
/// blank screen or an unbuilt one.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, this.phase});

  final String title;

  /// Which phase of ADMIN_APP_PROMPT.md will implement this screen.
  final String? phase;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Container(
          padding: const EdgeInsets.all(AppSizes.lg),
          margin: const EdgeInsets.all(AppSizes.defaultSpace),
          constraints: const BoxConstraints(maxWidth: 420),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkCard : AppColors.white,
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                spreadRadius: -2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.construction_rounded,
                size: AppSizes.iconLg,
                color: AppColors.darkGrey,
              ),
              const SizedBox(height: AppSizes.spaceBtwItems),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSizes.xs),
              Text(
                phase == null
                    ? 'Not implemented yet.'
                    : 'Not implemented yet — $phase.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
