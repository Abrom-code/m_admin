import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class PinPadView extends StatefulWidget {
  const PinPadView({
    super.key,
    required this.pinLength,
    required this.onCompleted,
    this.onBiometricPressed,
    this.showBiometricButton = false,
  });

  final int pinLength;
  final ValueChanged<String> onCompleted;
  final VoidCallback? onBiometricPressed;
  final bool showBiometricButton;

  @override
  State<PinPadView> createState() => PinPadViewState();
}

class PinPadViewState extends State<PinPadView>
    with SingleTickerProviderStateMixin {
  String _enteredPin = '';
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 450),
      vsync: this,
    );

    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -12.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -12.0, end: 12.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 12.0, end: -8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -8.0, end: 8.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void triggerError() {
    HapticFeedback.vibrate();
    setState(() {
      _hasError = true;
    });
    _shakeController.forward(from: 0).then((_) {
      if (mounted) {
        setState(() {
          _enteredPin = '';
          _hasError = false;
        });
      }
    });
  }

  void clear() {
    setState(() {
      _enteredPin = '';
      _hasError = false;
    });
  }

  void _onDigitPressed(String digit) {
    if (_enteredPin.length >= widget.pinLength) return;

    HapticFeedback.lightImpact();
    setState(() {
      _enteredPin += digit;
      _hasError = false;
    });

    if (_enteredPin.length == widget.pinLength) {
      widget.onCompleted(_enteredPin);
    }
  }

  void _onBackspacePressed() {
    if (_enteredPin.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Dot Indicators ──
        FittedBox(
          fit: BoxFit.scaleDown,
          child: AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(_shakeAnimation.value, 0),
                child: child,
              );
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.pinLength, (index) {
                final isFilled = index < _enteredPin.length;
                final dotColor = _hasError
                    ? AppColors.error
                    : (isFilled ? AppColors.primary : Colors.transparent);
                final borderColor = _hasError
                    ? AppColors.error
                    : (isFilled
                        ? AppColors.primary
                        : (dark ? Colors.white38 : Colors.black26));

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  width: isFilled ? 18 : 16,
                  height: isFilled ? 18 : 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: Border.all(
                      color: borderColor,
                      width: 2.2,
                    ),
                    boxShadow: isFilled && !_hasError
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: 28),

        // ── Keypad Grid (Telegram style) ──
        FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            width: 280,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDigitRow(['1', '2', '3'], dark),
                const SizedBox(height: 14),
                _buildDigitRow(['4', '5', '6'], dark),
                const SizedBox(height: 14),
                _buildDigitRow(['7', '8', '9'], dark),
                const SizedBox(height: 14),
                _buildKeypadRow(
                  widget.showBiometricButton
                      ? _buildIconButton(
                          icon: Iconsax.finger_scan_copy,
                          onTap: widget.onBiometricPressed,
                          dark: dark,
                        )
                      : const SizedBox(width: 64, height: 64),
                  _buildDigitButton('0', dark),
                  _buildIconButton(
                    icon: Icons.backspace_outlined,
                    onTap: _onBackspacePressed,
                    onLongPress: clear,
                    dark: dark,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeypadRow(Widget c1, Widget c2, Widget c3) {
    return Row(
      children: [
        Expanded(child: Center(child: c1)),
        Expanded(child: Center(child: c2)),
        Expanded(child: Center(child: c3)),
      ],
    );
  }

  Widget _buildDigitRow(List<String> digits, bool dark) {
    return _buildKeypadRow(
      _buildDigitButton(digits[0], dark),
      _buildDigitButton(digits[1], dark),
      _buildDigitButton(digits[2], dark),
    );
  }

  Widget _buildDigitButton(String digit, bool dark) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onDigitPressed(digit),
          customBorder: const CircleBorder(),
          splashColor: AppColors.primary.withValues(alpha: 0.18),
          highlightColor: AppColors.primary.withValues(alpha: 0.08),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
              border: Border.all(
                color: dark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.07),
                width: 1.2,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              digit,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w500,
                color: dark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onTap,
    VoidCallback? onLongPress,
    required bool dark,
  }) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          customBorder: const CircleBorder(),
          splashColor: AppColors.primary.withValues(alpha: 0.18),
          highlightColor: AppColors.primary.withValues(alpha: 0.08),
          child: Center(
            child: Icon(
              icon,
              size: 24,
              color: dark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
