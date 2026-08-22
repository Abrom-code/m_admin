import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/users/models/admin_subscription_plan.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

class ApprovePaymentResult {
  const ApprovePaymentResult({
    required this.amount,
    required this.planKey,
    required this.planDurationMonths,
    required this.expiresAt,
    required this.notificationTitle,
    required this.notificationBody,
  });

  final num amount;
  final String planKey;
  final int planDurationMonths;
  final DateTime expiresAt;
  final String notificationTitle;
  final String notificationBody;
}

/// Dialog to verify payment amount, select matching premium plan, and preview
/// notification details before approving a payment receipt.
class ApprovePaymentDialog extends StatefulWidget {
  const ApprovePaymentDialog({
    super.key,
    required this.review,
  });

  final PaymentReview review;

  static Future<ApprovePaymentResult?> show(
    BuildContext context, {
    required PaymentReview review,
  }) {
    return showDialog<ApprovePaymentResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => ApprovePaymentDialog(review: review),
    );
  }

  @override
  State<ApprovePaymentDialog> createState() => _ApprovePaymentDialogState();
}

class _ApprovePaymentDialogState extends State<ApprovePaymentDialog> {
  late final TextEditingController _amountController;
  late String _selectedPlanKey;
  late bool _extendFromCurrent;
  DateTime? _customExpiryDate;

