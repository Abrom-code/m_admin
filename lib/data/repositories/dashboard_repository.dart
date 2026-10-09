import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

// ── Models ──────────────────────────────────────────────────────────────

/// Stats surfaced on the dashboard KPI row.
class DashboardStats {
  const DashboardStats({
    required this.totalUsers,
    required this.paidUsers,
    required this.pendingPayments,
    required this.newUsersThisWeek,
    required this.totalRevenue,
    required this.recentReceipts,
    this.reportedQuestionsCount = 0,
    this.noteReviewersCount = 0,
    this.noteReviewsCount = 0,
  });

  final int totalUsers;
  final int paidUsers;
  final int pendingPayments;
  final int newUsersThisWeek;
  final double totalRevenue;
  final List<RecentReceiptRow> recentReceipts;
  final int reportedQuestionsCount;
  final int noteReviewersCount;
  final int noteReviewsCount;

  /// Derived: users without an active subscription.
  int get unpaidUsers => totalUsers - paidUsers;

  DashboardStats copyWith({
    int? pendingPayments,
    int? reportedQuestionsCount,
    int? noteReviewersCount,
    int? noteReviewsCount,
  }) => DashboardStats(
    totalUsers: totalUsers,
    paidUsers: paidUsers,
    pendingPayments: pendingPayments ?? this.pendingPayments,
    newUsersThisWeek: newUsersThisWeek,
    totalRevenue: totalRevenue,
    recentReceipts: recentReceipts,
    reportedQuestionsCount: reportedQuestionsCount ?? this.reportedQuestionsCount,
    noteReviewersCount: noteReviewersCount ?? this.noteReviewersCount,
    noteReviewsCount: noteReviewsCount ?? this.noteReviewsCount,
  );
}

class RecentReceiptRow {
  const RecentReceiptRow({
    required this.id,
    required this.displayName,
    required this.userEmail,
    required this.status,
    required this.paymentMethod,
    required this.amount,
    required this.createdAt,
  });

  final int id;
  final String displayName;
  final String userEmail;
  final String status;
  final String paymentMethod;
  final double amount;
  final DateTime? createdAt;

  factory RecentReceiptRow.fromJson(Map<String, dynamic> json) {
    // users is a left join — it is null when the account was deleted.
    final rawUser = json['users'];
    final Map<String, dynamic> u = rawUser is Map<String, dynamic>
        ? rawUser
        : (rawUser is List && rawUser.isNotEmpty && rawUser.first is Map)
            ? Map<String, dynamic>.from(rawUser.first as Map)
            : const {};
    final firstName = u['first_name']?.toString() ?? '';
    final lastName = u['last_name']?.toString() ?? '';
    final fullName = '$firstName $lastName'.trim();
    return RecentReceiptRow(
      id: _toInt(json['id']) ?? 0,
      displayName: fullName.isEmpty ? (u['email']?.toString() ?? '—') : fullName,
      userEmail: u['email']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      paymentMethod: json['payment_method']?.toString() ?? '',
      amount: _toDouble(json['amount']),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}

/// One day of data for the chart.
class DailyPoint {
  const DailyPoint({
    required this.day,
    required this.value,
    this.methodBreakdown = const {},
  });
  final DateTime day;
  final double value;
  final Map<String, double> methodBreakdown;
}

/// Tests available per subject divided by category (Entrance, Model, Chapter/Grade).
class SubjectTestCount {
  const SubjectTestCount({
    required this.subjectId,
    required this.subjectName,
    required this.testCount,
    this.entranceCount = 0,
    this.modelCount = 0,
    this.chapterGradeCount = 0,
  });
  final int subjectId;
  final String subjectName;
  final int testCount;
  final int entranceCount;
  final int modelCount;
  final int chapterGradeCount;
}

/// One stage of the conversion funnel.
class FunnelPoint {
  const FunnelPoint({required this.label, required this.count});
  final String label;
  final int count;
}

/// One slice for the stream-split donut.
class StreamPoint {
  const StreamPoint({required this.stream, required this.count});
  final String stream;
  final int count;
}

// ── Numeric helpers ──────────────────────────────────────────────────────────
// Supabase returns numeric/decimal columns as String in some query shapes
// (e.g. when included alongside a .count()). These helpers accept both.

double _toDouble(dynamic v) {
  if (v == null) return 0;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString()) ?? 0;
}

int? _toInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

// ── Repository ──────────────────────────────────────────────────────────

class DashboardRepository {
  final _sb = Supabase.instance.client;

