import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/data/repositories/question_reports_repository.dart';
import 'package:m_admin/features/content/models/question_report_admin_model.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/toast_helper.dart';

class DashboardController extends GetxController {
  static DashboardController get instance => Get.find();

  static const _priceHiddenKey = 'dashboard_price_hidden';
  final _storage = GetStorage();

  final _repo = DashboardRepository();
  final _reportsRepo = QuestionReportsRepository();

  final stats = Rxn<DashboardStats>();
  final signupSeries = <DailyPoint>[].obs;
  final revenueSeries = <DailyPoint>[].obs;
  final subjectTestCounts = <SubjectTestCount>[].obs;
  final subscriptionFunnel = <FunnelPoint>[].obs;
  final streamSplit = <StreamPoint>[].obs;

  // Question Reports Section
  final questionReportGroups = <QuestionReportGroupModel>[].obs;
  final pendingQuestionReportsCount = 0.obs;
  final isReportsLoading = false.obs;

  // ── Sensitive KPI Visibility Toggles ─────────────────────────────
  final isActiveHidden = false.obs;
  final isPriceHidden = true.obs;

  void toggleActiveVisibility() => isActiveHidden.value = !isActiveHidden.value;
  void togglePriceVisibility() {
    isPriceHidden.value = !isPriceHidden.value;
    _storage.write(_priceHiddenKey, isPriceHidden.value);
  }

  // ── Chart Controls ───────────────────────────────────────────────
  final isLoading = false.obs;
  final isChartLoading = false.obs;
  final errorMessage = RxnString();
  final rangeDays = 30.obs;
  final customDateRange = Rxn<DateTimeRange>();
  final selectedMethodFilter = RxnString();

  @override
  void onInit() {
    super.onInit();
    final saved = _storage.read<bool>(_priceHiddenKey);
    if (saved != null) {
      isPriceHidden.value = saved;
    }
    load();
  }

  void setPresetDays(int days) {
    customDateRange.value = null;
    rangeDays.value = days;
    reloadChartSeries();
  }

  void setCustomDateRange(DateTimeRange range) {
    customDateRange.value = range;
    final diff = range.end.difference(range.start).inDays + 1;
    rangeDays.value = diff;
    reloadChartSeries();
  }

  void setMethodFilter(String? method) {
    if (selectedMethodFilter.value == method) return;
    selectedMethodFilter.value = method;
    reloadChartSeries();
  }

  Future<void> reloadChartSeries() async {
    try {
      isChartLoading.value = true;
      final range = customDateRange.value;
      final Future<List<DailyPoint>> signupsFuture = range != null
          ? _repo.fetchSignupsDaily(null, range.start, range.end)
          : _repo.fetchSignupsDaily(rangeDays.value);

      final Future<List<DailyPoint>> revenueFuture = range != null
          ? _repo.fetchRevenueDaily(null, range.start, range.end, selectedMethodFilter.value)
          : _repo.fetchRevenueDaily(rangeDays.value, null, null, selectedMethodFilter.value);

      final results = await Future.wait([signupsFuture, revenueFuture]);
      signupSeries.value = results[0];
      revenueSeries.value = results[1];
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isChartLoading.value = false;
    }
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      isChartLoading.value = true;
      errorMessage.value = null;

      final range = customDateRange.value;
      final Future<List<DailyPoint>> signupsFuture = range != null
          ? _repo.fetchSignupsDaily(null, range.start, range.end)
          : _repo.fetchSignupsDaily(rangeDays.value);

      final Future<List<DailyPoint>> revenueFuture = range != null
          ? _repo.fetchRevenueDaily(null, range.start, range.end, selectedMethodFilter.value)
          : _repo.fetchRevenueDaily(rangeDays.value, null, null, selectedMethodFilter.value);

      // Fan out all queries in parallel.
      final results = await Future.wait([
        _repo.fetchStats(),
        signupsFuture,
        revenueFuture,
        _repo.fetchSubjectTestCounts(),
        _repo.fetchSubscriptionFunnel(),
        _repo.fetchStreamSplit(),
        loadQuestionReports(),
      ]);

      stats.value = results[0] as DashboardStats;
      signupSeries.value = results[1] as List<DailyPoint>;
      revenueSeries.value = results[2] as List<DailyPoint>;
      subjectTestCounts.value = results[3] as List<SubjectTestCount>;
      subscriptionFunnel.value = results[4] as List<FunnelPoint>;
      streamSplit.value = results[5] as List<StreamPoint>;

      // Keep the sidebar badge consistent with the KPI stat so they always
      // show the same number regardless of which refreshed last.
      final pending = stats.value?.pendingPayments ?? 0;
      if (Get.isRegistered<AdminNavController>()) {
        AdminNavController.instance.pendingPaymentCount.value = pending;
      }
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
      isChartLoading.value = false;
    }
  }

  Future<void> loadQuestionReports() async {
    try {
      isReportsLoading.value = true;
      final raw = await _reportsRepo.fetchReports(status: 'pending', pageSize: 50);
      final groups = QuestionReportGroupModel.groupReports(raw, sortBy: 'count_desc');
      questionReportGroups.value = groups;
      pendingQuestionReportsCount.value = await _reportsRepo.countPendingReports();
    } catch (_) {
      // Non-blocking for general dashboard stats
    } finally {
      isReportsLoading.value = false;
    }
  }

  /// Permanently deletes all reports for the question from the database when fixed
  Future<void> fixAndRemoveQuestionGroup(QuestionReportGroupModel group) async {
    try {
      final count = group.reportCount;
      if (group.questionId != null) {
        await _reportsRepo.deleteReportsForQuestion(questionId: group.questionId);
        questionReportGroups.removeWhere((g) => g.questionId == group.questionId);
      } else if (group.challengeQuestionId != null) {
        await _reportsRepo.deleteReportsForQuestion(challengeQuestionId: group.challengeQuestionId);
        questionReportGroups.removeWhere((g) => g.challengeQuestionId == group.challengeQuestionId);
      } else {
        for (final r in group.reports) {
          await _reportsRepo.deleteReport(r.id);
        }
        questionReportGroups.removeWhere((g) => g.targetKey == group.targetKey);
      }
      pendingQuestionReportsCount.value = await _reportsRepo.countPendingReports();
      ToastHelper.success('Question fixed! $count report(s) removed from database');
    } catch (e) {
      ToastHelper.error(AppExceptionHandler.handle(e).message);
    }
  }
}
