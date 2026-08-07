/// A row from `public.users` as seen from the admin console.
///
/// Column list from the Supabase access catalogue:
///   id text (Firebase UID — NOT a uuid)
///   first_name text
///   last_name text
///   email text
///   stream text
///   subscription_status text ('inactive' | 'pending' | 'active')
///   fcm_token text (write-only; never displayed)
///
/// No created_at / updated_at — the catalogue confirmed they are never
/// referenced by the student app, so they may or may not exist.
class AdminUserModel {
  const AdminUserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.stream,
    required this.subscriptionStatus,
    this.createdAt,
  });

  final String id; // Firebase UID
  final String firstName;
  final String lastName;
  final String email;
  final String stream;
  final String subscriptionStatus; // 'inactive' | 'pending' | 'active'
  final DateTime? createdAt;

  String get displayName {
    final name = '$firstName $lastName'.trim();
    return name.isEmpty ? (email.isEmpty ? id : email) : name;
  }

  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return '${firstName[0]}${lastName[0]}'.toUpperCase();
    }
    if (displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    return '?';
  }

  bool get isActive => subscriptionStatus == 'active';
  bool get isPending => subscriptionStatus == 'pending';
  bool get isInactive => subscriptionStatus == 'inactive';

  factory AdminUserModel.fromJson(Map<String, dynamic> json) {
    return AdminUserModel(
      id: json['id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      stream: json['stream']?.toString() ?? '',
      subscriptionStatus:
          json['subscription_status']?.toString() ?? 'inactive',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }

  AdminUserModel copyWith({String? subscriptionStatus}) => AdminUserModel(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    stream: stream,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    createdAt: createdAt,
  );
}
