import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

// ── Filter Enum ──────────────────────────────────────────────────────

enum SessionFilter {
  all,
  locked,
  readyToPair,
  blockedAuth,
}

enum DeviceRecentStatus {
  blocked,    // User attempted login on unauthorized device (reset requested)
  reset,      // Admin reset device lock, awaiting student to pair new phone
  connected,  // User device is bound and connected
  ready,      // Fresh account, ready to pair first device
}

// ── Model ────────────────────────────────────────────────────────────

class SessionRow {
  const SessionRow({
    required this.userId,
    this.userName,
    this.userEmail,
    required this.deviceId,
    this.deviceModel,
    this.osVersion,
    this.lastActiveAt,
    this.updatedAt,
    this.blockedCount = 0,
    this.lastBlockedAt,
    this.lastBlockedDeviceModel,
    this.lastBlockedNote,
    this.resetCount = 0,
    this.lastResetAt,
  });

  final String userId;
  final String? userName;
  final String? userEmail;
  final String deviceId;
  final String? deviceModel;
  final String? osVersion;
  final DateTime? lastActiveAt;
  final DateTime? updatedAt;
  final int blockedCount;
  final DateTime? lastBlockedAt;
  final String? lastBlockedDeviceModel;
  final String? lastBlockedNote;
  final int resetCount;
  final DateTime? lastResetAt;

  bool get isLocked => deviceId.trim().isNotEmpty;
  bool get hasBlockedAuth => blockedCount > 0;
  String get firebaseUid => userId;

  /// Determines the latest lifecycle status of this user's device:
  /// - `blocked`: The user attempted to log in from an unauthorized phone most recently.
  /// - `reset`: Admin reset the device, and the student hasn't paired a new device yet.
  /// - `connected`: A device is actively bound and linked.
  /// - `ready`: Fresh account, ready to connect.
  DeviceRecentStatus get recentStatus {
    // 1. If currently unbound (no device locked)
    if (!isLocked) {
      if (hasBlockedAuth &&
          (lastResetAt == null ||
              (lastBlockedAt != null && lastBlockedAt!.isAfter(lastResetAt!)))) {
        return DeviceRecentStatus.blocked;
      }
      if (resetCount > 0 || lastResetAt != null) {
        return DeviceRecentStatus.reset;
      }
      return DeviceRecentStatus.ready;
    }

    // 2. Currently bound (isLocked == true):
    if (lastBlockedAt != null) {
      final resetTime = lastResetAt;
      final isBlockedAfterReset =
          resetTime == null || lastBlockedAt!.isAfter(resetTime);
      if (isBlockedAfterReset) {
        return DeviceRecentStatus.blocked;
      }
    }

    return DeviceRecentStatus.connected;
  }

  SessionRow copyWith({
    String? userId,
    String? userName,
    String? userEmail,
    String? deviceId,
    String? deviceModel,
    String? osVersion,
    DateTime? lastActiveAt,
    DateTime? updatedAt,
    int? blockedCount,
    DateTime? lastBlockedAt,
    String? lastBlockedDeviceModel,
    String? lastBlockedNote,
    int? resetCount,
    DateTime? lastResetAt,
  }) {
    return SessionRow(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      deviceId: deviceId ?? this.deviceId,
      deviceModel: deviceModel ?? this.deviceModel,
      osVersion: osVersion ?? this.osVersion,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      updatedAt: updatedAt ?? this.updatedAt,
      blockedCount: blockedCount ?? this.blockedCount,
      lastBlockedAt: lastBlockedAt ?? this.lastBlockedAt,
      lastBlockedDeviceModel: lastBlockedDeviceModel ?? this.lastBlockedDeviceModel,
      lastBlockedNote: lastBlockedNote ?? this.lastBlockedNote,
      resetCount: resetCount ?? this.resetCount,
      lastResetAt: lastResetAt ?? this.lastResetAt,
    );
  }

