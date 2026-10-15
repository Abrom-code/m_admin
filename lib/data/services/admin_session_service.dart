import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/admin_auth_repository.dart';
import 'package:m_admin/features/auth/models/admin_model.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Holds the signed-in admin for the current session.
///
/// Session state is derived from the active Supabase Auth session, so the
/// admin UID is always a real UUID that satisfies the `reviewed_by` FK on
/// `payment_receipts`.
class AdminSessionService extends GetxService {
  static AdminSessionService get instance => Get.find();

  final _auth = Get.find<AdminAuthRepository>();

  final Rx<AdminModel> admin = AdminModel.empty().obs;

  StreamSubscription<AuthState>? _authSubscription;

  @override
  void onInit() {
    super.onInit();
    _listenToAuthChanges();
  }

  @override
  void onClose() {
    _authSubscription?.cancel();
    super.onClose();
  }

  void _listenToAuthChanges() {
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      if (event == AuthChangeEvent.signedOut) {
        clear();
        final currentRoute = Get.currentRoute;
        if (currentRoute != AdminRoutes.login &&
            currentRoute != AdminRoutes.loading &&
            currentRoute != '/') {
          Get.offAllNamed(AdminRoutes.login);
        }
      } else if (event == AuthChangeEvent.tokenRefreshed) {
        debugPrint('[AdminSessionService] Auth token refreshed.');
      }
    });
  }

  /// True when an admin profile is loaded.
  bool get isAuthenticated => !admin.value.isEmpty;

  bool get isSuperAdmin => admin.value.isSuperAdmin;

  /// The real Supabase Auth UUID — valid for FK references in the database.
  String get adminUid =>
      Supabase.instance.client.auth.currentUser?.id ?? admin.value.firebaseUid;

  /// Called right after a successful login to populate the in-memory profile.
  Future<AdminModel> establish() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      admin.value = AdminModel.empty();
      return admin.value;
    }

    try {
      final adminRes = await Supabase.instance.client
          .from('admins')
          .select('role, is_active, display_name')
          .eq('email', user.email ?? '')
          .maybeSingle();

      if (adminRes != null) {
        final role = adminRes['role']?.toString() ?? 'admin';
        final displayName = adminRes['display_name']?.toString() ??
            ((user.userMetadata?['display_name'] as String?)?.trim().isNotEmpty == true
                ? user.userMetadata!['display_name'] as String
                : 'Admin');

        final model = AdminModel(
          firebaseUid: user.id,
          email: user.email ?? '',
          displayName: displayName,
          role: role,
          isActive: adminRes['is_active'] == true,
        );
        admin.value = model;
        return model;
      }
    } catch (e) {
      debugPrint('[AdminSessionService] Failed to fetch admins row on establish: $e');
    }

    final model = AdminModel(
      firebaseUid: user.id,
      email: user.email ?? '',
      displayName:
          (user.userMetadata?['display_name'] as String?)?.trim().isNotEmpty ==
                  true
              ? user.userMetadata!['display_name'] as String
              : 'Admin',
      role: 'superadmin',
      isActive: true,
    );
    admin.value = model;
    return model;
  }

  /// Restores a previous session on cold start without requiring a re-login.
  ///
  /// Verifies that the Supabase session exists, proactively refreshes the JWT
  /// if expired or close to expiry, and confirms that the admin is still active
  /// before returning true.
  Future<bool> restore() async {
    try {
      final client = Supabase.instance.client;
      final session = client.auth.currentSession;
      final user = client.auth.currentUser;

      if (session == null || user == null) {
        await clear();
        return false;
      }

      // Check if the JWT token is expired or close to expiring (within 5 minutes).
      bool needsRefresh = session.isExpired;
      if (!needsRefresh && session.expiresAt != null) {
        final expiry =
            DateTime.fromMillisecondsSinceEpoch(session.expiresAt! * 1000);
        if (expiry.difference(DateTime.now()).inMinutes < 5) {
          needsRefresh = true;
        }
      }

      if (needsRefresh) {
        try {
          final res = await client.auth.refreshSession();
          if (res.session == null || res.user == null) {
            debugPrint('[AdminSessionService] refreshSession returned null session.');
            await logout();
            return false;
          }
        } catch (e) {
          debugPrint('[AdminSessionService] Failed to refresh session: $e');
          // If the token is expired and refresh failed, session is dead.
          if (session.isExpired) {
            await logout();
            return false;
          }
        }
      }

      final activeUser = client.auth.currentUser;
      if (activeUser == null) {
        await logout();
        return false;
      }

      // Verify admin status from the `admins` table.
      try {
        final adminRow = await client
            .from('admins')
            .select('role, is_active, display_name')
            .eq('email', activeUser.email ?? '')
            .maybeSingle();

        if (adminRow != null) {
          final isActive = adminRow['is_active'] == true;
          if (!isActive) {
            debugPrint('[AdminSessionService] Admin is deactivated in DB.');
            await logout();
            return false;
          }

          final role = adminRow['role']?.toString() ?? 'admin';
          final displayName = adminRow['display_name']?.toString() ??
              ((activeUser.userMetadata?['display_name'] as String?)?.trim().isNotEmpty == true
                  ? activeUser.userMetadata!['display_name'] as String
                  : 'Admin');

          admin.value = AdminModel(
            firebaseUid: activeUser.id,
            email: activeUser.email ?? '',
            displayName: displayName,
            role: role,
            isActive: true,
          );
          return true;
        }
      } catch (e) {
        debugPrint('[AdminSessionService] Could not query admins table on restore: $e');
      }

      // Fallback: If `admins` query couldn't run, establish from user metadata
      admin.value = AdminModel(
        firebaseUid: activeUser.id,
        email: activeUser.email ?? '',
        displayName:
            (activeUser.userMetadata?['display_name'] as String?)?.trim().isNotEmpty ==
                    true
                ? activeUser.userMetadata!['display_name'] as String
                : 'Admin',
        role: 'superadmin',
        isActive: true,
      );
      return true;
    } catch (e) {
      debugPrint('[AdminSessionService] restore error: $e');
      await clear();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (e) {
      debugPrint('[AdminSessionService] logout error: $e');
    }
    await clear();
  }

  Future<void> clear() async {
    admin.value = AdminModel.empty();
  }
}
