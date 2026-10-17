import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/data/repositories/revenue_costs_repository.dart';
import 'package:m_admin/features/revenue/models/revenue_cost_record.dart';
import 'package:m_admin/features/security/controllers/app_lock_controller.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

class RevenueController extends GetxController {
  RevenueController({
    DashboardRepository? repo,
    RevenueCostsRepository? costsRepo,
    GetStorage? storage,
    this.autoLoad = true,
  })  : _repo = repo,
        _costsRepo = costsRepo,
        _storage = storage ?? GetStorage();

  static RevenueController get instance => Get.find();

  static const _priceHiddenKey = 'dashboard_price_hidden';
  final GetStorage _storage;
  final DashboardRepository? _repo;
  final RevenueCostsRepository? _costsRepo;
  final bool autoLoad;

  DashboardRepository get repo => _repo ?? DashboardRepository();
  RevenueCostsRepository get costsRepo => _costsRepo ?? RevenueCostsRepository();

  final revenueSeries = <DailyPoint>[].obs;
  final totalRevenueAllTime = 0.0.obs;

  // ── Privacy & Visibility ──────────────────────────────────────────
  final isPriceHidden = true.obs;

  void togglePriceVisibility() {
    isPriceHidden.value = !isPriceHidden.value;
    _storage.write(_priceHiddenKey, isPriceHidden.value);
  }

  // ── PIN & Page Lock ───────────────────────────────────────────────
  final isRevenueLocked = true.obs;

  void lockRevenue() {
    isRevenueLocked.value = true;
  }

  void unlockRevenue() {
    isRevenueLocked.value = false;
  }

  void _syncLockState() {
    final hasPasscode = Get.isRegistered<AppLockController>() &&
        AppLockController.instance.isPasscodeEnabled.value;
    isRevenueLocked.value = hasPasscode;
  }

  // ── Filters & Controls ───────────────────────────────────────────
  final isLoading = false.obs;
  final isChartLoading = false.obs;
  final errorMessage = RxnString();
  final rangeDays = 30.obs;
  final customDateRange = Rxn<DateTimeRange>();
  final selectedMethodFilter = RxnString();

  // ── Chart View Mode ('net' vs 'gross') ────────────────────────────
  final chartViewMode = 'net'.obs; // 'net' (decreased by costs) or 'gross'

  void setChartViewMode(String mode) {
    chartViewMode.value = mode;
  }

  // ── Promotion & Operational Costs / Deductions ───────────────────
  final costRecords = <RevenueCostRecord>[].obs;
  final isCostsLoading = false.obs;
  final costFilterMode = 'period'.obs; // 'period' or 'all'

  void setCostFilterMode(String mode) {
    costFilterMode.value = mode;
  }

  // ── Time Comparison Feature ──────────────────────────────────────
  final isCompareEnabled = false.obs;
  final compareOption = 'previous'.obs; // 'previous', '7d', '14d', '30d', '90d', 'custom'
  final comparisonCustomRange = Rxn<DateTimeRange>();
  final comparisonSeries = <DailyPoint>[].obs;
  final isComparisonLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    final saved = _storage.read<bool>(_priceHiddenKey);
    if (saved != null) {
      isPriceHidden.value = saved;
    }

    _syncLockState();

    if (Get.isRegistered<AppLockController>()) {
      ever(AppLockController.instance.isPasscodeEnabled, (_) => _syncLockState());
    }

    if (Get.isRegistered<AdminNavController>()) {
      ever(AdminNavController.instance.selectedIndex, (index) {
        if (index != AdminNavPage.revenue &&
            Get.isRegistered<AppLockController>() &&
            AppLockController.instance.isPasscodeEnabled.value) {
          isRevenueLocked.value = true;
        }
      });
    }

    if (autoLoad) {
      load();
      loadCosts();
    }
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

  // ── Costs CRUD & Synchronization ─────────────────────────────────

  Future<void> loadCosts() async {
    try {
      isCostsLoading.value = true;
      final list = await costsRepo.loadCosts();
      costRecords.value = list;
    } catch (_) {
      // Fallback already handled in repo
    } finally {
      isCostsLoading.value = false;
    }
  }

  Future<void> addCostRecord({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? notes,
  }) async {
    final record = RevenueCostRecord(
      id: '${DateTime.now().millisecondsSinceEpoch}_${math.Random().nextInt(9999)}',
      title: title.trim(),
      amount: amount,
      category: category,
      date: date,
      notes: notes?.trim().isEmpty == true ? null : notes?.trim(),
      createdAt: DateTime.now(),
    );

    costRecords.insert(0, record);
    costRecords.sort((a, b) => b.date.compareTo(a.date));
    await costsRepo.saveCosts(costRecords);
  }

