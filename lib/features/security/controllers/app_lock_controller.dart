import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum AppLockType { pin, pattern }

class AppLockController extends GetxController with WidgetsBindingObserver {
  static AppLockController get instance => Get.find();

  final _storage = GetStorage();
  final _localAuth = LocalAuthentication();

  // Storage keys
  static const _kPasscodeEnabled = 'security_passcode_enabled';
  static const _kLockType = 'security_lock_type'; // 'pin' or 'pattern'
  static const _kPasscodeHash = 'security_passcode_hash';
  static const _kPasscodeSalt = 'security_passcode_salt';
  static const _kBiometricEnabled = 'security_biometric_enabled';
  static const _kAutoLockMinutes = 'security_auto_lock_minutes';
  static const _kPinLength = 'security_pin_length';
  static const _kIsLocked = 'security_is_locked';

  // Observables
  final isPasscodeEnabled = false.obs;
  final lockType = AppLockType.pin.obs;
  final isBiometricEnabled = false.obs;
  final canUseBiometrics = false.obs;
  final pinLength = 4.obs; // 4 or 6
  final autoLockMinutes = 0.obs; // 0 = immediately, 1 = 1m, 5 = 5m, -1 = disabled

  final isLocked = false.obs;
  final isAuthenticating = false.obs;
  final isVerifyingAdmin = false.obs;

  bool _hasUserDismissedBiometrics = false;
  bool get hasUserDismissedBiometrics => _hasUserDismissedBiometrics;

