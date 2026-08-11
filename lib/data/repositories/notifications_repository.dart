import 'package:m_admin/features/notifications/models/admin_notification_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationsRepository {
  final _sb = Supabase.instance.client;

  Future<List<AdminNotificationModel>> fetchRecent({
    int page = 0,
    int pageSize = 30,
    String? typeFilter,
  }) async {
    try {

      // Filters must be applied before .order()/.range() — the Supabase
      // Flutter client returns a PostgrestTransformBuilder after those calls,
      // which no longer exposes .eq().
      var q = _sb.from('notifications').select();

      if (typeFilter != null && typeFilter.isNotEmpty) {
        q = q.eq('type', typeFilter);
      }

      final rows = await q
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);


      return rows
          .map(
            (r) => AdminNotificationModel.fromJson(
              Map<String, dynamic>.from(r),
            ),
          )
          .toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<int> countAll() async {
    try {
      final r = await _sb
          .from('notifications')
          .select('id')
          .count(CountOption.exact);
      return r.count;
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Sends a broadcast or user-targeted notification.
  /// Inserts the notification record into the database.
  /// The student app picks it up via Supabase Realtime — no FCM push needed.
  ///
  /// [audience]: `'all'` | `'stream:<name>'` | `'user:<uid>'`
  Future<void> sendBroadcast({
    required String title,
    required String body,
    required String type,
    required String audience,
    Map<String, dynamic> payload = const {},
  }) async {
    try {
      String? targetStream;
      String? userId;

      if (audience.startsWith('stream:')) {
        targetStream = audience.substring(7);
      } else if (audience.startsWith('user:')) {
        userId = audience.substring(5);
      }

      await _sb.from('notifications').insert({
        'title': title,
        'body': body,
        'type': type,
        'user_id': userId,
        'target_stream': targetStream,
        'payload': payload,
        'is_read': false,
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Delete a notification by ID
  Future<void> delete(int id) async {
    try {
      await _sb.from('notifications').delete().eq('id', id);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Delete multiple notifications by ID in a single round-trip.
  Future<void> deleteMany(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      await _sb.from('notifications').delete().inFilter('id', ids);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Get notification statistics
  Future<Map<String, int>> getStats() async {
    try {
      final allCount = await _sb
          .from('notifications')
          .select('id')
          .count(CountOption.exact);

      final announcementCount = await _sb
          .from('notifications')
          .select('id')
          .eq('type', 'announcement')
          .count(CountOption.exact);

      final contentCount = await _sb
          .from('notifications')
          .select('id')
          .eq('type', 'new_content')
          .count(CountOption.exact);

      final paymentCount = await _sb
          .from('notifications')
          .select('id')
          .eq('type', 'payment')
          .count(CountOption.exact);

      return {
        'total': allCount.count,
        'announcement': announcementCount.count,
        'new_content': contentCount.count,
        'payment': paymentCount.count,
      };
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }
}
