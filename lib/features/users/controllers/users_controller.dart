import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/users_repository.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/dashboard/controllers/dashboard_controller.dart';
import 'package:m_admin/features/users/models/admin_subscription_plan.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UsersController extends GetxController {
  static UsersController get instance => Get.find();

  final _repo = UsersRepository();
  final _session = Get.find<AdminSessionService>();

  final rows = <AdminUserModel>[].obs;
  final totalCount = 0.obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final counts = <String, int>{}.obs;
  final availableStreams = <String>[].obs;

  final searchQuery = ''.obs;
  final statusFilter = RxnString();
  final streamFilter = RxnString();
  final dateRange = Rxn<DateTimeRange>();
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
      final result = await _repo.fetchUsers(
        search: searchQuery.value,
        statusFilter: statusFilter.value,
        streamFilter: streamFilter.value,
        dateRange: dateRange.value,
        page: page.value,
        pageSize: pageSize,
      );
      rows.value = result.users;
      totalCount.value = result.totalCount;
      _deduplicateRows();
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

  void setDateRange(DateTimeRange? range) {
    dateRange.value = range;
    page.value = 0;
    load();
  }

  void clearFilters() {
    searchController.clear();
    searchQuery.value = '';
    statusFilter.value = null;
    streamFilter.value = null;
    dateRange.value = null;
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
    String? plan,
    DateTime? expiresAt,
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
        plan: plan,
        expiresAt: expiresAt,
      );

      // Update the in-memory row so the list reflects the change immediately.
      applyLocalStatusUpdate(
        user.id,
        status,
        plan: plan,
        expiresAt: expiresAt,
      );

      SnackbarHelper.success(
        'Updated',
        '${user.displayName} is now $status.',
      );
      await refreshCounts();

      // Refresh dashboard stats (subscription funnel, active users).
      if (Get.isRegistered<DashboardController>()) {
        DashboardController.instance.load();
      }

      // Build specific push notification with plan and expiration timing.
      String? notifTitle;
      String? notifBody;
      if (status == 'active' && expiresAt != null) {
        notifTitle = AdminSubscriptionPlan.buildGrantNotificationTitle(
          plan,
          expiresAt: expiresAt,
        );
        notifBody = AdminSubscriptionPlan.buildGrantNotificationBody(
          planKey: plan,
          expiresAt: expiresAt,
        );
      }

      // Send push notification only for activation (not revocation).
      // Revocation is handled silently via Supabase DB update only.
      if (status == 'active' && notifTitle != null && notifBody != null) {
        await _repo.sendSubscriptionPush(
          userId: user.id,
          status: status,
          title: notifTitle,
          body: notifBody,
          reason: reason,
        );
      }
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
        '\'s upload attempts set to .',
      );
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      actingIds.remove(user.id);
      actingIds.refresh();
    }
  }

  /// Permanently deletes a user from auth and public tables.
  Future<bool> deleteUser(AdminUserModel user, {String? reason}) async {
    if (isActing(user.id)) return false;

    try {
      actingIds.add(user.id);
      actingIds.refresh();

      await _repo.deleteUserPermanently(
        user.id,
        _session.adminUid,
        userEmail: user.email,
        reason: reason,
      );

      // Remove from in-memory row list (including any duplicate email rows)
      rows.removeWhere((r) =>
          r.id == user.id ||
          (user.email.isNotEmpty &&
              r.email.trim().toLowerCase() == user.email.trim().toLowerCase()));
      rows.refresh();

      await refreshCounts();

      // Refresh dashboard if registered
      if (Get.isRegistered<DashboardController>()) {
        DashboardController.instance.load();
      }

      SnackbarHelper.success(
        'User Deleted',
        '${user.displayName} has been permanently deleted.',
      );
      return true;
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
      return false;
    } finally {
      actingIds.remove(user.id);
      actingIds.refresh();
    }
  }

  /// Updates a user's subscription status in the in-memory list without a
  /// network round-trip.
  void applyLocalStatusUpdate(
    String userId,
    String status, {
    String? plan,
    DateTime? expiresAt,
  }) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].id == userId) {
        rows[i] = rows[i].copyWith(
          subscriptionStatus: status,
          subscriptionPlan: status == 'inactive' ? null : (plan ?? rows[i].subscriptionPlan),
          subscriptionExpiresAt: status == 'inactive' ? null : (expiresAt ?? rows[i].subscriptionExpiresAt),
        );
      }
    }
    _deduplicateRows();
    rows.refresh();
  }

  void applyLocalUploadCountUpdate(String userId, int count) {
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].id == userId) {
        rows[i] = rows[i].copyWith(receiptUploadCount: count);
      }
    }
    _deduplicateRows();
    rows.refresh();
  }

  void _deduplicateRows() {
    final seenEmails = <String, AdminUserModel>{};
    final unique = <AdminUserModel>[];

    for (final user in rows) {
      final cleanEmail = user.email.trim().toLowerCase();
      if (cleanEmail.isEmpty) {
        unique.add(user);
        continue;
      }

      if (seenEmails.containsKey(cleanEmail)) {
        final existing = seenEmails[cleanEmail]!;
        // Prefer active subscription status or newest record
        final preferred = (user.isActive && !existing.isActive) ? user : existing;
        seenEmails[cleanEmail] = preferred;
        final idx = unique.indexWhere((u) => u.email.trim().toLowerCase() == cleanEmail);
        if (idx != -1) {
          unique[idx] = preferred;
        }
      } else {
        seenEmails[cleanEmail] = user;
        unique.add(user);
      }
    }

    rows.assignAll(unique);
  }

  // ── Realtime ────────────────────────────────────────────────────────

  void _subscribeRealtime() {
    try {
      _channel = Supabase.instance.client
          .channel('admin_users_status')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'users',
            callback: (payload) {
              if (payload.eventType == PostgresChangeEvent.delete) {
                final oldId = payload.oldRecord['id']?.toString();
                if (oldId != null) {
                  rows.removeWhere((r) => r.id == oldId);
                  rows.refresh();
                  refreshCounts();
                }
                return;
              }

              final newRow = payload.newRecord;
              final userId = newRow['id']?.toString();
              if (userId == null) return;

              final updatedUser =
                  AdminUserModel.fromJson(Map<String, dynamic>.from(newRow));
              final cleanEmail = updatedUser.email.trim().toLowerCase();

              final currentStream = streamFilter.value;
              final currentStatus = statusFilter.value;

              final matchesStream = currentStream == null ||
                  currentStream.isEmpty ||
                  updatedUser.stream.toLowerCase() ==
                      currentStream.toLowerCase();
              final matchesStatus = currentStatus == null ||
                  currentStatus.isEmpty ||
                  updatedUser.subscriptionStatus == currentStatus;

              // Find by matching user ID or matching email
              final idx = rows.indexWhere(
                (r) =>
                    r.id == userId ||
                    (cleanEmail.isNotEmpty &&
                        r.email.trim().toLowerCase() == cleanEmail),
              );

              if (idx != -1) {
                if (matchesStream && matchesStatus) {
                  rows[idx] = updatedUser;
                } else {
                  rows.removeAt(idx);
                }
              } else if (matchesStream && matchesStatus && page.value == 0) {
                rows.insert(0, updatedUser);
              }

              _deduplicateRows();
              rows.refresh();
              refreshCounts();
              loadStreams();
            },
          )
          .subscribe();
    } catch (_) {
    }
  }
}