  factory SessionRow.fromJson(
    Map<String, dynamic> j, {
    List<Map<String, dynamic>> blockedAttempts = const [],
    int resetCount = 0,
    DateTime? lastResetAt,
  }) {
    final user = j['users'] as Map<String, dynamic>? ?? {};
    final fName = user['first_name']?.toString() ?? '';
    final lName = user['last_name']?.toString() ?? '';
    final fullName = user['full_name']?.toString() ?? '';
    final resolvedName = fullName.isNotEmpty
        ? fullName
        : ('$fName $lName'.trim().isNotEmpty ? '$fName $lName'.trim() : null);

    final latestBlocked = blockedAttempts.isNotEmpty ? blockedAttempts.first : null;

    return SessionRow(
      userId: (j['user_id'] ?? j['firebase_uid'])?.toString() ?? '',
      userName: resolvedName,
      userEmail: user['email']?.toString(),
      deviceId: j['device_id']?.toString() ?? '',
      deviceModel: j['device_model']?.toString(),
      osVersion: j['os_version']?.toString(),
      lastActiveAt: j['last_active_at'] != null ? DateTime.tryParse(j['last_active_at'].toString()) : null,
      updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at'].toString()) : null,
      blockedCount: blockedAttempts.length,
      lastBlockedAt: latestBlocked?['created_at'] != null
          ? DateTime.tryParse(latestBlocked!['created_at'].toString())
          : null,
      lastBlockedDeviceModel: latestBlocked?['device_model']?.toString(),
      lastBlockedNote: latestBlocked?['note']?.toString(),
      resetCount: resetCount,
      lastResetAt: lastResetAt,
    );
  }
}

// ── Controller ───────────────────────────────────────────────────────

class SessionsController extends GetxController {
  static SessionsController get instance => Get.find();

  final _sb = Supabase.instance.client;

  final rows = <SessionRow>[].obs;
  final allRows = <SessionRow>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final actingUids = <String>{}.obs;
  final searchQuery = ''.obs;
  final searchController = TextEditingController();
  final selectedFilter = SessionFilter.all.obs;

  final page = 0.obs;
  static const pageSize = 30;

  int get totalSessions => allRows.length;
  int get lockedCount => allRows.where((r) => r.isLocked).length;
  int get unlockedCount => allRows.where((r) => !r.isLocked).length;
  int get blockedAuthCount => allRows.where((r) => r.hasBlockedAuth).length;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      // 1. Query sessions
      final sessionData = await _sb
          .from('user_sessions')
          .select('''
            user_id, device_id, device_model, os_version, last_active_at, updated_at,
            users(first_name, last_name, full_name, email)
          ''')
          .order('updated_at', ascending: false);

      // 2. Query blocked authentication attempts from device_history
      List<Map<String, dynamic>> blockedHistory = [];
      try {
        final historyData = await _sb
            .from('device_history')
            .select('user_id, device_id, device_model, os_version, note, created_at')
            .eq('action', 'BLOCKED_ATTEMPT')
            .order('created_at', ascending: false);
        blockedHistory = List<Map<String, dynamic>>.from(historyData as List);
      } catch (e) {
        debugPrint('[SessionsController] Error fetching device_history: $e');
      }

      // 3. Query admin reset history from device_history to count resets per user and get last reset time
      final Map<String, int> resetCountByUser = {};
      final Map<String, DateTime> lastResetByUser = {};
      try {
        final resetData = await _sb
            .from('device_history')
            .select('user_id, created_at')
            .eq('action', 'ADMIN_RESET')
            .order('created_at', ascending: false);
        for (final item in (resetData as List)) {
          final uid = item['user_id']?.toString();
          if (uid != null && uid.isNotEmpty) {
            resetCountByUser[uid] = (resetCountByUser[uid] ?? 0) + 1;
            if (!lastResetByUser.containsKey(uid) && item['created_at'] != null) {
              lastResetByUser[uid] = DateTime.tryParse(item['created_at'].toString()) ?? DateTime.now();
            }
          }
        }
      } catch (e) {
        debugPrint('[SessionsController] Error fetching reset counts: $e');
      }

      // Group blocked attempts by user_id
      final Map<String, List<Map<String, dynamic>>> blockedByUser = {};
      for (final item in blockedHistory) {
        final uid = item['user_id']?.toString();
        if (uid != null && uid.isNotEmpty) {
          blockedByUser.putIfAbsent(uid, () => []).add(item);
        }
      }

