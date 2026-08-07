import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/data/repositories/content_repository.dart';
import 'package:m_admin/features/content/controllers/test_editor_controller.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';

class TestEditorScreen extends StatelessWidget {
  const TestEditorScreen({
    super.key,
    required this.subjectId,
    this.testId,
    this.subjectName = '',
  });

  final int subjectId;
  final int? testId;
  final String subjectName;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(
      TestEditorController(testId: testId, subjectId: subjectId),
      tag: 'test_editor_${testId ?? 'new'}',
    );

    return AdminScaffold(
      title: testId == null ? 'New test' : 'Edit test',
      subtitle: subjectName,
      actions: [
        Obx(
          () => FilledButton.icon(
            onPressed: controller.isSaving.value ? null : controller.saveTest,
            icon: controller.isSaving.value
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.save_rounded, size: AppSizes.iconSm),
            label: const Text('Save'),
          ),
        ),
      ],
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: _TestForm(controller: controller),
            ),
            if (testId != null) ...[
              const SizedBox(width: AppSizes.spaceBtwItems),
              Expanded(
                flex: 5,
                child: _QuestionList(controller: controller),
              ),
            ],
          ],
        );
      }),
    );
  }
}

class _TestForm extends StatelessWidget {
  const _TestForm({required this.controller});
  final TestEditorController controller;

