import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/admin_payment_repository.dart';
import 'package:m_admin/data/services/admin_notification_service.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/dashboard/controllers/dashboard_controller.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/features/users/controllers/users_controller.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Status tabs, in display order.
const List<String> kPaymentTabs = ['pending', 'approved', 'rejected', 'all'];

class PaymentsController extends GetxController {
  static PaymentsController get instance => Get.find();

  final _repo = AdminPaymentRepository();
  final _session = Get.find<AdminSessionService>();

  // ── Query state ──────────────────────────────────────────────────
  final activeTab = 'pending'.obs;
  final searchQuery = ''.obs;
  final methodFilter = RxnString();
  final dateRange = Rxn<DateTimeRange>();
  final page = 0.obs;
  static const pageSize = 25;

  // ── Results ──────────────────────────────────────────────────────
  final rows = <PaymentReview>[].obs;
  final totalCount = 0.obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final counts = <String, int>{}.obs;

  /// Keyed by receipt id so one row's spinner never freezes the whole table.
  final actingIds = <String>{}.obs;

  final searchController = TextEditingController();

  Timer? _debounce;
  RealtimeChannel? _channel;

  bool isActing(String id) => actingIds.contains(id);

  @override
  void onInit() {
    super.onInit();
    loadQueue();
    refreshCounts();
    _subscribeRealtime();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    searchController.dispose();
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.onClose();
  }

  // ── Loading ──────────────────────────────────────────────────────

