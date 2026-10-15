import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/security/controllers/app_lock_controller.dart';
import 'package:m_admin/features/security/screens/app_lock_screen.dart';

/// Wraps the entire application and conditionally presents the [AppLockScreen]
/// overlay whenever the console is locked.
class AppLockHost extends StatelessWidget {
  const AppLockHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isLockRegistered = Get.isRegistered<AppLockController>();
      final isSessionRegistered = Get.isRegistered<AdminSessionService>();

      final isLocked = isLockRegistered &&
          AppLockController.instance.isLocked.value &&
          AppLockController.instance.isPasscodeEnabled.value;

      final isAuthenticated =
          isSessionRegistered && AdminSessionService.instance.isAuthenticated;

      // Only display the passcode screen if the session is authenticated and locked
      final shouldShowLock = isLocked && isAuthenticated;

      return Stack(
        fit: StackFit.expand,
        children: [
          child,
          if (shouldShowLock)
            const Positioned.fill(
              child: FocusScope(
                autofocus: true,
                child: AppLockScreen(),
              ),
            ),
        ],
      );
    });
  }
}
