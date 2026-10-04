import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/features/notes/controllers/notes_controller.dart';
import 'package:m_admin/features/notes/models/admin_note_model.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(NotesController());
    final dark = AppHelperFunctions.isDark(context);

    return AdminScaffold(
      onRefresh: ctrl.loadNotes,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Stat Summary Cards ─────────────────────────────────────────
          Obx(() {
            final all = ctrl.notes;
            final premiumCount = all.where((n) => n.isPremium).length;
            final freeCount = all.length - premiumCount;
            final subjectCount = all.map((n) => n.subjectId).toSet().length;

            return LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 650;
                final cards = [
                  _StatTile(
                    label: 'Total Notes',
                    value: '${all.length}',
                    icon: Iconsax.document_copy,
                    color: AppColors.primary,
                  ),
                  _StatTile(
                    label: 'Premium',
                    value: '$premiumCount',
                    icon: Iconsax.crown_copy,
                    color: AppColors.warning,
                  ),
                  _StatTile(
                    label: 'Free',
                    value: '$freeCount',
                    icon: Iconsax.unlock_copy,
                    color: AppColors.success,
                  ),
                  _StatTile(
                    label: 'Subjects',
                    value: '$subjectCount',
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

          // ── Filter & Search Toolbar ────────────────────────────────────
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
                          decoration: InputDecoration(
                            hintText: 'Search notes by title or subject...',
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
                                onPressed: () => ctrl.searchQuery.value = '',
                              );
                            }),
                          ),
                          style: const TextStyle(fontSize: 12.5),
                          onChanged: (val) => ctrl.searchQuery.value = val,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Get.toNamed(AdminRoutes.noteEditor),
                      icon: const Icon(Iconsax.add_copy, size: 15),
                      label: const Text('New Note', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.sm + 4),

                // Filters Row: Grade Chips & Subject Dropdown
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
                    _GradeChip(
                      label: 'All',
                      grade: null,
                      controller: ctrl,
                    ),
                    _GradeChip(
                      label: 'Grade 9',
                      grade: 9,
                      controller: ctrl,
                    ),
                    _GradeChip(
                      label: 'Grade 10',
                      grade: 10,
                      controller: ctrl,
                    ),
                    _GradeChip(
                      label: 'Grade 11',
                      grade: 11,
                      controller: ctrl,
                    ),
                    _GradeChip(
                      label: 'Grade 12',
                      grade: 12,
                      controller: ctrl,
                    ),
                    const SizedBox(width: 4),

                    // Subject dropdown
                    Obx(() {
                      final subjects = ctrl.subjects;
                      return Container(
                        height: 30,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                          border: Border.all(
                            color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int?>(
                            value: ctrl.selectedSubjectId.value,
                            isDense: true,
                            hint: const Text('All Subjects', style: TextStyle(fontSize: 11)),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('All Subjects', style: TextStyle(fontSize: 11)),
                              ),
                              ...subjects.map((s) => DropdownMenuItem<int?>(
                                    value: s['id'] as int?,
                                    child: Text(
                                      s['name']?.toString() ?? '',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  )),
                            ],
                            onChanged: ctrl.setSubjectFilter,
                          ),
                        ),
                      );
                    }),

                    Obx(() {
                      final hasFilter = ctrl.selectedGrade.value != null ||
                          ctrl.selectedSubjectId.value != null ||
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

          // ── Notes List Grouped by Subject ──────────────────────────────
          Obx(() {
            if (ctrl.isLoading.value && ctrl.notes.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.defaultSpace),
                  child: AppCircularLoading(),
                ),
              );
            }

            final grouped = ctrl.notesGroupedBySubject;

            if (grouped.isEmpty) {
              return AdminCard(
                padding: const EdgeInsets.all(AppSizes.defaultSpace * 1.5),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Iconsax.document_text_copy,
                        size: 48,
                        color: dark ? Colors.white30 : AppColors.darkGrey.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: AppSizes.md),
                      const Text(
                        'No Notes Found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: AppSizes.xs),
                      const Text(
                        'Try clearing your filters or create a new note for students.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSizes.md),
                      ElevatedButton.icon(
                        onPressed: () => Get.toNamed(AdminRoutes.noteEditor),
                        icon: const Icon(Iconsax.add_copy, size: 18),
                        label: const Text('Add Note'),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: grouped.entries.map((entry) {
                final subjectName = entry.key;
                final subjectNotes = entry.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.spaceBtwSections),
                  child: AdminSection(
                    title: '$subjectName (${subjectNotes.length})',
                    child: Column(
                      children: subjectNotes.map((note) {
                        return _NoteTile(
                          note: note,
                          controller: ctrl,
                        );
                      }).toList(),
                    ),
                  ),
                );
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
  final NotesController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final isSelected = controller.selectedGrade.value == grade;
      return ChoiceChip(
        showCheckmark: false,
        label: Text(label, style: const TextStyle(fontSize: 11)),
        selected: isSelected,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
        onSelected: (_) => controller.setGradeFilter(grade),
      );
    });
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({
    required this.note,
    required this.controller,
  });

  final AdminNoteModel note;
  final NotesController controller;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkSurface : AppColors.lightGrey,
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
        border: Border.all(
          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Document icon with grade badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 36,
                width: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                ),
                child: const Icon(
                  Iconsax.document_copy,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 0.5),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: Text(
                    'G${note.grade}',
                    style: const TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: AppSizes.sm + 2),

          // Title, Chapter, Metadata
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        note.title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSizes.sm),
                    // Premium / Free badge
                    InkWell(
                      onTap: () => controller.togglePremium(note),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: note.isPremium
                              ? AppColors.warning.withValues(alpha: 0.14)
                              : AppColors.success.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: note.isPremium
                                ? AppColors.warning
                                : AppColors.success,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              note.isPremium
                                  ? Iconsax.crown_copy
                                  : Iconsax.unlock_copy,
                              size: 11,
                              color: note.isPremium
                                  ? AppColors.warning
                                  : AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              note.isPremium ? 'PREMIUM' : 'FREE',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: note.isPremium
                                    ? AppColors.warning
                                    : AppColors.success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _MetaItem(
                      icon: Iconsax.folder_2_copy,
                      label: 'Chapter ${note.chapterNumber}',
                    ),
                    _MetaItem(
                      icon: Iconsax.document_upload_copy,
                      label: note.formattedSize,
                    ),
                    if (note.pageCount > 0)
                      _MetaItem(
                        icon: Iconsax.book_1_copy,
                        label: note.formattedPages,
                      ),
                    if (note.orderIndex > 0)
                      _MetaItem(
                        icon: Iconsax.sort_copy,
                        label: 'Order: ${note.orderIndex}',
                      ),
                  ],
                ),
                if (note.description != null && note.description!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    note.description!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSizes.md),

          // Actions: Edit and Delete
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Edit note',
                icon: const Icon(Iconsax.edit_2_copy, size: 18),
                onPressed: () => Get.toNamed(
                  AdminRoutes.noteEditor,
                  arguments: {'note': note},
                ),
              ),
              Obx(() {
                final isDeleting = controller.isDeleting[note.id] == true;
                if (isDeleting) {
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
                  tooltip: 'Delete note',
                  icon: const Icon(
                    Iconsax.trash_copy,
                    size: 18,
                    color: AppColors.error,
                  ),
                  onPressed: () async {
                    final confirmed = await AppDialogBoxes.confirm(
                      title: 'Delete Note',
                      message: 'Are you sure you want to delete "${note.title}"?\n'
                          'This will also remove the PDF file from storage.',
                      confirmLabel: 'Delete',
                      isDestructive: true,
                    );
                    if (confirmed) {
                      controller.deleteNote(note);
                    }
                  },
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: AppColors.textSecondary),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
