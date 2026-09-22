import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/question_reports_repository.dart';
import 'package:m_admin/features/content/models/question_report_admin_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/toast_helper.dart';

class QuestionReportsController extends GetxController {
  final QuestionReportsRepository _repo = QuestionReportsRepository();

  final reports = <QuestionReportAdminModel>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();

  final selectedStatus = 'pending'.obs; // 'pending' | 'resolved' | 'dismissed' | 'all'
  final selectedReason = RxnString();
  final pendingCount = 0.obs;

  final searchController = TextEditingController();

  @override
  void onInit() {
    super.onInit();
    loadReports();
    loadPendingCount();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadPendingCount() async {
    try {
      final count = await _repo.countPendingReports();
      pendingCount.value = count;
    } catch (_) {}
  }

  Future<void> loadReports() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      final statusArg = selectedStatus.value == 'all' ? null : selectedStatus.value;
      final result = await _repo.fetchReports(
        status: statusArg,
        reason: selectedReason.value,
        search: searchController.text.trim(),
      );

      reports.value = result;
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  void changeStatusFilter(String status) {
    if (selectedStatus.value == status) return;
    selectedStatus.value = status;
    loadReports();
  }

  void changeReasonFilter(String? reason) {
    if (selectedReason.value == reason) return;
    selectedReason.value = reason;
    loadReports();
  }

  void onSearchChanged(String _) {
    loadReports();
  }

  Future<void> resolveReport(QuestionReportAdminModel report, {String? notes}) async {
    try {
      await _repo.updateStatus(report.id, status: 'resolved', adminNotes: notes);
      ToastHelper.success('Report marked as resolved');
      loadPendingCount();
      loadReports();
    } catch (e) {
      ToastHelper.error(AppExceptionHandler.handle(e).message);
    }
  }

  Future<void> dismissReport(QuestionReportAdminModel report, {String? notes}) async {
    try {
      await _repo.updateStatus(report.id, status: 'dismissed', adminNotes: notes);
      ToastHelper.info('Report dismissed');
      loadPendingCount();
      loadReports();
    } catch (e) {
      ToastHelper.error(AppExceptionHandler.handle(e).message);
    }
  }
}
