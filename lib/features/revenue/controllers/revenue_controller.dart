import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

class RevenueController extends GetxController {
  static RevenueController get instance => Get.find();

  static const _priceHiddenKey = 'dashboard_price_hidden';
  final _storage = GetStorage();
  final _repo = DashboardRepository();

  final revenueSeries = <DailyPoint>[].obs;
  final totalRevenueAllTime = 0.0.obs;

  // ── Privacy & Visibility ──────────────────────────────────────────
  final isPriceHidden = true.obs;

  void togglePriceVisibility() {
    isPriceHidden.value = !isPriceHidden.value;
    _storage.write(_priceHiddenKey, isPriceHidden.value);
  }

  // ── Filters & Controls ───────────────────────────────────────────
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
      final points = range != null
          ? await _repo.fetchRevenueDaily(
              null,
              range.start,
              range.end,
              selectedMethodFilter.value,
            )
          : await _repo.fetchRevenueDaily(
              rangeDays.value,
              null,
              null,
              selectedMethodFilter.value,
            );
      revenueSeries.value = points;
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
          ? _repo.fetchRevenueDaily(
              null,
              range.start,
              range.end,
              selectedMethodFilter.value,
            )
          : _repo.fetchRevenueDaily(
              rangeDays.value,
              null,
              null,
              selectedMethodFilter.value,
            );

      final results = await Future.wait([
        _repo.fetchStats(),
        revenueFuture,
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