  @override
  Widget build(BuildContext context) {
    return AdminSection(
      title: 'Test details',
      child: Form(
        key: controller.formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: controller.titleCtrl,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: AppSizes.spaceBtwInputFields),
            Obx(
              () => DropdownButtonFormField<String>(
                initialValue: controller.typeValue.value,
                decoration: const InputDecoration(labelText: 'Type'),
                items: TestEditorController.validTypes
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) controller.typeValue.value = v;
                },
              ),
            ),
            const SizedBox(height: AppSizes.spaceBtwInputFields),
            TextFormField(
              controller: controller.gradeCtrl,
              decoration: const InputDecoration(
                labelText: 'Grade',
                hintText: 'e.g. 9',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: AppSizes.spaceBtwInputFields),
            Obx(() {
              if (controller.typeValue.value != 'chapter') {
                return const SizedBox.shrink();
              }
              return DropdownButtonFormField<int?>(
                initialValue: controller.selectedChapterId.value,
                decoration: const InputDecoration(labelText: 'Chapter'),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('— None —'),
                  ),
                  ...controller.chapters.map(
                    (c) => DropdownMenuItem<int?>(
                      value: (c['id'] as num).toInt(),
                      child: Text(
                        'Gr${c['grade']} Ch${c['chapter_number']}: '
                        '${c['title'] ?? ''}',
                      ),
                    ),
                  ),
                ],
                onChanged: (v) => controller.selectedChapterId.value = v,
              );
            }),
            const SizedBox(height: AppSizes.spaceBtwInputFields),
            Obx(
              () => CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Untimed', style: TextStyle(fontSize: 13)),
                subtitle: const Text(
                  'Writes time = -1',
                  style: TextStyle(fontSize: 11),
                ),
                value: controller.isUntimed.value,
                onChanged: (v) => controller.isUntimed.value = v ?? false,
              ),
            ),
            Obx(() {
              if (controller.isUntimed.value) return const SizedBox.shrink();
              return TextFormField(
                controller: controller.timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Time (minutes)',
                  hintText: 'e.g. 30',
                ),
                keyboardType: TextInputType.number,
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _QuestionList extends StatelessWidget {
  const _QuestionList({required this.controller});
  final TestEditorController controller;

  @override
  Widget build(BuildContext context) {
    return AdminSection(
      title: 'Questions',
      trailing: Obx(
        () => Text(
          '${controller.questions.length} total',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
      ),
      child: Obx(() {
        if (controller.questions.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
            child: Column(
              children: [
                const Text(
                  'No questions yet.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: AppSizes.sm),
                OutlinedButton.icon(
                  onPressed: () => _openQuestionEditor(context, null),
                  icon: const Icon(Icons.add_rounded, size: AppSizes.iconSm),
                  label: const Text('Add question'),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openQuestionEditor(context, null),
                icon: const Icon(Icons.add_rounded, size: AppSizes.iconSm),
                label: const Text('Add question'),
              ),
            ),
            const SizedBox(height: AppSizes.sm),
            ListView.separated(
              shrinkWrap: true,
              primary: false,
              itemCount: controller.questions.length,
              separatorBuilder: (_, index) =>
                  const Divider(height: 1),
              itemBuilder: (context, i) {
                final q = controller.questions[i];
                final qId = (q['id'] as num?)?.toInt();
                final order = (q['question_order'] as num?)?.toInt() ?? i + 1;
                final text = q['question_text']?.toString() ?? '';
                final opts = q['options'];
                final optCount =
                    opts is List ? opts.length : 0;
                final correct =
                    (q['correct_option_index'] as num?)?.toInt();

                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    child: Text(
                      '$order',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  title: Text(
                    text.length > 80 ? '${text.substring(0, 80)}…' : text,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '$optCount options · answer: ${correct != null ? String.fromCharCode(65 + correct) : "?"}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Edit',
                        iconSize: AppSizes.iconSm,
                        onPressed: () => _openQuestionEditor(context, qId),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        tooltip: 'Delete',
                        iconSize: AppSizes.iconSm,
                        onPressed: qId == null
                            ? null
                            : () => _confirmDelete(context, qId),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        );
      }),
    );
  }

  void _openQuestionEditor(BuildContext context, int? questionId) {
    Get.to(
      () => QuestionEditorScreen(
        testId: controller.testId!,
        subjectId: controller.subjectId,
        questionId: questionId,
      ),
    )?.then((saved) {
      if (saved == true) controller.reload();
    });
  }

  Future<void> _confirmDelete(BuildContext context, int qId) async {
    final ok = await AppDialogBoxes.confirm(
      title: 'Delete question',
      message: 'Remove this question from the test? This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (ok) controller.deleteQuestion(qId);
  }
}

// Stub — replaced by the full QuestionEditorScreen below.
class QuestionEditorScreen extends StatelessWidget {
  const QuestionEditorScreen({
    super.key,
    required this.testId,
    required this.subjectId,
    this.questionId,
  });

  final int testId;
  final int subjectId;
  final int? questionId;

  @override
  Widget build(BuildContext context) {
    return _QuestionEditorView(
      testId: testId,
      subjectId: subjectId,
      questionId: questionId,
    );
  }
}

class _QuestionEditorView extends StatefulWidget {
  const _QuestionEditorView({
    required this.testId,
    required this.subjectId,
    this.questionId,
  });

  final int testId;
  final int subjectId;
  final int? questionId;

  @override
  State<_QuestionEditorView> createState() => _QuestionEditorViewState();
}

class _QuestionEditorViewState extends State<_QuestionEditorView> {
  final _repo = ContentRepository();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isDirty = false;

  final _questionCtrl = TextEditingController();
  final _explanationEnCtrl = TextEditingController();
  final _explanationAmCtrl = TextEditingController();
  final _options = <TextEditingController>[];
  int _correctIndex = 0;

  @override
  void initState() {
    super.initState();
    // Start with 4 empty option fields.
    _options.addAll(List.generate(4, (_) => TextEditingController()));
    if (widget.questionId != null) _loadQuestion();
  }

  @override
  void dispose() {
    _questionCtrl.dispose();
    _explanationEnCtrl.dispose();
    _explanationAmCtrl.dispose();
    for (final c in _options) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadQuestion() async {
    setState(() => _isLoading = true);
    try {
      final data = await _repo.fetchQuestionDetail(widget.questionId!);
      _questionCtrl.text = data['question_text']?.toString() ?? '';
      _explanationEnCtrl.text = data['explanation_en']?.toString() ?? '';
      _explanationAmCtrl.text = data['explanation_am']?.toString() ?? '';

      final opts = data['options'];
      if (opts is List) {
        for (final c in _options) {
          c.dispose();
        }
        _options.clear();
        for (final o in opts) {
          _options.add(TextEditingController(text: o?.toString() ?? ''));
        }
      }

      _correctIndex =
          (data['correct_option_index'] as num?)?.toInt() ?? 0;
    } catch (e) {
      // ignore load errors — blank form is still usable
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<bool> _save() async {
    if (!_formKey.currentState!.validate()) return false;
    if (_options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 2 options.')),
      );
      return false;
    }
    if (_correctIndex >= _options.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a valid correct answer.')),
      );
      return false;
    }

    setState(() => _isSaving = true);
    try {
      final data = <String, dynamic>{
        if (widget.questionId != null) 'id': widget.questionId,
        'test_id': widget.testId,
        'subject_id': widget.subjectId,
        'question_text': _questionCtrl.text.trim(),
        'options': _options.map((c) => c.text.trim()).toList(),
        'correct_option_index': _correctIndex,
        'explanation_en': _explanationEnCtrl.text.trim(),
        'explanation_am': _explanationAmCtrl.text.trim(),
      };

      await _repo.upsertQuestion(data);
      _isDirty = false;
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _addOption() {
    if (_options.length >= 6) return;
    setState(() => _options.add(TextEditingController()));
    _isDirty = true;
  }

  void _removeOption(int index) {
    if (_options.length <= 2) return;
    _options[index].dispose();
    setState(() {
      _options.removeAt(index);
      if (_correctIndex >= _options.length) {
        _correctIndex = _options.length - 1;
      }
    });
    _isDirty = true;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isDirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop || !_isDirty) return;
        final leave = await AppDialogBoxes.confirm(
          title: 'Unsaved changes',
          message: 'Leave without saving?',
          confirmLabel: 'Leave',
          isDestructive: true,
        );
        if (leave && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.questionId == null ? 'New question' : 'Edit question',
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: AppSizes.md),
              child: FilledButton.icon(
                onPressed: _isSaving
                    ? null
                    : () async {
                        final ok = await _save();
                        if (ok && context.mounted) {
                          Navigator.of(context).pop(true);
                        }
                      },
                icon: _isSaving
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded, size: AppSizes.iconSm),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppSizes.md),
                child: Form(
                  key: _formKey,
                  onChanged: () => _isDirty = true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── Question text ──────────────────────────────
                      AdminSection(
                        title: 'Question text',
                        child: TextFormField(
                          controller: _questionCtrl,
                          maxLines: 5,
                          minLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Enter question text…',
                            alignLabelWithHint: true,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceBtwItems),

                      // ── Answer options ─────────────────────────────
                      AdminSection(
                        title: 'Answer options',
                        trailing: Text(
                          '${_options.length}/6',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        child: Column(
                          children: [
                            for (int i = 0; i < _options.length; i++)
                              Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppSizes.sm,
                                ),
                                child: Row(
                                  children: [
                                    // Correct-answer radio.
                                    Radio<int>(
                                      value: i,
                                      groupValue: _correctIndex,
                                      onChanged: (v) => setState(
                                        () => _correctIndex = v!,
                                      ),
                                    ),
                                    // Option letter.
                                    SizedBox(
                                      width: 20,
                                      child: Text(
                                        String.fromCharCode(65 + i),
                                        style: TextStyle(
                                          fontWeight: _correctIndex == i
                                              ? FontWeight.w700
                                              : FontWeight.normal,
                                          color: _correctIndex == i
                                              ? AppColors.success
                                              : null,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.xs),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _options[i],
                                        decoration: InputDecoration(
                                          isDense: true,
                                          hintText: 'Option ${i + 1}',
                                        ),
                                        validator: (v) =>
                                            v == null || v.trim().isEmpty
                                                ? 'Required'
                                                : null,
                                      ),
                                    ),
                                    if (_options.length > 2)
                                      IconButton(
                                        tooltip: 'Remove',
                                        iconSize: AppSizes.iconSm,
                                        onPressed: () => _removeOption(i),
                                        icon: const Icon(
                                          Icons.remove_circle_outline,
                                          color: AppColors.error,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            if (_options.length < 6)
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: _addOption,
                                  icon: const Icon(
                                    Icons.add_rounded,
                                    size: AppSizes.iconSm,
                                  ),
                                  label: const Text('Add option'),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceBtwItems),

                      // ── Explanations ───────────────────────────────
                      AdminSection(
                        title: 'Explanations',
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _explanationEnCtrl,
                              maxLines: 3,
                              minLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'English explanation',
                                alignLabelWithHint: true,
                              ),
                            ),
                            const SizedBox(height: AppSizes.spaceBtwInputFields),
                            TextFormField(
                              controller: _explanationAmCtrl,
                              maxLines: 3,
                              minLines: 2,
                              decoration: const InputDecoration(
                                labelText: 'Amharic explanation (አማርኛ)',
                                alignLabelWithHint: true,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
