import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// Confirmation dialogs for the admin console.
///
/// The parent app's version of this file carried `changeDevice()`, which
/// depended on the student `LoginController` and a Telegram support button.
/// Neither has meaning here, so this is a rewrite rather than a copy — only
/// [showOkCancelDialog] is preserved verbatim from the parent.
class AppDialogBoxes {
  /// Kept identical to the parent app so shared idioms stay familiar.
  static void showOkCancelDialog({
    required BuildContext context,
    String? title,
    String? subtitle,
    required VoidCallback onPressed,
  }) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title ?? 'Confirm Action'),
          content: Text(subtitle ?? 'Are you sure you want to proceed?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => onPressed(),
              child: const Text(
                'OK',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The standard admin confirmation. Returns `true` only if confirmed.
  ///
  /// Every mutating admin action routes through this — approving a payment,
  /// granting premium, sending a broadcast. [detail] should name the concrete
  /// thing being acted on (student name, amount, audience size) in plain
  /// words, because the reviewer is confirming a real-world consequence.
  static Future<bool> confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Widget? detail,
    bool isDestructive = false,
  }) async {
    final dark = AppHelperFunctions.isDark(Get.context!);
    final accent = isDestructive ? AppColors.error : AppColors.primary;

    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: dark ? AppColors.darkCard : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isDestructive
                    ? Icons.warning_amber_rounded
                    : Icons.help_outline_rounded,
                color: accent,
                size: AppSizes.iconMd,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (detail != null) ...[
              const SizedBox(height: AppSizes.md),
              detail,
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: Text(cancelLabel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              minimumSize: const Size(96, 44),
            ),
            onPressed: () => Get.back(result: true),
            child: Text(confirmLabel),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    return result ?? false;
  }

  /// A destructive confirmation that requires the operator to type
  /// [expectedText] exactly before the action unlocks.
  ///
  /// Phase 10 requires this for content deletion: deleting a test
  /// cascade-deletes its questions, so the dialog must state the blast radius
  /// and refuse to proceed on a stray click.
  static Future<bool> confirmTyped({
    required String title,
    required String message,
    required String expectedText,
    String confirmLabel = 'Delete',
  }) async {
    final dark = AppHelperFunctions.isDark(Get.context!);
    final controller = TextEditingController();
    final matches = false.obs;

    controller.addListener(
      () => matches.value = controller.text.trim() == expectedText,
    );

    final result = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: dark ? AppColors.darkCard : AppColors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppSizes.sm),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: AppSizes.iconMd,
              ),
            ),
            const SizedBox(width: AppSizes.sm),
            Expanded(child: Text(title)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: AppSizes.md),
            Text(
              'Type "$expectedText" to confirm:',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(isDense: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('Cancel'),
          ),
          Obx(
            () => ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                minimumSize: const Size(96, 44),
              ),
              onPressed: matches.value ? () => Get.back(result: true) : null,
              child: Text(confirmLabel),
            ),
          ),
        ],
      ),
      barrierDismissible: false,
    );

    controller.dispose();
    return result ?? false;
  }

  /// A confirmation whose action runs inside the dialog, so the button can
  /// show an inline spinner and the dialog cannot be dismissed mid-write.
  ///
  /// Use this where a half-completed action would be dangerous to retry
  /// blindly — payment approval being the obvious case.
  static Future<bool> confirmAwait({
    required String title,
    required String message,
    required Future<void> Function() onConfirm,
    String confirmLabel = 'Confirm',
    bool isDestructive = false,
  }) async {
    final dark = AppHelperFunctions.isDark(Get.context!);
    final accent = isDestructive ? AppColors.error : AppColors.primary;
    final busy = false.obs;

    final result = await Get.dialog<bool>(
      PopScope(
        canPop: false,
        child: AlertDialog(
          backgroundColor: dark ? AppColors.darkCard : AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
          ),
          title: Text(title),
          content: Text(message),
          actions: [
            Obx(
              () => TextButton(
                onPressed: busy.value ? null : () => Get.back(result: false),
                child: const Text('Cancel'),
              ),
            ),
            Obx(
              () => ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size(96, 44),
                ),
                onPressed: busy.value
                    ? null
                    : () async {
                        busy.value = true;
                        try {
                          await onConfirm();
                          Get.back(result: true);
                        } catch (_) {
                          busy.value = false;
                          rethrow;
                        }
                      },
                child: busy.value
                    ? const AppCircularButtonLoading()
                    : Text(confirmLabel),
              ),
            ),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    return result ?? false;
  }
}
