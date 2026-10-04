import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/data/repositories/pilot_exams_repository.dart';
import 'package:m_admin/features/pilot_exams/controllers/pilot_exams_controller.dart';
import 'package:m_admin/features/pilot_exams/models/admin_pilot_exam_model.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class PilotExamEditorScreen extends StatefulWidget {
  const PilotExamEditorScreen({super.key, this.exam});

  final AdminPilotExamModel? exam;

  @override
  State<PilotExamEditorScreen> createState() => _PilotExamEditorScreenState();
}

class _PilotExamEditorScreenState extends State<PilotExamEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PilotExamsRepository();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _editionCtrl;
  late final TextEditingController _descCtrl;

  int _selectedGrade = 12;
  bool _isPremium = true;
  bool _isActive = true;

  final List<AdminPilotExamSubjectModel> _subjectsList = [];
  List<Map<String, dynamic>> _availableSubjects = [];
  bool _isSaving = false;

  bool get isEditing => widget.exam != null;

  @override
  void initState() {
    super.initState();
    final e = widget.exam;

    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _editionCtrl = TextEditingController(text: e?.edition ?? '2019 E.C.');
    _descCtrl = TextEditingController(text: e?.description ?? '');

    _selectedGrade = e?.grade ?? 12;
    _isPremium = e?.isPremium ?? true;
    _isActive = e?.isActive ?? true;

    if (e != null) {
      _subjectsList.addAll(e.subjects);
    }

    _loadAvailableSubjects();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _editionCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAvailableSubjects() async {
    try {
      final list = await _repo.fetchSubjects();
      if (!mounted) return;
      setState(() => _availableSubjects = list);
    } catch (_) {}
  }

  void _openSubjectDialog({AdminPilotExamSubjectModel? existing, int? index}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PilotSubjectDialog(
        existing: existing,
        availableSubjects: _availableSubjects,
        repo: _repo,
        onSaved: (subjectModel) {
          setState(() {
            if (index != null && index >= 0 && index < _subjectsList.length) {
              _subjectsList[index] = subjectModel;
            } else {
              _subjectsList.add(subjectModel);
            }
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final examPayload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'edition': _editionCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'grade': _selectedGrade,
        'is_premium': _isPremium,
        'is_active': _isActive,
      };

      if (isEditing && widget.exam!.id > 0) {
        examPayload['id'] = widget.exam!.id;
      }

      final savedExam = await _repo.upsertPilotExam(examPayload);
      final examId = savedExam.id;

      // Upsert linked subjects
      for (var i = 0; i < _subjectsList.length; i++) {
        final s = _subjectsList[i];
        final subjectPayload = <String, dynamic>{
          'pilot_exam_id': examId,
          'subject_id': s.subjectId,
          'subject_name': s.subjectName,
          'stream': s.stream.toLowerCase(),
          'test_id': s.testId,
          'order_index': i + 1,
          'question_count': s.questionCount,
          'time_minutes': s.timeMinutes,
        };
        if (s.id > 0) {
          subjectPayload['id'] = s.id;
        }
        await _repo.upsertPilotExamSubject(subjectPayload);
      }

      if (Get.isRegistered<PilotExamsController>()) {
        PilotExamsController.instance.loadPilotExams();
      }

      SnackbarHelper.success(
        'Saved',
        isEditing
            ? 'Pilot Exam updated successfully.'
            : 'Pilot Exam created successfully.',
      );
      Get.back(result: true);
    } catch (e) {
      SnackbarHelper.error('Save failed', e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Pilot Exam' : 'Create Pilot Exam'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: AdminScaffold(
        maxContentWidth: 900,
        body: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Basic Info Section ─────────────────────────────────────
              AdminSection(
                title: 'General Details',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: _titleCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Exam Title *',
                              hintText: 'e.g. 1st Semester Pilot Model Exam',
                              prefixIcon: Icon(Iconsax.award_copy, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Title is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: AppSizes.spaceBtwInputFields),
                        Expanded(
                          child: TextFormField(
                            controller: _editionCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Edition / Year *',
                              hintText: 'e.g. 2019 E.C.',
                              prefixIcon: Icon(Iconsax.calendar_1_copy, size: 20),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Edition is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // Grade dropdown
                    DropdownButtonFormField<int>(
                      initialValue: _selectedGrade,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level *',
                        prefixIcon: Icon(Iconsax.teacher_copy, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem(value: 9, child: Text('Grade 9')),
                        DropdownMenuItem(value: 10, child: Text('Grade 10')),
                        DropdownMenuItem(value: 11, child: Text('Grade 11')),
                        DropdownMenuItem(value: 12, child: Text('Grade 12 (Matric)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedGrade = val);
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Simulates the national examination standard...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // Toggles: Active and Premium
                    Row(
                      children: [
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _isActive,
                            onChanged: (v) => setState(() => _isActive = v),
                            title: const Text('Active Status', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Visible to students', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                        Expanded(
                          child: SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: _isPremium,
                            onChanged: (v) => setState(() => _isPremium = v),
                            title: const Text('Premium Access', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                            subtitle: const Text('Subscription required', style: TextStyle(fontSize: 11)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.spaceBtwSections),

              // ── Linked Subjects Section ────────────────────────────────
              AdminSection(
                title: 'Exam Subjects Breakdown (${_subjectsList.length})',
                trailing: TextButton.icon(
                  onPressed: () => _openSubjectDialog(),
                  icon: const Icon(Iconsax.add_circle_copy, size: 18),
                  label: const Text('Add Subject'),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_subjectsList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSizes.lg),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                          border: Border.all(
                            color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Iconsax.book_1_copy,
                                size: 36,
                                color: dark ? Colors.white30 : AppColors.darkGrey.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: AppSizes.sm),
                              const Text(
                                'No subjects configured yet',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Add common, natural, and social stream subjects that make up this pilot exam.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSizes.md),
                              OutlinedButton.icon(
                                onPressed: () => _openSubjectDialog(),
                                icon: const Icon(Iconsax.add_copy, size: 16),
                                label: const Text('Configure Subject'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _subjectsList.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final item = _subjectsList.removeAt(oldIndex);
                            _subjectsList.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, idx) {
                          final s = _subjectsList[idx];
                          Color streamColor = AppColors.info;
                          if (s.isNatural) streamColor = AppColors.success;
                          if (s.isSocial) streamColor = AppColors.warning;

                          return Container(
                            key: ValueKey('subject_${s.subjectId}_$idx'),
                            margin: const EdgeInsets.only(bottom: AppSizes.sm),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.md,
                              vertical: AppSizes.sm,
                            ),
                            decoration: BoxDecoration(
                              color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                              border: Border.all(
                                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                              ),
                            ),
                            child: Row(
                              children: [
                                ReorderableDragStartListener(
                                  index: idx,
                                  child: const Icon(
                                    Icons.drag_indicator,
                                    size: 20,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                                const SizedBox(width: AppSizes.sm),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            s.subjectName,
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                          const SizedBox(width: AppSizes.sm),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: streamColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              s.streamLabel,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w700,
                                                color: streamColor,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${s.questionCount} Questions • ${s.timeMinutes} Mins'
                                        '${s.testId != null && s.testId! > 0 ? ' • Test #${s.testId}' : ''}',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Iconsax.edit_2_copy, size: 16),
                                  onPressed: () => _openSubjectDialog(existing: s, index: idx),
                                ),
                                IconButton(
                                  icon: const Icon(Iconsax.trash_copy, size: 16, color: AppColors.error),
                                  onPressed: () {
                                    setState(() => _subjectsList.removeAt(idx));
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.spaceBtwSections * 1.5),

              // ── Save Actions ───────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSizes.spaceBtwItems),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isSaving ? 'Saving...' : (isEditing ? 'Update Exam' : 'Create Exam')),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceBtwSections),
            ],
          ),
        ),
      ),
    );
  }
}

class _PilotSubjectDialog extends StatefulWidget {
  const _PilotSubjectDialog({
    this.existing,
    required this.availableSubjects,
    required this.repo,
    required this.onSaved,
  });

  final AdminPilotExamSubjectModel? existing;
  final List<Map<String, dynamic>> availableSubjects;
  final PilotExamsRepository repo;
  final void Function(AdminPilotExamSubjectModel model) onSaved;

  @override
  State<_PilotSubjectDialog> createState() => _PilotSubjectDialogState();
}

class _PilotSubjectDialogState extends State<_PilotSubjectDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _subjectId;
  String _stream = 'natural';
  late final TextEditingController _qCountCtrl;
  late final TextEditingController _timeCtrl;
  int? _testId;

  List<Map<String, dynamic>> _subjectTests = [];
  bool _loadingTests = false;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _subjectId = ex?.subjectId ?? (widget.availableSubjects.isNotEmpty ? widget.availableSubjects.first['id'] as int? : null);
    _stream = ex?.stream.toLowerCase() ?? 'natural';
    _qCountCtrl = TextEditingController(text: (ex?.questionCount ?? 60).toString());
    _timeCtrl = TextEditingController(text: (ex?.timeMinutes ?? 90).toString());
    _testId = ex?.testId;

    if (_subjectId != null) {
      _loadTestsForSubject(_subjectId!);
    }
  }

  @override
  void dispose() {
    _qCountCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTestsForSubject(int subjectId) async {
    setState(() => _loadingTests = true);
    try {
      final tests = await widget.repo.fetchTestsForSubject(subjectId);
      if (!mounted) return;
      setState(() {
        _subjectTests = tests;
        if (_testId != null && !tests.any((t) => t['id'] == _testId)) {
          _testId = null;
        }
        _loadingTests = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingTests = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Exam Subject' : 'Add Exam Subject'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _subjectId,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    prefixIcon: Icon(Iconsax.book_copy, size: 20),
                  ),
                  items: widget.availableSubjects.map((s) {
                    return DropdownMenuItem<int>(
                      value: s['id'] as int?,
                      child: Text(s['name']?.toString() ?? 'Subject'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _subjectId = val);
                      _loadTestsForSubject(val);
                    }
                  },
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: AppSizes.spaceBtwInputFields),

                DropdownButtonFormField<String>(
                  initialValue: _stream,
                  decoration: const InputDecoration(
                    labelText: 'Stream *',
                    prefixIcon: Icon(Iconsax.category_copy, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'natural', child: Text('Natural Stream')),
                    DropdownMenuItem(value: 'social', child: Text('Social Stream')),
                    DropdownMenuItem(value: 'common', child: Text('Common (Both Streams)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _stream = val);
                  },
                ),
                const SizedBox(height: AppSizes.spaceBtwInputFields),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qCountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Questions Count',
                          prefixIcon: Icon(Iconsax.hashtag_copy, size: 18),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceBtwInputFields),
                    Expanded(
                      child: TextFormField(
                        controller: _timeCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Time (Minutes)',
                          prefixIcon: Icon(Iconsax.clock_copy, size: 18),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceBtwInputFields),

                DropdownButtonFormField<int?>(
                  initialValue: _testId,
                  decoration: InputDecoration(
                    labelText: 'Linked Test (Optional)',
                    prefixIcon: const Icon(Iconsax.task_copy, size: 18),
                    suffixIcon: _loadingTests
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : null,
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('None / Manual Questions'),
                    ),
                    ..._subjectTests.map((t) {
                      return DropdownMenuItem<int?>(
                        value: t['id'] as int?,
                        child: Text('${t['title']} (${t['question_count']} Qs)'),
                      );
                    }),
                  ],
                  onChanged: (val) => setState(() => _testId = val),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            final subName = widget.availableSubjects.firstWhereOrNull(
                  (s) => s['id'] == _subjectId,
                )?['name']?.toString() ??
                'Subject';

            final model = AdminPilotExamSubjectModel(
              id: widget.existing?.id ?? 0,
              pilotExamId: widget.existing?.pilotExamId ?? 0,
              subjectId: _subjectId!,
              subjectName: subName,
              stream: _stream,
              testId: _testId,
              orderIndex: widget.existing?.orderIndex ?? 1,
              questionCount: int.tryParse(_qCountCtrl.text.trim()) ?? 60,
              timeMinutes: int.tryParse(_timeCtrl.text.trim()) ?? 90,
            );

            widget.onSaved(model);
            Navigator.of(context).pop();
          },
          child: const Text('Save Subject'),
        ),
      ],
    );
  }
}
