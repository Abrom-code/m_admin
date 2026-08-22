import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:url_launcher/url_launcher.dart';

class AppHelperFunctions {
  static Future<void> openUrl(String url) async {
    final Uri uri = Uri.parse(url);

    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('$url open failed: $e');
    }
  }

  static Future<void> showImageZoom(
    BuildContext context,
    String imageUrl, {
    bool isAssetImage = false,
    File? cachedFile,
    int initialQuarterTurns = 0,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, _) {
          return _FullScreenImageViewer(
            imageUrl: imageUrl,
            isAssetImage: isAssetImage,
            cachedFile: cachedFile,
            initialQuarterTurns: initialQuarterTurns,
          );
        },
        transitionsBuilder: (context, animation, _, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }

  static void showAppDialog(
    BuildContext context,
    String title,
    String message,
    VoidCallback onOkPressed, {
    VoidCallback? onCancel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final dark = isDark(context);
        return Dialog(
          backgroundColor: dark ? AppColors.darkCard : AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Padding(
              padding: const EdgeInsets.all(AppSizes.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Icon ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(
                        alpha: dark ? 0.2 : 0.12,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pause_rounded,
                      color: AppColors.secondary,
                      size: 28,
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceBtwItems),

                  // ── Title ───────────────────────────────────────────
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.sm),

                  // ── Message ─────────────────────────────────────────
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: dark
                          ? AppColors.grey
                          : AppColors.darkerGrey.withValues(alpha: 0.8),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSizes.lg),

                  // ── Actions ─────────────────────────────────────────
                  Row(
                    children: [
                      // Secondary button (Cancel - safe default)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              onCancel?.call();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.3,
                                  ),
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),

                      // Primary button (Ok - main action)
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: onOkPressed,
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Ok',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  static String truncateText(String text, int maxLen) {
    if (text.length <= maxLen) {
      return text;
    } else {
      return '${text.substring(0, maxLen)}...';
    }
  }

  static bool isDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark;
  }

  static Size screenSize() {
    return MediaQuery.of(Get.context!).size;
  }

  static double screenHeight() {
    return MediaQuery.of(Get.context!).size.height;
  }

  static double screenWidth() {
    return MediaQuery.of(Get.context!).size.width;
  }

  static String getFormattedDate(
    DateTime date, {
    String formate = 'dd MMM yyyy',
  }) {
    return DateFormat(formate).format(date);
  }

  static String getChapterName(int n) {
    switch (n) {
      case 1:
        return 'Unit One';
      case 2:
        return 'Unit Two';
      case 3:
        return 'Unit Three';
      case 4:
        return 'Unit Four';
      case 5:
        return 'Unit Five';
      case 6:
        return 'Unit Six';
      case 7:
        return 'Unit Seven';
      case 8:
        return 'Unit Eight';
      case 9:
        return 'Unit Nine';
      case 10:
        return 'Unit Ten';
      case 11:
        return 'Unit Eleven';
      default:
        return 'Opps..!';
    }
  }

  // ── Safe numeric parsers ──────────────────────────────────────────────
  // Supabase returns numeric/decimal columns as String in some response
  // shapes. These helpers accept both num and String so a cast never throws.

  static int? toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double toDouble(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}

class _FullScreenImageViewer extends StatefulWidget {
  const _FullScreenImageViewer({
    required this.imageUrl,
    this.isAssetImage = false,
    this.cachedFile,
    this.initialQuarterTurns = 0,
  });

  final String imageUrl;
  final bool isAssetImage;
  final File? cachedFile;
  final int initialQuarterTurns;

  @override
  State<_FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<_FullScreenImageViewer> {
  final _transform = TransformationController();
  late int _quarterTurns;

  @override
  void initState() {
    super.initState();
    _quarterTurns = widget.initialQuarterTurns;
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _rotate() {
    setState(() => _quarterTurns = (_quarterTurns + 1) % 4);
  }

  void _reset() {
    setState(() {
      _quarterTurns = 0;
      _transform.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Full Screen Interactive Zoom & Pan ──
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transform,
              panEnabled: true,
              minScale: 0.5,
              maxScale: 8.0,
              child: Center(
                child: RotatedBox(
                  quarterTurns: _quarterTurns,
                  child: widget.isAssetImage
                      ? Image.asset(widget.imageUrl, fit: BoxFit.contain)
                      : widget.cachedFile != null
                          ? Image.file(widget.cachedFile!, fit: BoxFit.contain)
                          : Image.network(
                              widget.imageUrl,
                              fit: BoxFit.contain,
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                      ? child
                                      : const Center(
                                          child: CircularProgressIndicator(
                                            color: Colors.white,
                                          ),
                                        ),
                              errorBuilder: (context, _, _) => const Center(
                                child: Text(
                                  'Could not load image in full resolution.',
                                  style: TextStyle(color: Colors.white70),
                                ),
                              ),
                            ),
                ),
              ),
            ),
          ),

          // ── Top Floating Action Controls ──
          Positioned(
            top: 24,
            right: 20,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Rotate (90°)',
                      icon: const Icon(
                        Icons.rotate_90_degrees_cw_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _rotate,
                      visualDensity: VisualDensity.compact,
                    ),
                    IconButton(
                      tooltip: 'Reset Zoom & Rotation',
                      icon: const Icon(
                        Icons.center_focus_strong_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _reset,
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 4),
                    Container(width: 1, height: 20, color: Colors.white24),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
