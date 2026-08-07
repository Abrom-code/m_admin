import 'package:get/get.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

class DashboardController extends GetxController {
  static DashboardController get instance => Get.find();

  final _repo = DashboardRepository();

  final stats = Rxn<DashboardStats>();
  final signupSeries = <DailyPoint>[].obs;
  final revenueSeries = <DailyPoint>[].obs;
  final subjectTestCounts = <SubjectTestCount>[].obs;
  final subscriptionFunnel = <FunnelPoint>[].obs;
  final streamSplit = <StreamPoint>[].obs;

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
      ]);

      stats.value = results[0] as DashboardStats;
      signupSeries.value = results[1] as List<DailyPoint>;
      revenueSeries.value = results[2] as List<DailyPoint>;
      subjectTestCounts.value = results[3] as List<SubjectTestCount>;
      subscriptionFunnel.value = results[4] as List<FunnelPoint>;
      streamSplit.value = results[5] as List<StreamPoint>;
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }
}
