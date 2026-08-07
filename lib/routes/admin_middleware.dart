import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

/// Redirects to the login screen unless a live admin session exists.
///
/// This is a convenience, not the security boundary. The real boundary is
/// RLS plus `is_admin()` in the database: without a valid JWT, every
/// privileged query returns nothing regardless of which screen is on top.
class AdminAuthMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AdminSessionService>()) {
      return const RouteSettings(name: AdminRoutes.login);
    }

    return AdminSessionService.instance.isAuthenticated
        ? null
        : const RouteSettings(name: AdminRoutes.login);
  }
}

/// Blocks a route unless the signed-in admin is a superadmin.
///
/// Applied to destructive surfaces. Again advisory — the `admins_write_superadmin`
/// policy is what actually enforces it server-side.
class SuperAdminMiddleware extends GetMiddleware {
  @override
  RouteSettings? redirect(String? route) {
    if (!Get.isRegistered<AdminSessionService>()) {
      return const RouteSettings(name: AdminRoutes.login);
    }

    final session = AdminSessionService.instance;

    if (!session.isAuthenticated) {
      return const RouteSettings(name: AdminRoutes.login);
    }

    if (!session.isSuperAdmin) {
      SnackbarHelper.error(
        'Superadmin required',
        'Only a superadmin can open this screen.',
      );
      return const RouteSettings(name: AdminRoutes.dashboard);
    }

    return null;
  }
}

/// Guards individual destructive *actions*, as opposed to whole routes.
///
/// Mix into any controller that performs one, then call
/// [requireSuperAdmin] before writing.
mixin RoleGuard {
  AdminSessionService get _session => AdminSessionService.instance;

  bool get isSuperAdmin => _session.isSuperAdmin;

  /// Returns true when the action may proceed; otherwise reports why and
  /// returns false so the caller can abort.
  bool requireSuperAdmin({String? action}) {
    if (!_session.isAuthenticated) {
      SnackbarHelper.error(
        'Session expired',
        'Sign in again to continue.',
      );
      return false;
    }

    if (!_session.isSuperAdmin) {
      SnackbarHelper.error(
        'Superadmin required',
        action == null
            ? 'Only a superadmin can perform this action.'
            : 'Only a superadmin can $action.',
      );
      return false;
    }

    return true;
  }
}
