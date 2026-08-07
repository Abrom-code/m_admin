import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/users_repository.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

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

  bool isActing(String id) => actingIds.contains(id);

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  @override
  void onClose() {
    _debounce?.cancel();
    searchController.dispose();
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

  Future<void> setSubscription(AdminUserModel user, String status) async {
    if (isActing(user.id)) return;

    try {
      actingIds.add(user.id);
      actingIds.refresh();

      await _repo.setSubscriptionStatus(
        user.id,
        status,
        _session.adminUid,
      );

      final idx = rows.indexWhere((r) => r.id == user.id);
      if (idx != -1) {
        rows[idx] = user.copyWith(subscriptionStatus: status);
        rows.refresh();
      }

      SnackbarHelper.success(
        'Updated',
        '${user.displayName} is now $status.',
      );
      await refreshCounts();
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      actingIds.remove(user.id);
      actingIds.refresh();
    }
  }
}
