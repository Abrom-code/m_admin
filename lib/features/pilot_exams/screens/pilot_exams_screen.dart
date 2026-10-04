import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/features/pilot_exams/controllers/pilot_exams_controller.dart';
import 'package:m_admin/features/pilot_exams/models/admin_pilot_exam_model.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class PilotExamsScreen extends StatelessWidget {
  const PilotExamsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(PilotExamsController());
    final dark = AppHelperFunctions.isDark(context);

    return AdminScaffold(
      onRefresh: ctrl.loadPilotExams,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Stats Summary ──────────────────────────────────────────────
          Obx(() {
            final all = ctrl.exams;
            final activeCount = all.where((e) => e.isActive).length;
            final premiumCount = all.where((e) => e.isPremium).length;
            final totalSubjects = all.fold<int>(0, (sum, e) => sum + e.subjectCount);

            return LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final cards = [
                  _StatTile(
                    label: 'Pilot Exams',
                    value: '${all.length}',
                    icon: Iconsax.award_copy,
                    color: AppColors.primary,
                  ),
                  _StatTile(
                    label: 'Active',
                    value: '$activeCount',
                    icon: Iconsax.tick_circle_copy,
                    color: AppColors.success,
                  ),
                  _StatTile(
                    label: 'Premium',
                    value: '$premiumCount',
                    icon: Iconsax.crown_copy,
                    color: AppColors.warning,
                  ),
                  _StatTile(
                    label: 'Configured Subjects',
                    value: '$totalSubjects',
                    icon: Iconsax.book_copy,
                    color: AppColors.info,
                  ),
                ];

                if (isNarrow) {
                  return Wrap(
                    spacing: AppSizes.sm,
                    runSpacing: AppSizes.sm,
                    children: cards
                        .map((c) => SizedBox(
                              width: (constraints.maxWidth - AppSizes.sm) / 2,
                              child: c,
                            ))
                        .toList(),
                  );
                }

                return Row(
                  children: cards
                      .map((c) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSizes.xs,
                              ),
                              child: c,
                            ),
                          ))
                      .toList(),
                );
              },
            );
          }),

          const SizedBox(height: AppSizes.spaceBtwSections),

          // ── Search & Filter Toolbar ────────────────────────────────────
          AdminCard(
            padding: const EdgeInsets.all(AppSizes.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search pilot exams by title or edition...',
                          prefixIcon: const Icon(Iconsax.search_normal_1_copy, size: 20),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSizes.md,
                            vertical: AppSizes.sm,
                          ),
                          suffixIcon: Obx(() {
                            if (ctrl.searchQuery.value.isEmpty) {
                              return const SizedBox.shrink();
                            }
                            return IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () => ctrl.searchQuery.value = '',
                            );
                          }),
                        ),
                        onChanged: (val) => ctrl.searchQuery.value = val,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceBtwItems),
                    ElevatedButton.icon(
                      onPressed: () => Get.toNamed(AdminRoutes.pilotExamEditor),
                      icon: const Icon(Iconsax.add_copy, size: 18),
                      label: const Text('New Pilot Exam'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm + 4),

                // Grade filters
                Wrap(
                  spacing: AppSizes.sm,
                  runSpacing: AppSizes.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Grade:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    _GradeChip(label: 'All', grade: null, controller: ctrl),
                    _GradeChip(label: 'Grade 9', grade: 9, controller: ctrl),
                    _GradeChip(label: 'Grade 10', grade: 10, controller: ctrl),
                    _GradeChip(label: 'Grade 11', grade: 11, controller: ctrl),
                    _GradeChip(label: 'Grade 12', grade: 12, controller: ctrl),
                    Obx(() {
                      final hasFilter = ctrl.selectedGrade.value != null ||
                          ctrl.searchQuery.value.isNotEmpty;
                      if (!hasFilter) return const SizedBox.shrink();

                      return TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: ctrl.clearFilters,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Reset', style: TextStyle(fontSize: 12)),
                      );
                    }),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSizes.spaceBtwSections),

          // ── Pilot Exams List ───────────────────────────────────────────
          Obx(() {
            if (ctrl.isLoading.value && ctrl.exams.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.defaultSpace),
                  child: AppCircularLoading(),
                ),
              );
            }

            final filtered = ctrl.filteredExams;

            if (filtered.isEmpty) {
              return AdminCard(
                padding: const EdgeInsets.all(AppSizes.defaultSpace * 1.5),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Iconsax.award_copy,
                        size: 48,
                        color: dark ? Colors.white30 : AppColors.darkGrey.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: AppSizes.md),
                      const Text(
                        'No Pilot Exams Found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      const Text(
                        'Create a simulation national pilot exam for students.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSizes.md),
                      ElevatedButton.icon(
                        onPressed: () => Get.toNamed(AdminRoutes.pilotExamEditor),
                        icon: const Icon(Iconsax.add_copy, size: 18),
                        label: const Text('Create Pilot Exam'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: filtered.map((exam) {
                return _PilotExamCard(exam: exam, controller: ctrl);
              }).toList(),
            );
          }),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      padding: const EdgeInsets.all(AppSizes.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm + 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
            ),
            child: Icon(icon, color: color, size: AppSizes.iconMd),
          ),
          const SizedBox(width: AppSizes.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeChip extends StatelessWidget {
  const _GradeChip({
    required this.label,
    required this.grade,
    required this.controller,
  });

  final String label;
  final int? grade;
  final PilotExamsController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = controller.selectedGrade.value == grade;
      return ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        onSelected: (_) => controller.setGradeFilter(grade),
      );
    });
  }
}

