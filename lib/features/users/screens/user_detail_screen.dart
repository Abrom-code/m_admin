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

  AdminUserModel get _liveUser {
    if (!Get.isRegistered<UsersController>()) return widget.user;
    final controller = UsersController.instance;
    final idx = controller.rows.indexWhere((r) => r.id == widget.user.id);
    return idx != -1 ? controller.rows[idx] : widget.user;
  }

  Future<void> _grantPremiumWithPlan(AdminUserModel user) async {
    const plans = [
      {'key': '6_months', 'label': '6 Months', 'months': 6},
      {'key': '1_year', 'label': '1 Year (Default)', 'months': 12},
      {'key': '2_years', 'label': '2 Years', 'months': 24},
      {'key': '3_years', 'label': '3 Years', 'months': 36},
      {'key': '4_years', 'label': '4 Years', 'months': 48},
    ];

    String selectedPlanKey = '1_year';
    int selectedMonths = 12;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Grant Premium Access'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select subscription plan duration for ${user.displayName}:',
                    style: const TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  for (final p in plans)
                    InkWell(
                      onTap: () {
                        setDialogState(() {
                          selectedPlanKey = p['key'] as String;
                          selectedMonths = p['months'] as int;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Radio<String>(
                              value: p['key'] as String,
                              groupValue: selectedPlanKey,
                              onChanged: (val) {
                                if (val != null) {
                                  setDialogState(() {
                                    selectedPlanKey = val;
                                    selectedMonths = p['months'] as int;
                                  });
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Text(p['label'] as String),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: const Text('Grant Access'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final now = DateTime.now();
    final expiry = DateTime(now.year, now.month + selectedMonths, now.day);

    await UsersController.instance.setSubscription(
      user,
      'active',
      plan: selectedPlanKey,
      expiresAt: expiry,
    );
  }

  Future<void> _setStatus(String status) async {
    final user = _liveUser;

    if (status == 'active') {
      await _grantPremiumWithPlan(user);
      return;
    }

    if (status == 'inactive') {
      final result = await AppDialogBoxes.confirmWithReason(
        title: 'Revoke premium',
        message: 'Manually revoke premium access for ${user.displayName}? '
            'This will deactivate their subscription.',
        confirmLabel: 'Revoke premium',
        reasonHint: 'Reason for revoking (included in notification)',
      );
      if (result == null) return;

      await UsersController.instance
          .setSubscription(user, status, reason: result);
      return;
    }

    final confirmed = await AppDialogBoxes.confirm(
      title: 'Set $status',
      message: 'Change ${user.displayName}\'s subscription to "$status"?',
      confirmLabel: 'Confirm',
      isDestructive: false,
    );
    if (!confirmed) return;

    await UsersController.instance.setSubscription(user, status);
  }

  Future<void> _resetUploadCount(AdminUserModel user) async {
    final confirmed = await AppDialogBoxes.confirm(
      title: 'Reset upload limit',
      message:
          'Reset receipt upload attempts for ${user.displayName} from ${user.receiptUploadCount} back to 0?',
      confirmLabel: 'Reset to 0',
      isDestructive: false,
    );
    if (!confirmed) return;

    await UsersController.instance.setReceiptUploadCount(user, 0);
  }

  @override
  Widget build(BuildContext context) {
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
              title: 'Subscription & Upload Limit',
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
                      if (user.isExpired)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius:
                                BorderRadius.circular(AppSizes.borderRadiusSm),
                          ),
                          child: const Text(
                            'EXPIRED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
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
                  if (user.subscriptionPlan != null &&
                      user.subscriptionPlan!.isNotEmpty) ...[
                    const SizedBox(height: AppSizes.sm),
                    _Row('Plan', user.planLabel),
                  ],
                  if (user.subscriptionExpiresAt != null) ...[
                    const SizedBox(height: AppSizes.sm),
                    _Row(
                      'Expires',
                      '${DateFormat('d MMM yyyy').format(user.subscriptionExpiresAt!)} (${user.remainingDaysText})',
                    ),
                  ],
                  const SizedBox(height: AppSizes.sm),
                  Row(
                    children: [
                      const Text(
                        'Upload attempts',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: (user.exceededUploadLimit
                                  ? AppColors.error
                                  : AppColors.primary)
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppSizes.borderRadiusSm),
                        ),
                        child: Text(
                          '${user.receiptUploadCount} / 2${user.exceededUploadLimit ? ' (Limit Reached)' : ''}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: user.exceededUploadLimit
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spaceBtwItems),
                  Obx(() {
                    final acting = Get.isRegistered<UsersController>() &&
                        UsersController.instance.isActing(user.id);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
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
                        ),
                        if (user.receiptUploadCount > 0) ...[
                          const SizedBox(height: AppSizes.sm),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.md,
                                vertical: AppSizes.sm,
                              ),
                            ),
                            onPressed: acting ? null : () => _resetUploadCount(user),
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Reset upload limit to 0'),
                          ),
                        ],
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
    final planKey = data['plan_key']?.toString();
    final planLabel = switch (planKey) {
      '6_months' => '6 Months',
      '1_year' => '1 Year',
      '2_years' => '2 Years',
      '3_years' => '3 Years',
      '4_years' => '4 Years',
      _ => planKey ?? '',
    };
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
                      method.isEmpty
                          ? ''
                          : '· $method${planLabel.isNotEmpty ? ' ($planLabel)' : ''}',
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
