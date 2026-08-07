import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/themes/theme_controller.dart';

/// The console's primary navigation.
///
/// Rendered as a fixed column on wide layouts and inside a [Drawer] below the
/// breakpoint — the same widget either way.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({super.key, required this.onLogout, this.onNavigate});

  final VoidCallback onLogout;

  /// Called after a nav tap, so drawer mode can close itself.
  final VoidCallback? onNavigate;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final nav = AdminNavController.instance;

    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _SidebarBrand(),
            const Divider(height: 1),

            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(
                  vertical: AppSizes.sm,
                  horizontal: AppSizes.sm,
                ),
                itemCount: AdminNavController.items.length,
                itemBuilder: (context, index) {
                  final item = AdminNavController.items[index];
                  return Obx(
                    () => _SidebarItem(
                      item: item,
                      selected: nav.selectedIndex.value == index,
                      badgeCount: nav.badgeFor(item.badgeSource),
                      onTap: () {
                        nav.changePage(index);
                        onNavigate?.call();
                      },
                    ),
                  );
                },
              ),
            ),

            const Divider(height: 1),
            _SidebarFooter(onLogout: onLogout),
          ],
        ),
      ),
    );
  }
}

class _SidebarBrand extends StatelessWidget {
  const _SidebarBrand();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
            ),
            child: const Icon(
              Iconsax.shield_tick_copy,
              color: AppColors.primary,
              size: AppSizes.iconSm + 4,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MatricMate',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                Text(
                  'Admin console',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A nav row, styled after the parent app's floating nav button:
/// `AnimatedContainer` 200ms `Curves.easeInOut`, primary tint at 12% alpha,
/// radius 22.
class _SidebarItem extends StatelessWidget {
  const _SidebarItem({
    required this.item,
    required this.selected,
    required this.badgeCount,
    required this.onTap,
  });

  final AdminNavItem item;
  final bool selected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    final foreground = selected
        ? AppColors.primary
        : (dark ? Colors.white54 : AppColors.darkGrey);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSizes.md,
            vertical: AppSizes.sm + 2,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(22),
          ),
          child: Row(
            children: [
              Icon(item.icon, size: AppSizes.iconMd - 4, color: foreground),
              const SizedBox(width: AppSizes.sm + 4),
              Expanded(
                child: Text(
                  item.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
              if (badgeCount > 0) _Badge(count: badgeCount),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      constraints: const BoxConstraints(minWidth: 20),
      decoration: BoxDecoration(
        color: AppColors.warning,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: AppColors.white,
        ),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final session = AdminSessionService.instance;
    final theme = ThemeController.instance;
    final dark = AppHelperFunctions.isDark(context);

    return Padding(
      padding: const EdgeInsets.all(AppSizes.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Obx(() {
            final admin = session.admin.value;

            return Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.sm,
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      admin.initials,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSizes.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          admin.displayNameOrEmail,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          admin.email,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSizes.xs),
                  _RoleChip(role: admin.role),
                ],
              ),
            );
          }),

          // Theme toggle
          Obx(
            () => SwitchListTile(
              dense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
              ),
              value: theme.themeMode.value == ThemeMode.dark || dark,
              onChanged: theme.toggleTheme,
              title: const Text('Dark mode', style: TextStyle(fontSize: 12)),
              secondary: const Icon(Iconsax.moon_copy, size: AppSizes.iconSm),
            ),
          ),

          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: AppSizes.sm,
            ),
            leading: const Icon(
              Iconsax.logout_copy,
              size: AppSizes.iconSm,
              color: AppColors.error,
            ),
            title: const Text(
              'Sign out',
              style: TextStyle(fontSize: 12, color: AppColors.error),
            ),
            onTap: onLogout,
          ),
        ],
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    final isSuper = role == 'superadmin';
    final color = isSuper ? AppColors.secondary : AppColors.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      ),
      child: Text(
        isSuper ? 'SUPER' : 'ADMIN',
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}