  Future<void> loadQueue() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      final result = await _repo.fetchQueue(
        status: activeTab.value,
        search: searchQuery.value,
        method: methodFilter.value,
        range: dateRange.value,
        page: page.value,
        pageSize: pageSize,
      );
      rows.value = result.rows;
      totalCount.value = result.totalCount;
    } catch (e) {
      final failure = AppExceptionHandler.handle(e);
      errorMessage.value = failure.message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshCounts() async {
    try {
      final results = await Future.wait(
        kPaymentTabs.map((tab) => _repo.countByStatus(tab)),
      );

      counts.value = {
        for (var i = 0; i < kPaymentTabs.length; i++) kPaymentTabs[i]: results[i],
      };

      // Keep the sidebar badge honest.
      if (Get.isRegistered<AdminNavController>()) {
        AdminNavController.instance.pendingPaymentCount.value =
            counts['pending'] ?? 0;
      }
    } catch (_) {
    }
  }

  Future<void> refreshAll() async {
    await Future.wait([loadQueue(), refreshCounts()]);
  }

  // ── Filters ──────────────────────────────────────────────────────

  void changeTab(String tab) {
    if (activeTab.value == tab) return;
    activeTab.value = tab;
    page.value = 0;
    loadQueue();
  }

  void onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      searchQuery.value = value;
      page.value = 0;
      loadQueue();
    });
  }

  void setMethodFilter(String? method) {
    methodFilter.value = method;
    page.value = 0;
    loadQueue();
  }

  void setDateRange(DateTimeRange? range) {
    dateRange.value = range;
    page.value = 0;
    loadQueue();
  }

  void clearFilters() {
    searchController.clear();
    searchQuery.value = '';
    methodFilter.value = null;
    dateRange.value = null;
    page.value = 0;
    loadQueue();
  }

  void changePage(int next) {
    if (next < 0) return;
    page.value = next;
    loadQueue();
  }

  // ── Actions ──────────────────────────────────────────────────────

  /// Approves a receipt and notifies the student with timing and plan details.
  Future<bool> approve(
    PaymentReview review, {
    num? amount,
    String? planKey,
    int? planDurationMonths,
    DateTime? expiresAt,
    String? notificationTitle,
    String? notificationBody,
  }) async {
    if (isActing(review.id)) return false;

    final resolvedPlanKey = planKey ?? review.planKey;
    final resolvedDuration = planDurationMonths ?? review.planDurationMonths;
    final resolvedAmount = amount ?? review.amount;

    try {
      actingIds.add(review.id);
      actingIds.refresh();

      final calculatedExpiry = await _repo.approve(
        receiptId: review.id,
        userId: review.userId,
        adminUid: _session.adminUid,
        amount: resolvedAmount,
        planKey: resolvedPlanKey,
        planDurationMonths: resolvedDuration,
        customExpiry: expiresAt,
      );

      _applyLocal(
        review.copyWith(
          status: 'approved',
          amount: resolvedAmount,
          reviewedBy: _session.adminUid,
          reviewedAt: DateTime.now(),
          subscriptionStatus: 'active',
          planKey: resolvedPlanKey,
          planDurationMonths: resolvedDuration,
        ),
      );

      // Keep the Users screen in sync without requiring a full reload.
      _syncUsersController(
        review.userId,
        'active',
        plan: resolvedPlanKey,
        expiresAt: calculatedExpiry,
      );

      final label = review.planLabel;
      SnackbarHelper.success(
        'Payment approved',
        '${review.displayName} now has $label premium access.',
      );

      await _notify(
        review.userId,
        'active',
        title: notificationTitle,
        body: notificationBody,
      );
      await refreshCounts();
      _refreshDashboard();
      return true;
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
      await refreshAll();
      return false;
    } finally {
      actingIds.remove(review.id);
      actingIds.refresh();
    }
  }

  Future<bool> reject(PaymentReview review, String reason) async {
    if (isActing(review.id)) return false;

    final trimmed = reason.trim();
    if (trimmed.isEmpty) {
      SnackbarHelper.warning('Reason required', 'Say why this was rejected.');
      return false;
    }

    try {
      actingIds.add(review.id);
      actingIds.refresh();

      await _repo.reject(
        receiptId: review.id,
        userId: review.userId,
        adminUid: _session.adminUid,
        reason: trimmed,
      );

      _applyLocal(
        review.copyWith(
          status: 'rejected',
          reviewedBy: _session.adminUid,
          reviewedAt: DateTime.now(),
          rejectionReason: trimmed,
          subscriptionStatus: 'inactive',
        ),
      );

      // Keep the Users screen in sync without requiring a full reload.
      _syncUsersController(review.userId, 'inactive');

      SnackbarHelper.success(
        'Payment rejected',
        '${review.displayName} has been notified.',
      );

      await _notify(
        review.userId,
        'rejected',
        title: 'Payment Rejected',
        body:
            'Your payment receipt for ${review.planLabel} could not be approved: $trimmed',
        reason: trimmed,
      );
      await refreshCounts();
      _refreshDashboard();
      return true;
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
      await refreshAll();
      return false;
    } finally {
      actingIds.remove(review.id);
      actingIds.refresh();
    }
  }

  Future<void> _notify(
    String userId,
    String status, {
    String? title,
    String? body,
    String? reason,
  }) async {
    try {
      await _repo.sendPaymentPush(
        userId: userId,
        status: status,
        title: title,
        body: body,
        reason: reason,
      );
    } catch (_) {
    }
  }

  /// Propagates a subscription status change to [UsersController] if it is
  /// alive, so the Users screen stays consistent without a full reload.
  void _syncUsersController(
    String userId,
    String status, {
    String? plan,
    DateTime? expiresAt,
  }) {
    if (Get.isRegistered<UsersController>()) {
      UsersController.instance.applyLocalStatusUpdate(
        userId,
        status,
        plan: plan,
        expiresAt: expiresAt,
      );
    }
  }

  void _refreshDashboard() {
    if (Get.isRegistered<DashboardController>()) {
      DashboardController.instance.load();
    }
  }

  void _applyLocal(PaymentReview updated) {
    final index = rows.indexWhere((r) => r.id == updated.id);
    if (index == -1) return;

    if (activeTab.value != 'all' && updated.status != activeTab.value) {
      rows.removeAt(index);
    } else {
      rows[index] = updated;
    }

    for (var i = 0; i < rows.length; i++) {
      if (rows[i].userId == updated.userId && rows[i].id != updated.id) {
        rows[i] = rows[i].copyWith(subscriptionStatus: updated.subscriptionStatus);
      }
    }

    rows.refresh();
  }

  PaymentReview? nextPendingAfter(PaymentReview current) {
    final pending = rows.where((r) => r.isPending).toList();
    if (pending.isEmpty) return null;

    final index = pending.indexWhere((r) => r.id == current.id);
    if (index == -1) return pending.first;
    if (index + 1 < pending.length) return pending[index + 1];
    return null;
  }

  PaymentReview? neighbourOf(PaymentReview current, int offset) {
    final index = rows.indexWhere((r) => r.id == current.id);
    if (index == -1) return null;
    final target = index + offset;
    if (target < 0 || target >= rows.length) return null;
    return rows[target];
  }

  // ── Realtime ─────────────────────────────────────────────────────

  void _subscribeRealtime() {
    try {
      _channel = Supabase.instance.client
          .channel('admin_payment_receipts')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: 'payment_receipts',
            callback: (payload) {
              refreshCounts();
              if (activeTab.value == 'pending' || activeTab.value == 'all') {
                if (page.value == 0) loadQueue();
              }
              final method =
                  payload.newRecord['payment_method']?.toString() ?? '';
              _notifyNewPayment(method);
            },
          )
          .subscribe((status, [error]) {
            if (error != null) {
              debugPrint('[PaymentsController] Realtime error: $error');
            }
            debugPrint('[PaymentsController] Realtime status: $status');
          });
    } catch (e) {
      debugPrint('[PaymentsController] Realtime setup failed: $e');
    }
  }

  void _notifyNewPayment(String paymentMethod) {
    if (Get.isRegistered<AdminNotificationService>()) {
      AdminNotificationService.instance
          .newPendingPayment(paymentMethod: paymentMethod);
    }

    final label = paymentMethod.isEmpty
        ? 'New payment'
        : '${paymentMethod[0].toUpperCase()}${paymentMethod.substring(1)} payment';
    SnackbarHelper.info('New payment pending', '$label is waiting for review.');
  }
}
