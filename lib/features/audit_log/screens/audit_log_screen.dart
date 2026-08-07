import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

// ── Model ────────────────────────────────────────────────────────────

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.adminUid,
    required this.action,
    this.entityType,
    this.entityId,
    this.note,
    required this.createdAt,
  });

  final int id;
  final String adminUid;
  final String action;
  final String? entityType;
  final String? entityId;
  final String? note;
  final DateTime createdAt;

  factory AuditEntry.fromJson(Map<String, dynamic> j) => AuditEntry(
    id: AppHelperFunctions.toInt(j['id']) ?? 0,
    adminUid: j['admin_uid']?.toString() ?? '',
    action: j['action']?.toString() ?? '',
    entityType: j['entity_type']?.toString(),
    entityId: j['entity_id']?.toString(),
    note: j['note']?.toString(),
    createdAt: j['created_at'] == null
        ? DateTime.now()
        : DateTime.parse(j['created_at'].toString()),
  );

  Color get actionColor {
    if (action.startsWith('approve')) return AppColors.success;
    if (action.startsWith('reject')) return AppColors.error;
    if (action.startsWith('grant')) return AppColors.info;
    if (action.startsWith('revoke')) return AppColors.warning;
    if (action.startsWith('delete')) return AppColors.error;
    if (action.startsWith('reset')) return AppColors.warning;
    return AppColors.textSecondary;
  }
}

// ── Controller ───────────────────────────────────────────────────────

class AuditLogController extends GetxController {
  static AuditLogController get instance => Get.find();

  final _sb = Supabase.instance.client;

  final entries = <AuditEntry>[].obs;
  final isLoading = false.obs;
  final errorMessage = RxnString();
  final page = 0.obs;
  static const pageSize = 50;

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
          .from('admin_audit_log')
          .select('id, admin_uid, action, entity_type, entity_id, note, created_at')
          .order('created_at', ascending: false)
          .range(
            page.value * pageSize,
            (page.value + 1) * pageSize - 1,
          );

      entries.value = data
          .map((r) => AuditEntry.fromJson(Map<String, dynamic>.from(r)))
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
}

// ── Screen ───────────────────────────────────────────────────────────

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(AuditLogController());

    return AdminScaffold(
      title: 'Audit Log',
      subtitle: 'Admin actions trail',
      scrollable: false,
      actions: [
        Obx(
          () => IconButton(
            tooltip: 'Refresh',
            onPressed: controller.isLoading.value ? null : controller.load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
      body: Obx(
        () => AdminDataTable<AuditEntry>(
          rows: controller.entries.toList(),
          isLoading: controller.isLoading.value,
          error: controller.errorMessage.value,
          onRetry: controller.load,
          emptyTitle: 'No audit entries yet',
          emptyMessage: 'Actions you take will be recorded here.',
          page: controller.page.value,
          pageSize: AuditLogController.pageSize,
          onPageChanged: controller.changePage,
          columns: [
            AdminColumn(
              label: 'TIME',
              width: 140,
              cell: (_, row) => Text(
                DateFormat('d MMM HH:mm:ss').format(row.createdAt.toLocal()),
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            AdminColumn(
              label: 'ACTION',
              flex: 2,
              cell: (_, row) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: row.actionColor.withValues(alpha: 0.12),
                  borderRadius:
                      BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: Text(
                  row.action,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: row.actionColor,
                  ),
                ),
              ),
            ),
            AdminColumn(
              label: 'ADMIN UID',
              flex: 3,
              cell: (_, row) => Row(
                children: [
                  Expanded(
                    child: Text(
                      row.adminUid,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    iconSize: AppSizes.iconSm,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Clipboard.setData(
                      ClipboardData(text: row.adminUid),
                    ),
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
            ),
            AdminColumn(
              label: 'ENTITY',
              flex: 3,
              cell: (_, row) {
                final label = [
                  if (row.entityType != null) row.entityType!,
                  if (row.entityId != null) '#${row.entityId}',
                ].join(' ');
                if (label.isEmpty) {
                  return const Text(
                    '—',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  );
                }
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      iconSize: AppSizes.iconSm,
                      visualDensity: VisualDensity.compact,
                      onPressed: () => Clipboard.setData(ClipboardData(text: label)),
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                );
              },
            ),
            AdminColumn(
              label: 'NOTE',
              flex: 4,
              cell: (_, row) {
                if (row.note?.isEmpty ?? true) {
                  return const Text(
                    '—',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  );
                }
                return Tooltip(
                  message: row.note!,
                  child: Text(
                    row.note!,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
