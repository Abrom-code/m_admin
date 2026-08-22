import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/data/repositories/admin_payment_repository.dart';
import 'package:m_admin/features/payments/controllers/payments_controller.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/screens/widgets/approve_payment_dialog.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_chips.dart';
import 'package:m_admin/features/payments/screens/widgets/receipt_viewer.dart';
import 'package:m_admin/features/payments/screens/widgets/reject_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Modern, content-first payment receipt review & audit screen.
class PaymentDetailScreen extends StatefulWidget {
  const PaymentDetailScreen({
    super.key,
    required this.review,
    this.isSideSheet = false,
  });

  final PaymentReview review;
  final bool isSideSheet;

  @override
  State<PaymentDetailScreen> createState() => _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends State<PaymentDetailScreen> {
  final _controller = PaymentsController.instance;
  final _repo = AdminPaymentRepository();
  final _focusNode = FocusNode();

  late PaymentReview _review;

  @override
  void initState() {
    super.initState();
    _review = widget.review;
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body = Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKey,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final twoPane = constraints.maxWidth >= 760;

          final left = ReceiptViewer(
            review: _review,
            resolveUrl: () => _repo.signedReceiptUrl(
              _review.receiptPath,
              fallbackUrl: _review.receiptUrl,
            ),
          );

          final right = SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.md),
            child: _ModernDetailPane(review: _review),
          );

          if (!twoPane) {
            return Column(
              children: [
                SizedBox(height: 320, child: left),
                Expanded(child: right),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(flex: 5, child: left),
              const VerticalDivider(width: 1),
              Expanded(flex: 4, child: right),
            ],
          );
        },
      ),
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Receipt #${_review.id}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(width: 10),
              PaymentMethodChip(method: _review.paymentMethod),
              if (_review.amount != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${_review.amount!.toStringAsFixed(0)} ${_review.currency}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.md),
            child: Center(child: PaymentStatusPill(status: _review.status)),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: _ModernActionBar(
        review: _review,
        onApprove: _approve,
        onReject: _reject,
      ),
    );
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    switch (event.logicalKey) {
      case LogicalKeyboardKey.keyA:
        if (_review.isPending) _approve();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyR:
        if (_review.isPending) _reject();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyJ:
        _goToNeighbour(1);
        return KeyEventResult.handled;
      case LogicalKeyboardKey.keyK:
        _goToNeighbour(-1);
        return KeyEventResult.handled;
      default:
        return KeyEventResult.ignored;
    }
  }

  void _goToNeighbour(int offset) {
    final next = _controller.neighbourOf(_review, offset);
    if (next == null) return;
    setState(() => _review = next);
  }

  Future<void> _approve() async {
    if (_controller.isActing(_review.id)) return;

    final result = await ApprovePaymentDialog.show(context, review: _review);
    if (result == null) return;

    final ok = await _controller.approve(
      _review,
      amount: result.amount,
      planKey: result.planKey == 'custom' ? _review.planKey : result.planKey,
      planDurationMonths: result.planDurationMonths,
      expiresAt: result.expiresAt,
      notificationTitle: result.notificationTitle,
      notificationBody: result.notificationBody,
    );
    if (!mounted) return;

    if (ok) _advance();
  }

  Future<void> _reject() async {
    if (_controller.isActing(_review.id)) return;

    final reason = await showRejectDialog(context);
    if (reason == null || reason.trim().isEmpty) return;

    final ok = await _controller.reject(_review, reason);
    if (!mounted) return;

    if (ok) _advance();
  }

  void _advance() {
    final next = _controller.nextPendingAfter(_review);

    if (next == null) {
      Navigator.of(context).maybePop();
      return;
    }

    setState(() => _review = next);
  }
}

// ── Right Detail Pane ──────────────────────────────────────────────────────

class _ModernDetailPane extends StatelessWidget {
  const _ModernDetailPane({required this.review});