  Future<DashboardStats> fetchStats() async {
    try {
      final since = DateTime.now()
          .subtract(const Duration(days: 7))
          .toUtc()
          .toIso8601String();

      // All queries fire in parallel — including recent receipts, reports, and note reviews.
      final results = await Future.wait<dynamic>([
        _sb.from('users').select('id').count(CountOption.exact),          // 0: total
        _sb
            .from('users')
            .select('id')
            .eq('subscription_status', 'active')
            .count(CountOption.exact),                                     // 1: paid
        _sb
            .from('payment_receipts')
            .select('id')
            .eq('status', 'pending')
            .count(CountOption.exact),                                     // 2: pending
        _sb
            .from('users')
            .select('id')
            .gte('created_at', since)
            .count(CountOption.exact),                                     // 3: new this week
        _sb
            .from('payment_receipts')
            .select('amount')
            .eq('status', 'approved'),                                     // 4: revenue rows
        _sb
            .from('payment_receipts')
            .select(
              'id, status, payment_method, amount, created_at, '
              'users(first_name, last_name, email)',
            )
            .order('created_at', ascending: false)
            .limit(6),                                                     // 5: recent
        _sb
            .from('question_reports')
            .select('id')
            .eq('status', 'pending')
            .count(CountOption.exact)
            .catchError((_) => null),                                      // 6: pending reports
        _sb
            .from('note_ratings')
            .select('user_id')
            .catchError((_) => <dynamic>[]),                               // 7: note ratings/reviewers
      ]);

      final total = (results[0] as dynamic).count as int;
      final paid = (results[1] as dynamic).count as int;
      final pending = (results[2] as dynamic).count as int;
      final newThisWeek = (results[3] as dynamic).count as int;

      final revenueRows = results[4] as List<dynamic>;
      final totalRevenue = revenueRows.fold<double>(
        0,
        (sum, r) => sum + _toDouble(r['amount']),
      );

      final recentRows = results[5] as List<dynamic>;

      final reportedCount = (results[6] as dynamic)?.count as int? ?? 0;

      final ratingRows = (results[7] as List<dynamic>?) ?? <dynamic>[];
      final totalReviews = ratingRows.length;
      final uniqueReviewers = ratingRows
          .map((r) => r['user_id']?.toString())
          .where((id) => id != null && id.isNotEmpty)
          .toSet()
          .length;
      final noteReviewers = uniqueReviewers > 0 ? uniqueReviewers : totalReviews;

      return DashboardStats(
        totalUsers: total,
        paidUsers: paid,
        pendingPayments: pending,
        newUsersThisWeek: newThisWeek,
        totalRevenue: totalRevenue,
        recentReceipts: recentRows
            .map((r) => RecentReceiptRow.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
        reportedQuestionsCount: reportedCount,
        noteReviewersCount: noteReviewers,
        noteReviewsCount: totalReviews,
      );
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Daily signup counts for the given date range or last [days] days.
  Future<List<DailyPoint>> fetchSignupsDaily([
    int? days,
    DateTime? startDate,
    DateTime? endDate,
  ]) async {
    try {
      final DateTime start;
      final DateTime end;
      if (startDate != null && endDate != null) {
        start = DateTime(startDate.year, startDate.month, startDate.day);
        end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
      } else {
        final d = days ?? 30;
        end = DateTime.now();
        start = end.subtract(Duration(days: d - 1));
      }

      final rows = await _sb
          .from('users')
          .select('created_at')
          .gte('created_at', start.toUtc().toIso8601String())
          .lte('created_at', end.toUtc().toIso8601String())
          .order('created_at');

      return _groupByDayRange(rows, 'created_at', start, end);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Daily approved-payment totals for the given date range or last [days] days,
  /// optionally filtered by payment method.
  Future<List<DailyPoint>> fetchRevenueDaily([
    int? days,
    DateTime? startDate,
    DateTime? endDate,
    String? method,
  ]) async {
    try {
      final DateTime start;
      final DateTime end;
      if (startDate != null && endDate != null) {
        start = DateTime(startDate.year, startDate.month, startDate.day);
        end = DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
      } else {
        final d = days ?? 30;
        end = DateTime.now();
        start = end.subtract(Duration(days: d - 1));
      }

      var query = _sb
          .from('payment_receipts')
          .select('reviewed_at, amount, payment_method')
          .eq('status', 'approved')
          .gte('reviewed_at', start.toUtc().toIso8601String())
          .lte('reviewed_at', end.toUtc().toIso8601String());

      if (method != null && method.isNotEmpty && method.toLowerCase() != 'all') {
        final clean = method.toLowerCase().replaceAll('payment_', '').replaceAll('_birr', '');
        query = query.or('payment_method.ilike.%$clean%,payment_method.ilike.%$method%');
      }

      final rows = await query.order('reviewed_at');

      final Map<String, double> totals = {};
      final Map<String, Map<String, double>> methodTotals = {};

      for (final r in rows) {
        final ts = r['reviewed_at']?.toString();
        if (ts == null) continue;
        final day = ts.substring(0, 10);
        final amt = _toDouble(r['amount']);
        totals[day] = (totals[day] ?? 0) + amt;

        final rawMethod = (r['payment_method']?.toString() ?? 'other').toLowerCase();
        final normMethod = rawMethod.contains('telebirr')
            ? 'telebirr'
            : (rawMethod.contains('cbe')
                ? 'cbe'
                : (rawMethod.contains('abyssinia') ? 'abyssinia' : 'other'));

        methodTotals.putIfAbsent(day, () => {});
        methodTotals[day]![normMethod] = (methodTotals[day]![normMethod] ?? 0) + amt;
      }

      return _buildSeriesRange(totals, start, end, methodTotals);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Number of published tests per subject (content health, not attempt data).
  ///
  /// Number of published tests per subject divided by Entrance, Model, and Tests.
  Future<List<SubjectTestCount>> fetchSubjectTestCounts() async {
    try {
      final subjectRows = await _sb
          .from('subjects')
          .select('id, name')
          .order('name');

      if (subjectRows.isEmpty) return [];

      // Fetch test types to calculate Entrance, Model, and Standard test counts
      final testRows = await _sb
          .from('tests')
          .select('subject_id, type');

      final entranceMap = <int, int>{};
      final modelMap = <int, int>{};
      final chapterGradeMap = <int, int>{};
      final totalMap = <int, int>{};

      for (final row in testRows) {
        final sid = _toInt(row['subject_id']) ?? 0;
        final type = row['type']?.toString().toLowerCase() ?? '';

        totalMap[sid] = (totalMap[sid] ?? 0) + 1;
        if (type == 'entrance') {
          entranceMap[sid] = (entranceMap[sid] ?? 0) + 1;
        } else if (type == 'model') {
          modelMap[sid] = (modelMap[sid] ?? 0) + 1;
        } else {
          chapterGradeMap[sid] = (chapterGradeMap[sid] ?? 0) + 1;
        }
      }

      return subjectRows.map((s) {
        final sid = _toInt(s['id']) ?? 0;
        return SubjectTestCount(
          subjectId: sid,
          subjectName: s['name']?.toString() ?? '',
          testCount: totalMap[sid] ?? 0,
          entranceCount: entranceMap[sid] ?? 0,
          modelCount: modelMap[sid] ?? 0,
          chapterGradeCount: chapterGradeMap[sid] ?? 0,
        );
      }).toList()
        ..sort((a, b) => b.testCount.compareTo(a.testCount));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Conversion funnel: Signups, Inactives, Actives, and Submitted.
  Future<List<FunnelPoint>> fetchSubscriptionFunnel() async {
    try {
      final results = await Future.wait<dynamic>([
        _sb.from('users').select('id').count(CountOption.exact), // 0: total signups
        _sb
            .from('users')
            .select('id')
            .neq('subscription_status', 'active')
            .count(CountOption.exact), // 1: inactives
        _sb
            .from('users')
            .select('id')
            .eq('subscription_status', 'active')
            .count(CountOption.exact), // 2: actives
        _sb
            .from('payment_receipts')
            .select('id')
            .count(CountOption.exact), // 3: submitted
      ]);

      return [
        FunnelPoint(label: 'Signups',   count: (results[0] as dynamic).count as int),
        FunnelPoint(label: 'Inactives', count: (results[1] as dynamic).count as int),
        FunnelPoint(label: 'Actives',   count: (results[2] as dynamic).count as int),
        FunnelPoint(label: 'Submitted', count: (results[3] as dynamic).count as int),
      ];
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// User count per stream using server-side counts — no full table scan.
  Future<List<StreamPoint>> fetchStreamSplit() async {
    try {
      final streams = ['natural', 'social', 'common'];
      final counts = await Future.wait(
        streams.map((s) async {
          final r = await _sb
              .from('users')
              .select('id')
              .eq('stream', s)
              .count(CountOption.exact);
          return MapEntry(s, r.count);
        }),
      );
      return counts
          .where((e) => e.value > 0)
          .map((e) => StreamPoint(stream: e.key, count: e.value))
          .toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────

  List<DailyPoint> _groupByDayRange(
    List<Map<String, dynamic>> rows,
    String tsField,
    DateTime start,
    DateTime end,
  ) {
    final Map<String, int> counts = {};
    for (final r in rows) {
      final ts = r[tsField]?.toString();
      if (ts == null || ts.length < 10) continue;
      final day = ts.substring(0, 10);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return _buildSeriesRange(
      counts.map((k, v) => MapEntry(k, v.toDouble())),
      start,
      end,
    );
  }

  List<DailyPoint> _buildSeriesRange(
    Map<String, double> totals,
    DateTime start,
    DateTime end, [
    Map<String, Map<String, double>>? methodTotals,
  ]) {
    final result = <DailyPoint>[];
    var current = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day);
    while (!current.isAfter(endDay)) {
      final key =
          '${current.year}-${current.month.toString().padLeft(2, '0')}-${current.day.toString().padLeft(2, '0')}';
      result.add(DailyPoint(
        day: current,
        value: totals[key] ?? 0,
        methodBreakdown: methodTotals?[key] ?? const {},
      ));
      current = current.add(const Duration(days: 1));
    }
    return result;
  }
}
