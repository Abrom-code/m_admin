import 'package:get/get.dart';
import 'package:m_admin/data/repositories/audit_log_repository.dart';
import 'package:m_admin/features/audit_log/models/admin_audit_log_model.dart';

class AuditLogController extends GetxController {
  static AuditLogController get instance => Get.find();

  final AuditLogRepository _repo = AuditLogRepository();

  final logs = <AdminAuditLogModel>[].obs;
  final isLoading = false.obs;
  final error = RxnString();

  final selectedAction = 'all'.obs;
  final startDate = Rxn<DateTime>();
  final endDate = Rxn<DateTime>();

  final currentPage = 0.obs;
  static const int pageSize = 25;
  final totalCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadLogs();
  }

  Future<void> loadLogs() async {
    try {
      isLoading.value = true;
      error.value = null;

      final count = await _repo.countAuditLogs(
        actionType: selectedAction.value,
        startDate: startDate.value,
        endDate: endDate.value,
      );
      totalCount.value = count;

      final list = await _repo.fetchAuditLogs(
        actionType: selectedAction.value,
        startDate: startDate.value,
        endDate: endDate.value,
        limit: pageSize,
        offset: currentPage.value * pageSize,
      );

      logs.assignAll(list);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void onPageChanged(int page) {
    currentPage.value = page;
    loadLogs();
  }

  void setActionFilter(String action) {
    selectedAction.value = action;
    currentPage.value = 0;
    loadLogs();
  }

  void setDateRange(DateTime? start, DateTime? end) {
    startDate.value = start;
    endDate.value = end;
    currentPage.value = 0;
    loadLogs();
  }

  void clearFilters() {
    selectedAction.value = 'all';
    startDate.value = null;
    endDate.value = null;
    currentPage.value = 0;
    loadLogs();
  }
}