  DateTime? _pausedTime;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
    _checkBiometrics();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!isPasscodeEnabled.value) return;

    if (state == AppLifecycleState.paused) {
      // If we are actively displaying the biometric dialog, the activity pause is just
      // the native biometric overlay, not the user leaving the app.
      if (isAuthenticating.value) return;

      _pausedTime = DateTime.now();
      if (autoLockMinutes.value == 0) {
        // Immediate lock on background
        lock();
      }
    } else if (state == AppLifecycleState.resumed) {
      // If resumed was fired right as the biometric prompt dismissed, do not treat
      // as returning from background.
      if (isAuthenticating.value) return;

      final wasBackgrounded = _pausedTime != null;
      if (wasBackgrounded && autoLockMinutes.value > 0) {
        final elapsed = DateTime.now().difference(_pausedTime!);
        if (elapsed.inMinutes >= autoLockMinutes.value) {
          lock();
        }
      }
      _pausedTime = null;

      // Only auto-prompt on resume if the app was actually backgrounded, is locked,
      // and the user has not explicitly dismissed/cancelled the biometric prompt.
      if (wasBackgrounded &&
          isLocked.value &&
          !_hasUserDismissedBiometrics &&
          isBiometricEnabled.value &&
          canUseBiometrics.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          authenticateWithBiometrics();
        });
      }
    }
  }

  void _loadSettings() {
    isPasscodeEnabled.value = _storage.read<bool>(_kPasscodeEnabled) ?? false;
    final savedType = _storage.read<String>(_kLockType) ?? 'pin';
    lockType.value = savedType == 'pattern' ? AppLockType.pattern : AppLockType.pin;
    isBiometricEnabled.value = _storage.read<bool>(_kBiometricEnabled) ?? false;
    pinLength.value = _storage.read<int>(_kPinLength) ?? 4;
    autoLockMinutes.value = _storage.read<int>(_kAutoLockMinutes) ?? 0;

    // Restore lock state if enabled
    if (isPasscodeEnabled.value) {
      final wasLocked = _storage.read<bool>(_kIsLocked) ?? true;
      isLocked.value = wasLocked;
    } else {
      isLocked.value = false;
    }
  }

  Future<void> _checkBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      final isSupported = await _localAuth.isDeviceSupported();
      if (!canCheck && !isSupported) {
        canUseBiometrics.value = false;
        return;
      }

      final available = await _localAuth.getAvailableBiometrics();
      // Only fingerprint is permitted
      final hasFingerprint = available.contains(BiometricType.fingerprint) ||
          available.contains(BiometricType.strong);
      canUseBiometrics.value =
          hasFingerprint || (available.isEmpty && (canCheck || isSupported));

      // Auto-prompt on startup if console is already locked and fingerprint enabled
      if (canUseBiometrics.value && isLocked.value && isBiometricEnabled.value) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          authenticateWithBiometrics();
        });
      }
    } catch (e) {
      debugPrint('[AppLockController] Fingerprint check error: $e');
      canUseBiometrics.value = false;
    }
  }

  // ── Lock Actions ──────────────────────────────────────────────────

  void lock() {
    if (!isPasscodeEnabled.value) return;
    _hasUserDismissedBiometrics = false;
    isLocked.value = true;
    _storage.write(_kIsLocked, true);

    // Auto-prompt fingerprint if enabled
    if (isBiometricEnabled.value && canUseBiometrics.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        authenticateWithBiometrics();
      });
    }
  }

  void unlock() {
    _hasUserDismissedBiometrics = false;
    // Schedule state update on the next frame so touch and window focus
    // events resolve cleanly before AppLockScreen is unmounted.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      isLocked.value = false;
      _storage.write(_kIsLocked, false);
    });
    if (WidgetsBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  // ── Verification ──────────────────────────────────────────────────

  bool verifyPin(String enteredPin) {
    if (!isPasscodeEnabled.value) return true;
    final salt = _storage.read<String>(_kPasscodeSalt) ?? '';
    final storedHash = _storage.read<String>(_kPasscodeHash) ?? '';

    final computedHash = _hash(enteredPin, salt);
    if (computedHash == storedHash) {
      unlock();
      return true;
    }
    return false;
  }

  /// Checks whether [enteredPin] matches the stored hash without unlocking the full app lock.
  bool checkPasscode(String enteredPin) {
    if (!isPasscodeEnabled.value) return true;
    final salt = _storage.read<String>(_kPasscodeSalt) ?? '';
    final storedHash = _storage.read<String>(_kPasscodeHash) ?? '';
    final computedHash = _hash(enteredPin, salt);
    return computedHash == storedHash;
  }

  bool verifyPattern(List<int> points) {
    if (!isPasscodeEnabled.value) return true;
    final salt = _storage.read<String>(_kPasscodeSalt) ?? '';
    final storedHash = _storage.read<String>(_kPasscodeHash) ?? '';

    final patternStr = points.join('-');
    final computedHash = _hash(patternStr, salt);
    if (computedHash == storedHash) {
      unlock();
      return true;
    }
    return false;
  }

  /// Checks whether [points] match the stored pattern without unlocking the full app lock.
  bool checkPattern(List<int> points) {
    if (!isPasscodeEnabled.value) return true;
    final salt = _storage.read<String>(_kPasscodeSalt) ?? '';
    final storedHash = _storage.read<String>(_kPasscodeHash) ?? '';
    final patternStr = points.join('-');
    final computedHash = _hash(patternStr, salt);
    return computedHash == storedHash;
  }

  /// Quick biometric authentication prompt for sensitive sub-views like Revenue.
  Future<bool> authenticateBiometricsQuick({
    String reason = 'Scan fingerprint to access Revenue Analytics',
  }) async {
    if (!canUseBiometrics.value || !isBiometricEnabled.value) return false;
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
      );
    } catch (e) {
      debugPrint('[AppLockController] Quick biometric auth error: $e');
      return false;
    }
  }

  Future<bool> authenticateWithBiometrics({bool userInitiated = false}) async {
    if (userInitiated) {
      _hasUserDismissedBiometrics = false;
    }

    if (!userInitiated && _hasUserDismissedBiometrics) {
      return false;
    }

    if (!canUseBiometrics.value || isAuthenticating.value || !isLocked.value) {
      return false;
    }

    try {
      isAuthenticating.value = true;
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Scan fingerprint to unlock MatricMate Admin',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );

      if (didAuthenticate && isLocked.value) {
        _hasUserDismissedBiometrics = false;
        unlock();
        return true;
      }
      // User tapped "Cancel", pressed outside/back, or auth failed
      _hasUserDismissedBiometrics = true;
      return false;
    } catch (e) {
      debugPrint('[AppLockController] Fingerprint auth error: $e');
      _hasUserDismissedBiometrics = true;
      return false;
    } finally {
      isAuthenticating.value = false;
    }
  }

  /// Emergency unlock when admin forgets passcode or pattern:
  /// Verifies email and password with Supabase Auth.
  Future<({bool success, String? error})> unlockWithAdminCredentials({
    required String email,
    required String password,
    bool resetPasscode = true,
  }) async {
    if (isVerifyingAdmin.value) return (success: false, error: 'Verification already in progress.');

    try {
      isVerifyingAdmin.value = true;
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (res.user != null) {
        if (Get.isRegistered<AdminSessionService>()) {
          await AdminSessionService.instance.establish();
        }
        if (resetPasscode) {
          await disablePasscode();
        } else {
          unlock();
        }
        return (success: true, error: null);
      }
      return (success: false, error: 'Invalid admin credentials.');
    } on AuthException catch (e) {
      debugPrint('[AppLockController] Auth error: ${e.message}');
      return (success: false, error: e.message);
    } catch (e) {
      debugPrint('[AppLockController] Admin credential verification error: $e');
      return (success: false, error: 'Verification failed: ${e.toString()}');
    } finally {
      isVerifyingAdmin.value = false;
    }
  }

  // ── Setup & Configuration ─────────────────────────────────────────

  Future<void> setPasscode({
    required String passcode,
    required AppLockType type,
    int? length,
    bool enableBiometrics = false,
  }) async {
    final salt = _generateSalt();
    final hash = _hash(passcode, salt);

    await _storage.write(_kPasscodeSalt, salt);
    await _storage.write(_kPasscodeHash, hash);
    await _storage.write(_kLockType, type == AppLockType.pattern ? 'pattern' : 'pin');
    await _storage.write(_kPasscodeEnabled, true);
    await _storage.write(_kBiometricEnabled, enableBiometrics);
    if (length != null) {
      await _storage.write(_kPinLength, length);
      pinLength.value = length;
    }

    lockType.value = type;
    isPasscodeEnabled.value = true;
    isBiometricEnabled.value = enableBiometrics;
    isLocked.value = false;
    await _storage.write(_kIsLocked, false);
  }

  Future<void> disablePasscode() async {
    await _storage.remove(_kPasscodeHash);
    await _storage.remove(_kPasscodeSalt);
    await _storage.write(_kPasscodeEnabled, false);
    await _storage.write(_kIsLocked, false);

    isPasscodeEnabled.value = false;
    isLocked.value = false;
  }

  Future<void> toggleBiometrics(bool enable) async {
    isBiometricEnabled.value = enable;
    await _storage.write(_kBiometricEnabled, enable);
  }

  Future<void> setAutoLockMinutes(int minutes) async {
    autoLockMinutes.value = minutes;
    await _storage.write(_kAutoLockMinutes, minutes);
  }

  Future<void> setPinLength(int length) async {
    pinLength.value = length;
    await _storage.write(_kPinLength, length);
  }

  // ── Hashing Helpers ───────────────────────────────────────────────

  String _generateSalt() {
    final rnd = Random.secure();
    final values = List<int>.generate(16, (i) => rnd.nextInt(256));
    return base64Url.encode(values);
  }

  String _hash(String input, String salt) {
    final bytes = utf8.encode('$salt::$input');
    return sha256.convert(bytes).toString();
  }
}
