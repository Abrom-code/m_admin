import 'package:m_admin/common/widgets/admin_date_filter_pill.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_data_table.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_chips.dart';
import 'package:m_admin/features/users/controllers/users_controller.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/features/users/screens/user_detail_screen.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class UsersScreen extends StatelessWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(UsersController());

    return AdminScaffold(
      pageIndex: AdminNavPage.users,
      onRefresh: controller.loadAll,
      scrollable: false,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _UserMetricRibbon(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          _UserFilterBar(controller: controller),
          const SizedBox(height: AppSizes.spaceBtwItems),
          Expanded(child: _UserTable(controller: controller)),
        ],
      ),
    );
  }
}

// ── 1. Status Ribbon ────────────────────────────────────────────────────────

class _UserMetricRibbon extends StatelessWidget {
  const _UserMetricRibbon({required this.controller});

  final UsersController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final active = controller.statusFilter.value ?? '';
      final allCount = controller.counts[''] ?? 0;
      final activeCount = controller.counts['active'] ?? 0;
      final pendingCount = controller.counts['pending'] ?? 0;
      final inactiveCount = controller.counts['inactive'] ?? 0;

      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _CompactUserRibbonCard(
              label: 'All Users',
              value: NumberFormat('#,##0').format(allCount),
              dotColor: AppColors.primary,
              isSelected: active.isEmpty,
              onTap: () => controller.setStatusFilter(null),
            ),
            const SizedBox(width: 8),
            _CompactUserRibbonCard(
              label: 'Active',
              value: NumberFormat('#,##0').format(activeCount),
              dotColor: AppColors.success,
              isSelected: active == 'active',
              onTap: () => controller.setStatusFilter('active'),
            ),
            const SizedBox(width: 8),
            _CompactUserRibbonCard(
              label: 'Pending',
              value: NumberFormat('#,##0').format(pendingCount),
              dotColor: AppColors.warning,
              isSelected: active == 'pending',
              onTap: () => controller.setStatusFilter('pending'),
            ),
            const SizedBox(width: 8),
            _CompactUserRibbonCard(
              label: 'Inactive',
              value: NumberFormat('#,##0').format(inactiveCount),
              dotColor: AppColors.error,
              isSelected: active == 'inactive',
              onTap: () => controller.setStatusFilter('inactive'),
            ),
          ],
        ),
      );
    });
  }
}

class _CompactUserRibbonCard extends StatelessWidget {
  const _CompactUserRibbonCard({
    required this.label,
    required this.value,
    required this.dotColor,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color dotColor;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 38,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected
              ? dotColor.withValues(alpha: dark ? 0.18 : 0.08)
              : (dark ? AppColors.darkSurface : AppColors.white),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          border: Border.all(
            color: isSelected
                ? dotColor.withValues(alpha: 0.55)
                : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected
                    ? (dark ? AppColors.white : AppColors.textPrimary)
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: dotColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: dotColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 2. Modern Filter Bar ───────────────────────────────────────────────────

class _UserFilterBar extends StatelessWidget {
  const _UserFilterBar({required this.controller});

  final UsersController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;
    final bgColor = dark
        ? AppColors.darkSurface
        : AppColors.white;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSizes.sm, vertical: AppSizes.xs),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          final searchInput = Container(
            height: 36,
            decoration: BoxDecoration(
              color: dark ? AppColors.darkGrey.withValues(alpha: 0.3) : AppColors.grey.withValues(alpha: 0.12),
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
                hintText: 'Search by name, email or UID...',
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
          );

          final filterRow = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Obx(
                () => Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: dark ? AppColors.darkSurface : AppColors.white,
                    borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                    border: Border.all(color: borderColor),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String?>(
                      value: controller.streamFilter.value,
                      isDense: true,
                      hint: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 14, color: AppColors.textSecondary),
                          SizedBox(width: 6),
                          Text('All Streams', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                      icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 16),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All Streams', style: TextStyle(fontSize: 12)),
                        ),
                        ...controller.availableStreams.map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(s, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                      onChanged: controller.setStreamFilter,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              // Registration Date Gap Filter
              Obx(
                () => AdminDateFilterPill(
                  selectedRange: controller.dateRange.value,
                  onRangeChanged: controller.setDateRange,
                  defaultLabel: 'Registration Date',
                ),
              ),
              const SizedBox(width: AppSizes.xs),
              Obx(() {
                final active = controller.streamFilter.value != null ||
                    controller.dateRange.value != null ||
                    controller.searchController.text.isNotEmpty;
                if (!active) return const SizedBox.shrink();
                return IconButton(
                  tooltip: 'Clear filters',
                  visualDensity: VisualDensity.compact,
                  onPressed: controller.clearFilters,
                  icon: const Icon(
                    Icons.filter_alt_off_rounded,
                    size: AppSizes.iconSm,
                    color: AppColors.error,
                  ),
                );
              }),
            ],
          );

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                searchInput,
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: filterRow,
                ),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: searchInput),
              const SizedBox(width: AppSizes.sm),
              filterRow,
            ],
          );
        },
      ),
    );
  }
}

// ── 3. Modern User Table ───────────────────────────────────────────────────

class _UserTable extends StatelessWidget {
  const _UserTable({required this.controller});

