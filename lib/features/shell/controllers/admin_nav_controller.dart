import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/data/repositories/question_reports_repository.dart';

/// One entry in the sidebar.
class AdminNavItem {
  const AdminNavItem({
    required this.label,
    required this.icon,
    this.badgeSource,
    this.superAdminOnly = false,
  });

  final String label;
  final IconData icon;

  /// Which reactive counter, if any, drives this item's badge.
  final AdminNavBadge? badgeSource;

  final bool superAdminOnly;
}

enum AdminNavBadge { pendingPayments, unreadAlerts, reportedQuestions }

/// Page index constants for shell navigation.
abstract final class AdminNavPage {
  static const int dashboard = 0;
  static const int payments = 1;
  static const int revenue = 2;
  static const int notifications = 3;
  static const int users = 4;
  static const int content = 5;
  static const int notes = 6;
  static const int pilotExams = 7;
  static const int reportedQuestions = 8;
  static const int challenges = 9;
  static const int sessions = 10;
  static const int settings = 11;
}

/// Drives the shell's sidebar and its `IndexedStack`.
class AdminNavController extends GetxController {
  static AdminNavController get instance => Get.find();

  final selectedIndex = 0.obs;

  /// Sidebar badges.
  final pendingPaymentCount = 0.obs;
  final unreadAlertCount = 0.obs;
  final reportedQuestionCount = 0.obs;

  static const items = <AdminNavItem>[
    AdminNavItem(label: 'Dashboard', icon: Iconsax.chart_2_copy),
    AdminNavItem(
      label: 'Payments',
      icon: Iconsax.receipt_copy,
      badgeSource: AdminNavBadge.pendingPayments,
    ),
    AdminNavItem(label: 'Revenue', icon: Iconsax.wallet_3_copy),
    AdminNavItem(
      label: 'Notifications',
      icon: Iconsax.notification_copy,
      badgeSource: AdminNavBadge.unreadAlerts,
    ),
    AdminNavItem(label: 'Users', icon: Iconsax.people_copy),
    AdminNavItem(label: 'Content', icon: Iconsax.book_copy),
    AdminNavItem(label: 'Notes', icon: Iconsax.document_copy),
    AdminNavItem(label: 'Pilot Exams', icon: Iconsax.award_copy),
    AdminNavItem(
      label: 'Reported Questions',
      icon: Iconsax.flag_copy,
      badgeSource: AdminNavBadge.reportedQuestions,
    ),
    AdminNavItem(label: 'Challenges', icon: Iconsax.cup_copy),
    AdminNavItem(label: 'Sessions', icon: Iconsax.mobile_copy),
    AdminNavItem(label: 'Settings', icon: Iconsax.setting_2_copy),
  ];

  @override
  void onInit() {
    super.onInit();
    loadReportedCount();
  }

  Future<void> loadReportedCount() async {
    try {
      final c = await QuestionReportsRepository().countPendingReports();
      reportedQuestionCount.value = c;
    } catch (_) {}
  }

  void changePage(int index) {
    if (index < 0 || index >= items.length) return;
    FocusManager.instance.primaryFocus?.unfocus();
    selectedIndex.value = index;
  }

  int badgeFor(AdminNavBadge? source) {
    switch (source) {
      case AdminNavBadge.pendingPayments:
        return pendingPaymentCount.value;
      case AdminNavBadge.unreadAlerts:
        return unreadAlertCount.value;
      case AdminNavBadge.reportedQuestions:
        return reportedQuestionCount.value;
      case null:
        return 0;
    }
  }

  // ── Per-page refresh registry ────────────────────────────────────────

  final _refreshFns = <int, Future<void> Function()>{};

  /// True while the current page's async refresh is running.
  final isRefreshing = false.obs;

  /// Called by [AdminScaffold] during build to register the screen's refresh.
  void setPageRefresh(int pageIndex, Future<void> Function() fn) {
    _refreshFns[pageIndex] = fn;
  }

  /// Triggers the active page's refresh, if one is registered.
  Future<void> invokeCurrentRefresh() async {
    final fn = _refreshFns[selectedIndex.value];
    if (fn == null) return;
    if (isRefreshing.value) return;
    try {
      isRefreshing.value = true;
      await fn();
    } finally {
      isRefreshing.value = false;
    }
  }

  /// True when the active page has a registered refresh callback.
  bool get currentPageHasRefresh =>
      _refreshFns.containsKey(selectedIndex.value);
}
