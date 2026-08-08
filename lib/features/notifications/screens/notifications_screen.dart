import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/notifications/controllers/notifications_controller.dart';
import 'package:m_admin/features/notifications/models/admin_notification_model.dart';
import 'package:m_admin/features/notifications/screens/notification_compose_screen.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

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
          Row(
            children: [
              Expanded(child: _TypeFilter(controller: controller)),
              const SizedBox(width: AppSizes.md),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        NotificationComposeScreen(controller: controller),
                  ),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.md,
                    vertical: AppSizes.sm,
                  ),
                ),
                icon: const Icon(Iconsax.send_1_copy, size: 18),
                label: const Text('Send notification'),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.spaceBtwItems),
          Expanded(child: _NotificationsList(controller: controller)),
        ],
      ),
    );
  }
}

class _TypeFilter extends StatelessWidget {
  const _TypeFilter({required this.controller});

  final NotificationsController controller;

  static final _types = [
    ('', Iconsax.menu_copy, 'All'),
    ('announcement', Iconsax.message_copy, 'Announcement'),
    ('new_content', Iconsax.document_text_copy, 'Content'),
    ('payment', Iconsax.wallet_copy, 'Payment'),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Row(
        children: [
          for (final (key, icon, label) in _types) ...[
            Flexible(
              child: ChoiceChip(
                showCheckmark: false,
                selected: (controller.typeFilter.value ?? '') == key,
                onSelected: (_) =>
                    controller.setTypeFilter(key.isEmpty ? null : key),
                avatar: Icon(
                  icon,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
                label: Text(label, style: const TextStyle(fontSize: 11)),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.xs,
                  vertical: 2,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ),
            if (_types.last.$1 != key) const SizedBox(width: AppSizes.xs),
          ],
        ],
      ),
    );
  }
}

class _NotificationsList extends StatelessWidget {
  const _NotificationsList({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.isLoading.value && controller.rows.isEmpty) {
        return const Center(child: CircularProgressIndicator());
      }

      if (controller.errorMessage.value != null && controller.rows.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.error,
                size: 48,
              ),
              const SizedBox(height: AppSizes.sm),
              Text(
                controller.errorMessage.value!,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppSizes.md),
              OutlinedButton.icon(
                onPressed: controller.load,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Retry'),
              ),
            ],
          ),
        );
      }

      if (controller.rows.isEmpty) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.notification_bing_copy,
                size: 64,
                color: AppColors.darkGrey.withValues(alpha: 0.5),
              ),
              const SizedBox(height: AppSizes.md),
              const Text(
                'No notifications sent yet',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.all(AppSizes.sm),
        itemCount: controller.rows.length,
        separatorBuilder: (context, index) =>
            const SizedBox(height: AppSizes.sm),
        itemBuilder: (context, index) {
          final notification = controller.rows[index];
          return _NotificationCard(
            notification: notification,
            onTap: () => _showNotificationDetail(context, notification),
          );
        },
      );
    });
  }

  void _showNotificationDetail(
    BuildContext context,
    AdminNotificationModel notification,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          _NotificationDetailDialog(notification: notification),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.notification, required this.onTap});

  final AdminNotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    final (label, color, icon) = switch (notification.type) {
      'announcement' => ('Announcement', AppColors.info, Iconsax.message_copy),
      'new_content' => (
        'New content',
        AppColors.success,
        Iconsax.document_text_copy,
      ),
      'payment' => ('Payment', AppColors.warning, Iconsax.wallet_copy),
      _ => (notification.type, AppColors.darkGrey, Iconsax.notification_copy),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
          border: Border.all(
            color: dark
                ? AppColors.darkGrey.withValues(alpha: 0.3)
                : AppColors.grey.withValues(alpha: 0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              spreadRadius: -2,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppSizes.borderRadiusSm,
                    ),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                const SizedBox(width: AppSizes.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      Text(
                        notification.audienceLabel,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (notification.createdAt != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        DateFormat('MMM d').format(notification.createdAt!),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      Text(
                        DateFormat('HH:mm').format(notification.createdAt!),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              notification.title,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              notification.body,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationDetailDialog extends StatelessWidget {
  const _NotificationDetailDialog({required this.notification});

  final AdminNotificationModel notification;

  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (notification.type) {
      'announcement' => ('Announcement', AppColors.info, Iconsax.message_copy),
      'new_content' => (
        'New content',
        AppColors.success,
        Iconsax.document_text_copy,
      ),
      'payment' => ('Payment', AppColors.warning, Iconsax.wallet_copy),
      _ => (notification.type, AppColors.darkGrey, Iconsax.notification_copy),
    };

    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(
                      AppSizes.borderRadiusMd,
                    ),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      Text(
                        notification.audienceLabel,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: AppSizes.md),
            const Divider(height: 1),
            const SizedBox(height: AppSizes.md),
            Text(
              notification.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              notification.body,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            if (notification.createdAt != null)
              Row(
                children: [
                  const Icon(
                    Iconsax.clock_copy,
                    size: 14,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat(
                      'MMM d, yyyy at HH:mm',
                    ).format(notification.createdAt!),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
