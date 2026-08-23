import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
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
    this.challengeId,
    this.initialSubjectId,
  });

  final String? challengeId;
  final int? initialSubjectId;

  @override
  State<ChallengeEditorScreen> createState() => _ChallengeEditorScreenState();
}

class _ChallengeEditorScreenState extends State<ChallengeEditorScreen> {
  late final ChallengeEditorController _ctrl;
  final _dateFormat = DateFormat('MMM dd, yyyy • HH:mm');
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(
      ChallengeEditorController(
        challengeId: widget.challengeId,
        initialSubjectId: widget.initialSubjectId,
      ),
      tag: 'challenge_editor_${widget.challengeId ?? 'new_${DateTime.now().millisecondsSinceEpoch}'}',
    );
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: now.subtract(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return null;

    final time = await showTimePicker(
      context: context,
      initialTime: initial != null
          ? TimeOfDay.fromDateTime(initial)
          : TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
    );
    if (time == null) return null;

    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  void _openQuestionDialog({ChallengeQuestionModel? question}) {
    if (_ctrl.currentSetId.value == null) {
      SnackbarHelper.warning('Save First', 'Please save the challenge details before adding questions.');
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ChallengeQuestionDialog(
        setId: _ctrl.currentSetId.value!,
        question: question,
        onSaved: () => _ctrl.reloadQuestions(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Obx(
            () => Text(
              _ctrl.isEditingExisting ? 'Edit Challenge' : 'Create New Challenge',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final id = await _ctrl.saveChallenge(isPublish: false);
                      if (id != null && !mounted) return;
                    },
                    child: const Text('Save Draft', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final id = await _ctrl.saveChallenge(isPublish: true);
                      if (id != null) {
                        Get.back(result: true);
                      }
                    },
                    icon: const Icon(Iconsax.send_1_copy, size: 14),
                    label: const Text('Publish / Schedule', style: TextStyle(fontSize: 12)),
                  ),
                  const SizedBox(width: 12),
                ],
              );
            }),
          ],
        ),
        body: Obx(() {
          if (_ctrl.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }

          return Scrollbar(
            controller: _scrollCtrl,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(AppSizes.md),
              child: Form(
                key: _ctrl.formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── SECTION 1: CHALLENGE DETAILS ────────────────────────
                    Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkCard : AppColors.white,
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                        border: Border.all(
                          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Iconsax.cup_copy, color: AppColors.primary, size: 18),
                              const SizedBox(width: 6),
                              const Text(
                                'Challenge Details & Schedule',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const Spacer(),
                              if (_ctrl.isEditingExisting)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _ctrl.status.value.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const Divider(height: 20),

                          // Challenge Title
                          TextFormField(
                            controller: _ctrl.titleCtrl,
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a title' : null,
                            decoration: InputDecoration(
                              labelText: 'Challenge Title *',
                              hintText: 'e.g. National Physics Round #4',
                              prefixIcon: const Icon(Iconsax.edit_copy, size: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSizes.spaceBtwInputFields),

                          // Subject & Stream Row
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              // Subject Selector
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 220, maxWidth: 350),
                                child: DropdownButtonFormField<int?>(
                                  initialValue: _ctrl.selectedSubjectId.value,
                                  decoration: InputDecoration(
                                    labelText: 'Subject *',
                                    prefixIcon: const Icon(Iconsax.book_copy, size: 16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                                    ),
                                  ),
                                  items: [
                                    const DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text('Select Subject'),
                                    ),
                                    ..._ctrl.subjects.map(
                                      (s) => DropdownMenuItem<int?>(
                                        value: s['id'] as int,
                                        child: Text(s['name']?.toString() ?? ''),
                                      ),
                                    ),
                                  ],
                                  onChanged: (v) => _ctrl.selectedSubjectId.value = v,
                                ),
                              ),

                              // Audience Stream Chips
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Target Audience Stream:',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Obx(
                                    () => Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _StreamChip(
                                          label: 'Both Streams',
                                          selected: _ctrl.audience.value == 'both',
                                          onTap: () => _ctrl.audience.value = 'both',
                                        ),
                                        const SizedBox(width: 6),
                                        _StreamChip(
                                          label: 'Natural Only',
                                          selected: _ctrl.audience.value == 'natural',
                                          onTap: () => _ctrl.audience.value = 'natural',
                                        ),
                                        const SizedBox(width: 6),
                                        _StreamChip(
                                          label: 'Social Only',
                                          selected: _ctrl.audience.value == 'social',
                                          onTap: () => _ctrl.audience.value = 'social',
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSizes.spaceBtwInputFields),

                          // Duration, Start and End Time
                          Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              // Test Duration
                              SizedBox(
                                width: 160,
                                child: TextFormField(
                                  controller: _ctrl.durationCtrl,
                                  keyboardType: TextInputType.number,
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                  decoration: InputDecoration(
                                    labelText: 'Duration (Mins) *',
                                    hintText: '40',
                                    prefixIcon: const Icon(Iconsax.timer_1_copy, size: 16),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                                    ),
                                  ),
                                ),
                              ),

                              // Start Time Picker
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                                  onTap: () async {
                                    final dt = await _pickDateTime(_ctrl.startsAt.value);
                                    if (dt != null) _ctrl.startsAt.value = dt;
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'Start Date & Time *',
                                      prefixIcon: const Icon(Iconsax.calendar_1_copy, size: 16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                                      ),
                                    ),
                                    child: Obx(
                                      () => Text(
                                        _ctrl.startsAt.value != null
                                            ? _dateFormat.format(_ctrl.startsAt.value!)
                                            : 'Tap to select start time',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),

                              // End Time Picker
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                                  onTap: () async {
                                    final dt = await _pickDateTime(_ctrl.endsAt.value);
                                    if (dt != null) _ctrl.endsAt.value = dt;
                                  },
                                  child: InputDecorator(
                                    decoration: InputDecoration(
                                      labelText: 'End Date & Time *',
                                      prefixIcon: const Icon(Iconsax.calendar_2_copy, size: 16),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                                      ),
                                    ),
                                    child: Obx(
                                      () => Text(
                                        _ctrl.endsAt.value != null
                                            ? _dateFormat.format(_ctrl.endsAt.value!)
                                            : 'Tap to select end time',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSizes.spaceBtwSections),

                    // ── SECTION 2: QUESTIONS LIST ───────────────────────────
                    Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkCard : AppColors.white,
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                        border: Border.all(
                          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  const Icon(Iconsax.document_copy, color: AppColors.primary, size: 18),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Questions (${_ctrl.questions.length})',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                              FilledButton.icon(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () async {
                                  // Save challenge first if not yet created so set_id exists
                                  if (!_ctrl.isEditingExisting && _ctrl.currentSetId.value == null) {
                                    final id = await _ctrl.saveChallenge(isPublish: false);
                                    if (id != null) _openQuestionDialog();
                                  } else {
                                    _openQuestionDialog();
                                  }
                                },
                                icon: const Icon(Iconsax.add_circle_copy, size: 14),
                                label: const Text('Add Question', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const Divider(height: 20),

                          if (_ctrl.questions.isEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24),
                              child: Column(
                                children: [
                                  Icon(Iconsax.document_copy, size: 40, color: dark ? Colors.white24 : AppColors.textSecondary),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No questions added to this challenge yet.',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Tap "Add Question" above or insert questions directly via Supabase SQL command.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: _ctrl.questions.length,
                              separatorBuilder: (_, _) => const SizedBox(height: 8),
                              itemBuilder: (context, idx) {
                                final q = _ctrl.questions[idx];
                                return _QuestionTile(
                                  question: q,
                                  index: idx + 1,
                                  dark: dark,
                                  onEdit: () => _openQuestionDialog(question: q),
                                  onDelete: () => _confirmDeleteQuestion(context, q),
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  void _confirmDeleteQuestion(BuildContext context, ChallengeQuestionModel q) {
    AppDialogBoxes.confirm(
      title: 'Delete Question',
      message: 'Are you sure you want to delete this question?',
      isDestructive: true,
      confirmLabel: 'Delete',
    ).then((confirmed) {
      if (confirmed) {
        _ctrl.deleteQuestion(q.id);
      }
    });
  }
}

// ── Stream Chip ──────────────────────────────────────────────────────────────

class _StreamChip extends StatelessWidget {
  const _StreamChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.borderPrimary,
            width: selected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Question Tile ────────────────────────────────────────────────────────────

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({
    required this.question,
    required this.index,
    required this.dark,
    required this.onEdit,
    required this.onDelete,
  });

  final ChallengeQuestionModel question;
  final int index;
  final bool dark;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    int correctIdx = -1;
    final parsed = int.tryParse(question.correctChoice);
    if (parsed != null) {
      correctIdx = parsed;
    } else {
      correctIdx = question.choices.indexOf(question.correctChoice);
    }

    return Container(
      padding: const EdgeInsets.all(AppSizes.sm + 4),
      decoration: BoxDecoration(
        color: dark ? AppColors.darkContainer : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
        border: Border.all(color: dark ? AppColors.darkBorder : AppColors.borderPrimary),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 22,
                height: 22,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  question.questionText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              IconButton(
                icon: const Icon(Iconsax.edit_2_copy, size: 14),
                visualDensity: VisualDensity.compact,
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Iconsax.trash_copy, size: 14, color: AppColors.error),
                visualDensity: VisualDensity.compact,
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Choices preview
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: List.generate(question.choices.length, (idx) {
              final isCorrect = idx == correctIdx || question.choices[idx] == question.correctChoice;
              final letter = String.fromCharCode(65 + idx);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isCorrect ? const Color(0xFF10B981).withValues(alpha: 0.15) : Colors.transparent,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: isCorrect ? const Color(0xFF10B981) : AppColors.borderPrimary,
                  ),
                ),
                child: Text(
                  '$letter: ${question.choices[idx]}',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: isCorrect ? FontWeight.bold : FontWeight.normal,
                    color: isCorrect ? const Color(0xFF10B981) : AppColors.textSecondary,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ── Question Dialog ──────────────────────────────────────────────────────────

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
  final _imageCtrl = TextEditingController();
  final _explEnCtrl = TextEditingController();
  final _explAmCtrl = TextEditingController();

  final _choiceControllers = List.generate(4, (_) => TextEditingController());
  int _correctChoiceIndex = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final q = widget.question;
    if (q != null) {
      _textCtrl.text = q.questionText;
      _imageCtrl.text = q.imageUrl ?? '';
      _explEnCtrl.text = q.explanationEn;
      _explAmCtrl.text = q.explanationAm;

      for (int i = 0; i < 4 && i < q.choices.length; i++) {
        _choiceControllers[i].text = q.choices[i];
      }

      final parsed = int.tryParse(q.correctChoice);
      if (parsed != null && parsed >= 0 && parsed < 4) {
        _correctChoiceIndex = parsed;
      } else {
        final idx = q.choices.indexOf(q.correctChoice);
        if (idx != -1) _correctChoiceIndex = idx;
      }
    }
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _imageCtrl.dispose();
    _explEnCtrl.dispose();
    _explAmCtrl.dispose();
    for (final c in _choiceControllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final choices = _choiceControllers.map((c) => c.text.trim()).toList();
    if (choices.any((c) => c.isEmpty)) {
      SnackbarHelper.warning('Missing Choices', 'Please fill in all 4 choices (A, B, C, D)');
      return;
    }

    setState(() => _isSaving = true);
    try {
      final payload = <String, dynamic>{
        if (widget.question != null) 'id': widget.question!.id,
        'set_id': widget.setId,
        'question_text': _textCtrl.text.trim(),
        'image_url': _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
        'choices': choices,
        'correct_choice': '$_correctChoiceIndex',
        'explanation_en': _explEnCtrl.text.trim(),
        'explanation_am': _explAmCtrl.text.trim(),
      };

      await _repo.upsertQuestion(payload);
      widget.onSaved();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      SnackbarHelper.error('Error', e.toString());
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
        child: Padding(
          padding: const EdgeInsets.all(AppSizes.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.question == null ? 'Add Challenge Question' : 'Edit Question',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Question Text
                        TextFormField(
                          controller: _textCtrl,
                          maxLines: 3,
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter question text' : null,
                          decoration: InputDecoration(
                            labelText: 'Question Text *',
                            hintText: 'Enter question with LaTeX formulas or markdown...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceBtwInputFields),

                        // Image URL (optional)
                        TextFormField(
                          controller: _imageCtrl,
                          decoration: InputDecoration(
                            labelText: 'Image URL (optional)',
                            prefixIcon: const Icon(Iconsax.image_copy, size: 16),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceBtwInputFields),

                        const Text(
                          'Choices & Correct Answer:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                        ),
                        const SizedBox(height: 6),

                        // Choices A, B, C, D
                        ...List.generate(4, (idx) {
                          final letter = String.fromCharCode(65 + idx);
                          final isSelected = _correctChoiceIndex == idx;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Radio<int>(
                                  value: idx,
                                  groupValue: _correctChoiceIndex,
                                  activeColor: const Color(0xFF10B981),
                                  onChanged: (v) => setState(() => _correctChoiceIndex = v ?? 0),
                                ),
                                Expanded(
                                  child: TextFormField(
                                    controller: _choiceControllers[idx],
                                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                                    decoration: InputDecoration(
                                      labelText: 'Choice $letter *',
                                      filled: isSelected,
                                      fillColor: isSelected
                                          ? const Color(0xFF10B981).withValues(alpha: 0.08)
                                          : null,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),

                        const SizedBox(height: AppSizes.spaceBtwInputFields),

                        // English Explanation
                        TextFormField(
                          controller: _explEnCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'English Explanation',
                            hintText: 'Step-by-step solution in English...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                          ),
                        ),
                        const SizedBox(height: AppSizes.spaceBtwInputFields),

                        // Amharic Explanation
                        TextFormField(
                          controller: _explAmCtrl,
                          maxLines: 2,
                          decoration: InputDecoration(
                            labelText: 'Amharic Explanation (አማርኛ)',
                            hintText: 'የጥያቄው ማብራሪያ በአማርኛ...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.md),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _isSaving ? null : _save,
                      child: _isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Save Question'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
