import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

/// Prompts the reviewer to enter a rejection reason before the action fires.
///
/// Returns the trimmed reason string, or null if the reviewer cancels.
/// An empty / null return is treated as a cancellation by [PaymentDetailScreen].
///
/// A minimum of 5 characters is required so the student always receives
/// a meaningful explanation, not a blank or one-word dismissal.
Future<String?> showRejectDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _RejectDialog(),
  );
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();
  bool _hasText = false;

  static const _presets = [
    'Receipt is unreadable or too blurry.',
    'Amount on receipt does not match the expected fee.',
    'Receipt appears to be a screenshot of a previous transaction.',
    'Wrong account number — payment was not received.',
    'Please resubmit with a clearer photo of the full receipt.',
  ];

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onChanged() {
    final hasText = _controller.text.trim().length >= 5;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  void _pickPreset(String text) {
    _controller.text = text;
    _controller.selection =
        TextSelection.fromPosition(TextPosition(offset: text.length));
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      titlePadding: const EdgeInsets.fromLTRB(
        AppSizes.md,
        AppSizes.md,
        AppSizes.md,
        0,
      ),
      contentPadding: const EdgeInsets.all(AppSizes.md),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cancel_outlined,
              color: AppColors.error,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          const Expanded(child: Text('Reject payment')),
        ],
      ),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'This reason is shown to the student in their notification. '
              'Be specific so they know exactly what to fix and resubmit.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSizes.md),

            // ── Quick-pick presets ──────────────────────────────────
            Wrap(
              spacing: AppSizes.xs,
              runSpacing: AppSizes.xs,
              children: [
                for (final preset in _presets)
                  ActionChip(
                    label: Text(
                      preset,
                      style: const TextStyle(fontSize: 11),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSizes.xs,
                      vertical: 0,
                    ),
                    onPressed: () => _pickPreset(preset),
                    backgroundColor:
                        dark ? AppColors.darkSurface : AppColors.softGrey,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppSizes.borderRadiusMd),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSizes.sm),

            // ── Free-text field ─────────────────────────────────────
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Describe the problem with this receipt…',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Get.back<String>(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            minimumSize: const Size(120, 44),
          ),
          onPressed: _hasText
              ? () => Get.back<String>(result: _controller.text.trim())
              : null,
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
