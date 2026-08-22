import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/data/repositories/users_repository.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_chips.dart';
import 'package:m_admin/features/users/controllers/users_controller.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/features/users/screens/widgets/subscription_plan_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key, required this.user});

  final AdminUserModel user;

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

enum _DetailAction { none, grant, changePlan, revoke, resetUploads }

class _UserDetailScreenState extends State<UserDetailScreen> {
  final _repo = UsersRepository();
  List<Map<String, dynamic>> _receipts = [];
  bool _loadingReceipts = true;
  _DetailAction _activeAction = _DetailAction.none;

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

  Future<void> _manageSubscription(AdminUserModel user, {bool isGranting = false}) async {
    final result = await SubscriptionPlanDialog.show(
      context,
      user: user,
      isGranting: isGranting,
    );

    if (result == null) return;

    setState(() => _activeAction = isGranting ? _DetailAction.grant : _DetailAction.changePlan);
    try {
      await UsersController.instance.setSubscription(
        user,
        'active',
        plan: result.planKey == 'custom' ? (user.subscriptionPlan ?? 'custom') : result.planKey,
        expiresAt: result.expiresAt,
      );
    } finally {
      if (mounted) setState(() => _activeAction = _DetailAction.none);
    }
  }

  Future<void> _setStatus(String status) async {
    final user = _liveUser;

    if (status == 'active') {
      await _manageSubscription(user, isGranting: true);
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

      setState(() => _activeAction = _DetailAction.revoke);
      try {
        await UsersController.instance
            .setSubscription(user, status, reason: result);
      } finally {
        if (mounted) setState(() => _activeAction = _DetailAction.none);
      }
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

    setState(() => _activeAction = _DetailAction.resetUploads);
    try {
      await UsersController.instance.setReceiptUploadCount(user, 0);
    } finally {
      if (mounted) setState(() => _activeAction = _DetailAction.none);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final user = _liveUser;
      final dark = AppHelperFunctions.isDark(context);

      return Scaffold(
        backgroundColor: dark ? AppColors.dark : AppColors.light,
        appBar: AppBar(
          backgroundColor: dark ? AppColors.darkSurface : AppColors.white,
          title: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(width: 8),
                _UserStatusPill(user: user),
              ],
            ),
          ),
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
              // ── 1. Profile Hero Card ──────────────────────────────────────
              _ProfileHeroCard(user: user),
              const SizedBox(height: AppSizes.spaceBtwItems),

              // ── 2. Subscription & Actions Card ────────────────────────────
              _SubscriptionActionsCard(
                user: user,
                activeAction: _activeAction,
                onGrant: () => _setStatus('active'),
                onChangePlan: () => _manageSubscription(user, isGranting: false),
                onRevoke: () => _setStatus('inactive'),
                onResetUploads: () => _resetUploadCount(user),
              ),
              const SizedBox(height: AppSizes.spaceBtwItems),

              // ── 3. Receipt History Card ───────────────────────────────────
              _ReceiptHistoryCard(
                loading: _loadingReceipts,
                receipts: _receipts,
              ),
            ],
          ),
        ),
      );
    });
  }
}

// ── Profile Hero Card ──────────────────────────────────────────────────────

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({required this.user});
  final AdminUserModel user;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
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
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSizes.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          const Divider(height: 1),
          const SizedBox(height: AppSizes.sm),
          _DetailRow('Firebase UID', user.id, copyable: true),
          _DetailRow('Academic Stream', user.stream.isEmpty ? '—' : user.stream),
          if (user.createdAt != null)
            _DetailRow(
              'Account Created',
              DateFormat('d MMM yyyy · HH:mm').format(user.createdAt!),
            ),
        ],
      ),
    );
  }
}

// ── Subscription & Actions Card ────────────────────────────────────────────

class _SubscriptionActionsCard extends StatelessWidget {
  const _SubscriptionActionsCard({
    required this.user,
    required this.activeAction,
    required this.onGrant,
    required this.onChangePlan,
    required this.onRevoke,
    required this.onResetUploads,
  });

