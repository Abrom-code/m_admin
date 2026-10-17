import 'dart:convert';

import 'package:flutter/material.dart' show DateTimeRange;
import 'package:http/http.dart' as http;
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/utils/constants/app_env.dart';
import 'package:m_admin/utils/exceptions/app_failure_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

/// Storage cleanup metric snapshot.
class ReceiptStorageStats {
  const ReceiptStorageStats({
    required this.totalActiveScreenshots,
    required this.olderThanOneWeekScreenshots,
    required this.rejectedReceiptsCount,
  });

  final int totalActiveScreenshots;
  final int olderThanOneWeekScreenshots;
  final int rejectedReceiptsCount;
}

/// Data access for the payment review queue.
class AdminPaymentRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<({List<PaymentReview> rows, int totalCount})> fetchQueue({
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
            '*, users!inner(id, first_name, last_name, full_name, email, stream, '
            'subscription_status)',
          );

      if (status != 'all') {
        query = query.eq('status', status);
      }

      if (method != null && method.isNotEmpty && method.toLowerCase() != 'all') {
        final clean = method.toLowerCase().replaceAll('payment_', '').replaceAll('_birr', '');
        query = query.or('payment_method.ilike.%$clean%,payment_method.ilike.%$method%');
      }

      if (range != null) {
        final startEat = DateTime.utc(range.start.year, range.start.month, range.start.day);
        final startUtc = startEat.subtract(EthiopianTimeHelper.eastAfricaOffset);
        final endEat = DateTime.utc(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
        final endUtc = endEat.subtract(EthiopianTimeHelper.eastAfricaOffset);
        query = query
            .gte('created_at', startUtc.toIso8601String())
            .lte('created_at', endUtc.toIso8601String());
      }

      final term = search?.trim() ?? '';
      if (term.isNotEmpty) {
        final safe = _escapeFilterValue(term);
        query = query.or(
          'first_name.ilike.%$safe%,'
          'last_name.ilike.%$safe%,'
          'full_name.ilike.%$safe%,'
          'email.ilike.%$safe%',
          referencedTable: 'users',
        );
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1)
          .count(CountOption.exact);

      final rows = (response.data as List)
          .map((row) => PaymentReview.fromJson(Map<String, dynamic>.from(row)))
          .toList();

      return (rows: rows, totalCount: response.count);
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
            '*, users!inner(id, first_name, last_name, full_name, email, stream, '
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
  Future<DateTime> approve({
    required String receiptId,
    required String userId,
    required String adminUid,
    num? amount,
    String? planKey,
    int? planDurationMonths,
    DateTime? customExpiry,
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
        'amount': ?amount,
        'plan_key': ?planKey,
        'plan_duration_months': ?planDurationMonths,
      }).eq('id', receiptId);

      // 2. Calculate subscription expiration
      DateTime newExpiry;
      if (customExpiry != null) {
        newExpiry = customExpiry;
      } else {
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

        newExpiry = DateTime(baseDate.year, baseDate.month + months, baseDate.day);
      }

      // 3. Grant active premium with calculated expiration and plan
      await _supabase
          .from('users')
          .update({
            'subscription_status': 'active',
            'subscription_plan': planKey ?? '1_year',
            'subscription_expires_at': newExpiry.toUtc().toIso8601String(),
          })
          .eq('id', userId);

      return newExpiry;
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Rejects a payment: removes the screenshot from storage, sets user to inactive,
  /// and permanently deletes the receipt row from payment_receipts database table.
  Future<void> reject({
    required String receiptId,
    required String userId,
    required String adminUid,
    required String reason,
    String? receiptPath,
  }) async {
    try {
      var path = receiptPath;
      if (path == null || path.isEmpty) {
        final row = await _supabase
            .from('payment_receipts')
            .select('receipt_path')
            .eq('id', receiptId)
            .maybeSingle();
        path = row?['receipt_path']?.toString();
      }

      // 1. Remove screenshot from storage bucket
      if (path != null && path.isNotEmpty) {
        try {
          await _supabase.storage.from('receipts').remove([path]);
        } catch (_) {
          // File might already be gone; continue with DB deletion
        }
      }

      // 2. Set user subscription status to inactive
      await _supabase
          .from('users')
          .update({
            'subscription_status': 'inactive',
            'subscription_expires_at': null,
          })
          .eq('id', userId);

      // 3. Permanently delete the receipt row from the database table
      await _supabase.from('payment_receipts').delete().eq('id', receiptId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Fetches counts for storage cleanup: active receipts with screenshots,
  /// screenshots older than 7 days, and any remaining rejected receipts.
  Future<ReceiptStorageStats> getCleanupStats() async {
    try {
      final nowUtc = DateTime.now().toUtc();
      final oneWeekAgo = nowUtc.subtract(const Duration(days: 7)).toIso8601String();

      // 1. Approved receipts with uploaded screenshot
      final totalActiveRows = await _supabase
          .from('payment_receipts')
          .select('id')
          .eq('status', 'approved')
          .not('receipt_path', 'is', null)
          .neq('receipt_path', '')
          .count(CountOption.exact);

      // 2. Approved receipts with screenshot older than 7 days
      final olderThanOneWeekRows = await _supabase
          .from('payment_receipts')
          .select('id')
          .eq('status', 'approved')
          .not('receipt_path', 'is', null)
          .neq('receipt_path', '')
          .lt('created_at', oneWeekAgo)
          .count(CountOption.exact);

      // 3. Any leftover rejected receipts in database
      final rejectedRows = await _supabase
          .from('payment_receipts')
          .select('id')
          .eq('status', 'rejected')
          .count(CountOption.exact);

      return ReceiptStorageStats(
        totalActiveScreenshots: totalActiveRows.count,
        olderThanOneWeekScreenshots: olderThanOneWeekRows.count,
        rejectedReceiptsCount: rejectedRows.count,
      );
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Deletes screenshots for approved payments from Supabase Storage and clears
  /// the receipt_path & receipt_url columns on the database rows.
  ///
  /// The accounting records (amounts, plans, dates) remain 100% intact!
  Future<int> deleteActiveReceiptScreenshots({
    bool olderThanOneWeekOnly = false,
  }) async {
    try {
      var query = _supabase
          .from('payment_receipts')
          .select('id, receipt_path')
          .eq('status', 'approved')
          .not('receipt_path', 'is', null)
          .neq('receipt_path', '');

      if (olderThanOneWeekOnly) {
        final oneWeekAgo = DateTime.now()
            .toUtc()
            .subtract(const Duration(days: 7))
            .toIso8601String();
        query = query.lt('created_at', oneWeekAgo);
      }

      final rows = await query.limit(500);
      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return 0;

      final paths = <String>[];
      final ids = <String>[];

      for (final r in list) {
        final path = r['receipt_path']?.toString();
        final id = r['id']?.toString();
        if (path != null && path.isNotEmpty) paths.add(path);
        if (id != null && id.isNotEmpty) ids.add(id);
      }

      // 1. Delete files from storage in chunks
      for (var i = 0; i < paths.length; i += 50) {
        final chunk = paths.sublist(i, (i + 50).clamp(0, paths.length));
        try {
          await _supabase.storage.from('receipts').remove(chunk);
        } catch (_) {}
      }

      // 2. Clear receipt_path and receipt_url in payment_receipts
      for (var i = 0; i < ids.length; i += 50) {
        final chunk = ids.sublist(i, (i + 50).clamp(0, ids.length));
        await _supabase
            .from('payment_receipts')
            .update({
              'receipt_path': null,
              'receipt_url': null,
            })
            .inFilter('id', chunk);
      }

      return ids.length;
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Deletes a single screenshot for an approved receipt from storage and nulls the columns.
  Future<void> deleteSingleReceiptScreenshot({
    required String receiptId,
    required String receiptPath,
  }) async {
    try {
      if (receiptPath.isNotEmpty) {
        try {
          await _supabase.storage.from('receipts').remove([receiptPath]);
        } catch (_) {}
      }

      await _supabase
          .from('payment_receipts')
          .update({
            'receipt_path': null,
            'receipt_url': null,
          })
          .eq('id', receiptId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Permanently removes any leftover or historic rejected receipts from
  /// the database and deletes their screenshots from storage.
  Future<int> purgeAllRejectedReceipts() async {
    try {
      final rows = await _supabase
          .from('payment_receipts')
          .select('id, receipt_path')
          .eq('status', 'rejected')
          .limit(500);

      final list = List<Map<String, dynamic>>.from(rows);
      if (list.isEmpty) return 0;

      final paths = <String>[];
      for (final r in list) {
        final p = r['receipt_path']?.toString();
        if (p != null && p.isNotEmpty) paths.add(p);
      }

      // 1. Delete storage files
      for (var i = 0; i < paths.length; i += 50) {
        final chunk = paths.sublist(i, (i + 50).clamp(0, paths.length));
        try {
          await _supabase.storage.from('receipts').remove(chunk);
        } catch (_) {}
      }

      // 2. Delete rows from payment_receipts
      await _supabase
          .from('payment_receipts')
          .delete()
          .eq('status', 'rejected');

      return list.length;
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
    String? title,
    String? body,
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
              if (title != null && title.isNotEmpty) 'title': title,
              if (body != null && body.isNotEmpty) 'body': body,
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
