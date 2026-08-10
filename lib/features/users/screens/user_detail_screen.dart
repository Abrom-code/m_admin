import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/data/repositories/users_repository.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_chips.dart';
import 'package:m_admin/features/users/controllers/users_controller.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.user});

  final AdminUserModel user;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _repo = UsersRepository();
  List<Map<String, dynamic>> _receipts = [];
  bool _loadingReceipts = true;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    try {
      final rows = await _repo.fetchReceiptsFor(widget.user.id);
      if (mounted) setState(() => _receipts = rows);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingReceipts = false);
    }
  }

  /// Returns the freshest copy of this user: from the controller's live list
  /// if present (so status changes propagate), otherwise falls back to the
  /// widget argument.
  AdminUserModel get _liveUser {
    if (!Get.isRegistered<UsersController>()) return widget.user;
    final controller = UsersController.instance;
    final idx = controller.rows.indexWhere((r) => r.id == widget.user.id);
    return idx != -1 ? controller.rows[idx] : widget.user;
  }

  Future<void> _setStatus(String status) async {
    final user = _liveUser;
    final verb = switch (status) {
      'active' => 'Grant premium',
      'inactive' => 'Revoke premium',
      _ => 'Set $status',
    };

    final confirmed = await AppDialogBoxes.confirm(
      title: verb,
      message: 'Manually change ${user.displayName}\'s subscription '
          'to "$status"? This overrides any pending receipt review.',
      confirmLabel: verb,
      isDestructive: status == 'inactive',
    );
    if (!confirmed) return;

    await UsersController.instance.setSubscription(user, status);
  }

  @override
  Widget build(BuildContext context) {
    // Obx re-renders whenever UsersController.rows changes, so the status
    // pill and action buttons stay accurate after any external update.
    return Obx(() {
      final user = _liveUser;
      return _buildScaffold(context, user);
    });
  }

  Widget _buildScaffold(BuildContext context, AdminUserModel user) {
    return Scaffold(
      appBar: AppBar(
        title: Text(user.displayName),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminSection(
              title: 'Profile',
              child: Column(
                children: [
                  _Row('ID (Firebase UID)', user.id, copyable: true),
                  _Row('Name', user.displayName),
                  _Row('Email', user.email, copyable: true),
                  _Row('Stream', user.stream.isEmpty ? '—' : user.stream),
                  if (user.createdAt != null)
                    _Row(
                      'Joined',
                      DateFormat('d MMM yyyy').format(user.createdAt!),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            AdminSection(
              title: 'Subscription',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'Current status',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: subscriptionStatusColor(user.subscriptionStatus)
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppSizes.borderRadiusSm),
                        ),
                        child: Text(
                          user.subscriptionStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: subscriptionStatusColor(
                              user.subscriptionStatus,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spaceBtwItems),
                  Obx(() {
                    final acting = Get.isRegistered<UsersController>() &&
                        UsersController.instance.isActing(user.id);
                    return Row(
                      children: [
                        if (!user.isActive)
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.md,
                                  vertical: AppSizes.sm,
                                ),
                              ),
                              onPressed: acting ? null : () => _setStatus('active'),
                              icon: acting
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.white,
                                      ),
                                    )
                                  : const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Grant premium'),
                            ),
                          ),
                        if (!user.isActive && !user.isInactive)
                          const SizedBox(width: AppSizes.sm),
                        if (!user.isInactive)
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.error,
                                side: const BorderSide(color: AppColors.error),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSizes.md,
                                  vertical: AppSizes.sm,
                                ),
                              ),
                              onPressed: acting ? null : () => _setStatus('inactive'),
                              icon: acting
                                  ? const SizedBox(
                                      height: 14,
                                      width: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.error,
                                      ),
                                    )
                                  : const Icon(Icons.block, size: 18),
                              label: const Text('Revoke premium'),
                            ),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            AdminSection(
              title: 'Receipt history',
              child: _loadingReceipts
                  ? const Padding(
                      padding: EdgeInsets.all(AppSizes.md),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _receipts.isEmpty
                      ? const Text(
                          'No receipts submitted.',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        )
                      : Column(
                          children: [
                            for (final r in _receipts) _ReceiptRow(data: r),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.copyable = false});

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: 'Copy',
              iconSize: AppSizes.iconSm,
              visualDensity: VisualDensity.compact,
              onPressed: () => Clipboard.setData(ClipboardData(text: value)),
              icon: const Icon(Icons.copy_rounded),
            ),
        ],
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.data});

  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final status = data['status']?.toString() ?? '';
    final method = data['payment_method']?.toString() ?? '';
    final date = data['created_at'] == null
        ? '—'
        : DateFormat('d MMM yyyy').format(
            DateTime.parse(data['created_at'].toString()),
          );
    final reason = data['rejection_reason']?.toString();
    final color = switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 6,
            height: 6,
            margin: const EdgeInsets.only(top: 5, right: AppSizes.sm),
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      date,
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    Text(
                      method.isEmpty ? '' : '· $method',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      status,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
                if (reason != null && reason.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      reason,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
