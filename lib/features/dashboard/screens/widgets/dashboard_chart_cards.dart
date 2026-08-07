import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/charts/donut_chart_painter.dart';
import 'package:m_admin/features/dashboard/controllers/dashboard_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

// ── Paid vs Unpaid donut ───────────────────────────────────────────────

class PaidUnpaidDonutCard extends StatelessWidget {
  const PaidUnpaidDonutCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;

    return AdminSection(
      title: 'Paid vs unpaid',
      child: Obx(() {
        final s = controller.stats.value;
        if (s == null || s.totalUsers == 0) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Text(
              'No user data yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          );
        }

        final segments = [
          DonutSegment(
            label: 'Paid',
            value: s.paidUsers.toDouble(),
            color: AppColors.success,
          ),
          DonutSegment(
            label: 'Unpaid',
            value: s.unpaidUsers.toDouble(),
            color: AppColors.grey,
          ),
        ];

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
          child: AdminDonutChart(segments: segments),
        );
      }),
    );
  }
}

// ── Stream split donut ────────────────────────────────────────────────

class StreamSplitCard extends StatelessWidget {
  const StreamSplitCard({super.key});

  static const _colors = {
    'natural': AppColors.success,
    'social': AppColors.info,
    'common': AppColors.amberAccent,
  };

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;

    return AdminSection(
      title: 'Stream split',
      child: Obx(() {
        final split = controller.streamSplit;
        if (split.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Text(
              'No data yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          );
        }

        final segments = split
            .map(
              (s) => DonutSegment(
                label: s.stream,
                value: s.count.toDouble(),
                color: _colors[s.stream.toLowerCase()] ?? AppColors.darkGrey,
              ),
            )
            .toList();

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSizes.sm),
          child: AdminDonutChart(segments: segments),
        );
      }),
    );
  }
}

// ── Subscription funnel ───────────────────────────────────────────────

class FunnelCard extends StatelessWidget {
  const FunnelCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;

    return AdminSection(
      title: 'Subscription funnel',
      child: Obx(() {
        final funnel = controller.subscriptionFunnel;
        if (funnel.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Text(
              'No data yet',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          );
        }

        final top = funnel.first.count;

        return Column(
          children: [
            for (int i = 0; i < funnel.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            funnel[i].label,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          NumberFormat.compact().format(funnel[i].count),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          top > 0
                              ? '(${(funnel[i].count / top * 100).toStringAsFixed(0)}%)'
                              : '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: top > 0 ? funnel[i].count / top : 0,
                        backgroundColor: AppColors.grey,
                        valueColor: AlwaysStoppedAnimation(_stageColor(i)),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }

  Color _stageColor(int index) {
    switch (index) {
      case 0:
        return AppColors.primary;
      case 1:
        return AppColors.info;
      case 2:
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }
}

// ── Tests per subject ─────────────────────────────────────────────────

class SubjectTestCountCard extends StatelessWidget {
  const SubjectTestCountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = DashboardController.instance;

    return AdminSection(
      title: 'Tests per subject',
      child: Obx(() {
        final subjects = controller.subjectTestCounts;
        if (subjects.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Text(
              'No subjects found',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          );
        }

        final maxCount = subjects.fold<int>(
          1,
          (m, s) => s.testCount > m ? s.testCount : m,
        );

        return Column(
          children: [
            for (final subject in subjects)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSizes.xs + 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subject.subjectName,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                        ),
                        Text(
                          '${subject.testCount} test${subject.testCount == 1 ? '' : 's'}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: subject.testCount == 0
                                ? AppColors.error
                                : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        minHeight: 7,
                        value: subject.testCount / maxCount,
                        backgroundColor: AppColors.grey,
                        valueColor: AlwaysStoppedAnimation(
                          subject.testCount == 0
                              ? AppColors.error
                              : AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      }),
    );
  }
}
