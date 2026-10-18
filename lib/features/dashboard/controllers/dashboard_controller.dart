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

  static const _activeHiddenKey = 'dashboard_active_hidden';
  final _storage = GetStorage();

  final _repo = DashboardRepository();
  final _reportsRepo = QuestionReportsRepository();

  final stats = Rxn<DashboardStats>();
  final signupSeries = <DailyPoint>[].obs;
  final subjectTestCounts = <SubjectTestCount>[].obs;
  final subscriptionFunnel = <FunnelPoint>[].obs;
  final streamSplit = <StreamPoint>[].obs;

  int get naturalStudentsCount => streamSplit
      .firstWhereOrNull((s) => s.stream.toLowerCase() == 'natural')
      ?.count ?? 0;

  int get socialStudentsCount => streamSplit
      .firstWhereOrNull((s) => s.stream.toLowerCase() == 'social')
      ?.count ?? 0;

  // Question Reports & Notes Section
  final questionReportGroups = <QuestionReportGroupModel>[].obs;
  final pendingQuestionReportsCount = 0.obs;
  final noteReviewersCount = 0.obs;
  final noteReviewsCount = 0.obs;
  final isReportsLoading = false.obs;

  // ── Sensitive KPI Visibility Toggles ─────────────────────────────
  final isActiveHidden = true.obs;

  void toggleActiveVisibility() {
    isActiveHidden.value = !isActiveHidden.value;
    _storage.write(_activeHiddenKey, isActiveHidden.value);
  }

  // ── Chart Controls ───────────────────────────────────────────────
  final isLoading = false.obs;
  final isChartLoading = false.obs;
  final errorMessage = RxnString();
  final rangeDays = 30.obs;
  final customDateRange = Rxn<DateTimeRange>();

  // ── 12-Hour Format Hourly Signups ──────────────────────────────
  final hourlySignups = <HourlySignupPoint>[].obs;
  final hourlyFilter = 'today'.obs; // 'today', '7d', '30d', '90d'
  final isHourlyLoading = false.obs;

  int get hourlyTotalSignups =>
      hourlySignups.fold<int>(0, (sum, p) => sum + p.count);

  HourlySignupPoint? get hourlyPeakHour {
    if (hourlySignups.isEmpty) return null;
    final maxP = hourlySignups.reduce((a, b) => a.count >= b.count ? a : b);
    return maxP.count > 0 ? maxP : null;
  }

  int get hourlyAmSignups =>
      hourlySignups.where((p) => p.isAm).fold<int>(0, (sum, p) => sum + p.count);

  int get hourlyPmSignups =>
      hourlySignups.where((p) => p.isPm).fold<int>(0, (sum, p) => sum + p.count);

  Future<void> setHourlyFilter(String filter) async {
    hourlyFilter.value = filter;
    await reloadHourlySignups();
  }

  Future<void> reloadHourlySignups() async {
    try {
      isHourlyLoading.value = true;
      final points = await _repo.fetchHourlySignups(filter: hourlyFilter.value);
      hourlySignups.value = points;
    } catch (e) {
      debugPrint('[DashboardController] Error loading hourly signups: $e');
    } finally {
      isHourlyLoading.value = false;
    }
  }

  @override
  void onInit() {
    super.onInit();
    final savedActive = _storage.read<bool>(_activeHiddenKey);
    if (savedActive != null) {
      isActiveHidden.value = savedActive;
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

  Future<void> reloadChartSeries() async {
    try {
      isChartLoading.value = true;
      final range = customDateRange.value;
      final points = range != null
          ? await _repo.fetchSignupsDaily(null, range.start, range.end)
          : await _repo.fetchSignupsDaily(rangeDays.value);

      signupSeries.value = points;
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isChartLoading.value = false;
    }
  }

  final chartsLoaded = false.obs;

  Future<void> load() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      final s = await _repo.fetchStats();
      stats.value = s;

      pendingQuestionReportsCount.value = s.reportedQuestionsCount;
      noteReviewersCount.value = s.noteReviewersCount;
      noteReviewsCount.value = s.noteReviewsCount;

      // Keep the sidebar badge consistent with the KPI stat
      if (Get.isRegistered<AdminNavController>()) {
        AdminNavController.instance.pendingPaymentCount.value = s.pendingPayments;
        AdminNavController.instance.reportedQuestionCount.value = s.reportedQuestionsCount;
      }
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }

    // Lazily load chart analytics asynchronously without blocking primary UI
    ensureChartsLoaded();
  }

  Future<void> ensureChartsLoaded({bool force = false}) async {
    if (chartsLoaded.value && !force) return;
    try {
      isChartLoading.value = true;

      final range = customDateRange.value;
      final Future<List<DailyPoint>> signupsFuture = range != null
          ? _repo.fetchSignupsDaily(null, range.start, range.end)
          : _repo.fetchSignupsDaily(rangeDays.value);

      final results = await Future.wait([
        signupsFuture,
        _repo.fetchSubjectTestCounts(),
        _repo.fetchSubscriptionFunnel(),
        _repo.fetchStreamSplit(),
        _repo.fetchHourlySignups(filter: hourlyFilter.value),
      ]);

      signupSeries.value = results[0] as List<DailyPoint>;
      subjectTestCounts.value = results[1] as List<SubjectTestCount>;
      subscriptionFunnel.value = results[2] as List<FunnelPoint>;
      streamSplit.value = results[3] as List<StreamPoint>;
      hourlySignups.value = results[4] as List<HourlySignupPoint>;
      chartsLoaded.value = true;
    } catch (e) {
      debugPrint('[DashboardController] Error loading charts: $e');
    } finally {
      isChartLoading.value = false;
    }
  }

  Future<void> loadQuestionReports() async {
    try {
      isReportsLoading.value = true;
      final count = await _reportsRepo.countPendingReports();
      pendingQuestionReportsCount.value = count;
      if (Get.isRegistered<AdminNavController>()) {
        AdminNavController.instance.reportedQuestionCount.value = count;
      }
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
