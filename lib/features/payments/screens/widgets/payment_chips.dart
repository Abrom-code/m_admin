import 'package:flutter/material.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

/// Colour for a receipt review status.
Color paymentStatusColor(String status) {
  switch (status) {
    case 'approved':
      return AppColors.success;
    case 'rejected':
      return AppColors.error;
    case 'pending':
    default:
      return AppColors.warning;
  }
}

/// Colour for a user's `subscription_status`.
///
/// Note `'rejected'` is not in this map on purpose: the admin app never writes
/// it to a user, because UserModel's three status getters all return false for
/// it. If it appears here, it came from somewhere else and is a bug worth
/// seeing as "unknown" rather than silently colouring it.
Color subscriptionStatusColor(String status) {
  switch (status) {
    case 'active':
      return AppColors.success;
    case 'pending':
      return AppColors.warning;
    case 'inactive':
      return AppColors.darkGrey;
    default:
      return AppColors.error;
  }
}

/// A small filled pill.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.dense = false,
  });

  final String label;
  final Color color;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 6 : AppSizes.sm,
        vertical: dense ? 2 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: dense ? 10 : 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class PaymentStatusPill extends StatelessWidget {
  const PaymentStatusPill({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: status.isEmpty ? 'unknown' : status,
      color: paymentStatusColor(status),
    );
  }
}

class PaymentMethodChip extends StatelessWidget {
  const PaymentMethodChip({super.key, required this.method});

  final String method;

  static const _colors = <String, Color>{
    'telebirr': AppColors.primary,
    'cbe': AppColors.info,
    'abyssinia': AppColors.amberAccent,
    'mpesa': AppColors.success,
  };

  @override
  Widget build(BuildContext context) {
    final color = _colors[method.toLowerCase()] ?? AppColors.darkGrey;

    return StatusPill(
      label: PaymentMethodInfo.labelOf(method),
      color: color,
      dense: true,
    );
  }
}
