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
  String? _loadedUrl;

  @override
  void initState() {
    super.initState();
    if (!widget.review.hasScreenshot) {
      _urlFuture = Future.value('');
    } else {
      _urlFuture = widget.resolveUrl().then((url) {
        _loadedUrl = url;
        return url;
      });
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
        _urlFuture = widget.resolveUrl().then((url) {
          _loadedUrl = url;
          return url;
        });
      }
      _quarterTurns = 0;
      _transform.value = Matrix4.identity();
    }
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
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
      return const _ScreenshotPurgedPlaceholder();
    }

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

                final url = snapshot.data!;

                return Stack(
                  children: [
                    // Interactive Viewer Pane
                    Positioned.fill(
                      child: GestureDetector(
                        onDoubleTap: () => _openFullScreen(url),
                        child: InteractiveViewer(
                          transformationController: _transform,
                          minScale: 0.5,
                          maxScale: 6,
                          child: Center(
                            child: RotatedBox(
                              quarterTurns: _quarterTurns,
                              child: InkWell(
                                onTap: () => _openFullScreen(url),
                                child: Image.network(
                                  url,
                                  fit: BoxFit.contain,
                                  loadingBuilder: (context, child, progress) =>
                                      progress == null
                                          ? child
                                          : const Center(
                                              child:
                                                  CircularProgressIndicator(),
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
                          ),
                        ),
                      ),
                    ),

                    // Tap to zoom hint overlay
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
                            color: Colors.black.withValues(alpha: 0.6),
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
                                'Click for Full Screen',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          _Toolbar(
            onRotate: () =>
                setState(() => _quarterTurns = (_quarterTurns + 1) % 4),
            onReset: () => setState(() {
              _quarterTurns = 0;
              _transform.value = Matrix4.identity();
            }),
            onFullScreen: _loadedUrl != null
                ? () => _openFullScreen(_loadedUrl!)
                : null,
            onOpenOriginal: (_loadedUrl != null && _loadedUrl!.isNotEmpty)
                ? () => AppHelperFunctions.openUrl(_loadedUrl!)
                : (widget.review.receiptUrl.startsWith('http')
                    ? () => AppHelperFunctions.openUrl(widget.review.receiptUrl)
                    : null),
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
    required this.onFullScreen,
    required this.onOpenOriginal,
  });

  final VoidCallback onRotate;
  final VoidCallback onReset;
  final VoidCallback? onFullScreen;
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Rotate 90°',
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
            if (onFullScreen != null)
              IconButton(
                tooltip: 'Full screen with zoom',
                onPressed: onFullScreen,
                icon: const Icon(Icons.fullscreen_rounded),
                iconSize: AppSizes.iconSm + 4,
              ),
            const SizedBox(width: AppSizes.sm),
            TextButton.icon(
              onPressed: onOpenOriginal,
              icon: const Icon(Icons.open_in_new_rounded, size: AppSizes.iconSm),
              label: const Text('Open original'),
            ),
          ],
        ),
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
  const _ScreenshotPurgedPlaceholder();

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
                size: 42,
                color: AppColors.success,
              ),
            ),
            const SizedBox(height: AppSizes.md),
            Text(
              'Screenshot Cleared to Save Storage',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.bold,
                color: dark ? AppColors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: const Text(
                'This payment has been reviewed and verified. The screenshot file was purged from storage to reclaim space, while the complete accounting and audit record is preserved.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
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
