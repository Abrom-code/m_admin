import 'dart:convert';

/// A payment receipt joined to the student who submitted it.
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
    this.planKey,
    this.planDurationMonths,
  });

  final String id;
  final String userId;

  final String userName;
  final String userEmail;
  final String userStream;

  /// The student's CURRENT premium flag
  final String subscriptionStatus;

  final String receiptPath;
  final String receiptUrl;
  final String verificationUrl;

  /// `'telebirr' | 'cbe' | 'abyssinia' | 'mpesa'`
  final String paymentMethod;

  final num? amount;
  final String currency;

  /// `'pending' | 'approved' | 'rejected'`.
  final String status;

  final DateTime? createdAt;
  final String? reviewedBy;
  final DateTime? reviewedAt;
  final String? rejectionReason;

  final String? planKey;
  final int? planDurationMonths;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isReviewed => !isPending;

  String get displayName =>
      userName.trim().isEmpty ? (userEmail.isEmpty ? userId : userEmail) : userName;

  String get amountLabel =>
      amount == null ? '—' : '${amount!.toStringAsFixed(0)} $currency';

  String get planLabel => switch (planKey) {
    '6_months' => '6 Months',
    '1_year' => '1 Year',
    '2_years' => '2 Years',
    '3_years' => '3 Years',
    '4_years' => '4 Years',
    _ => planKey ?? (planDurationMonths != null ? '$planDurationMonths Months' : '1 Year'),
  };

  factory PaymentReview.fromJson(Map<String, dynamic> json) {
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
      planKey: json['plan_key']?.toString(),
      planDurationMonths: (json['plan_duration_months'] as num?)?.toInt(),
    );
  }

  PaymentReview copyWith({
    String? status,
    num? amount,
    String? reviewedBy,
    DateTime? reviewedAt,
    String? rejectionReason,
    String? subscriptionStatus,
    String? planKey,
    int? planDurationMonths,
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
      planKey: planKey ?? this.planKey,
      planDurationMonths: planDurationMonths ?? this.planDurationMonths,
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

/// Display metadata for a payment method.
class PaymentMethodInfo {
  const PaymentMethodInfo({
    required this.label,
    required this.account,
    required this.holder,
  });

  final String label;
  final String account;
  final String holder;

  static const _defaultHolder = 'Beshasha Desmon';

  static const Map<String, PaymentMethodInfo> _defaults = {
    'telebirr': PaymentMethodInfo(
      label: 'Telebirr',
      account: '0983878287',
      holder: _defaultHolder,
    ),
    'cbe': PaymentMethodInfo(
      label: 'CBE',
      account: '1000786878626',
      holder: _defaultHolder,
    ),
    'abyssinia': PaymentMethodInfo(
      label: 'Abyssinia',
      account: '187978686',
      holder: _defaultHolder,
    ),
    'mpesa': PaymentMethodInfo(
      label: 'M-PESA',
      account: '0783738782',
      holder: _defaultHolder,
    ),
  };

  static Map<String, PaymentMethodInfo> byKey =
      Map<String, PaymentMethodInfo>.from(_defaults);

  static void loadFromConfig(Map<String, String> cfg) {
    PaymentMethodInfo merge(
      String key,
      String label,
      String accountKey,
      String holderKey,
    ) {
      final base = _defaults[key]!;
      final account = cfg[accountKey]?.trim();
      final holder = cfg[holderKey]?.trim();
      return PaymentMethodInfo(
        label: label,
        account: account != null && account.isNotEmpty ? account : base.account,
        holder: holder != null && holder.isNotEmpty ? holder : base.holder,
      );
    }

    final updated = <String, PaymentMethodInfo>{
      'telebirr': merge('telebirr', 'Telebirr',
          'payment_telebirr', 'payment_telebirr_holder'),
      'cbe': merge('cbe', 'CBE',
          'payment_cbe_birr', 'payment_cbe_birr_holder'),
      'abyssinia': merge('abyssinia', 'Abyssinia',
          'payment_abyssinia', 'payment_abyssinia_holder'),
      'mpesa': merge('mpesa', 'M-PESA',
          'payment_mpesa', 'payment_mpesa_holder'),
    };

    final extraRaw = cfg['payment_extra_accounts'] ?? '';
    if (extraRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(extraRaw);
        final list = decoded is List ? decoded : <dynamic>[];
        for (final item in list) {
          if (item is Map<String, dynamic>) {
            final k = item['key']?.toString() ?? '';
            if (k.isEmpty) continue;
            updated[k] = PaymentMethodInfo(
              label: item['label']?.toString() ?? k,
              account: item['account']?.toString() ?? '',
              holder: item['holder']?.toString() ?? '',
            );
          }
        }
      } catch (_) {
      }
    }

    byKey = updated;
  }

  static PaymentMethodInfo? of(String key) => byKey[key.toLowerCase()];

  static String labelOf(String key) =>
      byKey[key.toLowerCase()]?.label ?? (key.isEmpty ? 'Unknown' : key);
}
