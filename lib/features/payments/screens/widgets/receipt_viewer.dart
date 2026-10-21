import 'package:flutter/material.dart';
import 'package:m_admin/features/payments/models/payment_review.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Displays a receipt image with zoom, rotation, and full-screen view capability.
class ReceiptViewer extends StatefulWidget {
  const ReceiptViewer({
    super.key,
    required this.review,
    required this.resolveUrl,
    this.height = 540,
  });

  final PaymentReview review;

  /// Resolves a viewable URL — a short-lived signed one where possible,
  /// falling back to the stored public URL.
  final Future<String> Function() resolveUrl;

  final double height;

  @override
  State<ReceiptViewer> createState() => _ReceiptViewerState();
}

class _ReceiptViewerState extends State<ReceiptViewer> {
  late Future<String> _urlFuture;
  int _quarterTurns = 0;

  @override
  void initState() {
    super.initState();
    if (!widget.review.hasScreenshot) {
      _urlFuture = Future.value('');
    } else {
      _urlFuture = widget.resolveUrl();
    }
  }

  @override
  void didUpdateWidget(ReceiptViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.review.id != widget.review.id ||
        oldWidget.review.receiptPath != widget.review.receiptPath ||
        oldWidget.review.receiptUrl != widget.review.receiptUrl) {
      if (!widget.review.hasScreenshot) {
        _urlFuture = Future.value('');
      } else {
        _urlFuture = widget.resolveUrl();
      }
      _quarterTurns = 0;
    }
  }

  void _openFullScreen(String url) {
    AppHelperFunctions.showImageZoom(
      context,
      url,
      initialQuarterTurns: _quarterTurns,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    if (!widget.review.hasScreenshot) {
      return Container(
        height: 240,
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          border: Border.all(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
        ),
        child: _ScreenshotPurgedPlaceholder(isReviewed: widget.review.isReviewed),
      );
    }

    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        color: dark ? AppColors.black : const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
      ),
      clipBehavior: Clip.antiAlias,
      child: FutureBuilder<String>(
        future: _urlFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
            return _Unavailable(
              message: 'Could not load this receipt image.',
              url: widget.review.receiptUrl,
            );
          }

          final url = snapshot.data!;

          return Stack(
            children: [
              // Receipt Image Container (tap or double tap to view full screen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => _openFullScreen(url),
                  onDoubleTap: () => _openFullScreen(url),
                  child: Center(
                    child: RotatedBox(
                      quarterTurns: _quarterTurns,
                      child: Image.network(
                        url,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                        errorBuilder: (context, _, _) => _Unavailable(
                          message:
                              'This file could not be displayed as an image. Click to open directly.',
                          url: widget.review.receiptUrl,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Tap to zoom hint overlay (Top-Left)
              Positioned(
                top: 10,
                left: 10,
                child: InkWell(
                  onTap: () => _openFullScreen(url),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.fullscreen_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Full Screen',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Floating Rotate Button (Top-Right)
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white24),
                  ),
                  child: IconButton(
                    tooltip: 'Rotate 90°',
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.all(6),
                    constraints: const BoxConstraints(),
                    icon: const Icon(Icons.rotate_90_degrees_cw_rounded, size: 16, color: Colors.white),
                    onPressed: () => setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
                  ),
                ),
              ),
            ],
          );
        },
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

class _ScreenshotPurgedPlaceholder extends StatelessWidget {
  const _ScreenshotPurgedPlaceholder({this.isReviewed = false});

  final bool isReviewed;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_done_outlined,
                size: 36,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              isReviewed
                  ? 'Screenshot Cleared to Save Storage'
                  : 'No Screenshot Available',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: dark ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 320),
              child: Text(
                isReviewed
                    ? 'This payment has been reviewed and verified. The screenshot file was purged to conserve storage quota.'
                    : 'This payment has no attached screenshot or was submitted directly via transaction reference.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
