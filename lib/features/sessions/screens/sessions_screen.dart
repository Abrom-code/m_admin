import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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
    firebaseUid: j['firebase_uid']?.toString() ?? '',
    deviceId: j['device_id']?.toString() ?? '',
    trial: AppHelperFunctions.toInt(j['trial']) ?? 0,
  );
}

// ── Controller ───────────────────────────────────────────────────────

class SessionsController extends GetxController {
  static SessionsController get instance => Get.find();

  final _sb = Supabase.instance.client;

  final rows = <SessionRow>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final actingUids = <String>{}.obs;

  final page = 0.obs;
  static const pageSize = 30;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;

      final data = await _sb
          .from('user_sessions')
          .select('firebase_uid, device_id, trial')
          .order('firebase_uid')
          .range(page.value * pageSize, (page.value + 1) * pageSize - 1);

      rows.value = data
          .map((r) => SessionRow.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  void changePage(int next) {
    page.value = next;
    load();
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

      final idx = rows.indexWhere((r) => r.firebaseUid == session.firebaseUid);
      if (idx != -1) {
        rows[idx] = SessionRow(
          firebaseUid: session.firebaseUid,
          deviceId: session.deviceId,
          trial: 5,
        );
        rows.refresh();
      }

      SnackbarHelper.success('Trial reset', 'Set back to 5.');
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

      rows.removeWhere((r) => r.firebaseUid == session.firebaseUid);
      SnackbarHelper.success('Session deleted', 'User must re-launch the app.');
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
      pageIndex: 5,
      onRefresh: controller.load,
      scrollable: false,
      body: Obx(
        () => AdminDataTable<SessionRow>(
          rows: controller.rows.toList(),
          isLoading: controller.isLoading.value,
          error: controller.errorMessage.value,
          onRetry: controller.load,
          onRefresh: controller.load,
          emptyTitle: 'No active sessions',
          page: controller.page.value,
          pageSize: SessionsController.pageSize,
          onPageChanged: controller.changePage,
          columns: [
            AdminColumn(
              label: 'USER ID',
              flex: 4,
              cell: (context, row) => Row(
                children: [
                  Expanded(
                    child: Text(
                      row.firebaseUid,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy UID',
                    iconSize: AppSizes.iconSm,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: row.firebaseUid),
                    ),
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
            ),
            AdminColumn(
              label: 'DEVICE ID',
              flex: 3,
              cell: (_, row) => Text(
                row.deviceId,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            AdminColumn(
              label: 'TRIAL',
              width: 80,
              numeric: true,
              cell: (_, row) => Text(
                '${row.trial}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: row.trial <= 1 ? AppColors.error : AppColors.textPrimary,
                ),
              ),
            ),
          ],
          rowActions: (context, row) => Obx(() {
            if (controller.actingUids.contains(row.firebaseUid)) {
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
                  TextButton(
                    onPressed: () => controller.resetTrial(row),
                    child: const Text('Reset'),
                  ),
                IconButton(
                  tooltip: 'Delete session',
                  iconSize: AppSizes.iconSm,
                  onPressed: () async {
                    final ok = await AppDialogBoxes.confirm(
                      title: 'Delete session',
                      message:
                          'Remove ${row.firebaseUid}\'s session? '
                          'They will need to re-launch the app.',
                      confirmLabel: 'Delete',
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
      ),
    );
  }
}