  @override
  void initState() {
    super.initState();

    final initialPlanKey = widget.review.planKey;
    final initialAmount = widget.review.amount;

    // Match plan from review planKey or match from receipt amount
    if (initialPlanKey != null && AdminSubscriptionPlan.byKey(initialPlanKey) != null) {
      _selectedPlanKey = initialPlanKey;
    } else if (initialAmount != null && AdminSubscriptionPlan.matchByAmount(initialAmount) != null) {
      _selectedPlanKey = AdminSubscriptionPlan.matchByAmount(initialAmount)!.key;
    } else {
      _selectedPlanKey = AdminSubscriptionPlan.defaultPlan.key;
    }

    final defaultPriceForPlan =
        AdminSubscriptionPlan.byKey(_selectedPlanKey)?.defaultPrice ?? 250;
    final resolvedAmount = initialAmount ?? defaultPriceForPlan;
    _amountController =
        TextEditingController(text: resolvedAmount.toStringAsFixed(0));

    // By default, extend if user is already active
    _extendFromCurrent = widget.review.subscriptionStatus == 'active';
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  bool get _isCustom => _selectedPlanKey == 'custom';

  num get _currentAmount =>
      num.tryParse(_amountController.text.trim()) ??
      (AdminSubscriptionPlan.byKey(_selectedPlanKey)?.defaultPrice ?? 250);

  DateTime _calculateFinalExpiry() {
    if (_isCustom) {
      return _customExpiryDate ?? AdminSubscriptionPlan.calculateExpiry(12);
    }

    final plan = AdminSubscriptionPlan.byKey(_selectedPlanKey) ??
        AdminSubscriptionPlan.defaultPlan;

    if (_extendFromCurrent) {
      return AdminSubscriptionPlan.calculateExtendedExpiry(plan.durationMonths);
    }

    return AdminSubscriptionPlan.calculateExpiry(plan.durationMonths);
  }

  int get _planDurationMonths {
    if (_isCustom) {
      final days = _calculateFinalExpiry().difference(DateTime.now()).inDays;
      return (days / 30).round().clamp(1, 120);
    }
    return AdminSubscriptionPlan.byKey(_selectedPlanKey)?.durationMonths ?? 12;
  }

  void _onAmountChanged(String val) {
    final parsed = num.tryParse(val.trim());
    if (parsed != null) {
      final matched = AdminSubscriptionPlan.matchByAmount(parsed);
      if (matched != null && matched.key != _selectedPlanKey) {
        setState(() {
          _selectedPlanKey = matched.key;
        });
      } else {
        setState(() {});
      }
    }
  }

  void _selectPlan(String key) {
    setState(() {
      _selectedPlanKey = key;
      if (key != 'custom') {
        final plan = AdminSubscriptionPlan.byKey(key);
        if (plan != null) {
          _amountController.text = plan.defaultPrice.toString();
        }
      }
    });
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
    final notifTitle =
        AdminSubscriptionPlan.buildApprovalNotificationTitle(_selectedPlanKey);
    final notifBody = AdminSubscriptionPlan.buildApprovalNotificationBody(
      planKey: _selectedPlanKey,
      amount: _currentAmount,
      currency: widget.review.currency,
      expiresAt: finalExpiry,
    );

    return AlertDialog(
      title: const Row(
        children: [
          Icon(
            Icons.verified_user_rounded,
            color: AppColors.success,
            size: 24,
          ),
          SizedBox(width: 10),
          Text(
            'Approve Payment & Grant Premium',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Student banner
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.primary.withValues(alpha: 0.15),
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.review.displayName,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${widget.review.userEmail} · Method: ${widget.review.paymentMethod}',
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

              // Amount verification field
              const Text(
                '1. Verify Amount Paid:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.xs),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: _onAmountChanged,
                      decoration: InputDecoration(
                        labelText: 'Confirmed Amount (${widget.review.currency})',
                        prefixIcon: const Icon(Icons.payments_outlined, size: 18),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.xs),

              // Quick amount chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final plan in AdminSubscriptionPlan.all)
                    ActionChip(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      label: Text(
                        '${plan.defaultPrice} ETB (${plan.title})',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _selectedPlanKey == plan.key
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedPlanKey == plan.key
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                      onPressed: () => _selectPlan(plan.key),
                    ),
                ],
              ),
              const SizedBox(height: AppSizes.md),

              // Plan selection
              const Text(
                '2. Select Matching Premium Plan Duration:',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSizes.xs),

              for (final plan in AdminSubscriptionPlan.all)
                _buildPlanTile(plan),

              _buildCustomTile(),

              if (widget.review.subscriptionStatus == 'active') ...[
                const SizedBox(height: AppSizes.xs),
                Material(
                  color: Colors.transparent,
                  child: SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Extend from active expiration date',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Adds the duration on top of remaining active days',
                      style: TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                    ),
                    value: _extendFromCurrent,
                    onChanged: (val) {
                      setState(() {
                        _extendFromCurrent = val;
                      });
                    },
                  ),
                ),
              ],

              const SizedBox(height: AppSizes.md),

              // Timing & Notification preview
              Container(
                padding: const EdgeInsets.all(AppSizes.sm),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                  border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.notifications_active_rounded,
                          size: 16,
                          color: AppColors.success,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Notification Sent to Student',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.success,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      notifTitle,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      notifBody,
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
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSizes.md,
              vertical: AppSizes.sm,
            ),
          ),
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text('Confirm & Grant Premium'),
          onPressed: () {
            Navigator.of(context).pop(
              ApprovePaymentResult(
                amount: _currentAmount,
                planKey: _selectedPlanKey,
                planDurationMonths: _planDurationMonths,
                expiresAt: finalExpiry,
                notificationTitle: notifTitle,
                notificationBody: notifBody,
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlanTile(AdminSubscriptionPlan plan) {
    final isSelected = _selectedPlanKey == plan.key;

    return InkWell(
      onTap: () => _selectPlan(plan.key),
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: 6,
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
              width: 16,
              height: 16,
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
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  Text(
                    plan.title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  if (plan.badgeText != null) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        plan.badgeText!,
                        style: const TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${plan.defaultPrice} ETB',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTile() {
    final isSelected = _selectedPlanKey == 'custom';

    return InkWell(
      onTap: () {
        setState(() {
          _selectedPlanKey = 'custom';
        });
      },
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 2.5),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.sm,
          vertical: 6,
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
              width: 16,
              height: 16,
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
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 8),
            const Text(
              'Custom Expiry Date',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (isSelected)
              TextButton.icon(
                onPressed: _pickCustomDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 13),
                label: Text(
                  _customExpiryDate != null
                      ? DateFormat('d MMM yyyy').format(_customExpiryDate!)
                      : 'Pick Date',
                  style: const TextStyle(fontSize: 11),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
