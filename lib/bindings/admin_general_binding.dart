import 'package:get/get.dart';
import 'package:m_admin/data/repositories/admin_auth_repository.dart';
import 'package:m_admin/data/services/admin_notification_service.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/auth/controllers/admin_login_controller.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/utils/network_manager/network_manager.dart';

/// Core singletons for the admin console.
///
/// Mirrors the parent's `GeneralBinding` idiom — permanent registrations only.
/// Per-route controllers go in their own feature binding with
/// `Get.lazyPut(..., fenix: true)`.
///
/// Note there is no `DatabaseService` here: the admin app has no sqflite cache
/// by design, so nothing can render stale money.
class AdminGeneralBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(NetworkManager(), permanent: true);

    // Local OS notifications — registered early so any controller that starts
    // a Realtime subscription can call it immediately.
    Get.put(AdminNotificationService(), permanent: true);

    // Order matters: AdminSessionService resolves AdminAuthRepository in its
    // field initialiser, and AdminLoginController resolves both.
    Get.put(AdminAuthRepository(), permanent: true);
    Get.put(AdminSessionService(), permanent: true);

    // Permanent, matching the parent app's reasoning for auth controllers:
    // it owns TextEditingControllers that must not be disposed while the
    // login route is being rebuilt.
    Get.put(AdminLoginController(), permanent: true);

    // Permanent so the sidebar badges stay reactive across route changes,
    // matching the parent app's reasoning for its NotificationsController.
    Get.put(AdminNavController(), permanent: true);
  }
}
