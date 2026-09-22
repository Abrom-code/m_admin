import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
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
    required this.firebaseUid,
    required this.deviceId,
    required this.trial,
  });

  final String firebaseUid;
  final String deviceId;
  final int trial;

  factory SessionRow.fromJson(Map<String, dynamic> j) => SessionRow(
    firebaseUid: (j['user_id'] ?? j['firebase_uid'])?.toString() ?? '',
    deviceId: j['device_id']?.toString() ?? '',
    trial: AppHelperFunctions.toInt(j['trial']) ?? 0,
  );
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
  int get fullTrialCount => allRows.where((r) => r.trial >= 5).length;
  int get exhaustedTrialCount => allRows.where((r) => r.trial == 0).length;

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
          .select('firebase_uid, device_id, trial')
          .order('firebase_uid');

      final list = data
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
        return r.firebaseUid.toLowerCase().contains(q) ||
            r.deviceId.toLowerCase().contains(q);
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

  Future<void> resetTrial(SessionRow session) async {
    if (actingUids.contains(session.firebaseUid)) return;
    try {
      actingUids.add(session.firebaseUid);
      actingUids.refresh();

      await _sb
          .from('user_sessions')
          .update({'trial': 5})
          .eq('firebase_uid', session.firebaseUid);

      final updated = SessionRow(
        firebaseUid: session.firebaseUid,
        deviceId: session.deviceId,
        trial: 5,
      );

      final idxAll = allRows.indexWhere((r) => r.firebaseUid == session.firebaseUid);
      if (idxAll != -1) allRows[idxAll] = updated;

      final idx = rows.indexWhere((r) => r.firebaseUid == session.firebaseUid);
      if (idx != -1) {
        rows[idx] = updated;
        rows.refresh();
      }

      SnackbarHelper.success('Trial reset', 'Trial count set back to 5.');
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      actingUids.remove(session.firebaseUid);
      actingUids.refresh();
    }
  }

  Future<void> deleteSession(SessionRow session) async {
    if (actingUids.contains(session.firebaseUid)) return;
    try {
      actingUids.add(session.firebaseUid);
      actingUids.refresh();

      await _sb
          .from('user_sessions')
          .delete()
          .eq('firebase_uid', session.firebaseUid);

      allRows.removeWhere((r) => r.firebaseUid == session.firebaseUid);
      rows.removeWhere((r) => r.firebaseUid == session.firebaseUid);
      SnackbarHelper.success('Session deleted', 'User session removed successfully.');
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      actingUids.remove(session.firebaseUid);
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
              label: 'Full Trial (5/5)',
              value: '${controller.fullTrialCount}',
              icon: Iconsax.shield_tick_copy,
              color: AppColors.success,
              dark: dark,
            ),
            const SizedBox(width: 8),
            _SessionMetricPill(
              label: 'Exhausted (0/5)',
              value: '${controller.exhaustedTrialCount}',
              icon: Iconsax.warning_2_copy,
              color: AppColors.error,
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
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                onTapOutside: (_) => FocusScope.of(context).unfocus(),
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search sessions by Firebase UID or Device ID...',
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
            label: 'FIREBASE UID',
            flex: 4,
            cell: (context, row) => _SessionUidCell(uid: row.firebaseUid),
          ),
          AdminColumn(
            label: 'DEVICE ID',
            flex: 3,
            cell: (_, row) => _DeviceIdCell(deviceId: row.deviceId),
          ),
          AdminColumn(
            label: 'TRIAL REMAINING',
            width: 140,
            cell: (_, row) => _TrialGaugeCell(trial: row.trial),
          ),
        ],
        rowActions: (context, row) => Obx(() {
          final isActing = controller.actingUids.contains(row.firebaseUid);
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
              if (row.trial < 5)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: () => controller.resetTrial(row),
                  icon: const Icon(Icons.refresh_rounded, size: 13),
                  label: const Text('Reset to 5', style: TextStyle(fontSize: 11)),
                ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Revoke session',
                iconSize: 16,
                visualDensity: VisualDensity.compact,
                onPressed: () async {
                  final ok = await AppDialogBoxes.confirm(
                    title: 'Revoke device session',
                    message:
                        'Are you sure you want to remove the session for ${row.firebaseUid}? '
                        'The user will be prompted to re-launch the app.',
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

class _SessionUidCell extends StatelessWidget {
  const _SessionUidCell({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Iconsax.user_copy, size: 13, color: AppColors.primary),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            uid,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ),
        IconButton(
          tooltip: 'Copy UID',
          iconSize: 13,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            Clipboard.setData(ClipboardData(text: uid));
            SnackbarHelper.success('Copied', 'UID copied to clipboard.');
          },
          icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _DeviceIdCell extends StatelessWidget {
  const _DeviceIdCell({required this.deviceId});
  final String deviceId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.smartphone_rounded, size: 14, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            deviceId,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ),
      ],
    );
  }
}

class _TrialGaugeCell extends StatelessWidget {
  const _TrialGaugeCell({required this.trial});
  final int trial;

  @override
  Widget build(BuildContext context) {
    final color = trial >= 5
        ? AppColors.success
        : trial > 1
            ? AppColors.warning
            : AppColors.error;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$trial / 5 Tests',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
