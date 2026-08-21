/// A row from public.users as seen from the admin console.
///
/// Column list from the Supabase access catalogue:
///   id text (Firebase UID — NOT a uuid)
///   first_name text
///   last_name text
///   email text
///   stream text
///   subscription_status text ('inactive' | 'pending' | 'active')
///   fcm_token text (write-only; never displayed)
///   receipt_upload_count int (number of receipt upload attempts)
///   subscription_plan text
///   subscription_expires_at timestamptz
class AdminUserModel {
  const AdminUserModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.stream,
    required this.subscriptionStatus,
    this.createdAt,
    this.receiptUploadCount = 0,
    this.subscriptionPlan,
    this.subscriptionExpiresAt,
  });

  final String id; // Firebase UID
  final String firstName;
  final String lastName;
  final String email;
  final String stream;
  final String subscriptionStatus; // 'inactive' | 'pending' | 'active'
  final DateTime? createdAt;
  final int receiptUploadCount;
  final String? subscriptionPlan;
  final DateTime? subscriptionExpiresAt;

  String get displayName {
    final name = ' '.trim();
    return name.isEmpty ? (email.isEmpty ? id : email) : name;
  }

  String get initials {
    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return ''.toUpperCase();
    }
    if (displayName.isNotEmpty) {
      return displayName[0].toUpperCase();
    }
    return '?';
  }

  bool get isActive =>
      subscriptionStatus == 'active' &&
      (subscriptionExpiresAt == null ||
          subscriptionExpiresAt!.isAfter(DateTime.now()));

  bool get isPending => subscriptionStatus == 'pending';
  bool get isInactive => subscriptionStatus == 'inactive';

  bool get isExpired =>
      subscriptionStatus == 'active' &&
      subscriptionExpiresAt != null &&
      subscriptionExpiresAt!.isBefore(DateTime.now());

  bool get exceededUploadLimit => receiptUploadCount >= 2;

  String get planLabel => switch (subscriptionPlan) {
    '6_months' => '6 Months',
    '1_year' => '1 Year',
    '2_years' => '2 Years',
    '3_years' => '3 Years',
    '4_years' => '4 Years',
    _ => subscriptionPlan ?? '—',
  };

  String get remainingDaysText {
    if (subscriptionExpiresAt == null) return '';
    final diff = subscriptionExpiresAt!.difference(DateTime.now()).inDays;
    if (diff <= 0) return 'Expired';
    if (diff > 365) return ' yrs left';
    if (diff > 30) return ' mo left';
    return ' d left';
  }

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
      receiptUploadCount:
          (json['receipt_upload_count'] as num?)?.toInt() ?? 0,
      subscriptionPlan: json['subscription_plan']?.toString(),
      subscriptionExpiresAt: json['subscription_expires_at'] == null
          ? null
          : DateTime.tryParse(json['subscription_expires_at'].toString()),
    );
  }

  AdminUserModel copyWith({
    String? subscriptionStatus,
    int? receiptUploadCount,
    String? subscriptionPlan,
    DateTime? subscriptionExpiresAt,
  }) => AdminUserModel(
    id: id,
    firstName: firstName,
    lastName: lastName,
    email: email,
    stream: stream,
    subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
    createdAt: createdAt,
    receiptUploadCount: receiptUploadCount ?? this.receiptUploadCount,
    subscriptionPlan: subscriptionPlan ?? this.subscriptionPlan,
    subscriptionExpiresAt:
        subscriptionExpiresAt ?? this.subscriptionExpiresAt,
  );
}
