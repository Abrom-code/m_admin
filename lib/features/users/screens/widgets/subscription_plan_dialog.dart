import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/features/users/models/admin_subscription_plan.dart';
import 'package:m_admin/features/users/models/admin_user_model.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

class SubscriptionPlanResult {
  const SubscriptionPlanResult({
    required this.planKey,
    required this.expiresAt,
  });

  final String planKey;
  final DateTime expiresAt;
}

/// Dialog to grant, change, or extend subscription duration for a user.
class SubscriptionPlanDialog extends StatefulWidget {
  const SubscriptionPlanDialog({
    super.key,
    required this.user,
    this.isGranting = false,
  });

  final AdminUserModel user;
  final bool isGranting;

  static Future<SubscriptionPlanResult?> show(
    BuildContext context, {
    required AdminUserModel user,
    bool isGranting = false,
  }) {
    return showDialog<SubscriptionPlanResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => SubscriptionPlanDialog(
        user: user,
        isGranting: isGranting,
      ),
    );
  }

  @override
  State<SubscriptionPlanDialog> createState() => _SubscriptionPlanDialogState();
}

class _SubscriptionPlanDialogState extends State<SubscriptionPlanDialog> {
  late String _selectedPlanKey;
  late bool _extendFromCurrent;
  DateTime? _customExpiryDate;

  @override
  void initState() {
    super.initState();
    // Default to the user's current plan if valid, else 1_year
    final currentKey = widget.user.subscriptionPlan;
    if (currentKey != null && AdminSubscriptionPlan.byKey(currentKey) != null) {
      _selectedPlanKey = currentKey;
    } else {
      _selectedPlanKey = AdminSubscriptionPlan.defaultPlan.key;
    }

    // Default to extending if user has active remaining subscription
    _extendFromCurrent = widget.user.isActive &&
        widget.user.subscriptionExpiresAt != null &&
        widget.user.subscriptionExpiresAt!.isAfter(DateTime.now());

    if (widget.user.subscriptionExpiresAt != null) {
      _customExpiryDate = widget.user.subscriptionExpiresAt;
    } else {
      _customExpiryDate = AdminSubscriptionPlan.calculateExpiry(12);
    }
  }

  bool get _isCustom => _selectedPlanKey == 'custom';

  DateTime _calculateFinalExpiry() {
    if (_isCustom) {
      return _customExpiryDate ?? AdminSubscriptionPlan.calculateExpiry(12);
    }

    final plan = AdminSubscriptionPlan.byKey(_selectedPlanKey) ??
        AdminSubscriptionPlan.defaultPlan;

    if (_extendFromCurrent &&
        widget.user.subscriptionExpiresAt != null &&
        widget.user.subscriptionExpiresAt!.isAfter(DateTime.now())) {
      return AdminSubscriptionPlan.calculateExtendedExpiry(
        plan.durationMonths,
        currentExpiry: widget.user.subscriptionExpiresAt,
      );
    } else {
      return AdminSubscriptionPlan.calculateExpiry(plan.durationMonths);
    }
  }

  Future<void> _pickCustomDate() async {
    final now = DateTime.now();
    final initial = _customExpiryDate ?? now.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 10)),
    );

    if (picked != null) {
      setState(() {
        _customExpiryDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final finalExpiry = _calculateFinalExpiry();
    final now = DateTime.now();
    final diffDays = finalExpiry.difference(now).inDays;
    final hasActiveTime = widget.user.isActive &&
        widget.user.subscriptionExpiresAt != null &&
        widget.user.subscriptionExpiresAt!.isAfter(now);

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            widget.isGranting
                ? Icons.workspace_premium_rounded
                : Icons.edit_calendar_rounded,
            color: AppColors.primary,
            size: 22,
          ),
          const SizedBox(width: 10),
          Text(
            widget.isGranting
                ? 'Grant Premium Access'
                : 'Change Subscription Time',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User header
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      child: Text(
                        widget.user.initials,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.user.displayName,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            widget.user.email,
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
              const SizedBox(height: AppSizes.md),

              const Text(
                'Select Subscription Plan / Duration:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSizes.xs),

              // Standard Plan Cards
              for (final plan in AdminSubscriptionPlan.all)
                _buildPlanCard(
                  key: plan.key,
                  title: plan.title,
                  subtitle: plan.subtitle,
                  months: plan.durationMonths,
                  badge: plan.badgeText,
                  defaultPrice: plan.defaultPrice,
                ),

              // Custom Expiry Option
              _buildCustomDateCard(),

              // If user already has active time, provide toggle for extending vs fresh start
              if (hasActiveTime && !_isCustom) ...[
                const SizedBox(height: AppSizes.sm),
                Container(
                  padding: const EdgeInsets.all(AppSizes.sm),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.08),
                    borderRadius:
                        BorderRadius.circular(AppSizes.borderRadiusSm),
                    border: Border.all(
                      color: AppColors.info.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 18,
                        color: AppColors.info,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Extend from current expiry date?',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              'Current expiry: ${DateFormat('d MMM yyyy').format(widget.user.subscriptionExpiresAt!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _extendFromCurrent,
                        onChanged: (val) {
                          setState(() {
                            _extendFromCurrent = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: AppSizes.md),

              // Result preview box
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Target Subscription Summary',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Selected plan:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          _isCustom
                              ? 'Custom Expiry'
                              : AdminSubscriptionPlan.labelOf(_selectedPlanKey),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Expires at:',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          '${DateFormat('d MMM yyyy').format(finalExpiry)} ($diffDays days left)',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
          ),
          onPressed: () {
            Navigator.of(context).pop(
              SubscriptionPlanResult(
                planKey: _selectedPlanKey,
                expiresAt: finalExpiry,
              ),
            );
          },
          child: Text(widget.isGranting ? 'Grant Access' : 'Save Changes'),
        ),
      ],
    );
  }

  Widget _buildPlanCard({
    required String key,
    required String title,
    required String subtitle,
    required int months,
    String? badge,
    required int defaultPrice,
  }) {
    final isSelected = _selectedPlanKey == key;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlanKey = key;
        });
      },
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.borderPrimary.withValues(alpha: 0.6),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                      if (badge != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            badge,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
            Text(
              '$defaultPrice ETB',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomDateCard() {
    final isSelected = _selectedPlanKey == 'custom';

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlanKey = 'custom';
        });
      },
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.borderPrimary.withValues(alpha: 0.6),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textSecondary,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Center(
                      child: Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Custom Expiry Date',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Manually pick an exact expiration date',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              TextButton.icon(
                onPressed: _pickCustomDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 14),
                label: Text(
                  _customExpiryDate != null
                      ? DateFormat('d MMM yyyy').format(_customExpiryDate!)
                      : 'Pick Date',
                  style: const TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