      final list = (sessionData as List).map((r) {
        final rowMap = Map<String, dynamic>.from(r);
        final uid = (rowMap['user_id'] ?? rowMap['firebase_uid'])?.toString() ?? '';
        final userBlocked = blockedByUser[uid] ?? [];
        return SessionRow.fromJson(
          rowMap,
          blockedAttempts: userBlocked,
          resetCount: resetCountByUser[uid] ?? 0,
          lastResetAt: lastResetByUser[uid],
        );
      }).toList();

      // Include users with blocked attempts who might not be in active user_sessions
      final existingUids = list.map((r) => r.userId).toSet();
      final missingUids = blockedByUser.keys.where((uid) => !existingUids.contains(uid)).toList();
      if (missingUids.isNotEmpty) {
        try {
          final missingUsersData = await _sb
              .from('users')
              .select('id, first_name, last_name, full_name, email')
              .inFilter('id', missingUids);
          final missingUsersMap = {
            for (final u in (missingUsersData as List))
              u['id'].toString(): Map<String, dynamic>.from(u)
          };
          for (final uid in missingUids) {
            final u = missingUsersMap[uid] ?? {};
            final attempts = blockedByUser[uid]!;
            final latest = attempts.first;
            final fName = u['first_name']?.toString() ?? '';
            final lName = u['last_name']?.toString() ?? '';
            final fullName = u['full_name']?.toString() ?? '';
            final resolvedName = fullName.isNotEmpty
                ? fullName
                : ('$fName $lName'.trim().isNotEmpty ? '$fName $lName'.trim() : null);

            list.add(SessionRow(
              userId: uid,
              userName: resolvedName,
              userEmail: u['email']?.toString(),
              deviceId: '',
              deviceModel: null,
              osVersion: null,
              lastActiveAt: latest['created_at'] != null ? DateTime.tryParse(latest['created_at'].toString()) : null,
              updatedAt: latest['created_at'] != null ? DateTime.tryParse(latest['created_at'].toString()) : null,
              blockedCount: attempts.length,
              lastBlockedAt: latest['created_at'] != null ? DateTime.tryParse(latest['created_at'].toString()) : null,
              lastBlockedDeviceModel: latest['device_model']?.toString(),
              lastBlockedNote: latest['note']?.toString(),
              resetCount: resetCountByUser[uid] ?? 0,
              lastResetAt: lastResetByUser[uid],
            ));
          }
        } catch (e) {
          debugPrint('[SessionsController] Error fetching missing users for blocked attempts: $e');
        }
      }

      allRows.value = list;
      _applyFilterAndSearch();
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  void setFilter(SessionFilter filter) {
    if (selectedFilter.value == filter) {
      if (filter != SessionFilter.all) {
        selectedFilter.value = SessionFilter.all;
      }
    } else {
      selectedFilter.value = filter;
    }
    page.value = 0;
    _applyFilterAndSearch();
  }

  void onSearchChanged(String query) {
    searchQuery.value = query.trim().toLowerCase();
    page.value = 0;
    _applyFilterAndSearch();
  }

