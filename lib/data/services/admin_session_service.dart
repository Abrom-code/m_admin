import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/data/repositories/admin_auth_repository.dart';
import 'package:m_admin/features/auth/models/admin_model.dart';

/// Holds the signed-in admin for the current session.
///
/// Persistence is a simple boolean flag in GetStorage. No JWTs, no
/// secure-storage, no Firebase — this is a mock-auth session only.
class AdminSessionService extends GetxService {
  static AdminSessionService get instance => Get.find();

  static const _loggedInKey = 'admin_logged_in';

  final _storage = GetStorage();
  final _auth = Get.find<AdminAuthRepository>();

  final Rx<AdminModel> admin = AdminModel.empty().obs;

  static const _mockAdmin = AdminModel(
    firebaseUid: 'mock-admin-uid',
    email: 'howdes404@gmail.com',
    displayName: 'Admin',
    role: 'superadmin',
    isActive: true,
  );

  /// True when an admin profile is loaded.
  bool get isAuthenticated => !admin.value.isEmpty;

  bool get isSuperAdmin => admin.value.isSuperAdmin;

  String get adminUid => admin.value.firebaseUid;

  /// Sets the mock admin profile and persists the login flag.
  Future<AdminModel> establish() async {
    admin.value = _mockAdmin;
    _storage.write(_loggedInKey, true);
    return _mockAdmin;
  }

  /// Restores a previous session on cold start without requiring a re-login.
  Future<bool> restore() async {
    final persisted = _storage.read<bool>(_loggedInKey) ?? false;
    if (persisted) {
      admin.value = _mockAdmin;
    }
    return persisted;
  }

  Future<void> logout() async {
    await _auth.logout();
    await clear();
  }

  Future<void> clear() async {
    admin.value = AdminModel.empty();
    _storage.remove(_loggedInKey);
  }
}
