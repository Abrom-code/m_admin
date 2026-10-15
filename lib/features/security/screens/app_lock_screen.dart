import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/common/widgets/toast/app_toast.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/security/controllers/app_lock_controller.dart';
import 'package:m_admin/features/security/widgets/pattern_lock_view.dart';
import 'package:m_admin/features/security/widgets/pin_pad_view.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/validators/validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final _controller = AppLockController.instance;
  final GlobalKey<PinPadViewState> _pinPadKey = GlobalKey<PinPadViewState>();
  final GlobalKey<PatternLockViewState> _patternKey =
      GlobalKey<PatternLockViewState>();
  bool _showForgotDialog = false;

  Worker? _biometricsWorker;

  @override
  void initState() {
    super.initState();
    _initAutoFingerprint();
  }

  void _initAutoFingerprint() {
    void prompt() {
      if (!mounted) return;
      if (_controller.isBiometricEnabled.value &&
          _controller.canUseBiometrics.value &&
          _controller.isLocked.value &&
          !_controller.isAuthenticating.value &&
          !_controller.hasUserDismissedBiometrics) {
        _controller.authenticateWithBiometrics();
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_controller.canUseBiometrics.value) {
        prompt();
      } else if (_controller.isBiometricEnabled.value) {
        _biometricsWorker?.dispose();
        _biometricsWorker = once(_controller.canUseBiometrics, (canUse) {
          if (canUse) {
            prompt();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _biometricsWorker?.dispose();
    super.dispose();
  }

  void _onPinEntered(String pin) {
    final success = _controller.verifyPin(pin);
    if (!success) {
      _pinPadKey.currentState?.triggerError();
    }
  }

  void _onPatternEntered(List<int> points) {
    final success = _controller.verifyPattern(points);
    if (!success) {
      _patternKey.currentState?.triggerError();
    }
  }

  void _showForgotPasscodeDialog() {
    setState(() => _showForgotDialog = true);
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_showForgotDialog) {
          setState(() => _showForgotDialog = false);
        }
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: dark ? AppColors.dark : const Color(0xFFF7F9FC),
            body: SafeArea(
              child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth - 48 > 0
                      ? (constraints.maxWidth - 48 < 420
                          ? constraints.maxWidth - 48
                          : 420)
                      : 0,
                  maxWidth: 420,
                  minHeight: constraints.maxHeight - 32 > 0
                      ? constraints.maxHeight - 32
                      : 0,
                ),
                child: Center(
                  child: Obx(() {
                    final isPattern =
                        _controller.lockType.value == AppLockType.pattern;

                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // ── Lock Icon ──
                        Container(
                          width: 64,
                          height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.25),
                          width: 1.5,
                        ),
                      ),
                      child: const Icon(
                        Iconsax.lock_1_copy,
                        color: AppColors.primary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceBtwItems),

                    // ── Titles ──
                    Text(
                      'MatricMate Admin',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.3,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isPattern ? 'Draw unlock pattern' : 'Enter passcode',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Pad or Pattern View ──
                    if (isPattern)
                      Column(
                        children: [
                          PatternLockView(
                            key: _patternKey,
                            dimension: 270,
                            onCompleted: _onPatternEntered,
                          ),
                          const SizedBox(height: 16),
                          if (_controller.isBiometricEnabled.value &&
                              _controller.canUseBiometrics.value)
                            IconButton(
                              onPressed: () => _controller.authenticateWithBiometrics(
                                userInitiated: true,
                              ),
                              tooltip: 'Unlock with biometrics',
                              icon: const Icon(
                                Iconsax.finger_scan_copy,
                                size: 30,
                                color: AppColors.primary,
                              ),
                            ),
                        ],
                      )
                    else
                      PinPadView(
                        key: _pinPadKey,
                        pinLength: _controller.pinLength.value,
                        onCompleted: _onPinEntered,
                        showBiometricButton:
                            _controller.isBiometricEnabled.value &&
                                _controller.canUseBiometrics.value,
                        onBiometricPressed: () =>
                            _controller.authenticateWithBiometrics(
                          userInitiated: true,
                        ),
                      ),

                    const SizedBox(height: 28),

                    // ── Forgot Passcode Recovery ──
                    TextButton(
                      onPressed: _showForgotPasscodeDialog,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                      child: const Text(
                        'Forgot Passcode?',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        );
      },
    ),
  ),
),
if (_showForgotDialog)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.55),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: SingleChildScrollView(
                  child: Center(
                    child: _ForgotPasscodeDialog(
                      onClose: () => setState(() => _showForgotDialog = false),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Forgot Passcode Emergency Dialog ──────────────────────────────────────

class _ForgotPasscodeDialog extends StatefulWidget {
  const _ForgotPasscodeDialog({required this.onClose});

  final VoidCallback onClose;

  @override
  State<_ForgotPasscodeDialog> createState() => _ForgotPasscodeDialogState();
}

class _ForgotPasscodeDialogState extends State<_ForgotPasscodeDialog> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePass = true;
  bool _resetPasscode = true;

  @override
  void initState() {
    super.initState();
    // Prefill with current authenticated admin email
    String? currentEmail;
    try {
      currentEmail = Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {
      // Supabase not initialized in tests or offline
    }

    if (currentEmail != null && currentEmail.isNotEmpty) {
      _emailCtrl.text = currentEmail;
    } else if (Get.isRegistered<AdminSessionService>()) {
      final email = AdminSessionService.instance.admin.value.email;
      if (email.isNotEmpty) _emailCtrl.text = email;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final result = await AppLockController.instance.unlockWithAdminCredentials(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
      resetPasscode: _resetPasscode,
    );

    if (!mounted) return;

    if (result.success) {
      widget.onClose();
      AppToast.success(
        'App Unlocked',
        message: _resetPasscode
            ? 'Admin verified. Forgotten passcode has been reset.'
            : 'Admin credentials verified. You can change your passcode in Settings.',
      );
    } else {
      AppToast.error(
        'Verification Failed',
        message: result.error ?? 'Incorrect admin email or password.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final ctrl = AppLockController.instance;

    return Material(
      color: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      elevation: 16,
      shadowColor: Colors.black54,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.defaultSpace),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Iconsax.security_safe_copy,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: AppSizes.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Admin Identity Verification',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const Text(
                            'Enter your Supabase admin credentials to unlock',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceBtwSections),

                // Email
                TextFormField(
                  controller: _emailCtrl,
                  validator: AppValidator.validateEmail,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Admin Email',
                    prefixIcon: Icon(Iconsax.direct_right_copy),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwInputFields),

                // Password
                TextFormField(
                  controller: _passCtrl,
                  validator: (v) => AppValidator.validateEmptyText('Password', v),
                  obscureText: _obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Admin Password',
                    prefixIcon: const Icon(Iconsax.lock_copy),
                    suffixIcon: IconButton(
                      onPressed: () => setState(() => _obscurePass = !_obscurePass),
                      icon: Icon(
                        _obscurePass ? Iconsax.eye_slash_copy : Iconsax.eye_copy,
                      ),
                    ),
                  ),
                  onFieldSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: AppSizes.sm),
                Material(
                  type: MaterialType.transparency,
                  child: CheckboxListTile(
                    value: _resetPasscode,
                    onChanged: (v) => setState(() => _resetPasscode = v ?? true),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Reset forgotten passcode lock',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Clears PIN/Pattern upon unlock so you can set a fresh one in Settings',
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwSections),

                // Submit button
                Obx(
                  () => SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: ctrl.isVerifyingAdmin.value ? null : _submit,
                      child: ctrl.isVerifyingAdmin.value
                          ? const AppCircularButtonLoading()
                          : const Text('Verify & Unlock'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
