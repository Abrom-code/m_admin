import 'package:flutter/material.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// The page chrome every feature screen sits inside.
///
/// Defines page padding, max content width and the section header style in one
/// place, so eight feature screens cannot drift apart. Note this is NOT a
/// [Scaffold] — the shell owns the single Scaffold, and feature screens are
/// bodies inside its `IndexedStack`.
class AdminScaffold extends StatelessWidget {
  const AdminScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.maxContentWidth = 1200,
    this.scrollable = true,
    this.banner,
  });

  final String title;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget body;
  final double maxContentWidth;

  /// Set false when the body manages its own scrolling (a long data table,
  /// for instance) — nesting scroll views would break the table's own
  /// viewport.
  final bool scrollable;

  /// Rendered above the title. Used for standing caveats, such as the
  /// dashboard's sync-coverage warning.
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final header = Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceBtwItems),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: AppSizes.xs),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (actions != null && actions!.isNotEmpty)
            Wrap(
              spacing: AppSizes.sm,
              runSpacing: AppSizes.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions!,
            ),
        ],
      ),
    );

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banner != null) ...[
          banner!,
          const SizedBox(height: AppSizes.spaceBtwItems),
        ],
        header,
        if (scrollable) body else Expanded(child: body),
      ],
    );

    final constrained = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth),
        child: content,
      ),
    );

    return Padding(
      padding: const EdgeInsets.all(AppSizes.defaultSpace),
      child: scrollable
          ? SingleChildScrollView(child: constrained)
          : constrained,
    );
  }
}

/// A titled section inside a page, using the standard card idiom.
class AdminSection extends StatelessWidget {
  const AdminSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: AppSizes.spaceBtwItems),
          child,
        ],
      ),
    );
  }
}

/// The card idiom repeated verbatim across the parent app's analytics screens.
///
/// Extracted here so it exists once. Dark mode is read per widget via
/// [AppHelperFunctions.isDark], not from a global.
class AdminCard extends StatelessWidget {
  const AdminCard({
    super.key,
    required this.child,
    this.padding,
    this.borderColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets? padding;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    final container = Container(
      padding: padding ?? const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        border: borderColor == null ? null : Border.all(color: borderColor!),
        boxShadow: [
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

    if (onTap == null) return container;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      child: container,
    );
  }
}

/// An inline warning card. Used to state standing caveats in place rather than
/// letting a screen imply data is complete when it is not.
class AdminNoticeCard extends StatelessWidget {
  const AdminNoticeCard({
    super.key,
    required this.message,
    this.title,
    this.color = AppColors.warning,
    this.icon = Icons.info_outline_rounded,
    this.action,
  });

  final String message;
  final String? title;
  final Color color;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      borderColor: color.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: AppSizes.iconMd),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: AppSizes.xs),
                ],
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: AppSizes.sm), action!],
        ],
      ),
    );
  }
}
