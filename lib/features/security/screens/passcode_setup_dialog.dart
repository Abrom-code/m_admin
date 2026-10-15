import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/toast/app_toast.dart';
import 'package:m_admin/features/security/controllers/app_lock_controller.dart';
import 'package:m_admin/features/security/widgets/pattern_lock_view.dart';
import 'package:m_admin/features/security/widgets/pin_pad_view.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class PasscodeSetupDialog extends StatefulWidget {
  const PasscodeSetupDialog({super.key});

  static Future<void> show(BuildContext context) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => const PasscodeSetupDialog(),
    );
  }

  @override
  State<PasscodeSetupDialog> createState() => _PasscodeSetupDialogState();
}

class _PasscodeSetupDialogState extends State<PasscodeSetupDialog> {
  final _controller = AppLockController.instance;

  AppLockType _selectedType = AppLockType.pin;
  int _pinLength = 4;
  bool _enableBiometrics = false;

  int _step = 0; // 0 = first entry, 1 = confirm entry
  String _firstCode = '';
  final GlobalKey<PinPadViewState> _pinPadKey = GlobalKey<PinPadViewState>();
  final GlobalKey<PatternLockViewState> _patternKey =
      GlobalKey<PatternLockViewState>();

  @override
  void initState() {
    super.initState();
    _selectedType = _controller.lockType.value;
    _pinLength = _controller.pinLength.value;
    _enableBiometrics = _controller.isBiometricEnabled.value &&
        _controller.canUseBiometrics.value;
  }

  void _onCodeEntered(String code) {
    if (_step == 0) {
      setState(() {
        _firstCode = code;
        _step = 1;
      });
      _pinPadKey.currentState?.clear();
      _patternKey.currentState?.clear();
    } else {
      if (code == _firstCode) {
        _controller.setPasscode(
          passcode: code,
          type: _selectedType,
          length: _selectedType == AppLockType.pin ? _pinLength : null,
          enableBiometrics: _enableBiometrics,
        );
        Navigator.of(context).pop();
        AppToast.success(
          'Passcode Lock Activated',
          message:
              'Your admin console is now protected by ${_selectedType == AppLockType.pin ? "PIN" : "Pattern"} lock.',
        );
      } else {
        AppToast.error(
          'Codes Do Not Match',
          message: 'Please try again from the beginning.',
        );
        _pinPadKey.currentState?.triggerError();
        _patternKey.currentState?.triggerError();
        setState(() {
          _step = 0;
          _firstCode = '';
        });
      }
    }
  }

  void _onPatternCompleted(List<int> points) {
    if (points.length < 4) {
      AppToast.warning(
        'Pattern Too Short',
        message: 'Connect at least 4 dots.',
      );
      _patternKey.currentState?.triggerError();
      return;
    }
    _onCodeEntered(points.join('-'));
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

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
                          _controller.isPasscodeEnabled.value
                              ? 'Change Passcode Lock'
                              : 'Set Up Passcode Lock',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          _step == 0
                              ? (_selectedType == AppLockType.pin
                                  ? 'Enter a $_pinLength-digit PIN'
                                  : 'Draw an unlock pattern')
                              : 'Re-enter to confirm',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceBtwItems),

              // ── Type Selector (only on step 0) ──
              if (_step == 0) ...[
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: dark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _TypeButton(
                          label: 'PIN Code',
                          icon: Iconsax.hashtag_copy,
                          isSelected: _selectedType == AppLockType.pin,
                          onTap: () {
                            setState(() {
                              _selectedType = AppLockType.pin;
                              _step = 0;
                              _firstCode = '';
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: _TypeButton(
                          label: 'Pattern Grid',
                          icon: Iconsax.grid_2_copy,
                          isSelected: _selectedType == AppLockType.pattern,
                          onTap: () {
                            setState(() {
                              _selectedType = AppLockType.pattern;
                              _step = 0;
                              _firstCode = '';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.sm),

                // PIN length selector if PIN chosen
                if (_selectedType == AppLockType.pin)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: AppSizes.xs),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: dark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.black.withValues(alpha: 0.04),
                            borderRadius:
                                BorderRadius.circular(AppSizes.borderRadiusSm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _PinLengthChip(
                                label: '4 Digits',
                                isSelected: _pinLength == 4,
                                onTap: () {
                                  setState(() {
                                    _pinLength = 4;
                                    _step = 0;
                                    _firstCode = '';
                                  });
                                  _pinPadKey.currentState?.clear();
                                },
                              ),
                              const SizedBox(width: 4),
                              _PinLengthChip(
                                label: '6 Digits',
                                isSelected: _pinLength == 6,
                                onTap: () {
                                  setState(() {
                                    _pinLength = 6;
                                    _step = 0;
                                    _firstCode = '';
                                  });
                                  _pinPadKey.currentState?.clear();
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: AppSizes.md),
              ],

              // ── Interactive Pad / Pattern ──
              if (_selectedType == AppLockType.pin)
                PinPadView(
                  key: _pinPadKey,
                  pinLength: _pinLength,
                  onCompleted: _onCodeEntered,
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
                      'Connect at least 4 dots',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),

              const SizedBox(height: AppSizes.spaceBtwItems),

              // ── Biometric Switch (if hardware supported) ──
              if (_controller.canUseBiometrics.value && _step == 0)
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: _enableBiometrics,
                    onChanged: (v) => setState(() => _enableBiometrics = v),
                    title: const Text(
                      'Enable Fingerprint Unlock',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Unlock instantly using your device fingerprint scanner',
                      style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                    ),
                  ),
                ),

              // ── Disable Button (if already active) ──
              if (_controller.isPasscodeEnabled.value && _step == 0) ...[
                const Divider(),
                TextButton.icon(
                  onPressed: () async {
                    await _controller.disablePasscode();
                    if (context.mounted) {
                      Navigator.of(context).pop();
                      AppToast.info(
                        'Passcode Lock Disabled',
                        message: 'App lock has been turned off.',
                      );
                    }
                  },
                  icon: const Icon(Iconsax.lock_slash_copy, size: 18, color: AppColors.error),
                  label: const Text(
                    'Turn Off Passcode Lock',
                    style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600),
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

class _TypeButton extends StatelessWidget {
  const _TypeButton({
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
                size: 16,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
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

class _PinLengthChip extends StatelessWidget {
  const _PinLengthChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm - 2),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm - 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
