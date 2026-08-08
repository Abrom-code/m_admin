import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:http/http.dart' as http;
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/utils/constants/app_env.dart';
import 'package:m_admin/utils/exceptions/app_failure_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access for the payment review queue.
///
/// Approve and reject use two sequential direct writes (payment_receipts, then
/// users). Without an RPC there is no single transaction, but each write is
/// idempotent so retrying on a partial failure is safe.
class AdminPaymentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// One query yields receipt + student identity + current premium flag.
  ///
  /// `status: 'all'` skips the status filter.
  Future<List<PaymentReview>> fetchQueue({
    required String status,
    String? search,
    String? method,
    DateTimeRange? range,
    int page = 0,
    int pageSize = 25,
  }) async {
    try {
      var query = _supabase
          .from('payment_receipts')
          .select(
            '*, users!inner(id, first_name, last_name, email, stream, '
            'subscription_status)',
          );

      if (status != 'all') {
        query = query.eq('status', status);
      }

      if (method != null && method.isNotEmpty) {
        query = query.eq('payment_method', method);
      }

      if (range != null) {
        query = query
            .gte('created_at', range.start.toUtc().toIso8601String())
            .lte('created_at', range.end.toUtc().toIso8601String());
      }

      final term = search?.trim() ?? '';
      if (term.isNotEmpty) {
        final safe = _escapeFilterValue(term);
        query = query.or(
          'first_name.ilike.%$safe%,'
          'last_name.ilike.%$safe%,'
          'email.ilike.%$safe%',
          referencedTable: 'users',
        );
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1);

      return rows
          .map((row) => PaymentReview.fromJson(Map<String, dynamic>.from(row)))
          .toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<int> countByStatus(String status) async {
    try {
      var query = _supabase.from('payment_receipts').select('id');

      if (status != 'all') {
        query = query.eq('status', status);
      }

      final rows = await query.count(CountOption.exact);
      return rows.count;
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<PaymentReview> fetchDetail(String id) async {
    try {
      final row = await _supabase
          .from('payment_receipts')
          .select(
            '*, users!inner(id, first_name, last_name, email, stream, '
            'subscription_status)',
          )
          .eq('id', id)
          .maybeSingle();

      if (row == null) {
        throw AppFailure(
          title: 'Not found',
          message: 'Receipt #$id no longer exists.',
        );
      }

      return PaymentReview.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Approves a payment: marks the receipt approved and grants the user premium.
  ///
  /// Two sequential writes instead of one RPC transaction — if the second
  /// write ever fails the receipt is already approved, so re-running approve
  /// is safe (idempotent on the users row).
  ///
  /// The push is sent by the caller AFTER this returns so a failed FCM call
  /// never rolls back the database change.
  Future<void> approve({
    required String receiptId,
    required String userId,
    required String adminUid,
    num? amount,
    String? note,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _supabase.from('payment_receipts').update({
        'status': 'approved',
        'reviewed_by': adminUid,
        'reviewed_at': now,
        'amount': ?amount,
      }).eq('id', receiptId);

      await _supabase
          .from('users')
          .update({'subscription_status': 'active'})
          .eq('id', userId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Rejects a payment: marks the receipt rejected and sets user to inactive.
  ///
  /// `subscription_status` is written as `'inactive'` (not `'rejected'`)
  /// because UserModel in the student app has no rejected state — the student
  /// would end up stranded. The rejection reason is recorded on the receipt.
  Future<void> reject({
    required String receiptId,
    required String userId,
    required String adminUid,
    required String reason,
  }) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();

      await _supabase.from('payment_receipts').update({
        'status': 'rejected',
        'reviewed_by': adminUid,
        'reviewed_at': now,
        'rejection_reason': reason,
      }).eq('id', receiptId);

      await _supabase
          .from('users')
          .update({'subscription_status': 'inactive'})
          .eq('id', userId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Prefers a short-lived signed URL over the stored public one.
  ///
  /// The `receipts` bucket is currently PUBLIC — the student app calls
  /// `getPublicUrl` and never `createSignedUrl`, so every receipt is a
  /// permanent unauthenticated URL that anyone with the link can read. That
  /// should be flipped to private (Phase 13); this method already works
  /// either way, falling back to the stored URL if signing is refused.
  Future<String> signedReceiptUrl(String path, {String? fallbackUrl}) async {
    try {
      return await _supabase.storage
          .from('receipts')
          .createSignedUrl(path, 300);
    } catch (_) {
      if (fallbackUrl != null && fallbackUrl.isNotEmpty) return fallbackUrl;
      rethrow;
    }
  }

  /// Notifies the student of a review outcome.
  ///
  /// Failures here are reported but must not roll anything back — the write
  /// already committed, and Realtime will deliver the subscription change.
  Future<void> sendPaymentPush({
    required String userId,
    required String status,
    String? reason,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${AppEnv.adminFunctionsBaseUrl}/send-push'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer ${AppEnv.supabaseApiKey}',
              'x-webhook-secret': AppEnv.pushWebhookSecret,
            },
            body: jsonEncode({
              'event': 'payment_status',
              'user_id': userId,
              'status': status,
              if (reason != null && reason.isNotEmpty)
                'rejection_reason': reason,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 401) {
        throw const AppFailure(
          title: 'Push not sent',
          message:
              'The push service rejected the webhook secret. Check '
              'PUSH_WEBHOOK_SECRET in .env against the deployed function. '
              'The payment itself was saved.',
        );
      }

      if (response.statusCode != 200) {
        throw AppFailure(
          title: 'Push not sent',
          message:
              'The payment was saved, but the notification failed '
              '(${response.statusCode}).',
        );
      }
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Escapes PostgREST `or()` metacharacters.
  ///
  /// The parent app's AnalyticsController interpolates filter values straight
  /// into its queries. That pattern is not reproduced here, where the value is
  /// typed by a human into a search box.
  static String _escapeFilterValue(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll(',', r'\,')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll('"', r'\"')
        .replaceAll('*', r'\*');
  }
}
