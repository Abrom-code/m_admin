import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
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
  final isActionLoading = false.obs;
  final errorMessage = RxnString();

  final selectedStatus = 'pending'.obs; // 'pending' | 'resolved' | 'dismissed' | 'all'
  final selectedReason = RxnString();
  final sortBy = 'count_desc'.obs; // 'count_desc' (Most Reported) | 'date_desc' (Newest) | 'date_asc' (Oldest)
  final viewMode = 'grouped'.obs; // 'grouped' | 'list'
  final pendingCount = 0.obs;

  final searchController = TextEditingController();

  List<QuestionReportGroupModel> get groupedReports =>
      QuestionReportGroupModel.groupReports(reports, sortBy: sortBy.value);

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
      if (Get.isRegistered<AdminNavController>()) {
        AdminNavController.instance.reportedQuestionCount.value = count;
      }
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
        pageSize: 100,
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

  void changeSortBy(String sort) {
    sortBy.value = sort;
  }

  void toggleViewMode() {
    viewMode.value = viewMode.value == 'grouped' ? 'list' : 'grouped';
  }

  void onSearchChanged(String _) {
    loadReports();
  }

  /// Permanently removes the report from the database when fixed
  Future<void> fixAndRemoveReport(QuestionReportAdminModel report) async {
    try {
      isActionLoading.value = true;
      await _repo.deleteReport(report.id);
      reports.removeWhere((r) => r.id == report.id);
      loadPendingCount();
      ToastHelper.success('Report fixed and removed from database');
    } catch (e) {
      ToastHelper.error(AppExceptionHandler.handle(e).message);
    } finally {
      isActionLoading.value = false;
    }
  }

  /// Permanently removes all reports associated with this question from the database
  Future<void> fixAndRemoveQuestionGroup(QuestionReportGroupModel group) async {
    try {
      isActionLoading.value = true;
      final count = group.reportCount;
      if (group.questionId != null) {
        await _repo.deleteReportsForQuestion(questionId: group.questionId);
        reports.removeWhere((r) => r.questionId == group.questionId);
      } else if (group.challengeQuestionId != null) {
        await _repo.deleteReportsForQuestion(challengeQuestionId: group.challengeQuestionId);
        reports.removeWhere((r) => r.challengeQuestionId == group.challengeQuestionId);
      } else {
        for (final r in group.reports) {
          await _repo.deleteReport(r.id);
        }
        reports.removeWhere((r) => group.reports.any((gr) => gr.id == r.id));
      }
      loadPendingCount();
      ToastHelper.success('Question fixed! $count report(s) removed from database');
    } catch (e) {
      ToastHelper.error(AppExceptionHandler.handle(e).message);
    } finally {
      isActionLoading.value = false;
    }
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
