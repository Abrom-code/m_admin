import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/admin_auth_repository.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

class AdminLoginController extends GetxController {
  static AdminLoginController get instance => Get.find();

  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final isLoading = false.obs;
  final hidePassword = true.obs;

  final _session = Get.find<AdminSessionService>();
  final _auth = Get.find<AdminAuthRepository>();

  @override
  void onClose() {
    emailController.dispose();
    passwordController.dispose();
    super.onClose();
  }

  void togglePasswordVisibility() => hidePassword.value = !hidePassword.value;

  Future<void> login() async {
    if (isLoading.value) return;
    if (!(formKey.currentState?.validate() ?? false)) return;

    try {
      isLoading.value = true;

      await _auth.loginWithEmailAndPassword(
        emailController.text.trim(),
        passwordController.text,
      );

      await _session.establish();

      passwordController.clear();

      Get.offAllNamed(AdminRoutes.shell);
    } catch (e) {
      await _failClosed();
      AppExceptionHandler.handleResponse(e);
    } finally {
      isLoading.value = false;
    }
  }

  /// Tears down every trace of a partial session before returning to login.
  Future<void> _failClosed() async {
    try {
      await _session.logout();
    } catch (_) {
      // Ignored on purpose.
    }
  }
}
