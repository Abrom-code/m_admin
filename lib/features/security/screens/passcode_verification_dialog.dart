import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/features/security/controllers/app_lock_controller.dart';
import 'package:m_admin/features/security/widgets/pattern_lock_view.dart';
import 'package:m_admin/features/security/widgets/pin_pad_view.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/validators/validators.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum _VerifyMode { passcode, adminLogin }

/// Dialog requiring the admin to verify either their current passcode
/// (PIN or Pattern) OR login with admin email and password before
/// changing security settings or turning off app lock.
class PasscodeVerificationDialog extends StatefulWidget {
  const PasscodeVerificationDialog({
    super.key,
    this.title = 'Security Verification',
    this.subtitle = 'Re-enter your previous passcode or login with admin credentials to proceed.',
  });

  final String title;
  final String subtitle;

  /// Shows the dialog and returns `true` if verification succeeded, or `false` otherwise.
  static Future<bool> show(
    BuildContext context, {
    String? title,
    String? subtitle,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => PasscodeVerificationDialog(
        title: title ?? 'Security Verification',
        subtitle: subtitle ??
            'Re-enter your previous passcode or login with admin credentials to proceed.',
      ),
    );
    return result ?? false;
  }

  @override
  State<PasscodeVerificationDialog> createState() =>
      _PasscodeVerificationDialogState();
}

class _PasscodeVerificationDialogState
    extends State<PasscodeVerificationDialog> {
  final _controller = AppLockController.instance;

  _VerifyMode _mode = _VerifyMode.passcode;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  final GlobalKey<PinPadViewState> _pinPadKey = GlobalKey<PinPadViewState>();
  final GlobalKey<PatternLockViewState> _patternKey =
      GlobalKey<PatternLockViewState>();

  bool _obscurePass = true;
  String? _passcodeError;
  String? _adminError;

  @override
  void initState() {
    super.initState();
    // Prefill admin email if available
    String? currentEmail;
    try {
      currentEmail = Supabase.instance.client.auth.currentUser?.email;
    } catch (_) {}

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

  void _onPinEntered(String pin) {
    final valid = _controller.checkPasscode(pin);
    if (valid) {
      Navigator.of(context).pop(true);
    } else {
      _pinPadKey.currentState?.triggerError();
      setState(() {
        _passcodeError = 'Incorrect PIN code. Try again or switch to Admin Login.';
      });
    }
  }

  void _onPatternCompleted(List<int> points) {
    final valid = _controller.checkPattern(points);
    if (valid) {
      Navigator.of(context).pop(true);
    } else {
      _patternKey.currentState?.triggerError();
      setState(() {
        _passcodeError = 'Incorrect pattern. Try again or switch to Admin Login.';
      });
    }
  }

  Future<void> _submitAdminLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _adminError = null);

    final res = await _controller.verifyAdminCredentials(
      email: _emailCtrl.text.trim(),
      password: _passCtrl.text,
    );

    if (!mounted) return;

    if (res.success) {
      Navigator.of(context).pop(true);
    } else {
      setState(() {
        _adminError = res.error ?? 'Invalid admin credentials.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final isPin = _controller.lockType.value == AppLockType.pin;

    return Dialog(
      backgroundColor: dark ? AppColors.darkCard : AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.defaultSpace),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──
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
                          widget.title,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceBtwItems),

              // ── Mode Selector Tabs (Passcode vs Admin Login) ──
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _ModeTabButton(
                        label: isPin ? 'Previous PIN' : 'Previous Pattern',
                        icon: isPin ? Iconsax.hashtag_copy : Iconsax.grid_2_copy,
                        isSelected: _mode == _VerifyMode.passcode,
                        onTap: () {
                          setState(() {
                            _mode = _VerifyMode.passcode;
                            _passcodeError = null;
                            _adminError = null;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _ModeTabButton(
                        label: 'Admin Login',
                        icon: Iconsax.key_copy,
                        isSelected: _mode == _VerifyMode.adminLogin,
                        onTap: () {
                          setState(() {
                            _mode = _VerifyMode.adminLogin;
                            _passcodeError = null;
                            _adminError = null;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSizes.md),

              // ── Content ──
              if (_mode == _VerifyMode.passcode) ...[
                if (_passcodeError != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                      border: Border.all(
                        color: AppColors.error.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 15,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _passcodeError!,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: AppColors.error,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.sm),
                ],

                if (isPin)
                  PinPadView(
                    key: _pinPadKey,
                    pinLength: _controller.pinLength.value,
                    onCompleted: _onPinEntered,
                    showBiometricButton: false,
                  )
                else
                  Column(
                    children: [
                      PatternLockView(
                        key: _patternKey,
                        dimension: 260,
                        onCompleted: _onPatternCompleted,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Draw previous unlock pattern',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: AppSizes.sm),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _mode = _VerifyMode.adminLogin;
                        _passcodeError = null;
                      });
                    },
                    icon: const Icon(Iconsax.lock_1_copy, size: 14),
                    label: const Text(
                      'Forgot previous passcode? Login with Admin credentials',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ] else ...[
                // Admin Login Form
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_adminError != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.1),
                            borderRadius:
                                BorderRadius.circular(AppSizes.borderRadiusSm),
                            border: Border.all(
                              color: AppColors.error.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 15,
                                color: AppColors.error,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _adminError!,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSizes.sm),
                      ],

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

                      TextFormField(
                        controller: _passCtrl,
                        validator: (v) =>
                            AppValidator.validateEmptyText('Password', v),
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          labelText: 'Admin Password',
                          prefixIcon: const Icon(Iconsax.lock_copy),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                            icon: Icon(
                              _obscurePass
                                  ? Iconsax.eye_slash_copy
                                  : Iconsax.eye_copy,
                            ),
                          ),
                        ),
                        onFieldSubmitted: (_) => _submitAdminLogin(),
                      ),
                      const SizedBox(height: AppSizes.spaceBtwSections),

                      Obx(
                        () => SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _controller.isVerifyingAdmin.value
                                ? null
                                : _submitAdminLogin,
                            child: _controller.isVerifyingAdmin.value
                                ? const AppCircularButtonLoading()
                                : const Text('Verify & Proceed'),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      Center(
                        child: TextButton.icon(
                          onPressed: () {
                            setState(() {
                              _mode = _VerifyMode.passcode;
                              _adminError = null;
                            });
                          },
                          icon: Icon(
                            isPin
                                ? Iconsax.hashtag_copy
                                : Iconsax.grid_2_copy,
                            size: 14,
                          ),
                          label: Text(
                            isPin
                                ? 'Use previous PIN code'
                                : 'Use previous pattern',
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeTabButton extends StatelessWidget {
  const _ModeTabButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
