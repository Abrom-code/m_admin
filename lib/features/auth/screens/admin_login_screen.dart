import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/features/auth/controllers/admin_login_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/validators/validators.dart';

/// Sign-in screen.
///
/// There is deliberately no signup link — admin accounts are provisioned by
/// SQL only (see supabase/migrations/0002_seed_admin.sql). A Firebase account
/// without a matching `admins` row is rejected with "Access Denied".
class AdminLoginScreen extends StatelessWidget {
  const AdminLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = AdminLoginController.instance;
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.defaultSpace),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Container(
              padding: const EdgeInsets.all(AppSizes.lg),
              decoration: BoxDecoration(
                color: dark ? AppColors.darkCard : AppColors.white,
                borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 10,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Form(
                key: controller.formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Brand ──────────────────────────────────────
                    Center(
                      child: Container(
                        height: 56,
                        width: 56,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(
                            AppSizes.borderRadiusLg,
                          ),
                        ),
                        child: const Icon(
                          Iconsax.shield_tick_copy,
                          color: AppColors.primary,
                          size: AppSizes.iconLg,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceBtwItems),
                    Text(
                      'MatricMate Admin',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: AppSizes.xs),
                    const Text(
                      'Internal operations console',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceBtwSections),

                    // ── Email ──────────────────────────────────────
                    TextFormField(
                      controller: controller.emailController,
                      validator: AppValidator.validateEmail,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Iconsax.direct_right_copy),
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // ── Password ───────────────────────────────────
                    Obx(
                      () => TextFormField(
                        controller: controller.passwordController,
                        validator: (value) =>
                            AppValidator.validateEmptyText('Password', value),
                        obscureText: controller.hidePassword.value,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => controller.login(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Iconsax.lock_copy),
                          suffixIcon: IconButton(
                            onPressed: controller.togglePasswordVisibility,
                            icon: Icon(
                              controller.hidePassword.value
                                  ? Iconsax.eye_slash_copy
                                  : Iconsax.eye_copy,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.spaceBtwItems),

                    // ── Submit ─────────────────────────────────────
                    Obx(
                      () => SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: controller.isLoading.value
                              ? null
                              : controller.login,
                          child: controller.isLoading.value
                              ? const AppCircularButtonLoading()
                              : const Text('Sign in'),
                        ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.spaceBtwItems),
                    const Text(
                      'Admin accounts are provisioned by the database team.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