  final AdminUserModel user;
  final _DetailAction activeAction;
  final VoidCallback onGrant;
  final VoidCallback onChangePlan;
  final VoidCallback onRevoke;
  final VoidCallback onResetUploads;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Iconsax.card_pos_copy, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              const Text(
                'Subscription & Plan',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              _UserStatusPill(user: user),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          if (user.subscriptionPlan != null && user.subscriptionPlan!.isNotEmpty) ...[
            _DetailRow('Assigned Plan', user.planLabel),
          ],
          if (user.subscriptionExpiresAt != null) ...[
            _DetailRow(
              'Expiration Date',
              '${DateFormat('d MMM yyyy').format(user.subscriptionExpiresAt!)} (${user.remainingDaysText})',
            ),
          ],
          _DetailRow(
            'Receipt Uploads',
            '${user.receiptUploadCount} / 2 attempts used${user.exceededUploadLimit ? ' (Max limit reached)' : ''}',
          ),
          const SizedBox(height: AppSizes.md),
          const Divider(height: 1),
          const SizedBox(height: AppSizes.md),
          Obx(() {
            final isActing = Get.isRegistered<UsersController>() &&
                UsersController.instance.isActing(user.id);
            final isGrantLoading = isActing && activeAction == _DetailAction.grant;
            final isChangeLoading = isActing && activeAction == _DetailAction.changePlan;
            final isRevokeLoading = isActing && activeAction == _DetailAction.revoke;
            final isResetLoading = isActing && activeAction == _DetailAction.resetUploads;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (!user.isActive && !user.isExpired)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.success,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.md,
                              vertical: 10,
                            ),
                          ),
                          onPressed: isActing ? null : onGrant,
                          icon: isGrantLoading
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.workspace_premium_rounded, size: 16),
                          label: const Text(
                            'Grant Premium',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    if (user.isActive || user.isExpired)
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.md,
                              vertical: 10,
                            ),
                          ),
                          onPressed: isActing ? null : onChangePlan,
                          icon: isChangeLoading
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.edit_calendar_rounded, size: 16),
                          label: Text(
                            user.isExpired
                                ? 'Renew / Extend Plan'
                                : 'Change / Extend Plan',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    if (!user.isInactive) ...[
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.error,
                            side: const BorderSide(color: AppColors.error),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.md,
                              vertical: 10,
                            ),
                          ),
                          onPressed: isActing ? null : onRevoke,
                          icon: isRevokeLoading
                              ? const SizedBox(
                                  height: 14,
                                  width: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.error,
                                  ),
                                )
                              : const Icon(Icons.block_rounded, size: 16),
                          label: const Text(
                            'Revoke Access',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                        ),
                      ),
                    ],
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
                        vertical: 10,
                      ),
                    ),
                    onPressed: isActing ? null : onResetUploads,
                    icon: isResetLoading
                        ? const SizedBox(
                            height: 14,
                            width: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text(
                      'Reset Upload Limit to 0',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Receipt History Card ───────────────────────────────────────────────────

class _ReceiptHistoryCard extends StatelessWidget {
  const _ReceiptHistoryCard({
    required this.loading,
    required this.receipts,
  });

  final bool loading;
  final List<Map<String, dynamic>> receipts;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Iconsax.receipt_2_1_copy, size: 18, color: AppColors.primary),
              SizedBox(width: 8),
              Text(
                'Receipt History',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(AppSizes.md),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          else if (receipts.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSizes.sm),
              child: Text(
                'No receipts submitted by this student yet.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
            )
          else
            Column(
              children: [
                for (final r in receipts) _ReceiptTimelineTile(data: r),
              ],
            ),
        ],
      ),
    );
  }
}

class _ReceiptTimelineTile extends StatelessWidget {
  const _ReceiptTimelineTile({required this.data});
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
        : DateFormat('d MMM yyyy · HH:mm').format(
            DateTime.parse(data['created_at'].toString()),
          );
    final reason = data['rejection_reason']?.toString();
    final color = switch (status) {
      'approved' => AppColors.success,
      'rejected' => AppColors.error,
      _ => AppColors.warning,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: AppSizes.sm),
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                status.toUpperCase(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                date,
                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (method.isNotEmpty)
                PaymentMethodChip(method: method),
              if (planLabel.isNotEmpty) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    planLabel,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          if (reason != null && reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Rejection reason: $reason',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Shared Widgets ─────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value, {this.copyable = false});

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
            ),
          ),
          if (copyable)
            IconButton(
              tooltip: 'Copy to clipboard',
              iconSize: 14,
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: value));
                SnackbarHelper.success('Copied', '$label copied to clipboard.');
              },
              icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}

class _UserStatusPill extends StatelessWidget {
  const _UserStatusPill({required this.user});
  final AdminUserModel user;

  @override
  Widget build(BuildContext context) {
    final status = user.subscriptionStatus;
    final color = subscriptionStatusColor(status);
    final isExpired = user.isExpired;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (isExpired ? AppColors.error : color).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: isExpired ? AppColors.error : color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            isExpired ? 'Expired' : status.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: isExpired ? AppColors.error : color,
            ),
          ),
        ],
      ),
    );
  }
}
