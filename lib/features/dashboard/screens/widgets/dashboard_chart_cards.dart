import 'package:flutter/material.dart';
import 'package:get/get.dart';
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'PAID VS UNPAID',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Obx(() => Tooltip(
                      message: controller.isActiveHidden.value ? 'Show active' : 'Hide active',
                      child: InkWell(
                        onTap: controller.toggleActiveVisibility,
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Icon(
                            controller.isActiveHidden.value
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            size: 13,
                            color: controller.isActiveHidden.value
                                ? AppColors.primary
                                : AppColors.textSecondary.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                    )),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Obx(() {
                final s = controller.stats.value;
                final pct = s != null && s.totalUsers > 0
                    ? (s.paidUsers / s.totalUsers * 100).toStringAsFixed(0)
                    : '0';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$pct% Paid',
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Obx(() {
            final s = controller.stats.value;
            if (s == null || s.totalUsers == 0) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.md),
                child: Center(
                  child: Text(
                    'No user data yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              );
            }

            final activeLabel = controller.isActiveHidden.value
                ? 'Active (••••)'
                : 'Active (${s.paidUsers})';
            final segments = [
              DonutSegment(
                label: activeLabel,
                value: s.paidUsers.toDouble(),
                color: AppColors.success,
              ),
              DonutSegment(
                label: 'Free (${s.unpaidUsers})',
                value: s.unpaidUsers.toDouble(),
                color: dark ? AppColors.darkGrey : AppColors.grey,
              ),
            ];

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                child: AdminDonutChart(segments: segments, size: 100),
              ),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'STREAM DISTRIBUTION',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Obx(() {
                final split = controller.streamSplit;
                final total = split.fold<int>(0, (sum, s) => sum + s.count);
                return Text(
                  '$total Enrolled',
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Obx(() {
            final split = controller.streamSplit;
            if (split.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.md),
                child: Center(
                  child: Text(
                    'No stream data yet',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                  ),
                ),
              );
            }

            final segments = split
                .map(
                  (s) => DonutSegment(
                    label: s.stream.isEmpty
                        ? 'Unspecified'
                        : '${s.stream[0].toUpperCase()}${s.stream.substring(1)} (${s.count})',
                    value: s.count.toDouble(),
                    color: _colors[s.stream.toLowerCase()] ?? AppColors.darkGrey,
                  ),
                )
                .toList();

            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.xs),
                child: AdminDonutChart(segments: segments, size: 100),
              ),
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
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'CONVERSION FUNNEL',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              SizedBox(width: 4),
              Text(
                'Signups, Inactives, Actives & Submitted',
                style: TextStyle(
                  fontSize: 10.5,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.sm),
          Obx(() {
            final funnel = controller.subscriptionFunnel;
            if (funnel.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.md),
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
    required Color color,
    required bool dark,
  }) {
    final pctTop = topCount > 0 ? (count / topCount * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${index + 1}. ',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                NumberFormat('#,##0').format(count),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: dark ? AppColors.white : AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${pctTop.toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: topCount > 0 ? (count / topCount).clamp(0.0, 1.0) : 0,
              backgroundColor: dark
                  ? AppColors.darkSurface
                  : AppColors.grey.withValues(alpha: 0.35),
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
        return AppColors.info; // 1. Signups
      case 1:
        return AppColors.warning; // 2. Inactives
      case 2:
        return AppColors.success; // 3. Actives
      case 3:
        return AppColors.primary; // 4. Submitted
      default:
        return AppColors.primary;
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  'EXAM & TEST COVERAGE',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              InkWell(
                onTap: () => AdminNavController.instance.changePage(AdminNavPage.content),
                child: const Text(
                  'Manage in Content ➔',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSizes.xs),
          // ── Category Aggregates Bar ──
          Obx(() {
            final subjects = controller.subjectTestCounts;
            final totalEntrance = subjects.fold<int>(0, (s, e) => s + e.entranceCount);
            final totalModel = subjects.fold<int>(0, (s, e) => s + e.modelCount);
            final totalChapter = subjects.fold<int>(0, (s, e) => s + e.chapterGradeCount);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CategoryTag(
                    label: 'Entrance',
                    count: totalEntrance,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  _CategoryTag(
                    label: 'Model',
                    count: totalModel,
                    color: AppColors.amberAccent,
                  ),
                  const SizedBox(width: 6),
                  _CategoryTag(
                    label: 'Tests',
                    count: totalChapter,
                    color: AppColors.info,
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: AppSizes.sm),
          Obx(() {
            final subjects = controller.subjectTestCounts;
            if (subjects.isEmpty) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSizes.md),
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
                final isWide = constraints.maxWidth >= 550;

                if (isWide) {
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: AppSizes.sm,
                      mainAxisSpacing: 4,
                      mainAxisExtent: 56,
                    ),
                    itemCount: subjects.length,
                    itemBuilder: (context, idx) {
                      return _buildSubjectRow(
                        subjects[idx],
                        maxCount,
                        dark,
                      );
                    },
                  );
                }

                return Column(
                  children: subjects
                      .map((s) => _buildSubjectRow(s, maxCount, dark))
                      .toList(),
                );
              },
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(
    SubjectTestCount subject,
    int maxCount,
    bool dark,
  ) {
    final hasZero = subject.testCount == 0;
    final color = hasZero ? AppColors.error : AppColors.primary;

    return InkWell(
      onTap: () => AdminNavController.instance.changePage(AdminNavPage.content),
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
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
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Breakdown chips for Entrance, Model, Tests
                if (subject.entranceCount > 0) ...[
                  _MiniTypeChip(
                    text: '${subject.entranceCount} Ent',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 3),
                ],
                if (subject.modelCount > 0) ...[
                  _MiniTypeChip(
                    text: '${subject.modelCount} Mod',
                    color: AppColors.amberAccent,
                  ),
                  const SizedBox(width: 3),
                ],
                if (subject.chapterGradeCount > 0) ...[
                  _MiniTypeChip(
                    text: '${subject.chapterGradeCount} Test',
                    color: AppColors.info,
                  ),
                  const SizedBox(width: 3),
                ],
                Text(
                  '${subject.testCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: maxCount > 0 ? (subject.testCount / maxCount) : 0,
                backgroundColor: dark
                    ? AppColors.darkSurface
                    : AppColors.grey.withValues(alpha: 0.3),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTag extends StatelessWidget {
  const _CategoryTag({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 4),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTypeChip extends StatelessWidget {
  const _MiniTypeChip({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }
}