  void _applyFilterAndSearch() {
    final q = searchQuery.value;
    final filter = selectedFilter.value;

    rows.value = allRows.where((r) {
      final matchesFilter = switch (filter) {
        SessionFilter.all => true,
        SessionFilter.locked => r.isLocked,
        SessionFilter.readyToPair => !r.isLocked,
        SessionFilter.blockedAuth => r.hasBlockedAuth,
      };

      if (!matchesFilter) return false;

      if (q.isEmpty) return true;
      return r.userId.toLowerCase().contains(q) ||
          (r.userName?.toLowerCase().contains(q) ?? false) ||
          (r.userEmail?.toLowerCase().contains(q) ?? false) ||
          r.deviceId.toLowerCase().contains(q) ||
          (r.deviceModel?.toLowerCase().contains(q) ?? false) ||
          (r.lastBlockedDeviceModel?.toLowerCase().contains(q) ?? false) ||
          (r.lastBlockedNote?.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  List<SessionRow> get pagedRows {
    final start = page.value * pageSize;
    if (start >= rows.length) return [];
    final end = (start + pageSize).clamp(0, rows.length);
    return rows.sublist(start, end);
  }

  void changePage(int next) {
    page.value = next;
  }

  Future<void> resetDevice(SessionRow session) async {
    if (actingUids.contains(session.userId)) return;
    try {
      actingUids.add(session.userId);
      actingUids.refresh();

      final admin = _sb.auth.currentUser;
      final adminUid = admin?.email ?? admin?.id ?? 'admin';

      try {
        await _sb.rpc('admin_reset_user_device', params: {
          'p_user_id': session.userId,
          'p_admin_uid': adminUid,
          'p_reason': 'Reset device from Sessions console',
        });
      } catch (_) {
        await _sb
            .from('user_sessions')
            .update({
              'device_id': null,
              'device_model': null,
              'os_version': null,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('user_id', session.userId);
      }

      final updated = session.copyWith(
        deviceId: '',
        deviceModel: null,
        resetCount: session.resetCount + 1,
        lastResetAt: DateTime.now(),
      );

      final idxAll = allRows.indexWhere((r) => r.userId == session.userId);
      if (idxAll != -1) allRows[idxAll] = updated;

      _applyFilterAndSearch();
      SnackbarHelper.success('Device Reset', 'Device lock removed. User can pair a new phone on next login.');
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      actingUids.remove(session.userId);
      actingUids.refresh();
    }
  }

  Future<void> deleteSession(SessionRow session) async {
    if (actingUids.contains(session.userId)) return;
    try {
      actingUids.add(session.userId);
      actingUids.refresh();

      await _sb
          .from('user_sessions')
          .delete()
          .eq('user_id', session.userId);

      allRows.removeWhere((r) => r.userId == session.userId);
      _applyFilterAndSearch();
      SnackbarHelper.success('Session deleted', 'User session removed successfully.');
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      actingUids.remove(session.userId);
      actingUids.refresh();
    }
  }
}

// ── Screen ───────────────────────────────────────────────────────────

class SessionsScreen extends StatelessWidget {
  const SessionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(SessionsController());

    return AdminScaffold(
      pageIndex: AdminNavPage.sessions,
      onRefresh: controller.load,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SessionMetricRibbon(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          _SessionFilterBar(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          Expanded(child: _SessionTable(controller: controller)),
        ],
      ),
    );
  }
}

// ── 1. Session Metrics Ribbon / Filter Buttons ──────────────────────────────

class _SessionMetricRibbon extends StatelessWidget {
  const _SessionMetricRibbon({required this.controller});

  final SessionsController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Obx(() {
      final currentFilter = controller.selectedFilter.value;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _SessionMetricPill(
              label: 'Total Sessions',
              value: '${controller.totalSessions}',
              icon: Iconsax.devices_copy,
              color: AppColors.primary,
              dark: dark,
              isSelected: currentFilter == SessionFilter.all,
              onTap: () => controller.setFilter(SessionFilter.all),
            ),
            const SizedBox(width: 8),
            _SessionMetricPill(
              label: 'Locked (1 Device)',
              value: '${controller.lockedCount}',
              icon: Iconsax.shield_tick_copy,
              color: AppColors.success,
              dark: dark,
              isSelected: currentFilter == SessionFilter.locked,
              onTap: () => controller.setFilter(SessionFilter.locked),
            ),
            const SizedBox(width: 8),
            _SessionMetricPill(
              label: 'Ready to Pair',
              value: '${controller.unlockedCount}',
              icon: Icons.lock_open_rounded,
              color: AppColors.warning,
              dark: dark,
              isSelected: currentFilter == SessionFilter.readyToPair,
              onTap: () => controller.setFilter(SessionFilter.readyToPair),
            ),
            const SizedBox(width: 8),
            _SessionMetricPill(
              label: 'Blocked Auth',
              value: '${controller.blockedAuthCount}',
              icon: Icons.gpp_bad_rounded,
              color: AppColors.error,
              dark: dark,
              isSelected: currentFilter == SessionFilter.blockedAuth,
              onTap: () => controller.setFilter(SessionFilter.blockedAuth),
            ),
          ],
        ),
      );
    });
  }
}

class _SessionMetricPill extends StatelessWidget {
  const _SessionMetricPill({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.dark,
    this.isSelected = false,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool dark;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bgColor = isSelected
        ? color.withValues(alpha: dark ? 0.22 : 0.12)
        : (dark ? AppColors.darkSurface : AppColors.white);
    final borderColor = isSelected
        ? color
        : (dark ? AppColors.darkBorder : AppColors.borderPrimary);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        hoverColor: color.withValues(alpha: 0.08),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
            border: Border.all(
              color: borderColor,
              width: isSelected ? 1.6 : 1.0,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.18),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isSelected ? color : (dark ? AppColors.white : color),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? (dark ? Colors.white : color)
                      : (dark ? AppColors.white : AppColors.textPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? color : color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 2. Search & Filter Bar ─────────────────────────────────────────────────

class _SessionFilterBar extends StatelessWidget {
  const _SessionFilterBar({required this.controller});

  final SessionsController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: AppSizes.xs),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                color: dark
                    ? AppColors.darkGrey.withValues(alpha: 0.3)
                    : AppColors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
              ),
              child: TextField(
                controller: controller.searchController,
                onChanged: controller.onSearchChanged,
                onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search sessions by student, email, device, or user ID...',
                  hintStyle: TextStyle(
                    color: AppColors.textSecondary.withValues(alpha: 0.6),
                    fontSize: 12.5,
                  ),
                  prefixIcon: const Icon(
                    Iconsax.search_normal_copy,
                    size: 16,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: controller.searchController,
                    builder: (_, value, _) {
                      if (value.text.isEmpty) return const SizedBox.shrink();
                      return IconButton(
                        icon: const Icon(
                          Icons.close_rounded,
                          size: 15,
                          color: AppColors.textSecondary,
                        ),
                        onPressed: () {
                          controller.searchController.clear();
                          controller.onSearchChanged('');
                          FocusManager.instance.primaryFocus?.unfocus();
                        },
                        visualDensity: VisualDensity.compact,
                      );
                    },
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                ),
              ),
            ),
          ),
          Obx(() {
            final filter = controller.selectedFilter.value;
            if (filter == SessionFilter.all) return const SizedBox.shrink();

            final (name, color) = switch (filter) {
              SessionFilter.locked => ('Locked', AppColors.success),
              SessionFilter.readyToPair => ('Ready to Pair', AppColors.warning),
              SessionFilter.blockedAuth => ('Blocked Auth', AppColors.error),
              _ => ('Filtered', AppColors.primary),
            };

            return Padding(
              padding: const EdgeInsets.only(left: AppSizes.sm),
              child: InkWell(
                onTap: () => controller.setFilter(SessionFilter.all),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: color.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Filter: $name',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.close_rounded, size: 13, color: color),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: AppSizes.sm),
          IconButton(
            tooltip: 'Refresh Sessions',
            visualDensity: VisualDensity.compact,
            onPressed: controller.load,
            icon: const Icon(Icons.refresh_rounded, size: AppSizes.iconSm),
          ),
        ],
      ),
    );
  }
}

// ── 3. Modern Session Table ────────────────────────────────────────────────

class _SessionTable extends StatelessWidget {
  const _SessionTable({required this.controller});

