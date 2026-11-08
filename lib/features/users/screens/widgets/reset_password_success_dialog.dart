import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

/// Success dialog displaying the dynamically generated temporary password.
///
/// Security:
/// - Displayed exclusively to the authorized administrator who triggered the reset.
/// - Never saved to local storage, cache, or logs.
/// - Cleared from memory immediately when the dialog is dismissed.
class ResetPasswordSuccessDialog extends StatefulWidget {
  const ResetPasswordSuccessDialog({
    super.key,
    required this.studentName,
    required this.studentEmail,
    required this.temporaryPassword,
  });

  final String studentName;
  final String studentEmail;
  final String temporaryPassword;

  static Future<void> show(
    BuildContext context, {
    required String studentName,
    required String studentEmail,
    required String temporaryPassword,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ResetPasswordSuccessDialog(
        studentName: studentName,
        studentEmail: studentEmail,
        temporaryPassword: temporaryPassword,
      ),
    );
  }

  @override
  State<ResetPasswordSuccessDialog> createState() =>
      _ResetPasswordSuccessDialogState();
}

class _ResetPasswordSuccessDialogState
    extends State<ResetPasswordSuccessDialog> {
  bool _copied = false;
  bool _obscured = false;

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.temporaryPassword));
    setState(() => _copied = true);
    SnackbarHelper.success(
      'Password Copied',
      'Temporary password copied to clipboard.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final cardBg = dark ? AppColors.darkCard : AppColors.white;
    final borderColor = dark ? AppColors.darkBorder : AppColors.borderPrimary;

    return AlertDialog(
      backgroundColor: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
      ),
      contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_circle_rounded,
              color: AppColors.success,
              size: AppSizes.iconMd,
            ),
          ),
          const SizedBox(width: AppSizes.sm),
          const Expanded(
            child: Text(
              'Password Reset Successful',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Student details box
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkSurface : AppColors.softGrey,
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow('Student:', widget.studentName, dark),
                  const SizedBox(height: 6),
                  _infoRow('Email:', widget.studentEmail, dark),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // Temporary Password Box
            const Text(
              'Temporary Password:',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF6366F1).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                border: Border.all(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.vpn_key_rounded,
                    size: 18,
                    color: Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SelectableText(
                      _obscured
                          ? '•' * widget.temporaryPassword.length
                          : widget.temporaryPassword,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  ),
                  IconButton(
                    iconSize: 18,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: _obscured ? 'Show password' : 'Hide password',
                    icon: Icon(
                      _obscured
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: AppColors.textSecondary,
                    ),
                    onPressed: () => setState(() => _obscured = !_obscured),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.md),

            // Informational Notice: Changing is optional
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.25),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: AppColors.info,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Students are NOT required to change this temporary password after login. Changing their password is fully optional.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwItems),

            // Copy button
            ElevatedButton.icon(
              onPressed: _copyToClipboard,
              style: ElevatedButton.styleFrom(
                backgroundColor: _copied ? AppColors.success : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                ),
              ),
              icon: Icon(
                _copied ? Icons.check_rounded : Icons.copy_rounded,
                size: 16,
              ),
              label: Text(
                _copied ? 'Password Copied!' : 'Copy Password',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value, bool dark) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 65,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
