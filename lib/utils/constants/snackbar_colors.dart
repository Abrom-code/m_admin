import 'package:flutter/material.dart';

/// Brand-aligned color tokens for the toast/snackbar system.
///
/// Surfaces are intentionally inverted from the app background so toasts
/// always stand out regardless of screen content:
///   • Light mode → near-black charcoal surface (high contrast on white UI)
///   • Dark mode  → dark-teal-tinted charcoal (softer than pure black)
///
/// Variant colors are used exclusively for the left accent bar and icon —
/// the container background stays neutral across all variants.
///
/// All text/icon combinations meet WCAG AA contrast (≥4.5:1) against their
/// respective surface colors.
class SnackbarColors {
  SnackbarColors._();

  // ── Surfaces ──────────────────────────────────────────────────────────────
  /// Container background in light mode — near-black with a teal undertone.
  static const Color lightSurface = Color(0xFF1E2323);

  /// Container background in dark mode — slightly lighter than lightSurface
  /// so the card lifts off the dark scaffold.
  static const Color darkSurface = Color(0xFF2A3333);

  // ── Text ──────────────────────────────────────────────────────────────────
  /// Primary text on [lightSurface] — warm off-white (contrast ≈ 14:1).
  static const Color lightText = Color(0xFFF5F7F7);

  /// Primary text on [darkSurface] — slightly softer white (contrast ≈ 12:1).
  static const Color darkText = Color(0xFFF0F2F2);

  /// Secondary / subtitle text on [lightSurface].
  static const Color lightSubtext = Color(0xFFACB5B5);

  /// Secondary / subtitle text on [darkSurface].
  static const Color darkSubtext = Color(0xFF8FA3A3);

  /// Dismiss icon color on [lightSurface] (semi-transparent white).
  static const Color lightDismiss = Color(0xB3F5F7F7); // white 70%

  /// Dismiss icon color on [darkSurface].
  static const Color darkDismiss = Color(0xB3F0F2F2); // white 70%

  // ── Variant accents (icon + left accent bar only) ─────────────────────────
  /// Success — vivid green, WCAG AA against both surfaces.
  static const Color success = Color(0xFF22C55E);

  /// Error — bright red.
  static const Color error = Color(0xFFEF4444);

  /// Warning — amber.
  static const Color warning = Color(0xFFF59E0B);

  /// Info — primary teal, matches the app's brand color.
  static const Color info = Color(0xFF14B8A6);

  // ── Action button text ────────────────────────────────────────────────────
  /// Action label on light-mode surface (teal at full opacity).
  static const Color actionLight = Color(0xFF14B8A6);

  /// Action label on dark-mode surface — brightened for legibility on the
  /// slightly lighter [darkSurface].
  static const Color actionDark = Color(0xFF2DD4BF);

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Returns the correct surface color for the given [brightness].
  static Color surface(Brightness brightness) =>
      brightness == Brightness.light ? lightSurface : darkSurface;

  /// Returns the correct primary text color for the given [brightness].
  static Color text(Brightness brightness) =>
      brightness == Brightness.light ? lightText : darkText;

  /// Returns the correct subtext color for the given [brightness].
  static Color subtext(Brightness brightness) =>
      brightness == Brightness.light ? lightSubtext : darkSubtext;

  /// Returns the correct dismiss icon color for the given [brightness].
  static Color dismiss(Brightness brightness) =>
      brightness == Brightness.light ? lightDismiss : darkDismiss;

  /// Returns the correct action label color for the given [brightness].
  static Color action(Brightness brightness) =>
      brightness == Brightness.light ? actionLight : actionDark;
}
