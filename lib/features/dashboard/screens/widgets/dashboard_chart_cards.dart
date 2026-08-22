import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/charts/donut_chart_painter.dart';
import 'package:m_admin/data/repositories/dashboard_repository.dart';
import 'package:m_admin/features/dashboard/controllers/dashboard_controller.dart';
import 'package:m_admin/features/shell/controllers/admin_nav_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

// ── Paid vs Unpaid Donut ───────────────────────────────────────────────

class PaidUnpaidDonutCard extends StatelessWidget {
  const PaidUnpaidDonutCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: const Icon(
                  Iconsax.crown_copy,
                  size: 15,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Paid vs Unpaid Students',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Obx(() {
            final s = controller.stats.value;
            if (s == null || s.totalUsers == 0) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
                child: Center(
                  child: Text(
                    'No user data yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              );
            }

            final conversionRate = s.totalUsers > 0
                ? (s.paidUsers / s.totalUsers * 100).toStringAsFixed(1)
                : '0.0';

            final segments = [
              DonutSegment(
                label: 'Paid (Active)',
                value: s.paidUsers.toDouble(),
                color: AppColors.success,
              ),
              DonutSegment(
                label: 'Unpaid / Free',
                value: s.unpaidUsers.toDouble(),
                color: dark ? AppColors.darkGrey : AppColors.grey,
              ),
            ];

            return Column(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                    child: AdminDonutChart(segments: segments, size: 120),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Iconsax.chart_success_copy,
                        size: 13,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$conversionRate% Paid Conversion Rate',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Stream Split Donut ────────────────────────────────────────────────

class StreamSplitCard extends StatelessWidget {
  const StreamSplitCard({super.key});

  static const _colors = {
    'natural': AppColors.primary,
    'social': AppColors.amberAccent,
    'common': AppColors.info,
  };

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: const Icon(
                  Iconsax.hierarchy_2_copy,
                  size: 15,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Academic Stream Split',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Obx(() {
            final split = controller.streamSplit;
            if (split.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
                child: Center(
                  child: Text(
                    'No stream data yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              );
            }

            final totalStudents =
                split.fold<int>(0, (sum, s) => sum + s.count);

            final segments = split
                .map(
                  (s) => DonutSegment(
                    label: s.stream.isEmpty
                        ? 'Unspecified'
                        : '${s.stream[0].toUpperCase()}${s.stream.substring(1)}',
                    value: s.count.toDouble(),
                    color: _colors[s.stream.toLowerCase()] ?? AppColors.darkGrey,
                  ),
                )
                .toList();

            return Column(
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                    child: AdminDonutChart(segments: segments, size: 120),
                  ),
                ),
                const SizedBox(height: AppSizes.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSizes.sm,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Iconsax.teacher_copy,
                        size: 13,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '$totalStudents Total Enrolled Streams',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

// ── Subscription Funnel ───────────────────────────────────────────────

class FunnelCard extends StatelessWidget {
  const FunnelCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: const Icon(
                  Iconsax.filter_square_copy,
                  size: 16,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Subscription Conversion Funnel',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Text(
                      'Student journey from account registration to active premium access',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Obx(() {
            final funnel = controller.subscriptionFunnel;
            if (funnel.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
                child: Center(
                  child: Text(
                    'No conversion data yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              );
            }

            final top = funnel.first.count;

            return Column(
              children: [
                for (int i = 0; i < funnel.length; i++)
                  _buildFunnelRow(
                    index: i,
                    label: funnel[i].label,
                    count: funnel[i].count,
                    topCount: top,
                    prevCount: i > 0 ? funnel[i - 1].count : top,
                    color: _stageColor(i),
                    dark: dark,
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildFunnelRow({
    required int index,
    required String label,
    required int count,
    required int topCount,
    required int prevCount,
    required Color color,
    required bool dark,
  }) {
    final pctTop = topCount > 0 ? (count / topCount * 100) : 0.0;
    final pctPrev = prevCount > 0 ? (count / prevCount * 100) : 0.0;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(AppSizes.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? 0.06 : 0.04),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: color.withValues(alpha: dark ? 0.2 : 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                NumberFormat('#,##0').format(count),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: dark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${pctTop.toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
              if (index > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '(${pctPrev.toStringAsFixed(0)}% step)',
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              minHeight: 6,
              value: topCount > 0 ? (count / topCount) : 0,
              backgroundColor: dark
                  ? AppColors.darkSurface
                  : AppColors.grey.withValues(alpha: 0.4),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }

  Color _stageColor(int index) {
    switch (index) {
      case 0:
        return AppColors.info;
      case 1:
        return AppColors.amberAccent;
      case 2:
        return AppColors.primary;
      default:
        return AppColors.success;
    }
  }
}

// ── Tests per Subject Matrix ───────────────────────────────────────────

class SubjectTestCountCard extends StatelessWidget {
  const SubjectTestCountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;
    final dark = AppHelperFunctions.isDark(context);

    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.amberAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: const Icon(
                  Iconsax.book_1_copy,
                  size: 16,
                  color: AppColors.amberAccent,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Exam Content & Subject Matrix',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const Text(
                      'Distribution of entrance, model, grade, and chapter tests',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  AdminNavController.instance.changePage(2); // Go to Content
                },
                icon: const Icon(Iconsax.edit_copy, size: 14),
                label: const Text('Manage Tests'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.md),
          Obx(() {
            final subjects = controller.subjectTestCounts;
            if (subjects.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.lg),
                child: Center(
                  child: Text(
                    'No subjects found',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              );
            }

            final maxCount = subjects.fold<int>(
              1,
              (m, s) => s.testCount > m ? s.testCount : m,
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;

                if (isWide) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSizes.sm,
                      mainAxisSpacing: AppSizes.xs,
                      mainAxisExtent: 68,
                    ),
                    itemCount: subjects.length,
                    itemBuilder: (context, idx) {
                      return _buildSubjectTile(
                        subjects[idx],
                        maxCount,
                        dark,
                      );
                    },
                  );
                }

                return Column(
                  children: subjects
                      .map((s) => _buildSubjectTile(s, maxCount, dark))
                      .toList(),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubjectTile(
    SubjectTestCount subject,
    int maxCount,
    bool dark,
  ) {
    final hasZero = subject.testCount == 0;
    final color = hasZero ? AppColors.error : AppColors.primary;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.sm,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: dark
            ? AppColors.darkSurface.withValues(alpha: 0.5)
            : AppColors.lightGrey,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        border: Border.all(
          color: (hasZero ? AppColors.error : AppColors.borderPrimary)
              .withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  subject.subjectName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${subject.testCount} ${subject.testCount == 1 ? 'test' : 'tests'}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: maxCount > 0 ? (subject.testCount / maxCount) : 0,
              backgroundColor: dark
                  ? AppColors.darkSurface
                  : AppColors.grey.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ],
      ),
    );
  }
}
