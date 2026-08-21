import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/users_repository.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/dashboard/controllers/dashboard_controller.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersController extends GetxController {
  static UsersController get instance => Get.find();

  final _repo = UsersRepository();
  final _session = Get.find<AdminSessionService>();

  final rows = <AdminUserModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final counts = <String, int>{}.obs;
  final availableStreams = <String>[].obs;

  final searchQuery = ''.obs;
  final statusFilter = RxnString();
  final streamFilter = RxnString();
  final page = 0.obs;
  static const pageSize = 30;

  final actingIds = <String>{}.obs;
  final searchController = TextEditingController();

  Timer? _debounce;
  RealtimeChannel? _channel;

  bool isActing(String id) => actingIds.contains(id);

  @override
  void onInit() {
    super.onInit();
    loadAll();
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

  Future<void> loadAll() async {
    await Future.wait([load(), refreshCounts(), loadStreams()]);
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      rows.value = await _repo.fetchUsers(
        search: searchQuery.value,
        statusFilter: statusFilter.value,
        streamFilter: streamFilter.value,
        page: page.value,
        pageSize: pageSize,
      );
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshCounts() async {
    try {
      final statuses = ['', 'active', 'pending', 'inactive'];
      final results = await Future.wait(
        statuses.map((s) => _repo.countByStatus(s.isEmpty ? null : s)),
      );
      counts.value = {
        for (var i = 0; i < statuses.length; i++) statuses[i]: results[i],
      };
    } catch (_) {}
  }

  Future<void> loadStreams() async {
    try {
      availableStreams.value = await _repo.fetchStreams();
    } catch (_) {}
  }

  void onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      searchQuery.value = value;
      page.value = 0;
      load();
    });
  }

  void setStatusFilter(String? status) {
    statusFilter.value = status;
    page.value = 0;
    load();
  }

  void setStreamFilter(String? stream) {
    streamFilter.value = stream;
    page.value = 0;
    load();
  }

  void clearFilters() {
    searchController.clear();
    searchQuery.value = '';
    statusFilter.value = null;
    streamFilter.value = null;
    page.value = 0;
    load();
  }

  void changePage(int next) {
    page.value = next;
    load();
  }

  Future<void> setSubscription(
    AdminUserModel user,
    String status, {
    String? reason,
  }) async {
    if (isActing(user.id)) return;

    try {
      actingIds.add(user.id);
      actingIds.refresh();

      await _repo.setSubscriptionStatus(
        user.id,
        status,
        _session.adminUid,
      );

      // Update the in-memory row so the list reflects the change immediately.
      applyLocalStatusUpdate(user.id, status);

      SnackbarHelper.success(
        'Updated',
        '${user.displayName} is now $status.',
      );
      await refreshCounts();

      // Refresh dashboard stats (subscription funnel, active users).
      if (Get.isRegistered<DashboardController>()) {
        DashboardController.instance.load();
      }

      // Send push notification (best-effort — must not fail the action).
      await _repo.sendSubscriptionPush(
        userId: user.id,
        status: status,
        reason: reason,
      );
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      actingIds.remove(user.id);
      actingIds.refresh();
    }
  }

  Future<void> setReceiptUploadCount(AdminUserModel user, int count) async {
    if (isActing(user.id)) return;

    try {
      actingIds.add(user.id);
      actingIds.refresh();

      await _repo.setReceiptUploadCount(user.id, count);
      applyLocalUploadCountUpdate(user.id, count);

      SnackbarHelper.success(
        'Upload Limit Updated',
        '${user.displayName}\'s upload attempts set to $count.',
      );
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      actingIds.remove(user.id);
      actingIds.refresh();
    }
  }

  /// Updates a user's subscription status in the in-memory list without a
  /// network round-trip. Called by [PaymentsController] after approve/reject
  /// so the Users screen stays in sync without a full reload.
  void applyLocalStatusUpdate(String userId, String status) {
    final idx = rows.indexWhere((r) => r.id == userId);
    if (idx == -1) return;
    rows[idx] = rows[idx].copyWith(subscriptionStatus: status);
    rows.refresh();
  }

  void applyLocalUploadCountUpdate(String userId, int count) {
    final idx = rows.indexWhere((r) => r.id == userId);
    if (idx == -1) return;
    rows[idx] = rows[idx].copyWith(receiptUploadCount: count);
    rows.refresh();
  }

  // ── Realtime ────────────────────────────────────────────────────────

  /// Listen for UPDATE events on `users` so subscription_status changes made
  /// by payments (or another admin session) propagate to this screen without
  /// a manual refresh.
  void _subscribeRealtime() {
    try {
      _channel = Supabase.instance.client
          .channel('admin_users_status')
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: 'users',
            callback: (payload) {
              final newRow = payload.newRecord;
              final userId = newRow['id']?.toString();
              if (userId == null) return;
              final newStatus = newRow['subscription_status']?.toString();
              final uploadCount =
                  (newRow['receipt_upload_count'] as num?)?.toInt();

              final idx = rows.indexWhere((r) => r.id == userId);
              if (idx != -1) {
                rows[idx] = rows[idx].copyWith(
                  subscriptionStatus: newStatus ?? rows[idx].subscriptionStatus,
                  receiptUploadCount: uploadCount ?? rows[idx].receiptUploadCount,
                );
                rows.refresh();
              }
              // Also keep counts accurate.
              refreshCounts();
            },
          )
          .subscribe();
    } catch (_) {
      // Realtime is an enhancement — a failure here must not break the screen.
    }
  }
}
