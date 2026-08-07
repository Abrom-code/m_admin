import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

/// A utility class for managing a full-screen loading dialog.
class AppFullScreenLoader {
  /// Opens a full-screen loading dialog with a built-in Material design spinner.
  static void openLoadingDialog(String text, [String? _]) {
    showDialog(
      context: Get.overlayContext!,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: Container(
          color: AppHelperFunctions.isDark(Get.context!)
              ? AppColors.dark
              : AppColors.white,
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const AppPulsingDots(),
              const SizedBox(height: 24),
              DefaultTextStyle(
                style: Theme.of(Get.context!).textTheme.bodyMedium!.copyWith(
                  color: AppHelperFunctions.isDark(Get.context!)
                      ? Colors.white
                      : Colors.black,
                  decoration: TextDecoration.none,
                ),
                child: Text(text, textAlign: TextAlign.center),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void stopLoading() {
    Navigator.of(Get.overlayContext!).pop();
  }
}
