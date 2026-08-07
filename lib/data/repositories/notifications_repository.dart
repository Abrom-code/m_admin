import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:m_admin/features/notifications/models/admin_notification_model.dart';
import 'package:m_admin/utils/constants/app_env.dart';
import 'package:m_admin/utils/exceptions/app_failure_model.dart';
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

  /// Sends a broadcast or user-targeted notification via the `send-push` edge
  /// function. The edge function handles the FCM call and the DB insert.
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
      final String? userId =
          audience.startsWith('user:') ? audience.substring(5) : null;
      final String? targetStream =
          audience.startsWith('stream:') ? audience.substring(7) : null;

      final response = await http
          .post(
            Uri.parse('${AppEnv.adminFunctionsBaseUrl}/send-push'),
            headers: {
              'Content-Type': 'application/json',
              'x-webhook-secret': AppEnv.pushWebhookSecret,
            },
            body: jsonEncode({
              'event': 'broadcast',
              'title': title,
              'body': body,
              'type': type,
              'user_id': ?userId,
              'target_stream': ?targetStream,
              if (payload.isNotEmpty) 'payload': payload,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        throw const AppFailure(
          title: 'Not authorised',
          message:
              'The push service rejected the webhook secret. Check '
              'PUSH_WEBHOOK_SECRET in .env.',
        );
      }

      if (response.statusCode != 200) {
        throw AppFailure(
          title: 'Send failed',
          message: 'Status ${response.statusCode}: ${response.body}',
        );
      }
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }
}
