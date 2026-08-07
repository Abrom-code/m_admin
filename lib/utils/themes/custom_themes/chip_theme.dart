import 'package:flutter/material.dart';

class AppChipTheme {
  AppChipTheme._(); // Private constructor to prevent instantiation

  /// Light Chip Theme
  static ChipThemeData lightChipTheme = ChipThemeData(
    disabledColor: Colors.grey.withValues(alpha:0.4),
    labelStyle: const TextStyle(color: Colors.black),
    selectedColor: Colors.teal,
    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
    checkmarkColor: Colors.white,
  );

  /// Dark Chip Theme
  static const ChipThemeData darkChipTheme = ChipThemeData(
    disabledColor: Colors.grey,
    labelStyle: TextStyle(color: Colors.white),
    selectedColor: Colors.teal,
    padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 12),
    checkmarkColor: Colors.white,
  );
}
