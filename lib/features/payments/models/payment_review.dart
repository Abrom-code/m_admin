/// A payment receipt joined to the student who submitted it.
///
/// Parsed defensively throughout (`json['x']?.toString() ?? ''`) in the same
/// style as the parent app's models — the joined `users` object is null when a
/// receipt references a deleted account, and several columns did not exist
/// before migration 0001, so historical rows are sparse.
class PaymentReview {
  const PaymentReview({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    required this.userStream,
    required this.subscriptionStatus,
    required this.receiptPath,
    required this.receiptUrl,
    required this.verificationUrl,
    required this.paymentMethod,
    required this.amount,
    required this.currency,
    required this.status,
    this.createdAt,
    this.reviewedBy,
    this.reviewedAt,
    this.rejectionReason,
  });

  final String id;
  final String userId;

  final String userName;
  final String userEmail;
  final String userStream;

  /// The student's CURRENT premium flag, which is not the same thing as this
  /// receipt's status — a user may have an approved receipt and a later
  /// manual revocation.
  final String subscriptionStatus;

  final String receiptPath;
  final String receiptUrl;
  final String verificationUrl;

  /// `'telebirr' | 'cbe' | 'abyssinia' | 'mpesa'` — lowercase enum `.name`.
  final String paymentMethod;

  final num? amount;
  final String currency;

  /// `'pending' | 'approved' | 'rejected'`.
  final String status;

  final DateTime? createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isReviewed => !isPending;

  String get displayName =>
      userName.trim().isEmpty ? (userEmail.isEmpty ? userId : userEmail) : userName;

  String get amountLabel =>
      amount == null ? '—' : '${amount!.toStringAsFixed(0)} $currency';

  factory PaymentReview.fromJson(Map<String, dynamic> json) {
    // The join arrives as a nested object under `users`. PostgREST returns a
    // list instead of an object when the relationship is ambiguous, so accept
    // both rather than throwing on a shape difference.
    final rawUser = json['users'];
    final Map<String, dynamic> user = rawUser is Map<String, dynamic>
        ? rawUser
        : (rawUser is List && rawUser.isNotEmpty && rawUser.first is Map)
        ? Map<String, dynamic>.from(rawUser.first as Map)
        : const {};

    final firstName = user['first_name']?.toString() ?? '';
    final lastName = user['last_name']?.toString() ?? '';

    return PaymentReview(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: '$firstName $lastName'.trim(),
      userEmail: user['email']?.toString() ?? '',
      userStream: user['stream']?.toString() ?? '',
      subscriptionStatus:
          user['subscription_status']?.toString() ?? 'inactive',
      receiptPath: json['receipt_path']?.toString() ?? '',
      receiptUrl: json['receipt_url']?.toString() ?? '',
      verificationUrl: json['verification_url']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      amount: _parseNum(json['amount']),
      currency: json['currency']?.toString() ?? 'ETB',
      status: json['status']?.toString() ?? 'pending',
      createdAt: _parseDate(json['created_at']),
      reviewedBy: json['reviewed_by']?.toString(),
      reviewedAt: _parseDate(json['reviewed_at']),
      rejectionReason: json['rejection_reason']?.toString(),
    );
  }

  PaymentReview copyWith({
    String? status,
    num? amount,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? rejectionReason,
    String? subscriptionStatus,
  }) {
    return PaymentReview(
      id: id,
      userId: userId,
      userName: userName,
      userEmail: userEmail,
      userStream: userStream,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      receiptPath: receiptPath,
      receiptUrl: receiptUrl,
      verificationUrl: verificationUrl,
      paymentMethod: paymentMethod,
      amount: amount ?? this.amount,
      currency: currency,
      status: status ?? this.status,
      createdAt: createdAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }

  static num? _parseNum(dynamic v) {
    if (v == null) return null;
    if (v is num) return v;
    return num.tryParse(v.toString());
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}

/// Display metadata for the four payment methods the student app offers.
///
/// Account numbers are duplicated from the student app's `payment_enum.dart`
/// so a reviewer can check the receipt against the account it should have been
/// paid into. They are hardcoded there and would need an app release to
/// change — see the Phase 11 settings screen.
class PaymentMethodInfo {
  const PaymentMethodInfo({
    required this.label,
    required this.account,
    required this.holder,
  });

  final String label;
  final String account;
  final String holder;

  static const _holder = 'Beshasha Desmon';

  static const Map<String, PaymentMethodInfo> byKey = {
    'telebirr': PaymentMethodInfo(
      label: 'Telebirr',
      account: '0983878287',
      holder: _holder,
    ),
    'cbe': PaymentMethodInfo(
      label: 'CBE',
      account: '1000786878626',
      holder: _holder,
    ),
    'abyssinia': PaymentMethodInfo(
      label: 'Abyssinia',
      account: '187978686',
      holder: _holder,
    ),
    'mpesa': PaymentMethodInfo(
      label: 'M-PESA',
      account: '0783738782',
      holder: _holder,
    ),
  };

  static PaymentMethodInfo? of(String key) => byKey[key.toLowerCase()];

  static String labelOf(String key) =>
      byKey[key.toLowerCase()]?.label ?? (key.isEmpty ? 'Unknown' : key);
}
