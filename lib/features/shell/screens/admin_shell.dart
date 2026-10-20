import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/data/services/admin_notification_service.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/challenges/screens/challenges_list_screen.dart';
import 'package:m_admin/features/content/screens/content_screen.dart';
import 'package:m_admin/features/content/screens/question_reports_screen.dart';
import 'package:m_admin/features/dashboard/screens/dashboard_screen.dart';
import 'package:m_admin/features/notes/screens/notes_screen.dart';
import 'package:m_admin/features/notifications/screens/notifications_screen.dart';
import 'package:m_admin/features/payments/controllers/payments_controller.dart';
import 'package:m_admin/features/payments/screens/payments_screen.dart';
import 'package:m_admin/features/payments/screens/widgets/receipt_cleanup_dialog.dart';
import 'package:m_admin/features/payments/screens/widgets/verify_et_settings_dialog.dart';
import 'package:m_admin/features/pilot_exams/screens/pilot_exams_screen.dart';
import 'package:m_admin/features/revenue/screens/revenue_screen.dart';
import 'package:m_admin/features/security/controllers/app_lock_controller.dart';
import 'package:m_admin/features/security/screens/passcode_setup_dialog.dart';
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
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _requestNotificationPermission();
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (Get.isRegistered<AdminNotificationService>()) {
      await AdminNotificationService.instance.requestPermission();
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
            () => Text(
              nav.selectedIndex.value >= 0 &&
                      nav.selectedIndex.value < AdminNavController.items.length
                  ? AdminNavController.items[nav.selectedIndex.value].label
                  : 'Admin console',
            ),
          ),
          actions: [
            Obx(() {
              final isPayments = nav.selectedIndex.value == AdminNavPage.payments;
              if (!isPayments) return const SizedBox.shrink();

              final paymentsCtrl = Get.isRegistered<PaymentsController>()
                  ? PaymentsController.instance
                  : null;
              final isVerif = paymentsCtrl?.activeTab.value == 'verification';

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: isVerif ? 'Verify.ET Settings' : 'Verify.ET Gateway',
                    onPressed: () {
                      if (paymentsCtrl == null) return;
                      if (isVerif) {
                        VerifyEtSettingsDialog.show(context);
                      } else {
                        paymentsCtrl.changeTab('verification');
                      }
                    },
                    icon: Icon(
                      Iconsax.shield_tick_copy,
                      size: 20,
                      color: isVerif ? const Color(0xFF6366F1) : null,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Storage Cleanup',
                    onPressed: () => ReceiptCleanupDialog.show(context),
                    icon: const Icon(Icons.cleaning_services_rounded, size: 20),
                  ),
                ],
              );
            }),
            IconButton(
              tooltip: 'Admin Settings',
              onPressed: () => Get.toNamed(AdminRoutes.settings),
              icon: const Icon(Iconsax.setting_2_copy, size: 20),
            ),
            Obx(() {
              final lockCtrl = Get.isRegistered<AppLockController>()
                  ? AppLockController.instance
                  : null;
              final isEnabled = lockCtrl?.isPasscodeEnabled.value ?? false;

              return IconButton(
                tooltip: isEnabled ? 'Lock Console (Passcode)' : 'Set Up App Lock',
                onPressed: () {
                  if (lockCtrl == null) return;
                  if (isEnabled) {
                    lockCtrl.lock();
                  } else {
                    PasscodeSetupDialog.show(context);
                  }
                },
                icon: Icon(
                  isEnabled ? Iconsax.lock_copy : Iconsax.unlock_copy,
                  size: 20,
                  color: isEnabled ? AppColors.primary : AppColors.textSecondary,
                ),
              );
            }),
            Obx(() {
              final pageIdx = nav.selectedIndex.value;
              final hasRefresh = pageIdx >= 0 && nav.currentPageHasRefresh;
              if (!hasRefresh) return const SizedBox.shrink();

              final spinning = nav.isRefreshing.value;
              return AnimatedRotation(
                turns: spinning ? 1 : 0,
                duration: spinning
                    ? const Duration(milliseconds: 700)
                    : Duration.zero,
                child: IconButton(
                  tooltip: 'Refresh',
                  onPressed: spinning ? null : nav.invokeCurrentRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
              );
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

        // Narrow layout: bottom navigation bar + drawer for secondary pages.
        return Scaffold(
          key: _scaffoldKey,
          drawerEnableOpenDragGesture: false,
          appBar: appBar,
          drawer: Drawer(
            width: kSidebarWidth,
            child: AdminSidebar(
              onLogout: () => _confirmLogout(context),
              onNavigate: () => Navigator.of(context).maybePop(),
            ),
          ),
          body: _Pages(nav: nav),
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

// ── Bottom Navigation Bar (Strict 5-Tab Focus) ─────────────────────────────

class _AdminBottomNavBar extends StatelessWidget {
  const _AdminBottomNavBar({required this.nav});

  final AdminNavController nav;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Obx(() {
      final currentIdx = nav.selectedIndex.value;
      const bottomNavPages = [
        AdminNavPage.payments,
        AdminNavPage.notifications,
        AdminNavPage.dashboard,
        AdminNavPage.users,
        AdminNavPage.challenges,
      ];
      final matchedIdx = bottomNavPages.indexOf(currentIdx);
      final selectedDest = matchedIdx >= 0 ? matchedIdx : 2;

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
          indicatorColor: matchedIdx >= 0
              ? AppColors.primary.withValues(alpha: 0.16)
              : Colors.transparent,
          selectedIndex: selectedDest,
          onDestinationSelected: (index) {
            nav.changePage(bottomNavPages[index]);
          },
          destinations: [
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
              icon: Icon(Iconsax.chart_2_copy, size: 20),
              selectedIcon: Icon(Iconsax.chart_2, size: 20, color: AppColors.primary),
              label: 'Dashboard',
            ),
            const NavigationDestination(
              icon: Icon(Iconsax.people_copy, size: 20),
              selectedIcon: Icon(Iconsax.people, size: 20, color: AppColors.primary),
              label: 'Users',
            ),
            const NavigationDestination(
              icon: Icon(Iconsax.cup_copy, size: 20),
              selectedIcon: Icon(Iconsax.cup, size: 20, color: AppColors.primary),
              label: 'Challenges',
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

// ── Lazy Tab Instantiation (Eliminate Eager Multi-Screen Boot) ──────────────

class _Pages extends StatefulWidget {
  const _Pages({required this.nav});

  final AdminNavController nav;

  @override
  State<_Pages> createState() => _PagesState();
}

class _PagesState extends State<_Pages> {
  /// Tracks which tabs have been initialized at least once.
  final Set<int> _loadedTabs = {0};

  @override
  void initState() {
    super.initState();
    _loadedTabs.add(widget.nav.selectedIndex.value);
  }

  Widget _buildScreen(int index) {
    return switch (index) {
      AdminNavPage.dashboard => const DashboardScreen(),
      AdminNavPage.payments => const PaymentsScreen(),
      AdminNavPage.revenue => const RevenueScreen(),
      AdminNavPage.notifications => const NotificationsScreen(),
      AdminNavPage.users => const UsersScreen(),
      AdminNavPage.content => const ContentScreen(),
      AdminNavPage.notes => const NotesScreen(),
      AdminNavPage.pilotExams => const PilotExamsScreen(),
      AdminNavPage.reportedQuestions => const QuestionReportsScreen(),
      AdminNavPage.challenges => const ChallengesListScreen(),
      AdminNavPage.sessions => const SessionsScreen(),
      AdminNavPage.settings => const SettingsScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final currentIdx = widget.nav.selectedIndex.value;
      if (currentIdx >= 0 && currentIdx < AdminNavController.items.length) {
        _loadedTabs.add(currentIdx);
      }

      return IndexedStack(
        index: currentIdx.clamp(0, AdminNavController.items.length - 1),
        children: [
          for (var i = 0; i < AdminNavController.items.length; i++)
            ExcludeFocus(
              excluding: currentIdx != i,
              child: FocusScope(
                child: _loadedTabs.contains(i)
                    ? _buildScreen(i)
                    : const SizedBox.shrink(),
              ),
            ),
        ],
      );
    });
  }
}
