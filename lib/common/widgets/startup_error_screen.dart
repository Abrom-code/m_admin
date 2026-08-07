import 'package:flutter/material.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/themes/app_theme.dart';

/// A single thing that went wrong during startup.
class StartupProblem {
  const StartupProblem({required this.title, required this.detail});

  final String title;
  final String detail;
}

/// Shown instead of the app when configuration is missing or a backend client
/// could not be initialised.
///
/// This exists because silent misconfiguration is expensive here: the parent
/// app falls back to `dotenv.env['SUPABASE_URL'] ?? ''` and boots against an
/// empty URL, so every later call fails for reasons that look like network
/// errors. An admin tool that moves money should refuse to start and say why.
class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key, required this.problems});

  final List<StartupProblem> problems;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MatricMate Admin — configuration error',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      home: Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.defaultSpace),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSizes.sm),
                        decoration: BoxDecoration(
                          color: AppColors.error.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error_outline_rounded,
                          color: AppColors.error,
                          size: AppSizes.iconMd,
                        ),
                      ),
                      const SizedBox(width: AppSizes.sm),
                      Expanded(
                        child: Text(
                          'MatricMate Admin cannot start',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSizes.sm),
                  const Text(
                    'Fix the following, then restart the app.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSizes.spaceBtwItems),
                  for (final p in problems) ...[
                    _ProblemCard(problem: p),
                    const SizedBox(height: AppSizes.spaceBtwItems),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProblemCard extends StatelessWidget {
  const _ProblemCard({required this.problem});

  final StartupProblem problem;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.white,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            spreadRadius: -2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            problem.title,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSizes.xs),
          SelectableText(
            problem.detail,
            style: const TextStyle(
              fontSize: 12,
              height: 1.5,
              color: AppColors.textSecondary,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
