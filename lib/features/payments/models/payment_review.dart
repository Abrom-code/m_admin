import 'dart:convert';

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

/// Display metadata for a payment method.
///
/// Built-in methods (telebirr, cbe, abyssinia, mpesa) are seeded from
/// hardcoded defaults and overridden at runtime by [loadFromConfig] once
/// the admin app fetches values from `app_config`.  Extra methods added
/// from the Settings screen are appended to [byKey] the same way.
class PaymentMethodInfo {
  const PaymentMethodInfo({
    required this.label,
    required this.account,
    required this.holder,
  });

  final String label;
  final String account;
  final String holder;

  // ── Defaults (used before app_config is loaded or as fallback) ──────
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

  /// Live map — starts as the defaults, overwritten by [loadFromConfig].
  static Map<String, PaymentMethodInfo> byKey =
      Map<String, PaymentMethodInfo>.from(_defaults);

  /// Called once after `app_config` rows are fetched (e.g. from
  /// SettingsController or a dedicated config service).  Pass the full
  /// key→value map from the table.
  ///
  /// Keys expected:
  ///   payment_telebirr, payment_telebirr_holder
  ///   payment_cbe_birr, payment_cbe_birr_holder
  ///   payment_abyssinia, payment_abyssinia_holder
  ///   payment_mpesa, payment_mpesa_holder
  ///   payment_extra_accounts  (JSON array)
  static void loadFromConfig(Map<String, String> cfg) {
    // Helper: override a built-in entry when the config provides a value.
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

    // Append extra accounts from JSON array stored in app_config.
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
        // Malformed JSON — skip extra accounts silently.
      }
    }

    byKey = updated;
  }

  static PaymentMethodInfo? of(String key) => byKey[key.toLowerCase()];

  static String labelOf(String key) =>
      byKey[key.toLowerCase()]?.label ?? (key.isEmpty ? 'Unknown' : key);
}