  final SessionsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AdminDataTable<SessionRow>(
        minWidth: 840,
        rows: controller.pagedRows,
        isLoading: controller.isLoading.value,
        error: controller.errorMessage.value,
        onRetry: controller.load,
        onRefresh: controller.load,
        emptyTitle: switch (controller.selectedFilter.value) {
          SessionFilter.blockedAuth => 'No blocked login attempts',
          SessionFilter.readyToPair => 'No devices ready to pair',
          SessionFilter.locked => 'No locked devices',
          SessionFilter.all => controller.searchQuery.value.isNotEmpty
              ? 'No matching sessions'
              : 'No active device sessions found',
        },
        emptyMessage: switch (controller.selectedFilter.value) {
          SessionFilter.blockedAuth => 'No unauthorized login attempts have been logged.',
          SessionFilter.readyToPair => 'All current accounts have an assigned device lock.',
          SessionFilter.locked => 'No current accounts have an active device lock.',
          SessionFilter.all => controller.searchQuery.value.isNotEmpty
              ? 'Try adjusting your search terms.'
              : 'Sessions are registered when students open the mobile app.',
        },
        page: controller.page.value,
        pageSize: SessionsController.pageSize,
        totalCount: controller.rows.length,
        onPageChanged: controller.changePage,
        columns: [
          AdminColumn(
            label: 'STUDENT / USER',
            flex: 4,
            cell: (context, row) => _SessionUserCell(session: row),
          ),
          AdminColumn(
            label: 'DEVICE BOUND',
            flex: 3,
            cell: (_, row) => _DeviceIdCell(session: row),
          ),
          AdminColumn(
            label: 'LOCK & SECURITY STATUS',
            width: 175,
            cell: (_, row) => _LockStatusCell(session: row),
          ),
          AdminColumn(
            label: 'RESETS',
            width: 80,
            cell: (_, row) => _ResetCountCell(session: row),
          ),
          AdminColumn(
            label: 'LAST ACTIVE',
            width: 125,
            cell: (_, row) => _LastActiveCell(date: row.lastActiveAt ?? row.updatedAt),
          ),
        ],
        actionsWidth: 130,
        rowActions: (context, row) => Obx(() {
          final isActing = controller.actingUids.contains(row.userId);
          if (isActing) {
            return const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          final status = row.recentStatus;
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. First icon: Recent status (replaces the old blocked-only "x" icon with 3 states)
                IconButton(
                  tooltip: switch (status) {
                    DeviceRecentStatus.blocked =>
                      'Reset Requested / Blocked Attempt (${row.blockedCount}x) • Click for details',
                    DeviceRecentStatus.reset =>
                      'Device Reset (${row.resetCount}x) • Ready to connect new phone',
                    DeviceRecentStatus.connected =>
                      'Connected • ${row.deviceModel ?? (row.deviceId.isNotEmpty ? row.deviceId : "Active device")}',
                    DeviceRecentStatus.ready =>
                      'Ready to Connect • No device bound',
                  },
                  iconSize: 17,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    if (row.hasBlockedAuth) {
                      _showBlockedDetailsDialog(context, row, controller);
                    } else if (status == DeviceRecentStatus.reset) {
                      SnackbarHelper.info(
                        'Device Reset',
                        'Device lock was cleared (${row.resetCount} reset${row.resetCount == 1 ? '' : 's'}). The student can pair their next phone on login.',
                      );
                    } else if (status == DeviceRecentStatus.connected) {
                      SnackbarHelper.info(
                        'Device Connected',
                        'Currently bound to ${row.deviceModel ?? "device"} (${row.deviceId}).',
                      );
                    } else {
                      SnackbarHelper.info(
                        'Ready to Connect',
                        'Student has not bound a device yet.',
                      );
                    }
                  },
                  icon: Icon(
                    switch (status) {
                      DeviceRecentStatus.blocked => Icons.gpp_bad_rounded,
                      DeviceRecentStatus.reset => Icons.restart_alt_rounded,
                      DeviceRecentStatus.connected => Icons.phonelink_rounded,
                      DeviceRecentStatus.ready => Icons.phonelink_off_rounded,
                    },
                    color: switch (status) {
                      DeviceRecentStatus.blocked => AppColors.error,
                      DeviceRecentStatus.reset => AppColors.warning,
                      DeviceRecentStatus.connected => AppColors.success,
                      DeviceRecentStatus.ready => AppColors.textSecondary,
                    },
                  ),
                ),
                const SizedBox(width: 2),

                // 2. Middle icon: Reset Device Lock (Allow New Phone)
                if (row.isLocked) ...[
                  IconButton(
                    tooltip: 'Reset Device Lock (Allow New Phone)',
                    iconSize: 17,
                    padding: const EdgeInsets.all(4),
                    constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                    visualDensity: VisualDensity.compact,
                    onPressed: () async {
                      final name = row.userName ?? row.userEmail ?? row.userId;
                      final ok = await AppDialogBoxes.confirm(
                        title: 'Reset Device Lock',
                        message:
                            'Are you sure you want to reset device lock for $name? '
                            'They will be permitted to pair a new phone on their next login.',
                        confirmLabel: 'Reset Device',
                        isDestructive: false,
                      );
                      if (ok) controller.resetDevice(row);
                    },
                    icon: const Icon(
                      Icons.phonelink_erase_rounded,
                      color: AppColors.warning,
                    ),
                  ),
                  const SizedBox(width: 2),
                ],

                // 3. Last icon: Revoke Session (Delete from database)
                IconButton(
                  tooltip: 'Revoke session',
                  iconSize: 17,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                  visualDensity: VisualDensity.compact,
                  onPressed: () async {
                    final name = row.userName ?? row.userEmail ?? row.userId;
                    final ok = await AppDialogBoxes.confirm(
                      title: 'Revoke device session',
                      message:
                          'Are you sure you want to remove the session for $name? '
                          'The user session will be removed from the database.',
                      confirmLabel: 'Revoke',
                      isDestructive: true,
                    );
                    if (ok) controller.deleteSession(row);
                  },
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.error,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

// ── 4. Table Cell Components ───────────────────────────────────────────────

class _SessionUserCell extends StatelessWidget {
  const _SessionUserCell({required this.session});
  final SessionRow session;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final hasName = session.userName != null && session.userName!.isNotEmpty;

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.user_copy, size: 14, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                hasName ? session.userName! : (session.userEmail ?? session.userId),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: dark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
              if (hasName && session.userEmail != null) ...[
                const SizedBox(height: 1),
                Text(
                  session.userEmail!,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                  ),
                ),
              ] else if (hasName) ...[
                const SizedBox(height: 1),
                Text(
                  session.userId,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copy User ID',
          iconSize: 13,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: session.userId));
            SnackbarHelper.success('Copied', 'User ID copied to clipboard.');
          },
          icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _DeviceIdCell extends StatelessWidget {
  const _DeviceIdCell({required this.session});
  final SessionRow session;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final hasDevice = session.deviceId.isNotEmpty;
    final model = session.deviceModel;
    final os = session.osVersion;

    if (!hasDevice) {
      final isReset = session.recentStatus == DeviceRecentStatus.reset;
      return Row(
        children: [
          Icon(
            isReset ? Icons.restart_alt_rounded : Icons.phonelink_off_rounded,
            size: 14,
            color: isReset ? AppColors.warning : AppColors.textSecondary,
          ),
          const SizedBox(width: 6),
          Text(
            isReset ? 'Device reset • Ready' : 'Ready to connect',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: isReset ? AppColors.warning : AppColors.textSecondary,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.phonelink_rounded, size: 14, color: AppColors.success),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                model != null && model.isNotEmpty
                    ? (os != null && os.isNotEmpty ? '$model ($os)' : model)
                    : session.deviceId,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: dark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
              if (model != null && model.isNotEmpty)
                Text(
                  session.deviceId,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Copy Device ID',
          iconSize: 13,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: session.deviceId));
            SnackbarHelper.success('Copied', 'Device ID copied to clipboard.');
          },
          icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _LockStatusCell extends StatelessWidget {
  const _LockStatusCell({required this.session});
  final SessionRow session;

  @override
  Widget build(BuildContext context) {
    final status = session.recentStatus;
    final (label, color, icon) = switch (status) {
      DeviceRecentStatus.blocked => (
        'RESET REQUESTED',
        AppColors.error,
        Icons.gpp_bad_rounded,
      ),
      DeviceRecentStatus.reset => (
        'DEVICE RESET',
        AppColors.warning,
        Icons.restart_alt_rounded,
      ),
      DeviceRecentStatus.connected => (
        'CONNECTED',
        AppColors.success,
        Icons.phonelink_rounded,
      ),
      DeviceRecentStatus.ready => (
        'READY TO CONNECT',
        AppColors.warning,
        Icons.phonelink_off_rounded,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        if (session.hasBlockedAuth) ...[
          const SizedBox(height: 4),
          Tooltip(
            message: session.lastBlockedNote ??
                'Blocked login attempt from ${session.lastBlockedDeviceModel ?? 'unauthorized device'}'
                '${session.lastBlockedAt != null ? ' (${DateFormat('d MMM, HH:mm').format(session.lastBlockedAt!)})' : ''}',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: status == DeviceRecentStatus.blocked ? 0.12 : 0.07),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: status == DeviceRecentStatus.blocked ? 0.3 : 0.18),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    status == DeviceRecentStatus.blocked ? Icons.gpp_bad_rounded : Icons.history_rounded,
                    size: 11,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    status == DeviceRecentStatus.blocked
                        ? 'BLOCKED (${session.blockedCount})'
                        : 'PAST BLOCKED (${session.blockedCount})',
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResetCountCell extends StatelessWidget {
  const _ResetCountCell({required this.session});
  final SessionRow session;

  @override
  Widget build(BuildContext context) {
    final count = session.resetCount;

    if (count == 0) {
      return const Text(
        '—',
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      );
    }

    final color = count >= 3 ? AppColors.error : (count >= 2 ? AppColors.warning : AppColors.textSecondary);

    return Tooltip(
      message: '$count device reset(s) performed by admin',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.restart_alt_rounded, size: 13, color: color),
            const SizedBox(width: 4),
            Text(
              '$count',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LastActiveCell extends StatelessWidget {
  const _LastActiveCell({this.date});
  final DateTime? date;

  @override
  Widget build(BuildContext context) {
    if (date == null) {
      return const Text(
        'Never',
        style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
      );
    }
    return Text(
      DateFormat('d MMM, HH:mm').format(date!),
      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
    );
  }
}

// ── 5. Blocked Details Dialog ──────────────────────────────────────────────

void _showBlockedDetailsDialog(
  BuildContext context,
  SessionRow session,
  SessionsController controller,
) {
  final dark = AppHelperFunctions.isDark(context);
  final name = session.userName ?? session.userEmail ?? session.userId;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.gpp_bad_rounded, color: AppColors.error, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Blocked Unauthorized Attempt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dialogDetailRow('Target Account', name, dark),
            if (session.userEmail != null && session.userEmail != name)
              _dialogDetailRow('Email', session.userEmail!, dark),
            _dialogDetailRow('Account User ID', session.userId, dark, isMonospace: true),
            const Divider(height: 20),
            _dialogDetailRow(
              'Currently Bound Device',
              session.isLocked
                  ? (session.deviceModel != null && session.deviceModel!.isNotEmpty
                      ? '${session.deviceModel} (${session.deviceId})'
                      : session.deviceId)
                  : 'None (Ready to Pair)',
              dark,
            ),
            _dialogDetailRow(
              'Blocked Attempts Count',
              '${session.blockedCount} attempt(s)',
              dark,
              valueColor: AppColors.error,
              isBold: true,
            ),
            if (session.lastBlockedDeviceModel != null)
              _dialogDetailRow('Attempted From Device', session.lastBlockedDeviceModel!, dark),
            if (session.lastBlockedAt != null)
              _dialogDetailRow(
                'Latest Attempt Time',
                DateFormat('MMM d, yyyy • hh:mm a').format(session.lastBlockedAt!),
                dark,
              ),
            if (session.lastBlockedNote != null)
              _dialogDetailRow('System Note', session.lastBlockedNote!, dark),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Close'),
        ),
        if (session.isLocked)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.warning,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              controller.resetDevice(session);
            },
            icon: const Icon(Icons.phonelink_erase_rounded, size: 16),
            label: const Text('Reset Device Lock'),
          ),
      ],
    ),
  );
}

Widget _dialogDetailRow(
  String label,
  String value,
  bool dark, {
  bool isMonospace = false,
  bool isBold = false,
  Color? valueColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 140,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: dark ? AppColors.darkGrey : AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontFamily: isMonospace ? 'monospace' : null,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: valueColor ?? (dark ? AppColors.white : AppColors.textPrimary),
            ),
          ),
        ),
      ],
    ),
  );
}
