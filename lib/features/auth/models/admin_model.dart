/// An admin console operator.
///
/// Column names match `public.admins` from migration 0001 exactly. Every
/// field is parsed defensively (`?.toString() ?? ''`) in the same style as the
/// parent app's `UserModel`, so a null-heavy row never throws at parse time.
class AdminModel {
  const AdminModel({
    required this.firebaseUid,
    required this.email,
    required this.displayName,
    required this.role,
    required this.isActive,
    this.createdAt,
    this.lastLoginAt,
  });

  final String firebaseUid;
  final String email;
  final String displayName;

  /// `'admin'` or `'superadmin'` — CHECK-constrained in the database.
  final String role;

  final bool isActive;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;

  /// Destructive actions are restricted to superadmins.
  ///
  /// This is a UI affordance only. The database re-derives privilege from the
  /// `admins` table on every call, so a client that lies about its role gains
  /// nothing.
  bool get isSuperAdmin => role == 'superadmin';

  bool get isEmpty => firebaseUid.isEmpty;

  /// Falls back to the email's local part so the sidebar never renders blank.
  String get displayNameOrEmail {
    if (displayName.trim().isNotEmpty) return displayName;
    if (email.contains('@')) return email.split('@').first;
    return email;
  }

  /// Up to two initials for the avatar chip.
  String get initials {
    final source = displayNameOrEmail.trim();
    if (source.isEmpty) return '?';
    final parts = source.split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.elementAt(1)[0]}'.toUpperCase();
    }
    return source.substring(0, source.length >= 2 ? 2 : 1).toUpperCase();
  }

  factory AdminModel.empty() => const AdminModel(
    firebaseUid: '',
    email: '',
    displayName: '',
    role: 'admin',
    isActive: false,
  );

  factory AdminModel.fromJson(Map<String, dynamic> json) {
    return AdminModel(
      firebaseUid: json['firebase_uid']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      role: json['role']?.toString() ?? 'admin',
      // Postgres returns a real boolean, but tolerate a stringified one.
      isActive: json['is_active'] == true || json['is_active'] == 'true',
      createdAt: _parseDate(json['created_at']),
      lastLoginAt: _parseDate(json['last_login_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'firebase_uid': firebaseUid,
    'email': email,
    'display_name': displayName,
    'role': role,
    'is_active': isActive,
  };

  AdminModel copyWith({
    String? displayName,
    String? role,
    bool? isActive,
    DateTime? lastLoginAt,
  }) {
    return AdminModel(
      firebaseUid: firebaseUid,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }
}
