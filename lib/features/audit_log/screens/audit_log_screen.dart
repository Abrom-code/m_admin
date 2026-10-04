import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/audit_log/controllers/audit_log_controller.dart';
import 'package:m_admin/features/audit_log/models/admin_audit_log_model.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class AuditLogScreen extends StatelessWidget {
  const AuditLogScreen({super.key});

  static final _dateFormat = DateFormat('MMM dd, yyyy • HH:mm:ss');

  @override
  Widget build(BuildContext context) {
    final session = AdminSessionService.instance;
    final isSuper = session.isSuperAdmin;
    final ctrl = Get.put(AuditLogController());
    final dark = AppHelperFunctions.isDark(context);

    if (!isSuper) {
      return AdminScaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: const AdminNoticeCard(
              title: 'Access Restricted',
              message:
                  'The audit trail is only accessible to accounts with the Superadmin role. '
                  'Contact your administrator if you require elevated auditing access.',
              color: AppColors.error,
              icon: Iconsax.security_safe_copy,
            ),
          ),
        ),
      );
    }

    return AdminScaffold(
      onRefresh: ctrl.loadLogs,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Filter Toolbar ─────────────────────────────────────────────
          AdminCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
            child: Wrap(
              spacing: AppSizes.md,
              runSpacing: AppSizes.sm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Action Type Dropdown
                Obx(() {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                      border: Border.all(
                        color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: ctrl.selectedAction.value,
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('All Actions', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'approve_payment', child: Text('Approve Payment', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'reject_payment', child: Text('Reject Payment', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'broadcast', child: Text('Broadcast Notification', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'edit_user', child: Text('Edit User', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'delete_user', child: Text('Delete User', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'create_test', child: Text('Create Test', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'delete_test', child: Text('Delete Test', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'reset_device', child: Text('Reset Device', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'grant_trial', child: Text('Grant Extra Trial', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) ctrl.setActionFilter(val);
                        },
                      ),
                    ),
                  );
                }),

                // Date Range Button
                Obx(() {
                  final start = ctrl.startDate.value;
                  final end = ctrl.endDate.value;
                  final hasDate = start != null && end != null;
                  final dateText = hasDate
                      ? '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(end)}'
                      : 'Date Range';

                  return OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2023),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                        initialDateRange: hasDate ? DateTimeRange(start: start, end: end) : null,
                      );
                      if (picked != null) {
                        ctrl.setDateRange(picked.start, picked.end);
                      }
                    },
                    icon: const Icon(Iconsax.calendar_1_copy, size: 16),
                    label: Text(dateText, style: const TextStyle(fontSize: 12)),
                  );
                }),

                // Reset Filters
                Obx(() {
                  final isFiltered = ctrl.selectedAction.value != 'all' ||
                      ctrl.startDate.value != null ||
                      ctrl.endDate.value != null;
                  if (!isFiltered) return const SizedBox.shrink();

                  return TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: ctrl.clearFilters,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.spaceBtwItems),

          // ── Audit Log Table ────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              return AdminDataTable<AdminAuditLogModel>(
                columns: [
                  AdminColumn(
                    label: 'Timestamp',
                    flex: 2,
                    cell: (ctx, row) => Text(
                      _dateFormat.format(row.createdAt),
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                  AdminColumn(
                    label: 'Action',
                    flex: 2,
                    cell: (ctx, row) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: row.actionColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: row.actionColor, width: 0.8),
                      ),
                      child: Text(
                        row.formattedAction,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: row.actionColor,
                        ),
                      ),
                    ),
                  ),
                  AdminColumn(
                    label: 'Admin UID',
                    flex: 2,
                    cell: (ctx, row) => Tooltip(
                      message: row.adminUid,
                      child: Text(
                        row.adminUid.length > 12
                            ? '${row.adminUid.substring(0, 10)}…'
                            : row.adminUid,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ),
                  ),
                  AdminColumn(
                    label: 'Target',
                    flex: 2,
                    cell: (ctx, row) => Text(
                      '${row.entityType} ${row.entityId ?? ''}'.trim(),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                    ),
                  ),
                  AdminColumn(
                    label: 'Note / Details',
                    flex: 3,
                    cell: (ctx, row) => Text(
                      row.note ?? '—',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                rows: ctrl.logs,
                isLoading: ctrl.isLoading.value,
                error: ctrl.error.value,
                onRetry: ctrl.loadLogs,
                page: ctrl.currentPage.value,
                pageSize: AuditLogController.pageSize,
                totalCount: ctrl.totalCount.value,
                onPageChanged: ctrl.onPageChanged,
                emptyTitle: 'No audit records',
                emptyMessage: 'No actions matching the current filters were found.',
                rowActions: (ctx, row) => IconButton(
                  tooltip: 'View payload details',
                  icon: const Icon(Iconsax.eye_copy, size: 18),
                  onPressed: () => _showLogDetailsDialog(context, row),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  void _showLogDetailsDialog(BuildContext context, AdminAuditLogModel row) {
    final dark = AppHelperFunctions.isDark(context);
    final encoder = const JsonEncoder.withIndent('  ');

    String formatJson(Map<String, dynamic>? data) {
      if (data == null || data.isEmpty) return 'No data recorded.';
      try {
        return encoder.convert(data);
      } catch (_) {
        return data.toString();
      }
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: row.actionColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                row.formattedAction,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: row.actionColor,
                ),
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            const Text('Audit Details', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: SizedBox(
          width: 550,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _DetailRow(label: 'Timestamp', value: _dateFormat.format(row.createdAt)),
                _DetailRow(label: 'Admin UID', value: row.adminUid),
                _DetailRow(label: 'Entity Type', value: row.entityType),
                if (row.entityId != null) _DetailRow(label: 'Entity ID', value: row.entityId!),
                if (row.note != null) _DetailRow(label: 'Note', value: row.note!),
                const Divider(height: 24),
                if (row.before != null) ...[
                  const Text('State Before Mutation:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      formatJson(row.before),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (row.after != null) ...[
                  const Text('State After Mutation:', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                  const SizedBox(height: 6),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSizes.sm),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: SelectableText(
                      formatJson(row.after),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: SelectableText(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
