import 'dart:convert';
import 'package:flutter/foundation.dart';
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

  /// Sends a broadcast or user-targeted notification.
  ///
  /// Steps:
  ///   1. Inserts the row into `notifications` — the student app's Realtime
  ///      listener picks this up instantly when the app is foregrounded.
  ///   2. Calls the `send-push` edge function for FCM delivery — this reaches
  ///      students whose app is backgrounded or killed.
  ///
  /// The edge function sends a **data-only** FCM message (no system notification
  /// payload). The student app handles it in its background handler and shows
  /// a local notification itself — avoiding a duplicate when the app is open
  /// (the Realtime listener already showed it).
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
      // The edge function inserts the notification row into the DB AND sends
      // FCM. We don't insert here — doing so caused duplicate rows because
      // the edge function also inserts. Realtime picks up the DB row inserted
      // by the edge function for foregrounded student apps.

      // 2. FCM push — reaches backgrounded / killed student apps.
      //    Build the audience object the edge function expects.
      final String edgeAudience;
      String? edgeTargetStream;
      String? edgeTargetStatus;
      String? edgeUserId;

      if (audience == 'all') {
        edgeAudience = 'all';
      } else if (audience.startsWith('stream:')) {
        edgeAudience = 'stream';
        edgeTargetStream = audience.substring(7);
      } else if (audience.startsWith('status:')) {
        edgeAudience = 'status';
        edgeTargetStatus = audience.substring(7);
      } else if (audience.startsWith('user:')) {
        edgeAudience = 'user';
        edgeUserId = audience.substring(5);
      } else {
        edgeAudience = 'all';
      }

      final response = await http
          .post(
            Uri.parse('${AppEnv.adminFunctionsBaseUrl}/send-push'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppEnv.supabaseApiKey}',
              'x-webhook-secret': AppEnv.pushWebhookSecret,
            },
            body: jsonEncode({
              'event': 'announcement',
              'title': title,
              'body': body,
              'audience': edgeAudience,
              if (edgeTargetStream != null) 'target_stream': edgeTargetStream,
              if (edgeTargetStatus != null) 'target_status': edgeTargetStatus,
              if (edgeUserId != null) 'user_id': edgeUserId,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        throw const AppFailure(
          title: 'Not authorised',
          message: 'Push webhook secret rejected. Check PUSH_WEBHOOK_SECRET.',
        );
      }
      if (response.statusCode != 200) {
        // Non-fatal: DB row is already saved, Realtime will deliver it.
        // Log but don't surface as an error to the admin.
        debugPrint(
          '[NotificationsRepository] FCM push failed '
          '(${response.statusCode}): ${response.body}',
        );
      }
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
