import 'package:get/get.dart';
import 'package:m_admin/data/repositories/admin_auth_repository.dart';
import 'package:m_admin/features/auth/models/admin_model.dart';
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

  /// True when an admin profile is loaded.
  bool get isAuthenticated => !admin.value.isEmpty;

  bool get isSuperAdmin => admin.value.isSuperAdmin;

  /// The real Supabase Auth UUID — valid for FK references in the database.
  String get adminUid =>
      Supabase.instance.client.auth.currentUser?.id ?? admin.value.firebaseUid;

  /// Called right after a successful login to populate the in-memory profile.
  Future<AdminModel> establish() async {
    final user = Supabase.instance.client.auth.currentUser;
    final model = AdminModel(
      firebaseUid: user?.id ?? '',
      email: user?.email ?? '',
      displayName:
          (user?.userMetadata?['display_name'] as String?)?.trim().isNotEmpty ==
                  true
              ? user!.userMetadata!['display_name'] as String
              : 'Admin',
      role: 'superadmin',
      isActive: true,
    );
    admin.value = model;
    return model;
  }

  /// Restores a previous session on cold start without requiring a re-login.
  ///
  /// Supabase persists the JWT automatically; if `currentUser` is non-null the
  /// token is still valid and we just rebuild the in-memory profile.
  Future<bool> restore() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    admin.value = AdminModel(
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
    return true;
  }

  Future<void> logout() async {
    await _auth.logout();
    await clear();
  }

  Future<void> clear() async {
    admin.value = AdminModel.empty();
  }
}
