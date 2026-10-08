import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

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
  });

  final String userId;
  final String? userName;
  final String? userEmail;
  final String deviceId;
  final String? deviceModel;
  final String? osVersion;
  final DateTime? lastActiveAt;
  final DateTime? updatedAt;

  bool get isLocked => deviceId.trim().isNotEmpty;
  String get firebaseUid => userId;

  SessionRow copyWith({
    String? userId,
    String? userName,
    String? userEmail,
    String? deviceId,
    String? deviceModel,
    String? osVersion,
    DateTime? lastActiveAt,
    DateTime? updatedAt,
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
    );
  }

  factory SessionRow.fromJson(Map<String, dynamic> j) {
    final user = j['users'] as Map<String, dynamic>? ?? {};
    final fName = user['first_name']?.toString() ?? '';
    final lName = user['last_name']?.toString() ?? '';
    final fullName = user['full_name']?.toString() ?? '';
    final resolvedName = fullName.isNotEmpty
        ? fullName
        : ('$fName $lName'.trim().isNotEmpty ? '$fName $lName'.trim() : null);

    return SessionRow(
      userId: (j['user_id'] ?? j['firebase_uid'])?.toString() ?? '',
      userName: resolvedName,
      userEmail: user['email']?.toString(),
      deviceId: j['device_id']?.toString() ?? '',
      deviceModel: j['device_model']?.toString(),
      osVersion: j['os_version']?.toString(),
      lastActiveAt: j['last_active_at'] != null ? DateTime.tryParse(j['last_active_at'].toString()) : null,
      updatedAt: j['updated_at'] != null ? DateTime.tryParse(j['updated_at'].toString()) : null,
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

  final page = 0.obs;
  static const pageSize = 30;

  int get totalSessions => allRows.length;
  int get lockedCount => allRows.where((r) => r.isLocked).length;
  int get unlockedCount => allRows.where((r) => !r.isLocked).length;

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

      final data = await _sb
          .from('user_sessions')
          .select('''
            user_id, device_id, device_model, os_version, last_active_at, updated_at,
            users(first_name, last_name, full_name, email)
          ''')
          .order('updated_at', ascending: false);

      final list = (data as List)
          .map((r) => SessionRow.fromJson(Map<String, dynamic>.from(r)))
          .toList();

      allRows.value = list;
      _applySearch();
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  void onSearchChanged(String query) {
    searchQuery.value = query.trim().toLowerCase();
    page.value = 0;
    _applySearch();
  }

  void _applySearch() {
    if (searchQuery.value.isEmpty) {
      rows.value = allRows;
    } else {
      final q = searchQuery.value;
      rows.value = allRows.where((r) {
        return r.userId.toLowerCase().contains(q) ||
            (r.userName?.toLowerCase().contains(q) ?? false) ||
            (r.userEmail?.toLowerCase().contains(q) ?? false) ||
            r.deviceId.toLowerCase().contains(q) ||
            (r.deviceModel?.toLowerCase().contains(q) ?? false);
      }).toList();
    }
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
      );

      final idxAll = allRows.indexWhere((r) => r.userId == session.userId);
      if (idxAll != -1) allRows[idxAll] = updated;

      final idx = rows.indexWhere((r) => r.userId == session.userId);
      if (idx != -1) {
        rows[idx] = updated;
        rows.refresh();
      }

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
      rows.removeWhere((r) => r.userId == session.userId);
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
      pageIndex: 7,
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

// ── 1. Session Metrics Ribbon ──────────────────────────────────────────────

class _SessionMetricRibbon extends StatelessWidget {
  const _SessionMetricRibbon({required this.controller});

  final SessionsController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Obx(() {
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
            ),
            const SizedBox(width: 8),
            _SessionMetricPill(
              label: 'Locked (1 Device)',
              value: '${controller.lockedCount}',
              icon: Iconsax.shield_tick_copy,
              color: AppColors.success,
              dark: dark,
            ),
            const SizedBox(width: 8),
            _SessionMetricPill(
              label: 'Ready to Pair',
              value: '${controller.unlockedCount}',
              icon: Icons.lock_open_rounded,
              color: AppColors.warning,
              dark: dark,
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
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: dark ? AppColors.white : AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── 2. Search Toolbar ──────────────────────────────────────────────────────

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
        minWidth: 780,
        rows: controller.pagedRows,
        isLoading: controller.isLoading.value,
        error: controller.errorMessage.value,
        onRetry: controller.load,
        onRefresh: controller.load,
        emptyTitle: 'No active device sessions found',
        emptyMessage: 'Sessions are registered when students open the mobile app.',
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
            label: 'LOCK STATUS',
            width: 155,
            cell: (_, row) => _LockStatusCell(isLocked: row.isLocked),
          ),
          AdminColumn(
            label: 'LAST ACTIVE',
            width: 125,
            cell: (_, row) => _LastActiveCell(date: row.lastActiveAt ?? row.updatedAt),
          ),
        ],
        rowActions: (context, row) => Obx(() {
          final isActing = controller.actingUids.contains(row.userId);
          if (isActing) {
            return const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          }
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (row.isLocked) ...[
                IconButton(
                  tooltip: 'Reset Device Lock (Allow New Phone)',
                  iconSize: 18,
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
              IconButton(
                tooltip: 'Revoke session',
                iconSize: 18,
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
      return const Row(
        children: [
          Icon(Icons.lock_open_rounded, size: 14, color: AppColors.warning),
          SizedBox(width: 6),
          Text(
            'Ready to pair',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: AppColors.warning,
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        const Icon(Icons.smartphone_rounded, size: 14, color: AppColors.textSecondary),
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
  const _LockStatusCell({required this.isLocked});
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final color = isLocked ? AppColors.success : AppColors.warning;
    final label = isLocked ? 'LOCKED (1 DEVICE)' : 'READY TO PAIR';
    final icon = isLocked ? Icons.smartphone_rounded : Icons.lock_open_rounded;

    return Container(
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
