import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:http/http.dart' as http;
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/utils/constants/app_env.dart';
import 'package:m_admin/utils/exceptions/app_failure_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Data access for the payment review queue.
class AdminPaymentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

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
        throw const AppFailure(
          title: 'Not found',
          message: 'Receipt no longer exists.',
        );
      }

      return PaymentReview.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Approves a payment: marks the receipt approved, sets expiration, and grants the user premium.
  Future<void> approve({
    required String receiptId,
    required String userId,
    required String adminUid,
    num? amount,
    String? planKey,
    int? planDurationMonths,
    String? note,
  }) async {
    try {
      final now = DateTime.now().toUtc();
      final nowIso = now.toIso8601String();

      // 1. Update the receipt
      await _supabase.from('payment_receipts').update({
        'status': 'approved',
        'reviewed_by': adminUid,
        'reviewed_at': nowIso,
        'amount': amount,
      }).eq('id', receiptId);

      // 2. Calculate subscription expiration
      final months = planDurationMonths ?? 12;
      
      // Fetch current user expiration if active
      final userRow = await _supabase
          .from('users')
          .select('subscription_expires_at, subscription_status')
          .eq('id', userId)
          .maybeSingle();

      final currentExpiryRaw = userRow?['subscription_expires_at'];
      final currentExpiry = currentExpiryRaw != null
          ? DateTime.tryParse(currentExpiryRaw.toString())
          : null;

      final baseDate = (currentExpiry != null && currentExpiry.isAfter(DateTime.now()))
          ? currentExpiry
          : DateTime.now();

      final newExpiry = DateTime(baseDate.year, baseDate.month + months, baseDate.day);

      // 3. Grant active premium with calculated expiration and plan
      await _supabase
          .from('users')
          .update({
            'subscription_status': 'active',
            'subscription_plan': planKey ?? '1_year',
            'subscription_expires_at': newExpiry.toUtc().toIso8601String(),
          })
          .eq('id', userId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Rejects a payment: marks the receipt rejected and sets user to inactive.
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
          .update({
            'subscription_status': 'inactive',
            'subscription_expires_at': null,
          })
          .eq('id', userId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

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
