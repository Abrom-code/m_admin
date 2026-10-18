import 'dart:async';
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
import 'package:m_admin/utils/helpers/ethiopian_time_helper.dart';

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

  bool get isCurrentBlocked => recentStatus == DeviceRecentStatus.blocked;
  bool get isCurrentReadyToPair =>
      recentStatus == DeviceRecentStatus.reset || recentStatus == DeviceRecentStatus.ready;
  bool get isCurrentConnected => recentStatus == DeviceRecentStatus.connected;

  /// Determines the latest lifecycle status of this user's device:
  /// - `blocked`: The user attempted to log in from an unauthorized phone most recently.
  /// - `reset`: Admin reset the device, and the student hasn't paired a new device yet.
  /// - `connected`: A device is actively bound and linked.
  /// - `ready`: Fresh account, ready to connect.
  DeviceRecentStatus get recentStatus {
    // 1. If currently unbound (no device locked)
    if (!isLocked) {
      if (hasBlockedAuth) {
        final resetAfterBlocked =
            lastResetAt != null &&
            lastBlockedAt != null &&
            lastResetAt!.toUtc().isAfter(lastBlockedAt!.toUtc());
        if (!resetAfterBlocked) {
          return DeviceRecentStatus.blocked;
        }
      }
      if (resetCount > 0 || lastResetAt != null) {
        return DeviceRecentStatus.reset;
      }
      return DeviceRecentStatus.ready;
    }

    // 2. Currently bound (isLocked == true):
    if (lastBlockedAt != null) {
      // If the device was paired/updated or reset AFTER the last blocked attempt,
      // it is now actively connected and no longer blocked.
      final resetAfterBlocked =
          lastResetAt != null && lastResetAt!.toUtc().isAfter(lastBlockedAt!.toUtc());
      final updatedAfterBlocked =
          updatedAt != null && updatedAt!.toUtc().isAfter(lastBlockedAt!.toUtc());

      if (!resetAfterBlocked && !updatedAfterBlocked) {
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
      lastActiveAt: EthiopianTimeHelper.parseToEastAfricaTime(j['last_active_at']),
      updatedAt: EthiopianTimeHelper.parseToEastAfricaTime(j['updated_at']),
      blockedCount: blockedAttempts.length,
      lastBlockedAt: EthiopianTimeHelper.parseToEastAfricaTime(latestBlocked?['created_at']),
      lastBlockedDeviceModel: latestBlocked?['device_model']?.toString(),
      lastBlockedNote: latestBlocked?['note']?.toString(),
      resetCount: resetCount,
      lastResetAt: lastResetAt != null ? EthiopianTimeHelper.toEastAfricaTime(lastResetAt) : null,
    );
  }
}

// ── Controller ───────────────────────────────────────────────────────

class SessionsController extends GetxController {
  static SessionsController get instance => Get.find();

  final _sb = Supabase.instance.client;
  RealtimeChannel? _channel;
  Timer? _debounceTimer;
  bool _isFetching = false;

  final rows = <SessionRow>[].obs;
  final allRows = <SessionRow>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final actingUids = <String>{}.obs;
  final searchQuery = ''.obs;
  final searchController = TextEditingController();
  final selectedFilter = SessionFilter.all.obs;

  final page = 0.obs;
  static const pageSize = 25;

  int get totalSessions => allRows.length;
  int get lockedCount => allRows.where((r) => r.isCurrentConnected).length;
  int get connectedCount => lockedCount;
  int get unlockedCount => allRows.where((r) => r.isCurrentReadyToPair).length;
  int get readyToPairCount => unlockedCount;
  int get blockedAuthCount => allRows.where((r) => r.isCurrentBlocked).length;

  @override
  void onInit() {
    super.onInit();
    load();
    _subscribeRealtime();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    if (_channel != null) {
      _sb.removeChannel(_channel!);
      _channel = null;
    }
    searchController.dispose();
    super.onClose();
  }