  final PaymentReview review;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final method = PaymentMethodInfo.of(review.paymentMethod);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── 1. Student Identity Card ──────────────────────────────
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: Text(
                      review.displayName.isNotEmpty
                          ? review.displayName[0].toUpperCase()
                          : 'S',
                      style: const TextStyle(
                        fontSize: 13,
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
                          review.displayName,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: dark ? AppColors.white : AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          review.userEmail,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (review.userStream.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (review.userStream.toLowerCase() == 'natural'
                                ? AppColors.primary
                                : AppColors.amberAccent)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        review.userStream,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: review.userStream.toLowerCase() == 'natural'
                              ? AppColors.primary
                              : AppColors.amberAccent,
                        ),
                      ),
                    ),
                ],
              ),
              const Divider(height: 20),
              _DetailRow(
                label: 'Current Status',
                valueWidget: StatusPill(
                  label: review.subscriptionStatus,
                  color: subscriptionStatusColor(review.subscriptionStatus),
                  dense: true,
                ),
              ),
              _DetailRow(
                label: 'User ID',
                value: review.userId,
                copyable: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spaceBtwItems),

        // ── 2. Payment & Verification Card ─────────────────────────
        AdminCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PAYMENT TRANSACTION',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSizes.sm),
              _DetailRow(
                label: 'Selected Plan',
                value: review.planLabel,
              ),
              _DetailRow(
                label: 'Verified Amount',
                value: review.amount != null
                    ? '${review.amount!.toStringAsFixed(0)} ${review.currency}'
                    : '—',
              ),
              _DetailRow(
                label: 'Payment Method',
                value: PaymentMethodInfo.labelOf(review.paymentMethod),
              ),
              if (method != null)
                _DetailRow(
                  label: 'Account / Holder',
                  value: '${method.account} · ${method.holder}',
                  copyable: true,
                ),
              _DetailRow(
                label: 'Submitted At',
                value: review.createdAt == null
                    ? '—'
                    : DateFormat('d MMM yyyy, HH:mm').format(review.createdAt!),
              ),
              if (review.verificationUrl.isNotEmpty) ...[
                const SizedBox(height: 4),
                _DetailRow(
                  label: 'Bank Verification',
                  value: review.verificationUrl,
                  onTap: () =>
                      AppHelperFunctions.openUrl(review.verificationUrl),
                ),
              ],
            ],
          ),
        ),

        // ── 3. Review Outcome (if already reviewed) ────────────────
        if (review.isReviewed) ...[
          const SizedBox(height: AppSizes.spaceBtwItems),
          AdminCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'REVIEW AUDIT LOG',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                _DetailRow(label: 'Outcome', value: review.status),
                _DetailRow(
                  label: 'Reviewed At',
                  value: review.reviewedAt == null
                      ? '—'
                      : DateFormat('d MMM yyyy, HH:mm')
                          .format(review.reviewedAt!),
                ),
                _DetailRow(
                  label: 'Reviewed By',
                  value: review.reviewedBy ?? '—',
                ),
                if ((review.rejectionReason ?? '').isNotEmpty)
                  _DetailRow(
                    label: 'Decline Reason',
                    value: review.rejectionReason,
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    this.value,
    this.valueWidget,
    this.copyable = false,
    this.onTap,
  });

  final String label;
  final String? value;
  final Widget? valueWidget;
  final bool copyable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: valueWidget ??
                (onTap != null
                    ? InkWell(
                        onTap: onTap,
                        child: Text(
                          value ?? '',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.info,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      )
                    : SelectableText(
                        value ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: dark ? AppColors.white : AppColors.textPrimary,
                        ),
                      )),
          ),
          if (copyable && value != null)
            InkWell(
              onTap: () {
                Clipboard.setData(ClipboardData(text: value!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    duration: Duration(seconds: 1),
                  ),
                );
              },
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Iconsax.copy_copy,
                  size: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Bottom Action Bar ──────────────────────────────────────────────────────

class _ModernActionBar extends StatelessWidget {
  const _ModernActionBar({
    required this.review,
    required this.onApprove,
    required this.onReject,
  });

  final PaymentReview review;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final controller = PaymentsController.instance;
    final dark = AppHelperFunctions.isDark(context);

    if (!review.isPending) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : AppColors.white,
          border: Border(
            top: BorderSide(
              color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              review.isApproved
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              size: 16,
              color: paymentStatusColor(review.status),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Already marked as ${review.status.toUpperCase()}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: paymentStatusColor(review.status),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Obx(() {
      final busy = controller.isActing(review.id);

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : AppColors.white,
          border: Border(
            top: BorderSide(
              color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
            ),
          ),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 600;

            return Row(
              children: [
                if (!isCompact)
                  const Expanded(
                    child: Text(
                      'Shortcuts: [A] Approve · [R] Reject · [J/K] Next/Prev',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                if (isCompact) const Spacer(),
                OutlinedButton.icon(
                  onPressed: busy ? null : onReject,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  icon: const Icon(Icons.close_rounded, size: 15),
                  label: const Text('Decline', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: AppSizes.sm),
                ElevatedButton.icon(
                  onPressed: busy ? null : onApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: busy
                      ? const SizedBox(
                          height: 14,
                          width: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded, size: 16),
                  label: const Text(
                    'Approve & Grant Plan',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            );
          },
        ),
      );
    });
  }
}
