import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/notifications/controllers/notifications_controller.dart';
import 'package:m_admin/features/notifications/models/admin_notification_model.dart';
import 'package:m_admin/features/notifications/screens/notification_compose_screen.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NotificationsController());

    return AdminScaffold(
      pageIndex: 2,
      onRefresh: controller.load,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              onPressed: () => _openCompose(context, controller),
              icon: const Icon(Icons.send_rounded, size: AppSizes.iconSm),
              label: const Text('Send notification'),
            ),
          ),
          const SizedBox(height: AppSizes.spaceBtwItems),
          _TypeFilter(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          Expanded(child: _Table(controller: controller)),
        ],
      ),
    );
  }

  void _openCompose(
    BuildContext context,
    NotificationsController controller,
  ) {
    final wide = MediaQuery.sizeOf(context).width >= 900;

    if (wide) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 80,
            vertical: 60,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: NotificationComposeScreen(controller: controller),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (_) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: NotificationComposeScreen(controller: controller),
        ),
      );
    }
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.controller});

  final NotificationsController controller;

  static const _types = {
    '': 'All types',
    'announcement': 'Announcement',
    'new_content': 'New content',
    'payment': 'Payment',
  };

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: AppSizes.sm,
        children: [
          for (final entry in _types.entries)
            ChoiceChip(
              selected: (controller.typeFilter.value ?? '') == entry.key,
              onSelected: (_) => controller.setTypeFilter(
                entry.key.isEmpty ? null : entry.key,
              ),
              label: Text(entry.value),
            ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AdminDataTable<AdminNotificationModel>(
        rows: controller.rows.toList(),
        isLoading: controller.isLoading.value,
        error: controller.errorMessage.value,
        onRetry: controller.load,
        emptyTitle: 'No notifications sent yet',
        page: controller.page.value,
        pageSize: NotificationsController.pageSize,
        onPageChanged: controller.changePage,
        columns: [
          AdminColumn(
            label: 'DATE',
            flex: 2,
            cell: (_, row) => Text(
              row.createdAt == null
                  ? '—'
                  : DateFormat('d MMM yyyy, HH:mm').format(row.createdAt!),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          AdminColumn(
            label: 'TYPE',
            width: 130,
            cell: (_, row) => _TypePill(type: row.type),
          ),
          AdminColumn(
            label: 'AUDIENCE',
            flex: 2,
            cell: (_, row) => Text(
              row.audienceLabel,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          AdminColumn(
            label: 'TITLE',
            flex: 3,
            cell: (_, row) => Text(
              row.title,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          AdminColumn(
            label: 'MESSAGE',
            flex: 4,
            cell: (_, row) => Text(
              row.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  const _TypePill({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (type) {
      'announcement' => ('Announcement', AppColors.info),
      'new_content' => ('New content', AppColors.success),
      'payment' => ('Payment', AppColors.warning),
      _ => (type, AppColors.darkGrey),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
