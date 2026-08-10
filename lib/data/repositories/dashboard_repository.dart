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
  });

  final int totalUsers;
  final int paidUsers;
  final int pendingPayments;
  final int newUsersThisWeek;
  final double totalRevenue;
  final List<RecentReceiptRow> recentReceipts;

  /// Derived: users without an active subscription.
  int get unpaidUsers => totalUsers - paidUsers;

  DashboardStats copyWith({int? pendingPayments}) => DashboardStats(
    totalUsers: totalUsers,
    paidUsers: paidUsers,
    pendingPayments: pendingPayments ?? this.pendingPayments,
    newUsersThisWeek: newUsersThisWeek,
    totalRevenue: totalRevenue,
    recentReceipts: recentReceipts,
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

/// One day of data for the line chart.
class DailyPoint {
  const DailyPoint({required this.day, required this.value});
  final DateTime day;
  final double value;
}

/// Tests available per subject.
class SubjectTestCount {
  const SubjectTestCount({
    required this.subjectId,
    required this.subjectName,
    required this.testCount,
  });
  final int subjectId;
  final String subjectName;
  final int testCount;
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

      // All 6 queries fire in parallel — including recent receipts.
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

      return DashboardStats(
        totalUsers: total,
        paidUsers: paid,
        pendingPayments: pending,
        newUsersThisWeek: newThisWeek,
        totalRevenue: totalRevenue,
        recentReceipts: recentRows
            .map((r) => RecentReceiptRow.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
      );
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Daily signup counts for the last [days] days.
  Future<List<DailyPoint>> fetchSignupsDaily(int days) async {
    try {
      final since = DateTime.now()
          .subtract(Duration(days: days))
          .toUtc()
          .toIso8601String();

      final rows = await _sb
          .from('users')
          .select('created_at')
          .gte('created_at', since)
          .order('created_at');

      return _groupByDay(rows, 'created_at', days);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Daily approved-payment totals.
  Future<List<DailyPoint>> fetchRevenueDaily(int days) async {
    try {
      final since = DateTime.now()
          .subtract(Duration(days: days))
          .toUtc()
          .toIso8601String();

      final rows = await _sb
          .from('payment_receipts')
          .select('reviewed_at, amount')
          .eq('status', 'approved')
          .gte('reviewed_at', since)
          .order('reviewed_at');

      final Map<String, double> totals = {};
      for (final r in rows) {
        final ts = r['reviewed_at']?.toString();
        if (ts == null) continue;
        final day = ts.substring(0, 10);
        final amt = _toDouble(r['amount']);
        totals[day] = (totals[day] ?? 0) + amt;
      }

      return _buildSeries(totals, days);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Number of published tests per subject (content health, not attempt data).
  ///
  /// Uses server-side COUNT per subject so no test rows are transferred
  /// over the wire — just the subject list and one count per subject.
  Future<List<SubjectTestCount>> fetchSubjectTestCounts() async {
    try {
      final subjectRows = await _sb
          .from('subjects')
          .select('id, name')
          .order('name');

      if (subjectRows.isEmpty) return [];

      // Fire one COUNT query per subject in parallel.
      final counts = await Future.wait(
        subjectRows.map((s) async {
          final sid = _toInt(s['id']) ?? 0;
          final r = await _sb
              .from('tests')
              .select('id')
              .eq('subject_id', sid)
              .count(CountOption.exact);
          return MapEntry(sid, r.count);
        }),
      );

      final countMap = Map<int, int>.fromEntries(counts);

      return subjectRows.map((s) {
        final sid = _toInt(s['id']) ?? 0;
        return SubjectTestCount(
          subjectId: sid,
          subjectName: s['name']?.toString() ?? '',
          testCount: countMap[sid] ?? 0,
        );
      }).toList()
        ..sort((a, b) => b.testCount.compareTo(a.testCount));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Conversion funnel: signups → payment submitted → approved.
  Future<List<FunnelPoint>> fetchSubscriptionFunnel() async {
    try {
      final results = await Future.wait<dynamic>([
        _sb.from('users').select('id').count(CountOption.exact),           // 0: total signups
        _sb
            .from('users')
            .select('id')
            .not('subscription_status', 'eq', 'inactive')
            .count(CountOption.exact),                                      // 1: non-inactive
        _sb
            .from('payment_receipts')
            .select('id')
            .count(CountOption.exact),                                      // 2: submitted
        _sb
            .from('users')
            .select('id')
            .eq('subscription_status', 'active')
            .count(CountOption.exact),                                      // 3: currently active
      ]);

      return [
        FunnelPoint(label: 'Signups',           count: (results[0] as dynamic).count as int),
        FunnelPoint(label: 'Non-inactive',       count: (results[1] as dynamic).count as int),
        FunnelPoint(label: 'Submitted payment',  count: (results[2] as dynamic).count as int),
        FunnelPoint(label: 'Active',             count: (results[3] as dynamic).count as int),
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

  List<DailyPoint> _groupByDay(
    List<Map<String, dynamic>> rows,
    String tsField,
    int days,
  ) {
    final Map<String, int> counts = {};
    for (final r in rows) {
      final ts = r[tsField]?.toString();
      if (ts == null || ts.length < 10) continue;
      final day = ts.substring(0, 10);
      counts[day] = (counts[day] ?? 0) + 1;
    }
    return _buildSeries(counts.map((k, v) => MapEntry(k, v.toDouble())), days);
  }

  List<DailyPoint> _buildSeries(Map<String, double> totals, int days) {
    final result = <DailyPoint>[];
    final now = DateTime.now();
    for (int i = days - 1; i >= 0; i--) {
      final day = now.subtract(Duration(days: i));
      final key =
          '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
      result.add(DailyPoint(day: day, value: totals[key] ?? 0));
    }
    return result;
  }
}