  final UsersController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => AdminDataTable<AdminUserModel>(
        rows: controller.rows.toList(),
        isLoading: controller.isLoading.value,
        error: controller.errorMessage.value,
        onRetry: controller.load,
        onRefresh: controller.loadAll,
        emptyTitle: 'No students found',
        emptyMessage: 'Try adjusting your search query or stream filters.',
        page: controller.page.value,
        pageSize: UsersController.pageSize,
        totalCount: controller.totalCount.value,
        onPageChanged: controller.changePage,
        onRowTap: (user) => _openDetail(context, user),
        columns: [
          AdminColumn(
            label: 'STUDENT',
            flex: 3,
            cell: (_, user) => _StudentProfileCell(user: user),
          ),
          AdminColumn(
            label: 'STREAM',
            width: 100,
            cell: (_, user) => _StreamBadge(stream: user.stream),
          ),
          AdminColumn(
            label: 'SUBSCRIPTION',
            width: 120,
            cell: (_, user) => _UserStatusBadge(user: user),
          ),
          AdminColumn(
            label: 'PLAN / EXPIRY',
            flex: 2,
            cell: (_, user) => _PlanExpiryCell(user: user),
          ),
          AdminColumn(
            label: 'UPLOADS',
            width: 80,
            cell: (_, user) => _UploadCountBadge(user: user),
          ),
          AdminColumn(
            label: 'JOINED',
            width: 95,
            cell: (_, user) => Text(
              user.createdAt == null
                  ? '—'
                  : DateFormat('d MMM yyyy').format(user.createdAt!),
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ),
        ],
        rowActions: (context, user) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Delete User Permanently',
              icon: const Icon(
                Icons.delete_outline_rounded,
                size: 16,
                color: AppColors.error,
              ),
              onPressed: () => _confirmDelete(context, user),
            ),
            IconButton(
              tooltip: 'Manage Student',
              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 13),
              onPressed: () => _openDetail(context, user),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AdminUserModel user) async {
    final confirmed = await AppDialogBoxes.confirmTyped(
      title: 'Delete User Permanently',
      message: 'This will permanently delete "${user.displayName}" (${user.email}) '
          'and wipe ALL associated data including test attempts, bookmarks, '
          'receipts, and active sessions.\n\nThis action cannot be undone.',
      expectedText: 'DELETE',
      confirmLabel: 'Permanently Delete',
    );

    if (!confirmed) return;

    await controller.deleteUser(user);
  }

  void _openDetail(BuildContext context, AdminUserModel user) {
    FocusManager.instance.primaryFocus?.unfocus();
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
            constraints: const BoxConstraints(maxWidth: 680, maxHeight: 720),
            child: UserDetailScreen(user: user),
          ),
        ),
      );
    } else {
      Get.to(() => UserDetailScreen(user: user));
    }
  }
}

// ── 4. Table Cell Components ───────────────────────────────────────────────

class _StudentProfileCell extends StatelessWidget {
  const _StudentProfileCell({required this.user});
  final AdminUserModel user;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.8),
                AppColors.primary,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
            child: Text(
              user.initials,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
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
                user.fullName.isNotEmpty ? user.fullName : user.displayName,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                user.email,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StreamBadge extends StatelessWidget {
  const _StreamBadge({required this.stream});
  final String stream;

  @override
  Widget build(BuildContext context) {
    if (stream.isEmpty || stream == '—') {
      return const Text('—', style: TextStyle(fontSize: 12, color: AppColors.textSecondary));
    }

    final isNatural = stream.toLowerCase().contains('natural');
    final color = isNatural ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isNatural ? Icons.science_rounded : Icons.menu_book_rounded,
            size: 11,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              stream,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UserStatusBadge extends StatelessWidget {
  const _UserStatusBadge({required this.user});
  final AdminUserModel user;

  @override
  Widget build(BuildContext context) {
    final status = user.subscriptionStatus;
    final color = subscriptionStatusColor(status);
    final isExpired = user.isExpired;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: (isExpired ? AppColors.error : color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: isExpired ? AppColors.error : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              isExpired ? 'Expired' : status.toUpperCase(),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isExpired ? AppColors.error : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanExpiryCell extends StatelessWidget {
  const _PlanExpiryCell({required this.user});
  final AdminUserModel user;

  @override
  Widget build(BuildContext context) {
    if (user.subscriptionPlan == null || user.subscriptionPlan!.isEmpty) {
      return const Text('—', style: TextStyle(fontSize: 11, color: AppColors.textSecondary));
    }

    final hasExpiry = user.subscriptionExpiresAt != null;
    final isExpired = user.isExpired;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          user.planLabel,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (hasExpiry)
          Text(
            user.remainingDaysText,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: isExpired ? FontWeight.w700 : FontWeight.w500,
              color: isExpired
                  ? AppColors.error
                  : (user.remainingDaysText.contains('left') ? AppColors.success : AppColors.textSecondary),
            ),
          ),
      ],
    );
  }
}

class _UploadCountBadge extends StatelessWidget {
  const _UploadCountBadge({required this.user});
  final AdminUserModel user;

  @override
  Widget build(BuildContext context) {
    final count = user.receiptUploadCount;
    final isMax = user.exceededUploadLimit;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isMax ? AppColors.error : AppColors.primary).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        '$count / 2',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: isMax ? AppColors.error : AppColors.primary,
        ),
      ),
    );
  }
}