class _PilotExamCard extends StatelessWidget {
  const _PilotExamCard({required this.exam, required this.controller});

  final AdminPilotExamModel exam;
  final PilotExamsController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);


    return Padding(
      padding: const EdgeInsets.only(bottom: AppSizes.spaceBtwItems),
      child: AdminCard(
        padding: const EdgeInsets.all(AppSizes.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Title, Edition, Status & Actions
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with Grade badge
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 48,
                      width: 48,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                      ),
                      child: const Icon(
                        Iconsax.award_copy,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    Positioned(
                      right: -4,
                      bottom: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'G${exam.grade}',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSizes.md),

                // Title, Edition, and Badges
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exam.title,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSizes.sm),

                          // Edition badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.info.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.info.withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              exam.edition,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.info,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.xs),

                          // Active status badge
                          InkWell(
                            onTap: () => controller.toggleActive(exam),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: exam.isActive
                                    ? AppColors.success.withValues(alpha: 0.14)
                                    : AppColors.error.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: exam.isActive ? AppColors.success : AppColors.error,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                exam.isActive ? 'ACTIVE' : 'INACTIVE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: exam.isActive ? AppColors.success : AppColors.error,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSizes.xs),

                          // Premium badge
                          InkWell(
                            onTap: () => controller.togglePremium(exam),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: exam.isPremium
                                    ? AppColors.warning.withValues(alpha: 0.14)
                                    : AppColors.success.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: exam.isPremium ? AppColors.warning : AppColors.success,
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                exam.isPremium ? 'PRO' : 'FREE',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: exam.isPremium ? AppColors.warning : AppColors.success,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),

                      if (exam.description.isNotEmpty) ...[
                        Text(
                          exam.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],

                      // Metrics
                      Wrap(
                        spacing: 14,
                        runSpacing: 4,
                        children: [
                          _Metric(
                            icon: Iconsax.book_1_copy,
                            text: '${exam.subjectCount} Subjects',
                          ),
                          _Metric(
                            icon: Iconsax.task_copy,
                            text: '${exam.totalQuestions} Total Questions',
                          ),
                          _Metric(
                            icon: Iconsax.clock_copy,
                            text: '${exam.totalMinutes} Mins Duration',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: AppSizes.md),

                // Edit & Delete actions
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Edit exam',
                      icon: const Icon(Iconsax.edit_2_copy, size: 18),
                      onPressed: () => Get.toNamed(
                        AdminRoutes.pilotExamEditor,
                        arguments: {'exam': exam},
                      ),
                    ),
                    Obx(() {
                      final isDel = controller.isDeleting[exam.id] == true;
                      if (isDel) {
                        return const SizedBox(
                          width: 28,
                          height: 28,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }

                      return IconButton(
                        tooltip: 'Delete exam',
                        icon: const Icon(
                          Iconsax.trash_copy,
                          size: 18,
                          color: AppColors.error,
                        ),
                        onPressed: () async {
                          final confirmed = await AppDialogBoxes.confirm(
                            title: 'Delete Pilot Exam',
                            message: 'Are you sure you want to delete "${exam.title}"?\n'
                                'This will remove the exam and all its linked subjects.',
                            confirmLabel: 'Delete',
                            isDestructive: true,
                          );
                          if (confirmed) {
                            controller.deletePilotExam(exam);
                          }
                        },
                      );
                    }),
                  ],
                ),
              ],
            ),

            if (exam.subjects.isNotEmpty) ...[
              const Divider(height: 20),
              // Subject pills breakdown
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: exam.subjects.map((s) {
                  Color streamBg = AppColors.info.withValues(alpha: 0.1);
                  Color streamText = AppColors.info;
                  if (s.isNatural) {
                    streamBg = AppColors.success.withValues(alpha: 0.1);
                    streamText = AppColors.success;
                  } else if (s.isSocial) {
                    streamBg = AppColors.warning.withValues(alpha: 0.1);
                    streamText = AppColors.warning;
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.subjectName,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0.5),
                          decoration: BoxDecoration(
                            color: streamBg,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            s.streamLabel,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: streamText,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
