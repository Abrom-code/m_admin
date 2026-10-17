import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/features/audit_log/models/admin_audit_log_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

class AuditLogRepository {
  final _sb = Supabase.instance.client;

  /// Fetches paginated audit log entries with optional filters.
  Future<List<AdminAuditLogModel>> fetchAuditLogs({
    String? actionType,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 25,
    int offset = 0,
  }) async {
    try {
      var query = _sb.from('admin_audit_log').select();

      if (actionType != null && actionType.isNotEmpty && actionType != 'all') {
        query = query.eq('action', actionType);
      }
      if (startDate != null) {
        final startEat = DateTime.utc(startDate.year, startDate.month, startDate.day);
        final startUtc = startEat.subtract(EthiopianTimeHelper.eastAfricaOffset);
        query = query.gte('created_at', startUtc.toIso8601String());
      }
      if (endDate != null) {
        final endEat = DateTime.utc(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
        final endUtc = endEat.subtract(EthiopianTimeHelper.eastAfricaOffset);
        query = query.lte('created_at', endUtc.toIso8601String());
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return (rows as List)
          .map((r) => AdminAuditLogModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Counts total rows matching current filters.
  Future<int> countAuditLogs({
    String? actionType,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      var query = _sb.from('admin_audit_log').select();

      if (actionType != null && actionType.isNotEmpty && actionType != 'all') {
        query = query.eq('action', actionType);
      }
      if (startDate != null) {
        final startEat = DateTime.utc(startDate.year, startDate.month, startDate.day);
        final startUtc = startEat.subtract(EthiopianTimeHelper.eastAfricaOffset);
        query = query.gte('created_at', startUtc.toIso8601String());
      }
      if (endDate != null) {
        final endEat = DateTime.utc(endDate.year, endDate.month, endDate.day, 23, 59, 59, 999);
        final endUtc = endEat.subtract(EthiopianTimeHelper.eastAfricaOffset);
        query = query.lte('created_at', endUtc.toIso8601String());
      }

      final res = await query.count(CountOption.exact);
      return res.count;
    } catch (_) {
      return 0;
    }
  }
}
