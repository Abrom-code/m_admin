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
      pageIndex: 3,
      onRefresh: controller.loadAll,
      scrollable: false,
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

  static const _tabs = [
    ('', 'All'),
    ('active', 'Active'),
    ('pending', 'Pending'),
    ('inactive', 'Inactive'),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Wrap(
        spacing: AppSizes.xs,
        runSpacing: AppSizes.xs,
        children: [
          for (final (key, label) in _tabs)
            ChoiceChip(
              showCheckmark: false,
              selected: (controller.statusFilter.value ?? '') == key,
              onSelected: (_) => controller.setStatusFilter(
                key.isEmpty ? null : key,
              ),
              label: Text(
                controller.counts[key] == null
                    ? label
                    : '$label (${controller.counts[key]})',
                style: const TextStyle(fontSize: 11),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              visualDensity: VisualDensity.compact,
            ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatefulWidget {
  const _FilterBar({required this.controller});
  final UsersController controller;

  @override
  State<_FilterBar> createState() => _FilterBarState();
}

class _FilterBarState extends State<_FilterBar> {
  bool _searchOpen = false;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() => _searchOpen = !_searchOpen);
    if (_searchOpen) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _focus.requestFocus());
    } else {
      _focus.unfocus();
      widget.controller.searchController.clear();
      widget.controller.onSearchChanged('');
    }
  }

  @override
  Widget build(BuildContext context) {
    final borderColor =
        Theme.of(context).colorScheme.outline.withValues(alpha: 0.35);

    return AdminCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: 6,
      ),
      child: Row(
        children: [
          if (_searchOpen) ...[
            // ── Search mode: close + full-width field ───────────────
            IconButton(
              tooltip: 'Close',
              visualDensity: VisualDensity.compact,
              onPressed: _toggleSearch,
              icon: const Icon(Icons.close_rounded, size: AppSizes.iconSm),
            ),
            Expanded(
              child: TextField(
                controller: widget.controller.searchController,
                focusNode: _focus,
                onChanged: widget.controller.onSearchChanged,
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  isDense: true,
                  hintText: 'Name or email…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 4),
                ),
              ),
            ),
          ] else ...[
            // ── Default mode: search icon + pills ───────────────────
            IconButton(
              tooltip: 'Search',
              visualDensity: VisualDensity.compact,
              onPressed: _toggleSearch,
              icon: const Icon(Icons.search_rounded, size: AppSizes.iconSm),
            ),
            const Spacer(),
            // Stream dropdown pill
            Obx(
              () => _FilterDropdown<String?>(
                borderColor: borderColor,
                icon: Icons.tune_rounded,
                hint: 'Stream',
                value: widget.controller.streamFilter.value,
                items: [
                  const DropdownMenuItem(
                      value: null, child: Text('All streams')),
                  ...widget.controller.availableStreams.map(
                    (s) => DropdownMenuItem(value: s, child: Text(s)),
                  ),
                ],
                onChanged: widget.controller.setStreamFilter,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            // Clear (only when a filter is active)
            Obx(() {
              final active =
                  widget.controller.streamFilter.value != null ||
                      widget.controller.searchController.text.isNotEmpty;
              if (!active) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear filters',
                visualDensity: VisualDensity.compact,
                onPressed: widget.controller.clearFilters,
                icon: const Icon(
                  Icons.filter_alt_off_rounded,
                  size: AppSizes.iconSm,
                ),
              );
            }),
          ],
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

// ── Shared filter dropdown pill ────────────────────────────────────────

class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.borderColor,
    required this.icon,
    required this.hint,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final Color borderColor;
  final IconData icon;
  final String hint;
  final T? value;
  final List<DropdownMenuItem<T?>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13),
              const SizedBox(width: 5),
              Text(hint, style: const TextStyle(fontSize: 12)),
            ],
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 14),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Status pill ────────────────────────────────────────────────────────

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
