import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';

class ThemeController extends GetxController {
  static ThemeController get instance => Get.find();

  static const _key = 'theme_mode';
  final _storage = GetStorage();

  late final Rx<ThemeMode> themeMode;

  @override
  void onInit() {
    super.onInit();
    // Restore saved preference; default to system
    final saved = _storage.read<String>(_key);
    themeMode = _modeFromString(saved).obs;
  }

  void toggleTheme(bool isDark) {
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
    _storage.write(_key, isDark ? 'dark' : 'light');
  }

  ThemeMode _modeFromString(String? value) {
    switch (value) {
      case 'dark':
        return ThemeMode.dark;
      case 'light':
        return ThemeMode.light;
      default:
        return ThemeMode.system;
    }
  }
}