  Future<void> updateCostRecord(RevenueCostRecord updated) async {
    final idx = costRecords.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      costRecords[idx] = updated;
      costRecords.sort((a, b) => b.date.compareTo(a.date));
      await costsRepo.saveCosts(costRecords);
    }
  }

  Future<void> deleteCostRecord(String id) async {
    costRecords.removeWhere((c) => c.id == id);
    await costsRepo.saveCosts(costRecords);
  }

  // ── Cost Computations ─────────────────────────────────────────────

  /// Returns total costs incurred on a specific calendar day.
  double getCostForDay(DateTime day) {
    double total = 0.0;
    for (final cost in costRecords) {
      if (cost.date.year == day.year &&
          cost.date.month == day.month &&
          cost.date.day == day.day) {
        total += cost.amount;
      }
    }
    return total;
  }

  /// Returns total costs incurred within a given date range.
  double getTotalCostsForRange(DateTime start, DateTime end) {
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
    double total = 0.0;
    for (final cost in costRecords) {
      if (!cost.date.isBefore(startDay) && !cost.date.isAfter(endDay)) {
        total += cost.amount;
      }
    }
    return total;
  }

  /// List of costs within the currently active primary date range.
  List<RevenueCostRecord> get periodCostRecords {
    final range = getPrimaryDateRange();
    final startDay = DateTime(range.start.year, range.start.month, range.start.day);
    final endDay = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59, 999);
    return costRecords.where((c) {
      return !c.date.isBefore(startDay) && !c.date.isAfter(endDay);
    }).toList();
  }

  /// List of costs to display based on [costFilterMode].
  List<RevenueCostRecord> get displayedCostRecords {
    if (costFilterMode.value == 'all') {
      return costRecords;
    }
    return periodCostRecords;
  }

  /// Total promotional & operational costs in the primary period.
  double get primaryTotalCosts {
    final range = getPrimaryDateRange();
    return getTotalCostsForRange(range.start, range.end);
  }

  /// Net revenue in the primary period (Gross Revenue - Costs).
  double get primaryNetRevenue => primaryTotal - primaryTotalCosts;

  /// Net profit margin percentage for the primary period.
  double get primaryProfitMargin {
    final gross = primaryTotal;
    if (gross <= 0) return primaryNetRevenue >= 0 ? 0.0 : -100.0;
    return (primaryNetRevenue / gross) * 100.0;
  }

  /// Total promotional & operational costs all-time.
  double get allTimeTotalCosts =>
      costRecords.fold(0.0, (sum, c) => sum + c.amount);

  /// Net revenue all-time (All-Time Gross Revenue - All-Time Costs).
  double get allTimeNetRevenue =>
      totalRevenueAllTime.value - allTimeTotalCosts;

  /// All-time net profit margin percentage.
  double get allTimeProfitMargin {
    final gross = totalRevenueAllTime.value;
    if (gross <= 0) return allTimeNetRevenue >= 0 ? 0.0 : -100.0;
    return (allTimeNetRevenue / gross) * 100.0;
  }

  /// Series to render on chart based on [chartViewMode]:
  /// If 'net', values are decreased by each day's promotion/costs.
  List<DailyPoint> get effectiveRevenueSeries {
    if (chartViewMode.value == 'gross') {
      return revenueSeries;
    }
    return revenueSeries.map((p) {
      final dayCost = getCostForDay(p.day);
      final net = p.value - dayCost;
      return DailyPoint(
        day: p.day,
        value: net,
        methodBreakdown: p.methodBreakdown,
      );
    }).toList();
  }

  // ── Time Length Comparison Controls ──────────────────────────────
  DateTimeRange getPrimaryDateRange() {
    if (customDateRange.value != null) {
      return customDateRange.value!;
    }
    final now = DateTime.now();
    final d = rangeDays.value;
    final start = now.subtract(Duration(days: d - 1));
    return DateTimeRange(
      start: DateTime(start.year, start.month, start.day),
      end: DateTime(now.year, now.month, now.day, 23, 59, 59),
    );
  }

  DateTimeRange getComparisonDateRange() {
    if (compareOption.value == 'custom' &&
        comparisonCustomRange.value != null) {
      return comparisonCustomRange.value!;
    }

    final primary = getPrimaryDateRange();
    final primaryDays = primary.end.difference(primary.start).inDays + 1;

    if (compareOption.value == 'previous') {
      final compEnd = primary.start.subtract(const Duration(days: 1));
      final compStart = compEnd.subtract(Duration(days: primaryDays - 1));
      return DateTimeRange(
        start: DateTime(compStart.year, compStart.month, compStart.day),
        end: DateTime(compEnd.year, compEnd.month, compEnd.day, 23, 59, 59),
      );
    }

    int days = 30;
    if (compareOption.value == '7d') days = 7;
    if (compareOption.value == '14d') days = 14;
    if (compareOption.value == '30d') days = 30;
    if (compareOption.value == '90d') days = 90;

    final compEnd = primary.start.subtract(const Duration(days: 1));
    final compStart = compEnd.subtract(Duration(days: days - 1));
    return DateTimeRange(
      start: DateTime(compStart.year, compStart.month, compStart.day),
      end: DateTime(compEnd.year, compEnd.month, compEnd.day, 23, 59, 59),
    );
  }

  void toggleCompare() {
    isCompareEnabled.value = !isCompareEnabled.value;
    if (isCompareEnabled.value) {
      fetchComparisonSeries();
    } else {
      comparisonSeries.clear();
    }
  }

  void setCompareOption(String option) {
    compareOption.value = option;
    isCompareEnabled.value = true;
    fetchComparisonSeries();
  }

  void setComparisonCustomRange(DateTimeRange range) {
    comparisonCustomRange.value = range;
    compareOption.value = 'custom';
    isCompareEnabled.value = true;
    fetchComparisonSeries();
  }

  // ── Comparative Metrics ──────────────────────────────────────────
  double get primaryTotal =>
      revenueSeries.fold(0.0, (sum, p) => sum + p.value);

  double get comparisonTotal =>
      comparisonSeries.fold(0.0, (sum, p) => sum + p.value);

  double get comparisonTotalCosts {
    final range = getComparisonDateRange();
    return getTotalCostsForRange(range.start, range.end);
  }

  double get comparisonNetRevenue => comparisonTotal - comparisonTotalCosts;

  double get revenueGrowthPercentage {
    final comp = comparisonTotal;
    final prim = primaryTotal;
    if (comp <= 0) return prim > 0 ? 100.0 : 0.0;
    return ((prim - comp) / comp) * 100.0;
  }

  double get revenueGrowthAbsolute => primaryTotal - comparisonTotal;

  double get netRevenueGrowthPercentage {
    final comp = comparisonNetRevenue;
    final prim = primaryNetRevenue;
    if (comp <= 0) return prim > 0 ? 100.0 : 0.0;
    return ((prim - comp) / comp) * 100.0;
  }

  double get netRevenueGrowthAbsolute => primaryNetRevenue - comparisonNetRevenue;

  double get primaryDailyAverage {
    final count = revenueSeries.length;
    return count > 0 ? primaryTotal / count : 0.0;
  }

  double get primaryDailyNetAverage {
    final count = revenueSeries.length;
    return count > 0 ? primaryNetRevenue / count : 0.0;
  }

  double get comparisonDailyAverage {
    final count = comparisonSeries.length;
    return count > 0 ? comparisonTotal / count : 0.0;
  }

  double get averageGrowthPercentage {
    final comp = comparisonDailyAverage;
    final prim = primaryDailyAverage;
    if (comp <= 0) return prim > 0 ? 100.0 : 0.0;
    return ((prim - comp) / comp) * 100.0;
  }

  double get primaryPeak => revenueSeries.isEmpty
      ? 0.0
      : revenueSeries.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  double get comparisonPeak => comparisonSeries.isEmpty
      ? 0.0
      : comparisonSeries.map((p) => p.value).reduce((a, b) => a > b ? a : b);

  List<DailyPoint> get effectiveComparisonSeries {
    if (chartViewMode.value == 'gross') {
      return comparisonSeries;
    }
    return comparisonSeries.map((p) {
      final dayCost = getCostForDay(p.day);
      final net = p.value - dayCost;
      return DailyPoint(
        day: p.day,
        value: net,
        methodBreakdown: p.methodBreakdown,
      );
    }).toList();
  }

  Future<void> fetchComparisonSeries() async {
    if (!isCompareEnabled.value) {
      comparisonSeries.clear();
      return;
    }
    try {
      isComparisonLoading.value = true;
      final range = getComparisonDateRange();
      final points = await repo.fetchRevenueDaily(
        null,
        range.start,
        range.end,
        selectedMethodFilter.value,
      );
      comparisonSeries.value = points;
    } catch (_) {
      comparisonSeries.clear();
    } finally {
      isComparisonLoading.value = false;
    }
  }

  Future<void> reloadChartSeries() async {
    try {
      isChartLoading.value = true;
      final range = customDateRange.value;
      final Future<List<DailyPoint>> primaryFuture = range != null
          ? repo.fetchRevenueDaily(
              null,
              range.start,
              range.end,
              selectedMethodFilter.value,
            )
          : repo.fetchRevenueDaily(
              rangeDays.value,
              null,
              null,
              selectedMethodFilter.value,
            );

      final compFuture =
          isCompareEnabled.value ? fetchComparisonSeries() : Future.value();

      final results = await Future.wait([primaryFuture, compFuture]);
      revenueSeries.value = results[0] as List<DailyPoint>;
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
      final Future<List<DailyPoint>> revenueFuture = range != null
          ? repo.fetchRevenueDaily(
              null,
              range.start,
              range.end,
              selectedMethodFilter.value,
            )
          : repo.fetchRevenueDaily(
              rangeDays.value,
              null,
              null,
              selectedMethodFilter.value,
            );

      final compFuture =
          isCompareEnabled.value ? fetchComparisonSeries() : Future.value();

      final results = await Future.wait([
        repo.fetchStats(),
        revenueFuture,
        compFuture,
      ]);

      final stats = results[0] as DashboardStats;
      totalRevenueAllTime.value = stats.totalRevenue;
      revenueSeries.value = results[1] as List<DailyPoint>;
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
      isChartLoading.value = false;
    }
  }
}
