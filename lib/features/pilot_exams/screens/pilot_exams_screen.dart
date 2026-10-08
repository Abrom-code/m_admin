import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
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
      pageIndex: 6,
      onRefresh: ctrl.loadPilotExams,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Stats Summary Ribbon ───────────────────────────────────────
          Obx(() {
            final all = ctrl.exams;
            final activeCount = all.where((e) => e.isActive).length;
            final premiumCount = all.where((e) => e.isPremium).length;
            final totalSubjects = all.fold<int>(0, (sum, e) => sum + e.subjectCount);
            final sFilter = ctrl.statusFilter.value;

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _CompactRibbonCard(
                    label: 'Pilot Exams',
                    value: NumberFormat('#,##0').format(all.length),
                    dotColor: AppColors.primary,
                    icon: Iconsax.award_copy,
                    isSelected: sFilter == null,
                    onTap: () => ctrl.setStatusFilter(null),
                  ),
                  const SizedBox(width: 8),
                  _CompactRibbonCard(
                    label: 'Active',
                    value: NumberFormat('#,##0').format(activeCount),
                    dotColor: AppColors.success,
                    icon: Iconsax.tick_circle_copy,
                    isSelected: sFilter == 'active',
                    onTap: () => ctrl.setStatusFilter(sFilter == 'active' ? null : 'active'),
                  ),
                  const SizedBox(width: 8),
                  _CompactRibbonCard(
                    label: 'Premium',
                    value: NumberFormat('#,##0').format(premiumCount),
                    dotColor: AppColors.warning,
                    icon: Iconsax.crown_copy,
                    isSelected: sFilter == 'premium',
                    onTap: () => ctrl.setStatusFilter(sFilter == 'premium' ? null : 'premium'),
                  ),
                  const SizedBox(width: 8),
                  _CompactRibbonCard(
                    label: 'Configured Subjects',
                    value: NumberFormat('#,##0').format(totalSubjects),
                    dotColor: AppColors.info,
                    icon: Iconsax.book_copy,
                    isSelected: false,
                    onTap: null,
                  ),
                ],
              ),
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
                      child: SizedBox(
                        height: 36,
                        child: TextField(
                          controller: ctrl.searchController,
                          decoration: InputDecoration(
                            hintText: 'Search pilot exams by title or edition...',
                            hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Iconsax.search_normal_1_copy, size: 16),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.sm,
                              vertical: 8,
                            ),
                            suffixIcon: Obx(() {
                              if (ctrl.searchQuery.value.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return IconButton(
                                icon: const Icon(Icons.clear, size: 16),
                                onPressed: () {
                                  ctrl.searchController.clear();
                                  ctrl.searchQuery.value = '';
                                  FocusManager.instance.primaryFocus?.unfocus();
                                },
                              );
                            }),
                          ),
                          style: const TextStyle(fontSize: 12.5),
                          onChanged: (val) => ctrl.searchQuery.value = val,
                          onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                          onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Get.toNamed(AdminRoutes.pilotExamEditor),
                      icon: const Icon(Iconsax.add_copy, size: 15),
                      label: const Text('New Pilot Exam', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm + 4),

                // Grade filters
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Grade:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    _GradeChip(label: 'All', grade: null, controller: ctrl),
                    _GradeChip(label: 'G9', grade: 9, controller: ctrl, tooltip: 'Grade 9'),
                    _GradeChip(label: 'G10', grade: 10, controller: ctrl, tooltip: 'Grade 10'),
                    _GradeChip(label: 'G11', grade: 11, controller: ctrl, tooltip: 'Grade 11'),
                    _GradeChip(label: 'G12', grade: 12, controller: ctrl, tooltip: 'Grade 12'),
                    _GradeChip(label: 'National', grade: 0, controller: ctrl, tooltip: 'National (Optional)'),
                    Obx(() {
                      final hasFilter = ctrl.selectedGrade.value != null ||
                          ctrl.statusFilter.value != null ||
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

class _CompactRibbonCard extends StatelessWidget {
  const _CompactRibbonCard({
    required this.label,
    required this.value,
    required this.dotColor,
    required this.isSelected,
    this.icon,
    this.onTap,
  });

  final String label;
  final String value;
  final Color dotColor;
  final bool isSelected;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected
            ? dotColor.withValues(alpha: dark ? 0.18 : 0.08)
            : (dark ? AppColors.darkCard : AppColors.white),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        border: Border.all(
          color: isSelected
              ? dotColor
              : (dark
                  ? AppColors.darkGrey.withValues(alpha: 0.25)
                  : AppColors.borderPrimary.withValues(alpha: 0.7)),
          width: isSelected ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: dotColor),
            const SizedBox(width: 8),
          ] else ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? (dark ? AppColors.white : AppColors.textPrimary)
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: dotColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: dotColor,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: card,
    );
  }
}

class _GradeChip extends StatelessWidget {
  const _GradeChip({
    required this.label,
    required this.grade,
    required this.controller,
    this.tooltip,
  });

  final String label;
  final int? grade;
  final PilotExamsController controller;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = controller.selectedGrade.value == grade;
      return ChoiceChip(
        showCheckmark: false,
        label: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : AppColors.textSecondary,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primary,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        tooltip: tooltip,
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

                          // Verification / Active status badge
                          Tooltip(
                            message: exam.isActive
                                ? 'Published & live for students (click to unpublish)'
                                : 'Draft / Unverified (click to verify & publish)',
                            child: InkWell(
                              onTap: () => controller.toggleActive(exam),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: exam.isActive
                                      ? AppColors.success.withValues(alpha: 0.14)
                                      : AppColors.warning.withValues(alpha: 0.16),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: exam.isActive ? AppColors.success : AppColors.warning,
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      exam.isActive ? Icons.cloud_done_rounded : Icons.lock_clock_rounded,
                                      size: 11,
                                      color: exam.isActive ? AppColors.success : AppColors.warning,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      exam.isActive ? 'PUBLISHED' : 'UNVERIFIED',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: exam.isActive ? AppColors.success : AppColors.warning,
                                      ),
                                    ),
                                  ],
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
