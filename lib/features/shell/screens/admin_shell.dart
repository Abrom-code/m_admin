import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/audit_log/screens/audit_log_screen.dart';
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
import 'package:m_admin/utils/exceptions/exception_handler.dart';

/// Breakpoint below which the sidebar collapses into a drawer.
const double kSidebarBreakpoint = 900;

/// Fixed sidebar width on wide layouts.
const double kSidebarWidth = 260;

/// The persistent frame of the admin console.
///
/// The parent app uses a floating pill bottom nav for five phone tabs. An
/// admin tool is a desk tool, so this is a persistent left sidebar on wide
/// screens, falling back to a drawer under 900px.
class AdminShell extends StatelessWidget {
  const AdminShell({super.key});

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
              return IconButton(
                tooltip: 'Refresh',
                onPressed: nav.invokeCurrentRefresh,
                icon: const Icon(Icons.refresh_rounded),
              );
            }),
            const SizedBox(width: 4),
          ],
        );

        if (isWide) {
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

        return Scaffold(
          appBar: appBar,
          drawer: Drawer(
            width: kSidebarWidth,
            child: AdminSidebar(
              onLogout: () => _confirmLogout(context),
              // In drawer mode a tap should also close the drawer.
              onNavigate: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: _Pages(nav: nav),
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

/// The tab bodies.
///
/// An [IndexedStack] so tab state survives switching — a scrolled payment
/// queue or a half-written announcement is still there on return.
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
          const AuditLogScreen(),
          const SettingsScreen(),
        ],
      ),
    );
  }
}
