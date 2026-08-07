import 'package:flutter/material.dart';

/// --- Light & Dark Elevated Button Themes
class AppElevatedButtonTheme {
  AppElevatedButtonTheme._(); // To avoid creating instances

  /// --- Light Theme
  static final lightElevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: Colors.teal,
      disabledForegroundColor: Colors.teal.shade600,
      disabledBackgroundColor: Colors.teal.shade300,
      side: const BorderSide(color: Colors.teal),
      padding: const EdgeInsets.symmetric(vertical: 18),
      textStyle: const TextStyle(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );

  /// --- Dark Theme
  static final darkElevatedButtonTheme = ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      elevation: 0,
      foregroundColor: Colors.white,
      backgroundColor: Colors.teal,
      disabledForegroundColor: Colors.teal.shade600,
      disabledBackgroundColor: Colors.teal.shade300,
      side: const BorderSide(color: Colors.teal),
      padding: const EdgeInsets.symmetric(vertical: 18),
      textStyle: const TextStyle(
        fontSize: 16,
        color: Colors.white,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  ); // ElevatedButtonThemeData
}
