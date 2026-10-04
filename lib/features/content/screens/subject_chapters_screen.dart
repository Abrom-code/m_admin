import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/data/repositories/content_repository.dart';
import 'package:m_admin/features/content/screens/content_screen.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class SubjectChaptersScreen extends StatefulWidget {
  const SubjectChaptersScreen({super.key, required this.subject});

  final SubjectRow subject;

  @override
  State<SubjectChaptersScreen> createState() => _SubjectChaptersScreenState();
}

class _SubjectChaptersScreenState extends State<SubjectChaptersScreen> {
  final _repo = ContentRepository();
  final List<Map<String, dynamic>> _chapters = [];
  bool _isLoading = true;
  int? _filterGrade;

  @override
  void initState() {
    super.initState();
    _loadChapters();
  }

  Future<void> _loadChapters() async {
    setState(() => _isLoading = true);
    try {
      final rows = await _repo.fetchChaptersForSubject(
        widget.subject.id,
        grade: _filterGrade,
      );
      if (!mounted) return;
      setState(() {
        _chapters.clear();
        _chapters.addAll(rows);
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        SnackbarHelper.error('Error', e.toString());
      }
    }
  }

  void _openChapterDialog({Map<String, dynamic>? existing}) {
    final formKey = GlobalKey<FormState>();
    final numCtrl = TextEditingController(
      text: existing != null ? '${existing['chapter_number']}' : '${_chapters.length + 1}',
    );
    final titleCtrl = TextEditingController(text: existing?['title']?.toString() ?? '');
    int grade = (existing?['grade'] as num?)?.toInt() ?? 12;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          title: Text(existing != null ? 'Edit Chapter' : 'Add Chapter'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 320;
                        final numField = TextFormField(
                          controller: numCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Chapter # *',
                            prefixIcon: Icon(Iconsax.hashtag_copy, size: 18),
                          ),
                          validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                        );

                        final gradeDropdown = DropdownButtonFormField<int>(
                          initialValue: grade,
                          decoration: const InputDecoration(
                            labelText: 'Grade *',
                            prefixIcon: Icon(Iconsax.teacher_copy, size: 18),
                          ),
                          items: const [
                            DropdownMenuItem(value: 9, child: Text('Grade 9')),
                            DropdownMenuItem(value: 10, child: Text('Grade 10')),
                            DropdownMenuItem(value: 11, child: Text('Grade 11')),
                            DropdownMenuItem(value: 12, child: Text('Grade 12')),
                          ],
                          onChanged: (val) {
                            if (val != null) setDlgState(() => grade = val);
                          },
                        );

                        if (isNarrow) {
                          return Column(
                            children: [
                              numField,
                              const SizedBox(height: AppSizes.spaceBtwInputFields),
                              gradeDropdown,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: numField),
                            const SizedBox(width: AppSizes.spaceBtwInputFields),
                            Expanded(child: gradeDropdown),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),
                    TextFormField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Chapter Title *',
                        hintText: 'e.g. Introduction to Calculus',
                        prefixIcon: Icon(Iconsax.book_copy, size: 18),
                      ),
                      validator: (v) => v == null || v.trim().isEmpty ? 'Title is required' : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final payload = <String, dynamic>{
                  'subject_id': widget.subject.id,
                  'chapter_number': int.tryParse(numCtrl.text.trim()) ?? 1,
                  'grade': grade,
                  'title': titleCtrl.text.trim(),
                };
                if (existing != null && existing['id'] != null) {
                  payload['id'] = existing['id'];
                }

                Navigator.of(ctx).pop();
                try {
                  await _repo.upsertChapter(payload);
                  SnackbarHelper.success('Saved', 'Chapter saved successfully.');
                  _loadChapters();
                } catch (e) {
                  SnackbarHelper.error('Error', e.toString());
                }
              },
              child: const Text('Save Chapter'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteChapter(Map<String, dynamic> chapter) async {
    final id = (chapter['id'] as num?)?.toInt() ?? 0;
    final confirmed = await AppDialogBoxes.confirm(
      title: 'Delete Chapter',
      message: 'Are you sure you want to delete "${chapter['title']}"?\n'
          'Notes or questions linked to this chapter may lose chapter association.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirmed) return;

    try {
      await _repo.deleteChapter(id);
      SnackbarHelper.success('Deleted', 'Chapter removed.');
      _loadChapters();
    } catch (e) {
      SnackbarHelper.error('Delete failed', e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.subject.name} Chapters'),
        actions: [
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () => _openChapterDialog(),
            icon: const Icon(Iconsax.add_circle_copy, size: 18),
            label: const Text('Add Chapter'),
          ),
          const SizedBox(width: AppSizes.md),
        ],
      ),
      body: AdminScaffold(
        onRefresh: _loadChapters,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Filter Bar
            AdminCard(
              padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Filter by Grade:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                  ChoiceChip(
                    label: const Text('All', style: TextStyle(fontSize: 11)),
                    selected: _filterGrade == null,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) {
                      setState(() => _filterGrade = null);
                      _loadChapters();
                    },
                  ),
                  ...[9, 10, 11, 12].map((g) => ChoiceChip(
                        label: Text('Grade $g', style: const TextStyle(fontSize: 11)),
                        selected: _filterGrade == g,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          setState(() => _filterGrade = g);
                          _loadChapters();
                        },
                      )),
                ],
              ),
            ),

            const SizedBox(height: AppSizes.spaceBtwItems),

            // Chapters List
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(AppSizes.defaultSpace),
                  child: AppCircularLoading(),
                ),
              )
            else if (_chapters.isEmpty)
              AdminCard(
                padding: const EdgeInsets.all(AppSizes.defaultSpace * 1.5),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Iconsax.folder_2_copy,
                        size: 48,
                        color: dark ? Colors.white30 : AppColors.darkGrey.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: AppSizes.md),
                      const Text(
                        'No Chapters Found',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Add curriculum chapters to structure notes and chapter tests.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: AppSizes.md),
                      ElevatedButton.icon(
                        onPressed: () => _openChapterDialog(),
                        icon: const Icon(Iconsax.add_copy, size: 16),
                        label: const Text('Add First Chapter'),
                      ),
                    ],
                  ),
                ),
              )
            else
              AdminCard(
                padding: EdgeInsets.zero,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _chapters.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final ch = _chapters[index];
                    final num = ch['chapter_number'] ?? index + 1;
                    final title = ch['title']?.toString() ?? 'Chapter $num';
                    final grade = ch['grade'] ?? 12;

                    return ListTile(
                      leading: Container(
                        height: 36,
                        width: 36,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$num',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      subtitle: Text(
                        'Grade $grade • Chapter ID: ${ch['id']}',
                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Iconsax.edit_2_copy, size: 16),
                            onPressed: () => _openChapterDialog(existing: ch),
                          ),
                          IconButton(
                            icon: const Icon(Iconsax.trash_copy, size: 16, color: AppColors.error),
                            onPressed: () => _deleteChapter(ch),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
