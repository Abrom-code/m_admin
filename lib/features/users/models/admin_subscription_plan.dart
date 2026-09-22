/// Subscription plan definition and duration helpers for the admin app.
/// Matches the subscription plans in the main MatricMate app.
class AdminSubscriptionPlan {
  const AdminSubscriptionPlan({
    required this.key,
    required this.title,
    required this.durationMonths,
    required this.defaultPrice,
    this.subtitle = '',
    this.isFeatured = false,
    this.badgeText,
  });

  /// Stable key stored in `users.subscription_plan` and `payment_receipts.plan_key`.
  final String key;

  /// UI display name (e.g. "6 Months", "1 Year").
  final String title;

  /// Number of months this plan grants.
  final int durationMonths;

  /// Default price in ETB.
  final int defaultPrice;

  /// Subtitle description.
  final String subtitle;

  /// Whether this is the featured / recommended plan.
  final bool isFeatured;

  /// Optional badge text.
  final String? badgeText;

  /// All supported plans in display order.
  static const List<AdminSubscriptionPlan> all = [
    AdminSubscriptionPlan(
      key: '6_months',
      title: '6 Months',
      durationMonths: 6,
      defaultPrice: 150,
      subtitle: 'Semester prep',
    ),
    AdminSubscriptionPlan(
      key: '1_year',
      title: '1 Year',
      durationMonths: 12,
      defaultPrice: 250,
      subtitle: 'Full exam prep',
      isFeatured: true,
      badgeText: '⭐ Best Value',
    ),
    AdminSubscriptionPlan(
      key: '2_years',
      title: '2 Years',
      durationMonths: 24,
      defaultPrice: 400,
      subtitle: 'Grades 11 & 12',
    ),
    AdminSubscriptionPlan(
      key: '3_years',
      title: '3 Years',
      durationMonths: 36,
      defaultPrice: 550,
      subtitle: 'Grades 10 – 12',
    ),
    AdminSubscriptionPlan(
      key: '4_years',
      title: '4 Years',
      durationMonths: 48,
      defaultPrice: 650,
      subtitle: 'Full High School',
    ),
  ];

  /// The 1-year plan (default).
  static AdminSubscriptionPlan get defaultPlan =>
      all.firstWhere((p) => p.isFeatured, orElse: () => all[1]);

  /// Look up a plan by key.
  static AdminSubscriptionPlan? byKey(String? key) {
    if (key == null || key.isEmpty) return null;
    try {
      return all.firstWhere((p) => p.key == key);
    } catch (_) {
      return null;
    }
  }

  /// Human-readable label from a key.
  static String labelOf(String? key) => byKey(key)?.title ?? key ?? '—';

  /// Calculates expiry date by adding months to [baseDate].
  static DateTime calculateExpiry(int months, {DateTime? fromDate}) {
    final base = fromDate ?? DateTime.now();
    return DateTime(base.year, base.month + months, base.day);
  }

  /// If user currently has active remaining subscription, extend from current expiry date,
  /// otherwise calculate from now.
  static DateTime calculateExtendedExpiry(
    int months, {
    DateTime? currentExpiry,
  }) {
    final now = DateTime.now();
    final base = (currentExpiry != null && currentExpiry.isAfter(now))
        ? currentExpiry
        : now;
    return DateTime(base.year, base.month + months, base.day);
  }

  /// Finds the corresponding plan based on the paid amount in ETB.
  static AdminSubscriptionPlan? matchByAmount(num? amount) {
    if (amount == null || amount <= 0) return null;
    final intAmount = amount.round();
    try {
      return all.firstWhere((p) => p.defaultPrice == intAmount);
    } catch (_) {
      return null;
    }
  }

  /// Formats date cleanly as "D Mon YYYY", e.g. "24 Oct 2026".
  static String formatDate(DateTime date) =>
      '${date.day} ${_monthName(date.month)} ${date.year}';

  /// Builds notification title for payment approval.
  static String buildApprovalNotificationTitle(
    String? planKey, {
    DateTime? expiresAt,
  }) {
    if (planKey == 'custom' || byKey(planKey) == null) {
      if (expiresAt != null) {
        return 'Payment Approved! 🎉 (Until ${formatDate(expiresAt)})';
      }
      return 'Payment Approved! 🎉';
    }
    final label = labelOf(planKey);
    return 'Payment Approved! 🎉 ($label)';
  }

  /// Builds detailed notification body for payment approval with timing and amount.
  static String buildApprovalNotificationBody({
    required String? planKey,
    num? amount,
    String currency = 'ETB',
    required DateTime expiresAt,
  }) {
    final formattedDate = formatDate(expiresAt);
    final diffDays = expiresAt.difference(DateTime.now()).inDays;
    final timingText =
        diffDays > 0 ? '$formattedDate ($diffDays days left)' : formattedDate;

    if (planKey == 'custom' || byKey(planKey) == null) {
      final amountPrefix = (amount != null && amount > 0)
          ? 'Your payment of ${amount.toStringAsFixed(0)} $currency'
          : 'Your subscription';
      return '$amountPrefix has been approved! Premium access is active until $timingText. Enjoy full access to all exams!';
    }

    final label = labelOf(planKey);
    final amountPrefix = (amount != null && amount > 0)
        ? 'Your payment of ${amount.toStringAsFixed(0)} $currency for the $label plan'
        : 'Your $label subscription';
    return '$amountPrefix has been approved! Premium access is active until $timingText. Enjoy full access to all exams!';
  }

  /// Builds notification title for manual grant / extension.
  static String buildGrantNotificationTitle(
    String? planKey, {
    DateTime? expiresAt,
  }) {
    if (planKey == 'custom' || byKey(planKey) == null) {
      if (expiresAt != null) {
        return 'Premium Access Granted! 🎉 (Until ${formatDate(expiresAt)})';
      }
      return 'Premium Access Granted! 🎉';
    }
    final label = labelOf(planKey);
    return 'Premium Access Granted! 🎉 ($label)';
  }

  /// Builds detailed notification body for manual grant / extension with timing.
  static String buildGrantNotificationBody({
    required String? planKey,
    required DateTime expiresAt,
  }) {
    final formattedDate = formatDate(expiresAt);
    final diffDays = expiresAt.difference(DateTime.now()).inDays;
    final timingText =
        diffDays > 0 ? '$formattedDate ($diffDays days left)' : formattedDate;

    if (planKey == 'custom' || byKey(planKey) == null) {
      return 'You have been granted premium access valid until $timingText. Enjoy full access to all exams and features!';
    }

    final label = labelOf(planKey);
    return 'You have been granted $label premium access, valid until $timingText. Enjoy full access to all exams and features!';
  }

  static String _monthName(int month) => switch (month) {
    1 => 'Jan',
    2 => 'Feb',
    3 => 'Mar',
    4 => 'Apr',
    5 => 'May',
    6 => 'Jun',
    7 => 'Jul',
    8 => 'Aug',
    9 => 'Sep',
    10 => 'Oct',
    11 => 'Nov',
    12 => 'Dec',
    _ => '',
  };
}

