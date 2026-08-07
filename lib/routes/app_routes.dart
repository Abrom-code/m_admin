import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/common/widgets/layout/placeholder_screen.dart';
import 'package:m_admin/features/audit_log/screens/audit_log_screen.dart';
import 'package:m_admin/features/auth/screens/admin_loading_screen.dart';
import 'package:m_admin/features/auth/screens/admin_login_screen.dart';
import 'package:m_admin/features/content/screens/content_screen.dart';
import 'package:m_admin/features/content/screens/test_editor_screen.dart';
import 'package:m_admin/features/dashboard/screens/dashboard_screen.dart';
import 'package:m_admin/features/notifications/screens/notification_compose_screen.dart';
import 'package:m_admin/features/notifications/screens/notifications_screen.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/screens/payment_detail_screen.dart';
import 'package:m_admin/features/payments/screens/payments_screen.dart';
import 'package:m_admin/features/sessions/screens/sessions_screen.dart';
import 'package:m_admin/features/settings/screens/settings_screen.dart';
import 'package:m_admin/features/shell/screens/admin_shell.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/features/users/screens/user_detail_screen.dart';
import 'package:m_admin/features/users/screens/users_screen.dart';
import 'package:m_admin/routes/admin_middleware.dart';
import 'package:m_admin/routes/routes.dart';

/// Global route observer — mirrors the parent app so screens can subscribe
/// for `didPopNext` callbacks.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

/// The registered pages of the admin console.
///
/// Feature routes are filled in phase by phase; anything not yet built renders
/// a [PlaceholderScreen] that names the phase responsible for it.
class AdminAppRoutes {
  AdminAppRoutes._();

  static final List<GetPage> pages = <GetPage>[
    // ── Unguarded: these are how a session is established ──────────────
    GetPage(
      name: AdminRoutes.loading,
      page: () => const AdminLoadingScreen(),
    ),
    GetPage(
      name: AdminRoutes.login,
      page: () => const AdminLoginScreen(),
    ),

    // ── Guarded ────────────────────────────────────────────────────────
    GetPage(
      name: AdminRoutes.shell,
      page: () => const AdminShell(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.dashboard,
      page: () => const DashboardScreen(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.payments,
      page: () => const PaymentsScreen(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.paymentDetail,
      page: () {
        final args = Get.arguments as Map<String, dynamic>? ?? {};
        final review = args['review'] as PaymentReview?;
        if (review == null) {
          return const PlaceholderScreen(
            title: 'Payment detail',
            phase: 'Missing review argument',
          );
        }
        return PaymentDetailScreen(review: review);
      },
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.notifications,
      page: () => const NotificationsScreen(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.notificationCompose,
      page: () => const PlaceholderScreen(
        title: 'Compose',
        phase: 'Use dialog/sheet from NotificationsScreen',
      ),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.users,
      page: () => const UsersScreen(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.userDetail,
      page: () {
        final args = Get.arguments as Map<String, dynamic>? ?? {};
        final user = args['user'] as AdminUserModel?;
        if (user == null) {
          return const PlaceholderScreen(
            title: 'User detail',
            phase: 'Missing user argument',
          );
        }
        return UserDetailScreen(user: user);
      },
      middlewares: [AdminAuthMiddleware()],
    ),

    // ── Content (Phase 10) ─────────────────────────────────────────────
    GetPage(
      name: AdminRoutes.content,
      page: () => const ContentScreen(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.contentSubject,
      page: () =>
          const PlaceholderScreen(title: 'Subject', phase: 'Phase 10'),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.contentChapter,
      page: () =>
          const PlaceholderScreen(title: 'Chapter', phase: 'Phase 10'),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.contentTest,
      page: () {
        final args = Get.arguments as Map<String, dynamic>? ?? {};
        return TestEditorScreen(
          subjectId: (args['subject_id'] as num?)?.toInt() ?? 0,
          testId: (args['test_id'] as num?)?.toInt(),
          subjectName: args['subject_name']?.toString() ?? '',
        );
      },
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.contentQuestion,
      page: () {
        final args = Get.arguments as Map<String, dynamic>? ?? {};
        return QuestionEditorScreen(
          testId: (args['test_id'] as num?)?.toInt() ?? 0,
          subjectId: (args['subject_id'] as num?)?.toInt() ?? 0,
          questionId: (args['question_id'] as num?)?.toInt(),
        );
      },
      middlewares: [AdminAuthMiddleware()],
    ),

    // ── Phase 11 ───────────────────────────────────────────────────────
    GetPage(
      name: AdminRoutes.sessions,
      page: () => const SessionsScreen(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.auditLog,
      page: () => const AuditLogScreen(),
      middlewares: [AdminAuthMiddleware()],
    ),
    GetPage(
      name: AdminRoutes.settings,
      page: () => const SettingsScreen(),
      middlewares: [AdminAuthMiddleware()],
    ),
  ];
}
