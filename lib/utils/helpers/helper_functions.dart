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
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        pageBuilder: (context, _, _) {
          return Scaffold(
            backgroundColor: AppColors.black,
            body: SizedBox.expand(
              child: Stack(
                children: [
                  // 🔥 FULL SCREEN INTERACTIVE VIEW
                  Positioned.fill(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 1.0,
                      maxScale: 5.0,
                      child: Center(
                        child: isAssetImage
                            ? Image.asset(imageUrl, fit: BoxFit.contain)
                            : cachedFile != null
                            ? Image.file(cachedFile, fit: BoxFit.contain)
                            : Image.network(imageUrl, fit: BoxFit.contain),
                      ),
                    ),
                  ),

                  // CLOSE BUTTON
                  Positioned(
                    top: 40,
                    right: 20,
                    child: SafeArea(
                      child: IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: AppColors.white,
                          size: 30,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
