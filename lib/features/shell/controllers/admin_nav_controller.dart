import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

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

enum AdminNavBadge { pendingPayments, unreadAlerts }

/// Drives the shell's sidebar and its `IndexedStack`.
///
/// An `IndexedStack` rather than a swapped child is deliberate: tab state must
/// survive switching, so a half-filled notification draft or a scrolled
/// payment queue is still there when the operator comes back.
class AdminNavController extends GetxController {
  static AdminNavController get instance => Get.find();

  final selectedIndex = 0.obs;

  /// Sidebar badges. Refreshed by the payments realtime subscription in
  /// Phase 7 rather than polled.
  final pendingPaymentCount = 0.obs;
  final unreadAlertCount = 0.obs;

  static const items = <AdminNavItem>[
    AdminNavItem(label: 'Dashboard', icon: Iconsax.chart_2_copy),
    AdminNavItem(
      label: 'Payments',
      icon: Iconsax.receipt_copy,
      badgeSource: AdminNavBadge.pendingPayments,
    ),
    AdminNavItem(
      label: 'Notifications',
      icon: Iconsax.notification_copy,
      badgeSource: AdminNavBadge.unreadAlerts,
    ),
    AdminNavItem(label: 'Users', icon: Iconsax.people_copy),
    AdminNavItem(label: 'Content', icon: Iconsax.book_copy),
    AdminNavItem(label: 'Sessions', icon: Iconsax.mobile_copy),
    AdminNavItem(label: 'Audit Log', icon: Iconsax.document_text_copy),
    AdminNavItem(label: 'Settings', icon: Iconsax.setting_2_copy),
  ];

  void changePage(int index) {
    if (index < 0 || index >= items.length) return;
    selectedIndex.value = index;
  }

  int badgeFor(AdminNavBadge? source) {
    switch (source) {
      case AdminNavBadge.pendingPayments:
        return pendingPaymentCount.value;
      case AdminNavBadge.unreadAlerts:
        return unreadAlertCount.value;
      case null:
        return 0;
    }
  }

  // ── Per-page refresh registry ────────────────────────────────────────

  final _refreshFns = <int, VoidCallback>{};

  /// Called by [AdminScaffold] during build to register the screen's refresh.
  void setPageRefresh(int pageIndex, VoidCallback fn) {
    _refreshFns[pageIndex] = fn;
  }

  /// Triggers the active page's refresh, if one is registered.
  void invokeCurrentRefresh() => _refreshFns[selectedIndex.value]?.call();

  /// True when the active page has a registered refresh callback.
  bool get currentPageHasRefresh =>
      _refreshFns.containsKey(selectedIndex.value);
}
