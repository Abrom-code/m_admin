import 'package:flutter/material.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Displays a receipt image with zoom and rotation.
///
/// Broken images are EXPECTED here, not exceptional: the student app saves
/// every upload as `receipt_<uid>_<epochMillis>.jpg` regardless of what the
/// user actually picked, so a PNG or a PDF lands with a .jpg name and will not
/// decode. The failure state therefore explains the cause and offers the raw
/// URL rather than showing a bare broken-image glyph.
class ReceiptViewer extends StatefulWidget {
  const ReceiptViewer({
    super.key,
    required this.review,
    required this.resolveUrl,
  });

  final PaymentReview review;

  /// Resolves a viewable URL — a short-lived signed one where possible,
  /// falling back to the stored public URL.
  final Future<String> Function() resolveUrl;

  @override
  State<ReceiptViewer> createState() => _ReceiptViewerState();
}

class _ReceiptViewerState extends State<ReceiptViewer> {
  final _transform = TransformationController();

  late Future<String> _urlFuture;
  int _quarterTurns = 0;

  @override
  void initState() {
    super.initState();
    _urlFuture = widget.resolveUrl();
  }

  @override
  void didUpdateWidget(ReceiptViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.id != widget.review.id) {
      _urlFuture = widget.resolveUrl();
      _quarterTurns = 0;
      _transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      color: dark ? AppColors.black : AppColors.softGrey,
      child: Column(
        children: [
          Expanded(
            child: FutureBuilder<String>(
              future: _urlFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError || !snapshot.hasData) {
                  return _Unavailable(
                    message: 'Could not load this receipt.',
                    url: widget.review.receiptUrl,
                  );
                }

                return InteractiveViewer(
                  transformationController: _transform,
                  minScale: 0.5,
                  maxScale: 6,
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: _quarterTurns,
                      child: Image.network(
                        snapshot.data!,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(),
                              ),
                        errorBuilder: (context, _, _) => _Unavailable(
                          message:
                              'This file could not be displayed. Receipts are '
                              'always stored with a .jpg name even when the '
                              'student uploaded a PNG or a PDF, so the '
                              'original may not be an image at all.',
                          url: widget.review.receiptUrl,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _Toolbar(
            onRotate: () => setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
            onReset: () => setState(() {
              _quarterTurns = 0;
              _transform.value = Matrix4.identity();
            }),
            onOpenOriginal: widget.review.receiptUrl.isEmpty
                ? null
                : () => AppHelperFunctions.openUrl(widget.review.receiptUrl),
          ),
        ],
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.onRotate,
    required this.onReset,
    required this.onOpenOriginal,
  });

  final VoidCallback onRotate;
  final VoidCallback onReset;
  final VoidCallback? onOpenOriginal;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: AppSizes.xs,
      ),
      color: dark ? AppColors.darkSurface : AppColors.white,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Rotate',
            onPressed: onRotate,
            icon: const Icon(Icons.rotate_90_degrees_cw_rounded),
            iconSize: AppSizes.iconSm + 2,
          ),
          IconButton(
            tooltip: 'Reset view',
            onPressed: onReset,
            icon: const Icon(Icons.center_focus_strong_rounded),
            iconSize: AppSizes.iconSm + 2,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: onOpenOriginal,
            icon: const Icon(Icons.open_in_new_rounded, size: AppSizes.iconSm),
            label: const Text('Open original'),
          ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.url});

  final String message;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              size: AppSizes.iconLg,
              color: AppColors.darkGrey,
            ),
            const SizedBox(height: AppSizes.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AppColors.textSecondary,
              ),
            ),
            if (url.isNotEmpty) ...[
              const SizedBox(height: AppSizes.spaceBtwItems),
              OutlinedButton.icon(
                onPressed: () => AppHelperFunctions.openUrl(url),
                icon: const Icon(
                  Icons.open_in_new_rounded,
                  size: AppSizes.iconSm,
                ),
                label: const Text('Open the file directly'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
