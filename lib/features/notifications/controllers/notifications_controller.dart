import 'dart:async';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/notifications_repository.dart';
import 'package:m_admin/features/notifications/models/admin_notification_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class NotificationsController extends GetxController {
  static NotificationsController get instance => Get.find();

  final _repo = NotificationsRepository();

  final rows = <AdminNotificationModel>[].obs;
  final isLoading = false.obs;
  final isSending = false.obs;
  final isDeleting = false.obs;
  final errorMessage = RxnString();
  final typeFilter = RxnString();
  final page = 0.obs;
  final stats = Rxn<Map<String, int>>();
  static const pageSize = 30;

  // ── Multi-select ─────────────────────────────────────────────────
  final isSelecting = false.obs;
  final selectedIds = <int>{}.obs;

  bool get allSelected =>
      rows.isNotEmpty && selectedIds.length == rows.length;

  void enterSelectMode(int firstId) {
    selectedIds.clear();
    selectedIds.add(firstId);
    isSelecting.value = true;
  }

  void exitSelectMode() {
    isSelecting.value = false;
    selectedIds.clear();
  }

  void toggleSelection(int id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
      if (selectedIds.isEmpty) exitSelectMode();
    } else {
      selectedIds.add(id);
    }
    selectedIds.refresh();
  }

  void toggleSelectAll() {
    if (allSelected) {
      selectedIds.clear();
      exitSelectMode();
    } else {
      selectedIds.assignAll(rows.map((n) => n.id));
      isSelecting.value = true;
    }
    selectedIds.refresh();
  }

  @override
  void onInit() {
    super.onInit();
    load();
    loadStats();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      final fetched = await _repo.fetchRecent(
        page: page.value,
        pageSize: pageSize,
        typeFilter: typeFilter.value,
      );
      rows.value = fetched;
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadStats() async {
    try {
      stats.value = await _repo.getStats();
    } catch (_) {
      // Stats are non-critical — silently ignore failures
    }
  }

  void setTypeFilter(String? type) {
    typeFilter.value = type;
    page.value = 0;
    load();
  }

  void changePage(int next) {
    page.value = next;
    load();
  }

  Future<bool> send({
    required String title,
    required String body,
    required String type,
    required String audience,
  }) async {
    if (isSending.value) return false; // guard against double-tap
    try {
      isSending.value = true;
      await _repo.sendBroadcast(
        title: title,
        body: body,
        type: type,
        audience: audience,
      );
      SnackbarHelper.success('Sent', 'Notification delivered.');
      await load(); // refresh the list so the new row appears
      await loadStats(); // refresh stats
      return true;
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
      return false;
    } finally {
      isSending.value = false;
    }
  }

  Future<bool> delete(int id) async {
    try {
      await _repo.delete(id);
      rows.removeWhere((n) => n.id == id);
      selectedIds.remove(id);
      if (selectedIds.isEmpty) exitSelectMode();
      await loadStats();
      SnackbarHelper.success('Deleted', 'Notification removed.');
      return true;
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
      return false;
    }
  }

  Future<void> deleteSelected() async {
    if (selectedIds.isEmpty) return;
    final ids = selectedIds.toList();
    try {
      isDeleting.value = true;
      await _repo.deleteMany(ids);
      rows.removeWhere((n) => ids.contains(n.id));
      exitSelectMode();
      await loadStats();
      SnackbarHelper.success(
        'Deleted',
        '${ids.length} notification${ids.length == 1 ? '' : 's'} removed.',
      );
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      isDeleting.value = false;
    }
  }
}
