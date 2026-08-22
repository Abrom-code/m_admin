import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/content/screens/content_screen.dart';
import 'package:m_admin/features/dashboard/screens/dashboard_screen.dart';
import 'package:m_admin/features/notifications/screens/notifications_screen.dart';
import 'package:m_admin/features/payments/screens/payments_screen.dart';
import 'package:m_admin/features/sessions/screens/sessions_screen.dart';
import 'package:m_admin/features/settings/screens/settings_screen.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/features/shell/screens/widgets/admin_sidebar.dart';
import 'package:m_admin/features/users/screens/users_screen.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Breakpoint below which the sidebar collapses into a drawer and bottom navigation bar.
const double kSidebarBreakpoint = 900;

/// Fixed sidebar width on wide layouts.
const double kSidebarWidth = 260;

/// The persistent frame of the admin console.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  /// Key used to open the [Scaffold] drawer programmatically from the swipe
  /// gesture detector that lives inside the body.
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  /// Horizontal drag start position – used to decide swipe direction.
  double _dragStartX = 0;

  void _onHorizontalDragStart(DragStartDetails details) {
    _dragStartX = details.globalPosition.dx;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final dx = (details.globalPosition.dx) - _dragStartX;
    // Open the drawer only on a clear left-to-right swipe (> 30 px threshold)
    // that starts near the left edge of the screen (first 60 px).
    if (dx > 30 && _dragStartX < 60) {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final nav = AdminNavController.instance;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= kSidebarBreakpoint;

        final appBar = AppBar(
          title: Obx(
            () => Text(AdminNavController.items[nav.selectedIndex.value].label),
          ),
          actions: [
            Obx(() {
              if (!nav.currentPageHasRefresh) return const SizedBox.shrink();
              return Obx(() {
                final spinning = nav.isRefreshing.value;
                return AnimatedRotation(
                  turns: spinning ? 1 : 0,
                  duration: spinning
                      ? const Duration(milliseconds: 700)
                      : Duration.zero,
                  child: IconButton(
                    tooltip: 'Refresh',
                    onPressed:
                        spinning ? null : nav.invokeCurrentRefresh,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                );
              });
            }),
            const SizedBox(width: 4),
          ],
        );

        if (isWide) {
          // Wide layout: persistent sidebar – no drawer or bottom nav needed.
          return Scaffold(
            appBar: appBar,
            body: Row(
              children: [
                SizedBox(
                  width: kSidebarWidth,
                  child: AdminSidebar(onLogout: () => _confirmLogout(context)),
                ),
                Expanded(child: _Pages(nav: nav)),
              ],
            ),
          );
        }

        // Narrow layout: bottom navigation bar + drawer for secondary pages (Sessions, Settings).
        return Scaffold(
          key: _scaffoldKey,
          appBar: appBar,
          drawer: Drawer(
            width: kSidebarWidth,
            child: AdminSidebar(
              onLogout: () => _confirmLogout(context),
              // In drawer mode a tap should also close the drawer.
              onNavigate: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragStart: _onHorizontalDragStart,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            child: _Pages(nav: nav),
          ),
          bottomNavigationBar: _AdminBottomNavBar(nav: nav),
        );
      },
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await AppDialogBoxes.confirm(
      title: 'Sign out',
      message: 'You will need to sign in again to review payments.',
      confirmLabel: 'Sign out',
      isDestructive: true,
    );

    if (!confirmed) return;

    try {
      await AdminSessionService.instance.logout();
      Get.offAllNamed(AdminRoutes.login);
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    }
  }
}

// ── Bottom Navigation Bar ──────────────────────────────────────────────────

class _AdminBottomNavBar extends StatelessWidget {
  const _AdminBottomNavBar({required this.nav});

  final AdminNavController nav;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Obx(() {
      final currentIdx = nav.selectedIndex.value;
      // Tabs 0: Dashboard, 1: Payments, 2: Notifications, 3: Users, 4: Content.
      final selectedDest = (currentIdx >= 0 && currentIdx <= 4) ? currentIdx : 0;

      return Container(
        decoration: BoxDecoration(
          color: dark ? AppColors.darkSurface : AppColors.white,
          border: Border(
            top: BorderSide(
              color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
              width: 1,
            ),
          ),
        ),
        child: NavigationBar(
          height: 62,
          elevation: 0,
          backgroundColor: Colors.transparent,
          indicatorColor: AppColors.primary.withValues(alpha: 0.16),
          selectedIndex: selectedDest,
          onDestinationSelected: (index) {
            nav.changePage(index);
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Iconsax.chart_2_copy, size: 20),
              selectedIcon: Icon(Iconsax.chart_2, size: 20, color: AppColors.primary),
              label: 'Dashboard',
            ),
            NavigationDestination(
              icon: _NavBadge(
                count: nav.pendingPaymentCount.value,
                color: AppColors.warning,
                child: const Icon(Iconsax.receipt_copy, size: 20),
              ),
              selectedIcon: _NavBadge(
                count: nav.pendingPaymentCount.value,
                color: AppColors.warning,
                child: const Icon(Iconsax.receipt_2, size: 20, color: AppColors.primary),
              ),
              label: 'Payments',
            ),
            NavigationDestination(
              icon: _NavBadge(
                count: nav.unreadAlertCount.value,
                color: AppColors.error,
                child: const Icon(Iconsax.notification_copy, size: 20),
              ),
              selectedIcon: _NavBadge(
                count: nav.unreadAlertCount.value,
                color: AppColors.error,
                child: const Icon(Iconsax.notification, size: 20, color: AppColors.primary),
              ),
              label: 'Alerts',
            ),
            const NavigationDestination(
              icon: Icon(Iconsax.people_copy, size: 20),
              selectedIcon: Icon(Iconsax.profile_2user, size: 20, color: AppColors.primary),
              label: 'Users',
            ),
            const NavigationDestination(
              icon: Icon(Iconsax.book_copy, size: 20),
              selectedIcon: Icon(Iconsax.book, size: 20, color: AppColors.primary),
              label: 'Content',
            ),
          ],
        ),
      );
    });
  }
}

class _NavBadge extends StatelessWidget {
  const _NavBadge({
    required this.count,
    required this.color,
    required this.child,
  });

  final int count;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return child;
    return Badge(
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 9.5,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      backgroundColor: color,
      child: child,
    );
  }
}

// ── Tab Bodies ─────────────────────────────────────────────────────────────

class _Pages extends StatelessWidget {
  const _Pages({required this.nav});

  final AdminNavController nav;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => IndexedStack(
        index: nav.selectedIndex.value,
        children: [
          const DashboardScreen(),
          const PaymentsScreen(),
          const NotificationsScreen(),
          const UsersScreen(),
          const ContentScreen(),
          const SessionsScreen(),
          const SettingsScreen(),
        ],
      ),
    );
  }
}
