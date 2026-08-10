import 'package:get/get.dart';
import 'package:m_admin/data/repositories/admin_auth_repository.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/auth/controllers/admin_login_controller.dart';
import 'package:m_admin/features/payments/controllers/payments_controller.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/utils/network_manager/network_manager.dart';

/// Core singletons for the admin console.
class AdminGeneralBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(NetworkManager(), permanent: true);

    // AdminNotificationService is already registered and fully initialized
    // in main() via Get.putAsync — do not register it again here.

    Get.put(AdminAuthRepository(), permanent: true);
    Get.put(AdminSessionService(), permanent: true);
    Get.put(AdminLoginController(), permanent: true);
    Get.put(AdminNavController(), permanent: true);

    // PaymentsController is permanent so its Realtime subscription starts
    // with the app and stays alive regardless of which page is visible.
    // Registering it here (not inside PaymentsScreen.build) ensures
    // onInit() runs exactly once, on startup.
    Get.put(PaymentsController(), permanent: true);
  }
}
