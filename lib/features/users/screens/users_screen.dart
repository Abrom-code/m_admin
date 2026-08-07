import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_chips.dart';
import 'package:m_admin/features/users/controllers/users_controller.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/features/users/screens/user_detail_screen.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UsersController());

    return AdminScaffold(
      title: 'Users',
      subtitle: 'Student accounts and subscription management',
      scrollable: false,
      actions: [
        Obx(
          () => IconButton(
            tooltip: 'Refresh',
            onPressed: controller.isLoading.value ? null : controller.loadAll,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StatusTabs(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          _FilterBar(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          Expanded(child: _Table(controller: controller)),
        ],
      ),
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({required this.controller});

  final UsersController controller;

  static const _tabs = {
    '': 'All',
    'active': 'Active',
    'pending': 'Pending',
    'inactive': 'Inactive',
  };

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: AppSizes.sm,
        children: [
          for (final entry in _tabs.entries)
            ChoiceChip(
              selected:
                  (controller.statusFilter.value ?? '') == entry.key,
              onSelected: (_) => controller.setStatusFilter(
                entry.key.isEmpty ? null : entry.key,
              ),
              label: Text(
                controller.counts[entry.key] == null
                    ? entry.value
                    : '${entry.value} (${controller.counts[entry.key]})',
              ),
            ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.controller});

  final UsersController controller;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(AppSizes.sm),
      child: Wrap(
        spacing: AppSizes.sm,
        runSpacing: AppSizes.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: controller.searchController,
              onChanged: controller.onSearchChanged,
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Search name or email',
                prefixIcon: Icon(Icons.search_rounded, size: AppSizes.iconSm),
              ),
            ),
          ),
          Obx(
            () => SizedBox(
              width: 170,
              child: DropdownButtonFormField<String?>(
                initialValue: controller.streamFilter.value,
                isDense: true,
                decoration: const InputDecoration(
                  isDense: true,
                  labelText: 'Stream',
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text('All streams')),
                  ...controller.availableStreams.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s)),
                  ),
                ],
                onChanged: controller.setStreamFilter,
              ),
            ),
          ),
          TextButton(
            onPressed: controller.clearFilters,
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.controller});

  final UsersController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AdminDataTable<AdminUserModel>(
        rows: controller.rows.toList(),
        isLoading: controller.isLoading.value,
        error: controller.errorMessage.value,
        onRetry: controller.load,
        emptyTitle: 'No users found',
        page: controller.page.value,
        pageSize: UsersController.pageSize,
        totalCount: controller.counts[''],
        onPageChanged: controller.changePage,
        onRowTap: (user) => _openDetail(context, user),
        columns: [
          AdminColumn(
            label: 'NAME',
            flex: 3,
            cell: (_, user) => Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  child: Text(
                    user.initials,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        user.email,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AdminColumn(
            label: 'STREAM',
            flex: 1,
            cell: (_, user) => Text(
              user.stream.isEmpty ? '—' : user.stream,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          AdminColumn(
            label: 'STATUS',
            flex: 2,
            cell: (_, user) => _StatusPill(status: user.subscriptionStatus),
          ),
          AdminColumn(
            label: 'JOINED',
            flex: 2,
            cell: (_, user) => Text(
              user.createdAt == null
                  ? '—'
                  : DateFormat('d MMM yyyy').format(user.createdAt!),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
        rowActions: (context, user) => TextButton(
          onPressed: () => _openDetail(context, user),
          child: const Text('View'),
        ),
      ),
    );
  }

  void _openDetail(BuildContext context, AdminUserModel user) {
    final wide = MediaQuery.sizeOf(context).width >= 1100;
    if (wide) {
      showDialog(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 60,
            vertical: 40,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 700),
            child: UserDetailScreen(user: user),
          ),
        ),
      );
    } else {
      Get.to(() => UserDetailScreen(user: user));
    }
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final color = subscriptionStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      ),
      child: Text(
        status,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
