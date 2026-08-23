import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
import 'package:m_admin/features/challenges/controllers/challenge_editor_controller.dart';
import 'package:m_admin/features/challenges/models/challenge_question_model.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class ChallengeEditorScreen extends StatefulWidget {
  const ChallengeEditorScreen({
    super.key,
    this.setId,
    this.subjectId = 0,
    this.subjectName = '',
  });

  final String? setId;
  final int subjectId;
  final String subjectName;

  @override
  State<ChallengeEditorScreen> createState() => _ChallengeEditorScreenState();
}

class _ChallengeEditorScreenState extends State<ChallengeEditorScreen> {
  late final ChallengeEditorController _ctrl;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(
      ChallengeEditorController(setId: widget.setId, subjectId: widget.subjectId),
      tag: 'challenge_editor_${widget.setId ?? 'new_${DateTime.now().millisecondsSinceEpoch}'}',
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _openQuestionDialog({ChallengeQuestionModel? question}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChallengeQuestionDialog(
        setId: _ctrl.currentSetId.value ?? '',
        question: question,
        onSaved: () => _ctrl.reloadQuestions(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(_ctrl.isSetSaved ? 'Edit Question Set' : 'New Challenge Question Set'),
        ),
        actions: [
          Obx(() {
            if (_ctrl.isSaving.value) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return IconButton(
              tooltip: 'Save Question Set',
              icon: const Icon(Icons.check_rounded, size: 22),
              onPressed: () => _ctrl.saveQuestionSet(),
            );
          }),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(() {
        if (_ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final isSaved = _ctrl.isSetSaved;
        final qCount = _ctrl.questions.length;
        final isReady = qCount >= 30;

        return Scrollbar(
          controller: _scrollCtrl,
          child: SingleChildScrollView(
            controller: _scrollCtrl,
            padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, 100),
            child: Form(
              key: _ctrl.formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Progress Header Banner ────────────────────────
                  Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: dark ? AppColors.darkCard : AppColors.white,
                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                      border: Border.all(
                        color: isSaved
                            ? (isReady ? AppColors.success.withValues(alpha: 0.4) : AppColors.primary.withValues(alpha: 0.3))
                            : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isSaved ? (isReady ? AppColors.success : AppColors.primary) : AppColors.textSecondary)
                                    .withValues(alpha: 0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isReady ? Iconsax.cup_copy : (isSaved ? Iconsax.tick_circle_copy : Iconsax.edit_2_copy),
                                color: isReady ? AppColors.success : (isSaved ? AppColors.primary : AppColors.textSecondary),
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isSaved
                                        ? (isReady ? 'Batch Complete & Ready for Live' : 'Question Batch in Progress')
                                        : 'Step 1: Set Metadata & Subject',
                                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
                                  ),
                                  Text(
                                    isSaved
                                        ? '$qCount question${qCount == 1 ? '' : 's'} added (Recommended: 30–50)'
                                        : 'Fill in the title and subject to begin adding questions.',
                                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: (isReady ? AppColors.success : AppColors.warning).withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                isReady ? '$qCount Qs (READY)' : '$qCount / 30 Qs',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.bold,
                                  color: isReady ? AppColors.success : AppColors.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (isSaved) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (qCount / 30).clamp(0.0, 1.0),
                              backgroundColor: dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.2),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isReady ? AppColors.success : AppColors.primary,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // Copy Set ID for SQL bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.code_rounded, size: 15, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: SelectableText(
                                    'Set ID: ${_ctrl.currentSetId.value}',
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  borderRadius: BorderRadius.circular(4),
                                  onTap: () {
                                    final id = _ctrl.currentSetId.value ?? '';
                                    if (id.isNotEmpty) {
                                      Clipboard.setData(ClipboardData(text: id));
                                      SnackbarHelper.success('Copied to Clipboard', 'Set ID: $id (Use this in Supabase SQL editor)');
                                    }
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.14),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.copy_rounded, size: 12, color: AppColors.primary),
                                        SizedBox(width: 4),
                                        Text(
                                          'Copy Set ID for SQL',
                                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSizes.spaceBtwSections),

                  // ── Metadata Section ──────────────────────────────
                  AdminSection(
                    title: 'Question Set Details',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Set Title *',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        TextFormField(
                          controller: _ctrl.titleCtrl,
                          decoration: InputDecoration(
                            hintText: 'e.g. Grade 12 Physics National Challenge Batch 1 (50 Qs)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                          ),
                          validator: (val) =>
                              val == null || val.trim().isEmpty ? 'Please enter a title' : null,
                        ),
                        const SizedBox(height: AppSizes.spaceBtwItems),
                        const Text(
                          'Subject *',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                        const SizedBox(height: AppSizes.xs),
                        DropdownButtonFormField<int>(
                          value: _ctrl.selectedSubjectId.value != 0
                              ? _ctrl.selectedSubjectId.value
                              : null,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                          ),
                          hint: const Text('Select a Subject'),
                          items: _ctrl.subjects
                              .map(
                                (s) => DropdownMenuItem<int>(
                                  value: s['id'] as int,
                                  child: Text(s['name']?.toString() ?? ''),
                                ),
                              )
                              .toList(),
                          onChanged: (val) => _ctrl.selectedSubjectId.value = val,
                          validator: (val) => val == null ? 'Please select a subject' : null,
                        ),
                        if (!isSaved) ...[
                          const SizedBox(height: AppSizes.md),
                          Align(
                            alignment: Alignment.centerRight,
                            child: FilledButton.icon(
                              onPressed: _ctrl.isSaving.value ? null : () => _ctrl.saveQuestionSet(),
                              icon: const Icon(Iconsax.arrow_right_3_copy, size: 16),
                              label: const Text('Save & Start Adding Questions'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSizes.spaceBtwSections),

                  // ── Questions Section ─────────────────────────────
                  if (isSaved) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Questions in Batch (${_ctrl.questions.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        FilledButton.icon(
                          onPressed: () => _openQuestionDialog(),
                          icon: const Icon(Iconsax.add_copy, size: AppSizes.iconSm),
                          label: const Text('Add Question'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.md),
                    if (_ctrl.questions.isEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(AppSizes.xl),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                          border: Border.all(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              const Icon(Iconsax.note_copy, size: 40, color: AppColors.primary),
                              const SizedBox(height: AppSizes.sm),
                              const Text(
                                'No questions in this set yet.',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Click "Add Question" to build MCQs in the app or copy the Set ID above to insert in Supabase SQL Editor.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                              ),
                              const SizedBox(height: AppSizes.md),
                              FilledButton.icon(
                                onPressed: () => _openQuestionDialog(),
                                icon: const Icon(Iconsax.add_copy, size: 16),
                                label: const Text('Add First Question'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _ctrl.questions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSizes.sm),
                        itemBuilder: (context, idx) {
                          final q = _ctrl.questions[idx];
                          final parsedIdx = int.tryParse(q.correctChoice);
                          final correctText = parsedIdx != null && parsedIdx < q.choices.length
                              ? q.choices[parsedIdx]
                              : q.correctChoice;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                              side: BorderSide(
                                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(AppSizes.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 14,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.14),
                                    child: Text(
                                      '${idx + 1}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSizes.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          q.questionText,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.success.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'Correct: $correctText',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.success,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '• ${q.choices.length} choices',
                                              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                            ),
                                            if (q.explanationEn.isNotEmpty)
                                              const Text(
                                                '• EN Explanation',
                                                style: TextStyle(fontSize: 11, color: AppColors.primary),
                                              ),
                                            if (q.explanationAm.isNotEmpty)
                                              const Text(
                                                '• አማርኛ ማብራሪያ',
                                                style: TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        tooltip: 'Edit question',
                                        icon: const Icon(Iconsax.edit_copy, size: 18),
                                        onPressed: () => _openQuestionDialog(question: q),
                                      ),
                                      IconButton(
                                        tooltip: 'Delete question',
                                        icon: const Icon(Iconsax.trash_copy, size: 18, color: AppColors.error),
                                        onPressed: () async {
                                          final ok = await AppDialogBoxes.confirm(
                                            title: 'Delete question',
                                            message: 'Are you sure you want to remove this question?',
                                            confirmLabel: 'Delete',
                                            isDestructive: true,
                                          );
                                          if (ok) _ctrl.deleteQuestion(q.id);
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ] else ...[
                    Container(
                      padding: const EdgeInsets.all(AppSizes.lg),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                      ),
                      child: const Row(
                        children: [
                          Icon(Iconsax.info_circle_copy, color: AppColors.primary),
                          SizedBox(width: AppSizes.sm),
                          Expanded(
                            child: Text(
                              'Save this question set above, and the question authoring tools and Set ID will unlock immediately.',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
        final isSaved = _ctrl.isSetSaved;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 12),
          decoration: BoxDecoration(
            color: dark ? AppColors.darkCard : AppColors.white,
            border: Border(
              top: BorderSide(
                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _ctrl.isSaving.value ? null : () => _ctrl.saveQuestionSet(),
                    icon: _ctrl.isSaving.value
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Iconsax.document_upload_copy, size: AppSizes.iconSm),
                    label: const Text('Save Set'),
                  ),
                ),
                if (isSaved) ...[
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      onPressed: _ctrl.isSaving.value ? null : _ctrl.saveAndScheduleRound,
                      icon: const Icon(Iconsax.calendar_tick_copy, size: AppSizes.iconSm),
                      label: const Text('Save & Schedule Round'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }
}

// ── Question Authoring Dialog with Bilingual Explanations ────────────────────

class _ChallengeQuestionDialog extends StatefulWidget {
  const _ChallengeQuestionDialog({
    required this.setId,
    this.question,
    required this.onSaved,
  });

  final String setId;
  final ChallengeQuestionModel? question;
  final VoidCallback onSaved;

  @override
  State<_ChallengeQuestionDialog> createState() => _ChallengeQuestionDialogState();
}

class _ChallengeQuestionDialogState extends State<_ChallengeQuestionDialog> {
  final _repo = ChallengeRepository();
  final _formKey = GlobalKey<FormState>();

  final _textCtrl = TextEditingController();
  final _explanationEnCtrl = TextEditingController();
  final _explanationAmCtrl = TextEditingController();
  final _imageUrlCtrl = TextEditingController();

  final _choicesControllers = <TextEditingController>[];
  int _correctIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initFields();
  }

  void _initFields() {
    if (widget.question != null) {
      _textCtrl.text = widget.question!.questionText;
      _explanationEnCtrl.text = widget.question!.explanationEn.isNotEmpty
          ? widget.question!.explanationEn
          : widget.question!.explanation;
      _explanationAmCtrl.text = widget.question!.explanationAm;
      _imageUrlCtrl.text = widget.question!.imageUrl ?? '';

      for (final c in widget.question!.choices) {
        _choicesControllers.add(TextEditingController(text: c));
      }

      final parsedIdx = int.tryParse(widget.question!.correctChoice);
      if (parsedIdx != null && parsedIdx < _choicesControllers.length) {
        _correctIndex = parsedIdx;
      } else {
        final matchIdx = widget.question!.choices.indexOf(widget.question!.correctChoice);
        _correctIndex = matchIdx != -1 ? matchIdx : 0;
      }
    } else {
      _choicesControllers.addAll([
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
        TextEditingController(),
      ]);
    }
  }

  void _resetForNextQuestion() {
    _textCtrl.clear();
    _explanationEnCtrl.clear();
    _explanationAmCtrl.clear();
    _imageUrlCtrl.clear();
    for (final c in _choicesControllers) {
      c.clear();
    }
    setState(() {
      _correctIndex = 0;
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _explanationEnCtrl.dispose();
    _explanationAmCtrl.dispose();
    _imageUrlCtrl.dispose();
    for (final c in _choicesControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addChoice() {
    if (_choicesControllers.length >= 6) return;
    setState(() => _choicesControllers.add(TextEditingController()));
  }

  void _removeChoice(int idx) {
    if (_choicesControllers.length <= 2) return;
    _choicesControllers[idx].dispose();
    setState(() {
      _choicesControllers.removeAt(idx);
      if (_correctIndex >= _choicesControllers.length) {
        _correctIndex = _choicesControllers.length - 1;
      }
    });
  }

  Future<bool> _save({bool addAnother = false}) async {
    if (!_formKey.currentState!.validate()) return false;
    if (_choicesControllers.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 choices required')),
      );
      return false;
    }

    setState(() => _isSaving = true);
    try {
      final choicesList = _choicesControllers.map((c) => c.text.trim()).toList();
      final expEn = _explanationEnCtrl.text.trim();
      final expAm = _explanationAmCtrl.text.trim();

      final data = <String, dynamic>{
        if (widget.question != null && widget.question!.id.isNotEmpty)
          'id': widget.question!.id,
        'set_id': widget.setId,
        'question_text': _textCtrl.text.trim(),
        'choices': choicesList,
        'correct_choice': _correctIndex.toString(),
        'explanation': expEn.isNotEmpty ? expEn : expAm,
        'explanation_en': expEn,
        'explanation_am': expAm,
        'image_url': _imageUrlCtrl.text.trim().isNotEmpty ? _imageUrlCtrl.text.trim() : null,
      };

      await _repo.upsertQuestion(data);
      widget.onSaved();

      if (mounted) {
        if (addAnother) {
          _resetForNextQuestion();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Question saved! Ready for next question.'),
              duration: Duration(seconds: 1),
            ),
          );
        } else {
          Navigator.of(context).pop();
        }
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final dialogWidth = screenWidth > 600 ? 560.0 : (screenWidth * 0.92);

    return AlertDialog(
      title: Text(widget.question == null ? 'Add MCQ Question' : 'Edit Question'),
      actionsOverflowButtonSpacing: 8,
      actionsOverflowAlignment: OverflowBarAlignment.end,
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Question Text *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _textCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Enter question stem (English or Amharic)...',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: AppSizes.spaceBtwItems),

                const Text('Choices (Tap letter circle for correct answer) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 6),
                ...List.generate(_choicesControllers.length, (idx) {
                  final letter = String.fromCharCode(65 + idx);
                  final isSelected = _correctIndex == idx;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => setState(() => _correctIndex = idx),
                          child: Container(
                            width: 32,
                            height: 32,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isSelected ? AppColors.success : Colors.transparent,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? AppColors.success : AppColors.borderPrimary,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Text(
                              letter,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                                color: isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _choicesControllers[idx],
                            decoration: InputDecoration(
                              hintText: 'Option $letter text',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: const OutlineInputBorder(),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                          ),
                        ),
                        if (_choicesControllers.length > 2)
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            onPressed: () => _removeChoice(idx),
                          ),
                      ],
                    ),
                  );
                }),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: _choicesControllers.length < 6 ? _addChoice : null,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Choice'),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwItems),

                // ── Bilingual Explanations ─────────────────────────
                const Text('English Explanation (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _explanationEnCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'Explain why the correct answer is right in English...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwItems),

                const Text('Amharic Explanation / አማርኛ ማብራሪያ (Optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _explanationAmCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'የአማርኛ ማብራሪያ እዚህ ያስገቡ (ለምን ትክክል እንደሆነ)...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSizes.spaceBtwItems),

                const Text('Image URL (optional)', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 4),
                TextFormField(
                  controller: _imageUrlCtrl,
                  decoration: const InputDecoration(
                    hintText: 'https://...',
                    border: OutlineInputBorder(),
                  ),
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
        if (widget.question == null)
          OutlinedButton(
            onPressed: _isSaving ? null : () => _save(addAnother: true),
            child: const Text('Save & Add Another'),
          ),
        FilledButton(
          onPressed: _isSaving ? null : () => _save(addAnother: false),
          child: _isSaving
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save Question'),
        ),
      ],
    );
  }
}
