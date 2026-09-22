import 'package:get/get.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/data/repositories/question_reports_repository.dart';
import 'package:m_admin/features/content/models/question_report_admin_model.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/toast_helper.dart';

class DashboardController extends GetxController {
  static DashboardController get instance => Get.find();

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

  final isLoading = false.obs;
  final errorMessage = RxnString();
  final rangeDays = 30.obs;

  @override
  void onInit() {
    super.onInit();
    load();
    ever(rangeDays, (_) => load());
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      final days = rangeDays.value;

      // Fan out all queries in parallel.
      final results = await Future.wait([
        _repo.fetchStats(),
        _repo.fetchSignupsDaily(days),
        _repo.fetchRevenueDaily(days),
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