  void _debouncedReload({Duration delay = const Duration(seconds: 3)}) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(delay, () {
      if (!isClosed) load(showIndicator: false);
    });
  }

  void _subscribeRealtime() {
    try {
      _channel = _sb.channel('admin_sessions_realtime')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'user_sessions',
          callback: (payload) {
            final eventType = payload.eventType;

            if (eventType == PostgresChangeEvent.delete) {
              final oldUid = (payload.oldRecord['user_id'] ?? payload.oldRecord['firebase_uid'])
                  ?.toString()
                  .trim()
                  .toLowerCase();
              if (oldUid != null && oldUid.isNotEmpty) {
                allRows.removeWhere((r) => r.userId.trim().toLowerCase() == oldUid);
                _applyFilterAndSearch();
              }
              return;
            }

            final newRecord = payload.newRecord;
            final rawUid = (newRecord['user_id'] ?? newRecord['firebase_uid'])?.toString() ?? '';
            final uid = rawUid.trim().toLowerCase();
            if (uid.isEmpty) return;

            final newDeviceId = newRecord['device_id']?.toString() ?? '';
            final newModel = newRecord['device_model']?.toString();
            final newOs = newRecord['os_version']?.toString();
            final newLastActive = EthiopianTimeHelper.parseToEastAfricaTime(newRecord['last_active_at']);
            final newUpdatedAt = EthiopianTimeHelper.parseToEastAfricaTime(newRecord['updated_at']);

            final idx = allRows.indexWhere((r) => r.userId.trim().toLowerCase() == uid);

            if (eventType == PostgresChangeEvent.update) {
              if (idx != -1) {
                // In-memory update: eliminates expensive table re-queries on heartbeats
                allRows[idx] = allRows[idx].copyWith(
                  deviceId: newDeviceId,
                  deviceModel: newModel ?? allRows[idx].deviceModel,
                  osVersion: newOs ?? allRows[idx].osVersion,
                  lastActiveAt: newLastActive ?? allRows[idx].lastActiveAt,
                  updatedAt: newUpdatedAt ?? allRows[idx].updatedAt,
                );
                _applyFilterAndSearch();
              } else {
                _debouncedReload();
              }
              return;
            }

            if (eventType == PostgresChangeEvent.insert) {
              if (idx != -1) {
                allRows[idx] = allRows[idx].copyWith(
                  deviceId: newDeviceId,
                  deviceModel: newModel,
                  osVersion: newOs,
                  lastActiveAt: newLastActive,
                  updatedAt: newUpdatedAt,
                );
                _applyFilterAndSearch();
              } else {
                _debouncedReload();
              }
            }
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'device_history',
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.insert) {
              final action = payload.newRecord['action']?.toString() ?? '';
              final rawUid = payload.newRecord['user_id']?.toString() ?? '';
              final uid = rawUid.trim().toLowerCase();

              if (action == 'BLOCKED_ATTEMPT') {
                final model = payload.newRecord['device_model']?.toString() ?? 'device';
                final note = payload.newRecord['note']?.toString();
                final createdAt = EthiopianTimeHelper.parseToEastAfricaTime(payload.newRecord['created_at']) ?? DateTime.now();

                SnackbarHelper.error(
                  'Blocked Auth Attempt',
                  'Unauthorized login attempt from $model blocked.',
                );

                final idx = allRows.indexWhere((r) => r.userId.trim().toLowerCase() == uid);
                if (idx != -1) {
                  // Instant in-memory update with zero network egress
                  allRows[idx] = allRows[idx].copyWith(
                    blockedCount: allRows[idx].blockedCount + 1,
                    lastBlockedAt: createdAt,
                    lastBlockedDeviceModel: model,
                    lastBlockedNote: note,
                  );
                  _applyFilterAndSearch();
                } else {
                  _debouncedReload();
                }
              } else if (action == 'ADMIN_RESET') {
                final createdAt = EthiopianTimeHelper.parseToEastAfricaTime(payload.newRecord['created_at']) ?? DateTime.now();
                final idx = allRows.indexWhere((r) => r.userId.trim().toLowerCase() == uid);
                if (idx != -1) {
                  // Instant in-memory reset status update with zero network egress
                  allRows[idx] = allRows[idx].copyWith(
                    deviceId: '',
                    resetCount: allRows[idx].resetCount + 1,
                    lastResetAt: createdAt,
                  );
                  _applyFilterAndSearch();
                } else {
                  _debouncedReload();
                }
              }
            }
          },
        )
        ..subscribe((status, [error]) {
          if (error != null) {
            debugPrint('[SessionsController] Realtime error: $error');
          }
        });
    } catch (e) {
      debugPrint('[SessionsController] Realtime setup failed: $e');
    }
  }

  Future<void> load({bool showIndicator = true}) async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      if (showIndicator) isLoading.value = true;
      errorMessage.value = null;

      // Execute queries concurrently in parallel with strict limits to minimize bandwidth and egress
      final results = await Future.wait<dynamic>([
        // 0. Active/Recent sessions (bounded to 500)
        _sb
            .from('user_sessions')
            .select('''
              user_id, device_id, device_model, os_version, last_active_at, updated_at,
              users(first_name, last_name, full_name, email)
            ''')
            .order('updated_at', ascending: false)
            .limit(500),

        // 1. Recent blocked authentication attempts (bounded to 250)
        _sb
            .from('device_history')
            .select('user_id, device_id, device_model, os_version, note, created_at')
            .eq('action', 'BLOCKED_ATTEMPT')
            .order('created_at', ascending: false)
            .limit(250)
            .catchError((e) {
              debugPrint('[SessionsController] Error fetching device_history: $e');
              return <dynamic>[];
            }),

        // 2. Recent admin resets (bounded to 300)
        _sb
            .from('device_history')
            .select('user_id, created_at')
            .eq('action', 'ADMIN_RESET')
            .order('created_at', ascending: false)
            .limit(300)
            .catchError((e) {
              debugPrint('[SessionsController] Error fetching reset counts: $e');
              return <dynamic>[];
            }),
      ]);

      final sessionData = results[0] as List;
      final blockedHistory = List<Map<String, dynamic>>.from(results[1] as List);
      final resetData = results[2] as List;

      // Group resets by user_id
      final Map<String, int> resetCountByUser = {};
      final Map<String, DateTime> lastResetByUser = {};
      for (final item in resetData) {
        final uid = item['user_id']?.toString().trim().toLowerCase();
        if (uid != null && uid.isNotEmpty) {
          resetCountByUser[uid] = (resetCountByUser[uid] ?? 0) + 1;
          if (!lastResetByUser.containsKey(uid) && item['created_at'] != null) {
            lastResetByUser[uid] =
                EthiopianTimeHelper.parseToEastAfricaTime(item['created_at']) ?? DateTime.now();
          }
        }
      }

      // Group blocked attempts by user_id
      final Map<String, List<Map<String, dynamic>>> blockedByUser = {};
      for (final item in blockedHistory) {
        final uid = item['user_id']?.toString().trim().toLowerCase();
        if (uid != null && uid.isNotEmpty) {
          blockedByUser.putIfAbsent(uid, () => []).add(item);
        }
      }

      final list = sessionData.map((r) {
        final rowMap = Map<String, dynamic>.from(r);
        final rawUid = (rowMap['user_id'] ?? rowMap['firebase_uid'])?.toString() ?? '';
        final uid = rawUid.trim().toLowerCase();
        final userBlocked = blockedByUser[uid] ?? [];
        return SessionRow.fromJson(
          rowMap,
          blockedAttempts: userBlocked,
          resetCount: resetCountByUser[uid] ?? 0,
          lastResetAt: lastResetByUser[uid],
        );
      }).toList();

      // Include users with blocked attempts who might not be in active user_sessions
      final existingUids = list.map((r) => r.userId.trim().toLowerCase()).toSet();
      final missingUids = blockedByUser.keys.where((uid) => !existingUids.contains(uid)).toList();
      if (missingUids.isNotEmpty) {
        try {
          // Bounded chunk to avoid large payloads / URL overflows
          final safeMissingUids = missingUids.take(50).toList();
          final missingUsersData = await _sb
              .from('users')
              .select('id, first_name, last_name, full_name, email')
              .inFilter('id', safeMissingUids);
          final missingUsersMap = {
            for (final u in (missingUsersData as List))
              u['id'].toString().trim().toLowerCase(): Map<String, dynamic>.from(u)
          };
          for (final uid in safeMissingUids) {
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
              lastActiveAt: EthiopianTimeHelper.parseToEastAfricaTime(latest['created_at']),
              updatedAt: EthiopianTimeHelper.parseToEastAfricaTime(latest['created_at']),
              blockedCount: attempts.length,
              lastBlockedAt: EthiopianTimeHelper.parseToEastAfricaTime(latest['created_at']),
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
      _isFetching = false;
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

  int _effectiveTimestamp(SessionRow r) {
    int maxMs = r.updatedAt?.millisecondsSinceEpoch ?? 0;
    final activeMs = r.lastActiveAt?.millisecondsSinceEpoch ?? 0;
    final blockedMs = r.lastBlockedAt?.millisecondsSinceEpoch ?? 0;
    final resetMs = r.lastResetAt?.millisecondsSinceEpoch ?? 0;
    if (activeMs > maxMs) maxMs = activeMs;
    if (blockedMs > maxMs) maxMs = blockedMs;
    if (resetMs > maxMs) maxMs = resetMs;
    return maxMs;
  }

  void _applyFilterAndSearch() {
    final q = searchQuery.value;
    final filter = selectedFilter.value;

    final filtered = allRows.where((r) {
      final matchesFilter = switch (filter) {
        SessionFilter.all => true,
        SessionFilter.locked => r.isCurrentConnected,
        SessionFilter.readyToPair => r.isCurrentReadyToPair,
        SessionFilter.blockedAuth => r.isCurrentBlocked,
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

    // Priority sorting:
    if (filter == SessionFilter.blockedAuth) {
      // In blocked auth section, sort by the latest blocked attempt time strictly descending
      filtered.sort((a, b) {
        final aTime = a.lastBlockedAt?.millisecondsSinceEpoch ?? 0;
        final bTime = b.lastBlockedAt?.millisecondsSinceEpoch ?? 0;
        return bTime.compareTo(aTime);
      });
    } else {
      // In general list, sort by most recent event (blocked attempt, active, or updated)
      filtered.sort((a, b) {
        final aTime = _effectiveTimestamp(a);
        final bTime = _effectiveTimestamp(b);
        return bTime.compareTo(aTime);
      });
    }

    rows.value = filtered;
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
              label: 'Connected (1 Device)',
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
              SessionFilter.locked => ('Connected', AppColors.success),
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
        minWidth: 940,
        rows: controller.pagedRows,
        isLoading: controller.isLoading.value,
        error: controller.errorMessage.value,
        onRetry: controller.load,
        onRefresh: controller.load,
        emptyTitle: switch (controller.selectedFilter.value) {
          SessionFilter.blockedAuth => 'No currently blocked attempts',
          SessionFilter.readyToPair => 'No devices ready to pair',
          SessionFilter.locked => 'No connected devices',
          SessionFilter.all => controller.searchQuery.value.isNotEmpty
              ? 'No matching sessions'
              : 'No active device sessions found',
        },
        emptyMessage: switch (controller.selectedFilter.value) {
          SessionFilter.blockedAuth => 'All unauthorized login attempts have been resolved or reset.',
          SessionFilter.readyToPair => 'All current accounts have an active device or are currently blocked.',
          SessionFilter.locked => 'No current accounts have an active connected device.',
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
                if (row.isLocked || row.isCurrentBlocked) ...[
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasName ? session.userName! : (session.userEmail ?? session.userId),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
                  maxLines: 1,
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
                  maxLines: 1,
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
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Copy User ID',
          iconSize: 13,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
    final isCurrentBlocked = session.isCurrentBlocked;
    final hasBlocked = session.hasBlockedAuth;

    if (!hasDevice) {
      final isReset = session.recentStatus == DeviceRecentStatus.reset;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                isCurrentBlocked
                    ? Icons.gpp_bad_rounded
                    : (isReset ? Icons.restart_alt_rounded : Icons.phonelink_off_rounded),
                size: 14,
                color: isCurrentBlocked
                    ? AppColors.error
                    : (isReset ? AppColors.warning : AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  isCurrentBlocked
                      ? 'No device bound'
                      : (isReset ? 'Device reset • Ready to pair' : 'Ready to pair'),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: isCurrentBlocked
                        ? AppColors.error
                        : (isReset ? AppColors.warning : AppColors.textSecondary),
                  ),
                ),
              ),
            ],
          ),
          if (isCurrentBlocked && session.lastBlockedDeviceModel != null) ...[
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.block_rounded, size: 10, color: AppColors.error),
                const SizedBox(width: 3),
                Flexible(
                  child: Text(
                    'Attempted: ${session.lastBlockedDeviceModel}',
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
            ),
          ],
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
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                model != null && model.isNotEmpty
                    ? (os != null && os.isNotEmpty ? '$model ($os)' : model)
                    : session.deviceId,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
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
                  maxLines: 1,
                  style: const TextStyle(
                    fontSize: 10,
                    fontFamily: 'monospace',
                    color: AppColors.textSecondary,
                  ),
                ),
              if (hasBlocked && session.lastBlockedDeviceModel != null) ...[
                const SizedBox(height: 2),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.gpp_bad_rounded, size: 11, color: AppColors.error),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        'Attempted: ${session.lastBlockedDeviceModel}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 4),
        IconButton(
          tooltip: 'Copy Device ID',
          iconSize: 13,
          padding: const EdgeInsets.all(4),
          constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
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
        'BLOCKED ATTEMPT',
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
      mainAxisSize: MainAxisSize.min,
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
                color: AppColors.error.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.gpp_bad_rounded,
                    size: 11,
                    color: AppColors.error,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'BLOCKED (${session.blockedCount})',
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
      '${DateFormat('d MMM, HH:mm').format(date!)} EAT',
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
                '${DateFormat('MMM d, yyyy • hh:mm a').format(session.lastBlockedAt!)} (EAT)',
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
        if (session.isLocked || session.isCurrentBlocked)
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
