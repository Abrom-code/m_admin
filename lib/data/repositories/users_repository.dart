import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

class UsersRepository {
  final _sb = Supabase.instance.client;

  Future<List<AdminUserModel>> fetchUsers({
    String? search,
    String? statusFilter,
    String? streamFilter,
    int page = 0,
    int pageSize = 30,
  }) async {
    try {
      var q = _sb
          .from('users')
          .select('id, first_name, last_name, email, stream, '
              'subscription_status, created_at');

      if (statusFilter != null && statusFilter.isNotEmpty) {
        q = q.eq('subscription_status', statusFilter);
      }

      if (streamFilter != null && streamFilter.isNotEmpty) {
        q = q.eq('stream', streamFilter);
      }

      if (search != null && search.trim().isNotEmpty) {
        final safe = search.trim().replaceAll("'", "''");
        q = q.or(
          'first_name.ilike.%$safe%,'
          'last_name.ilike.%$safe%,'
          'email.ilike.%$safe%',
        );
      }

      final rows = await q
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return rows
          .map(
            (r) =>
                AdminUserModel.fromJson(Map<String, dynamic>.from(r)),
          )
          .toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<int> countByStatus(String? status) async {
    try {
      var q = _sb.from('users').select('id');
      if (status != null && status.isNotEmpty) {
        q = q.eq('subscription_status', status);
      }
      final r = await q.count(CountOption.exact);
      return r.count;
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Manual subscription override — used when a payment was confirmed outside
  /// the app (e.g. cash, or a corrected bank error).
  Future<void> setSubscriptionStatus(
    String userId,
    String status,
    String adminUid,
  ) async {
    try {
      await _sb
          .from('users')
          .update({'subscription_status': status})
          .eq('id', userId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchReceiptsFor(
    String userId,
  ) async {
    try {
      final rows = await _sb
          .from('payment_receipts')
          .select(
            'id, status, payment_method, amount, created_at, '
            'reviewed_by, reviewed_at, rejection_reason',
          )
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return rows
          .map((r) => Map<String, dynamic>.from(r))
          .toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Distinct stream values for the filter dropdown.
  Future<List<String>> fetchStreams() async {
    try {
      final rows = await _sb
          .from('users')
          .select('stream')
          .not('stream', 'is', null)
          .not('stream', 'eq', '');

      final set = <String>{};
      for (final r in rows) {
        final v = r['stream']?.toString();
        if (v != null && v.isNotEmpty) set.add(v);
      }
      return set.toList()..sort();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }
}
