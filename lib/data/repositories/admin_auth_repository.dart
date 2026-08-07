import 'package:get/get.dart';
import 'package:m_admin/utils/constants/app_env.dart';
import 'package:m_admin/utils/exceptions/app_failure_model.dart';

/// Mock authentication for the admin console.
///
/// Credentials are validated locally against the values in .env
/// (MOCK_ADMIN_EMAIL / MOCK_ADMIN_PASSWORD). Falls back to the hardcoded
/// defaults in AppEnv if the keys are absent or blank.
class AdminAuthRepository extends GetxController {
  static AdminAuthRepository get instance => Get.find();

  Future<void> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    if (email.trim() != AppEnv.mockAdminEmail ||
        password != AppEnv.mockAdminPassword) {
      throw const AppFailure(
        title: 'Sign-in Failed',
        message: 'Invalid email or password.',
      );
    }
  }

  Future<void> logout() async {
    // No external auth session to tear down in mock mode.
  }
}
