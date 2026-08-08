import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  late AdminUserModel _user;
  List<Map<String, dynamic>> _receipts = [];
  bool _loadingReceipts = true;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    try {
      final rows = await _repo.fetchReceiptsFor(_user.id);
      if (mounted) setState(() => _receipts = rows);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingReceipts = false);
    }
  }

  Future<void> _setStatus(String status) async {
    final verb = switch (status) {
      'active' => 'Grant premium',
      'inactive' => 'Revoke premium',
      _ => 'Set $status',
    };

    final confirmed = await AppDialogBoxes.confirm(
      title: verb,
      message: 'Manually change ${_user.displayName}\'s subscription '
          'to "$status"? This overrides any pending receipt review.',
      confirmLabel: verb,
      isDestructive: status == 'inactive',
    );
    if (!confirmed) return;

    await UsersController.instance.setSubscription(_user, status);
    if (mounted) setState(() => _user = _user.copyWith(subscriptionStatus: status));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_user.displayName),
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
                  _Row('ID (Firebase UID)', _user.id, copyable: true),
                  _Row('Name', _user.displayName),
                  _Row('Email', _user.email, copyable: true),
                  _Row('Stream',
                      _user.stream.isEmpty ? '—' : _user.stream),
                  if (_user.createdAt != null)
                    _Row(
                      'Joined',
                      DateFormat('d MMM yyyy').format(_user.createdAt!),
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
                          color: subscriptionStatusColor(_user.subscriptionStatus)
                              .withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppSizes.borderRadiusSm),
                        ),
                        child: Text(
                          _user.subscriptionStatus,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: subscriptionStatusColor(
                              _user.subscriptionStatus,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.spaceBtwItems),
                  Row(
                    children: [
                      if (!_user.isActive)
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.md,
                                vertical: AppSizes.sm,
                              ),
                            ),
                            onPressed: () => _setStatus('active'),
                            icon: const Icon(Icons.check_circle_outline, size: 18),
                            label: const Text('Grant premium'),
                          ),
                        ),
                      if (!_user.isActive && !_user.isInactive)
                        const SizedBox(width: AppSizes.sm),
                      if (!_user.isInactive)
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
                            onPressed: () => _setStatus('inactive'),
                            icon: const Icon(Icons.block, size: 18),
                            label: const Text('Revoke premium'),
                          ),
                        ),
                    ],
                  ),
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
