import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/data/repositories/admin_payment_repository.dart';
import 'package:m_admin/features/payments/controllers/payments_controller.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/features/payments/screens/widgets/payment_chips.dart';
import 'package:m_admin/features/payments/screens/widgets/receipt_viewer.dart';
import 'package:m_admin/features/payments/screens/widgets/reject_dialog.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Full review surface for a single receipt.
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
            child: _DetailPane(review: _review),
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
        title: Text('Receipt #${_review.id}'),
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
      bottomNavigationBar: _ActionBar(
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

    final amount = _review.amount ?? 250;

    final confirmed = await AppDialogBoxes.confirm(
      title: 'Approve payment',
      message:
          'Grant ${_review.planLabel} premium access to ${_review.displayName} '
          '(${_review.userEmail})?',
      confirmLabel: 'Approve',
      detail: _ConfirmDetail(
        rows: {
          'Plan': _review.planLabel,
          'Amount': '$amount ${_review.currency}',
          'Method': PaymentMethodInfo.labelOf(_review.paymentMethod),
          'Current status': _review.subscriptionStatus,
        },
      ),
    );

    if (!confirmed) return;

    final ok = await _controller.approve(_review, amount: amount);
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

// ── Right pane ────────────────────────────────────────────────────────

class _DetailPane extends StatelessWidget {
  const _DetailPane({required this.review});

  final PaymentReview review;

  @override
  Widget build(BuildContext context) {
    final method = PaymentMethodInfo.of(review.paymentMethod);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Student ──────────────────────────────────────────────
        AdminSection(
          title: 'Student',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValue(label: 'Name', value: review.displayName),
              _KeyValue(label: 'Email', value: review.userEmail),
              _KeyValue(
                label: 'Stream',
                value: review.userStream.isEmpty ? '—' : review.userStream,
              ),
              _KeyValue(label: 'User ID', value: review.userId, copyable: true),
              Padding(
                padding: const EdgeInsets.only(top: AppSizes.sm),
                child: Row(
                  children: [
                    const Text(
                      'Current access',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    StatusPill(
                      label: review.subscriptionStatus,
                      color: subscriptionStatusColor(review.subscriptionStatus),
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSizes.spaceBtwItems),

        // ── Payment ──────────────────────────────────────────────
        AdminSection(
          title: 'Payment',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _KeyValue(label: 'Plan', value: review.planLabel),
              _KeyValue(
                label: 'Amount',
                value: review.amount != null
                    ? '${review.amount} ${review.currency}'
                    : '—',
              ),
              _KeyValue(
                label: 'Method',
                value: PaymentMethodInfo.labelOf(review.paymentMethod),
              ),
              if (method != null) ...[
                _KeyValue(
                  label: 'Paid to',
                  value: '${method.account}  (${method.holder})',
                  copyable: true,
                ),
              ],
              _KeyValue(
                label: 'Submitted',
                value: review.createdAt == null
                    ? '—'
                    : DateFormat('d MMM yyyy, HH:mm').format(review.createdAt!),
              ),
              const SizedBox(height: AppSizes.sm),

              if (review.verificationUrl.isNotEmpty)
                _KeyValue(
                  label: 'Transaction',
                  value: review.verificationUrl,
                  onTap: () =>
                      AppHelperFunctions.openUrl(review.verificationUrl),
                ),
            ],
          ),
        ),

        // ── Review outcome ───────────────────────────────────────
        if (review.isReviewed) ...[
          const SizedBox(height: AppSizes.spaceBtwItems),
          AdminSection(
            title: 'Review',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _KeyValue(label: 'Outcome', value: review.status),
                _KeyValue(
                  label: 'Reviewed at',
                  value: review.reviewedAt == null
                      ? '—'
                      : DateFormat(
                          'd MMM yyyy, HH:mm',
                        ).format(review.reviewedAt!),
                ),
                _KeyValue(
                  label: 'Reviewed by',
                  value: review.reviewedBy ?? '—',
                ),
                if ((review.rejectionReason ?? '').isNotEmpty)
                  _KeyValue(label: 'Reason', value: review.rejectionReason!),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({
    required this.label,
    required this.value,
    this.copyable = false,
    this.onTap,
  });

  final String label;
  final String value;
  final bool copyable;
  final VoidCallback? onTap;

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
            child: onTap != null
                ? InkWell(
                    onTap: onTap,
                    child: Text(
                      value,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.info,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : SelectableText(value, style: const TextStyle(fontSize: 12)),
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

class _ConfirmDetail extends StatelessWidget {
  const _ConfirmDetail({required this.rows});

  final Map<String, String> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in rows.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Text(
                    entry.key,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    entry.value,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
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

// ── Footer ────────────────────────────────────────────────────────────

class _ActionBar extends StatelessWidget {
  const _ActionBar({
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
        padding: const EdgeInsets.all(AppSizes.md),
        color: dark ? AppColors.darkSurface : AppColors.softGrey,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              review.isApproved
                  ? Icons.check_circle_rounded
                  : Icons.cancel_rounded,
              size: AppSizes.iconSm,
              color: paymentStatusColor(review.status),
            ),
            const SizedBox(width: AppSizes.sm),
            Text(
              'Already ${review.status} — no further action available.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return Obx(() {
      final busy = controller.isActing(review.id);

      return Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : AppColors.white,
          border: Border(
            top: BorderSide(
              color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton(
              onPressed: busy ? null : onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.close_rounded, size: AppSizes.iconSm),
            ),
            const SizedBox(width: AppSizes.sm),
            ElevatedButton(
              onPressed: busy ? null : onApprove,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                minimumSize: const Size(44, 44),
                padding: EdgeInsets.zero,
              ),
              child: busy
                  ? const SizedBox(
                      height: 14,
                      width: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: AppSizes.iconSm),
            ),
          ],
        ),
      );
    });
  }
}
