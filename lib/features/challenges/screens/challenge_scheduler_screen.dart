import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:intl/intl.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/features/challenges/controllers/challenge_scheduler_controller.dart';
import 'package:m_admin/features/challenges/screens/challenge_editor_screen.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class ChallengeSchedulerScreen extends StatefulWidget {
  const ChallengeSchedulerScreen({
    super.key,
    this.challengeId,
    this.preselectedSetId,
    this.preselectedSubjectId,
  });

  final String? challengeId;
  final String? preselectedSetId;
  final int? preselectedSubjectId;

  @override
  State<ChallengeSchedulerScreen> createState() => _ChallengeSchedulerScreenState();
}

class _ChallengeSchedulerScreenState extends State<ChallengeSchedulerScreen> {
  late final ChallengeSchedulerController _ctrl;
  final _dateFormat = DateFormat('EEE, MMM dd, yyyy • HH:mm');

  @override
  void initState() {
    super.initState();
    _ctrl = Get.put(
      ChallengeSchedulerController(
        challengeId: widget.challengeId,
        preselectedSetId: widget.preselectedSetId,
        preselectedSubjectId: widget.preselectedSubjectId,
      ),
      tag: 'scheduler_${widget.challengeId ?? widget.preselectedSetId ?? 'new_${DateTime.now().millisecondsSinceEpoch}'}',
    );
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

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.challengeId == null ? 'Schedule Challenge Round' : 'Edit Challenge Schedule'),
        actions: [
          IconButton(
            tooltip: 'Publish Challenge',
            icon: const Icon(Icons.check_rounded, size: 22),
            onPressed: () => _ctrl.scheduleAndPublish(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Obx(() {
        if (_ctrl.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }

        final hasSets = _ctrl.questionSets.isNotEmpty;
        final selectedSet = _ctrl.selectedSet;
        final selectedAudience = _ctrl.selectedAudience.value;
        final startsAt = _ctrl.startsAt.value;
        final endsAt = _ctrl.endsAt.value;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(AppSizes.md, AppSizes.md, AppSizes.md, 100),
          child: Form(
            key: _ctrl.formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Section 1: Question Set Selection ───────────────
                AdminSection(
                  title: '1. Select Content & Questions',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hasSets) ...[
                        Container(
                          padding: const EdgeInsets.all(AppSizes.md),
                          decoration: BoxDecoration(
                            color: AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                            border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Iconsax.info_circle_copy, color: AppColors.warning, size: 20),
                                  SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'No Question Sets Available',
                                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: AppColors.warning),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'A challenge round requires a Question Set with questions for students to solve. Create your first question set to proceed.',
                                style: TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: AppSizes.md),
                              FilledButton.icon(
                                onPressed: () async {
                                  final ok = await Get.to(() => const ChallengeEditorScreen());
                                  if (ok == true || ok is String) {
                                    await _ctrl.reloadQuestionSets();
                                    if (ok is String) {
                                      _ctrl.onSetSelected(ok);
                                    }
                                  }
                                },
                                icon: const Icon(Iconsax.add_copy, size: 16),
                                label: const Text('Create Question Set Now'),
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Question Set *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                            TextButton.icon(
                              onPressed: () async {
                                final ok = await Get.to(() => const ChallengeEditorScreen());
                                if (ok == true || ok is String) {
                                  await _ctrl.reloadQuestionSets();
                                  if (ok is String) {
                                    _ctrl.onSetSelected(ok);
                                  }
                                }
                              },
                              icon: const Icon(Iconsax.add_circle_copy, size: 14),
                              label: const Text('Create New Set', style: TextStyle(fontSize: 11.5)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        DropdownButtonFormField<String>(
                          value: _ctrl.selectedSetId.value,
                          isExpanded: true,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          hint: const Text('Select a Question Set', overflow: TextOverflow.ellipsis),
                          items: _ctrl.questionSets
                              .map(
                                (s) => DropdownMenuItem<String>(
                                  value: s.id,
                                  child: Text(
                                    '${s.title} (${s.subjectName ?? 'Subject'}) • ${s.questionCount} Qs',
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: _ctrl.onSetSelected,
                          validator: (val) => val == null ? 'Please select a question set' : null,
                        ),

                        if (selectedSet != null) ...[
                          const SizedBox(height: AppSizes.sm),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: AppSizes.md, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Iconsax.document_copy, color: AppColors.primary, size: 18),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Subject: ${selectedSet.subjectName ?? 'Subject'} • ${selectedSet.questionCount} Questions',
                                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                                      ),
                                    ),
                                    if (selectedSet.questionCount < 30)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.warning.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          '< 30 Qs',
                                          style: TextStyle(fontSize: 10, color: AppColors.warning, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.code_rounded, size: 13, color: AppColors.textSecondary),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: SelectableText(
                                        'Set ID: ${selectedSet.id}',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 10.5,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      borderRadius: BorderRadius.circular(4),
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: selectedSet.id));
                                        SnackbarHelper.success('Copied!', 'Set ID: ${selectedSet.id} (Ready for SQL)');
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.copy_rounded, size: 10, color: AppColors.primary),
                                            SizedBox(width: 3),
                                            Text(
                                              'Copy ID',
                                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.primary),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.spaceBtwSections),

                // ── Section 2: Round Details & Audience ─────────────
                AdminSection(
                  title: '2. Round Details & Audience',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Display Title *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _ctrl.titleCtrl,
                        decoration: InputDecoration(
                          hintText: 'e.g. Physics Weekend National Stream Challenge',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: AppSizes.spaceBtwItems),

                      const Text('Target Audience *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _AudienceCard(
                            label: 'Both Streams (Natural & Social)',
                            icon: Icons.public_rounded,
                            selected: selectedAudience == 'both',
                            onTap: () => _ctrl.selectedAudience.value = 'both',
                          ),
                          _AudienceCard(
                            label: 'Natural Science Only',
                            icon: Icons.eco_rounded,
                            selected: selectedAudience == 'natural',
                            onTap: () => _ctrl.selectedAudience.value = 'natural',
                          ),
                          _AudienceCard(
                            label: 'Social Science Only',
                            icon: Icons.account_balance_rounded,
                            selected: selectedAudience == 'social',
                            onTap: () => _ctrl.selectedAudience.value = 'social',
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.spaceBtwItems),

                      const Text('Attempt Time Limit (Minutes) *', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
                      const SizedBox(height: 4),
                      TextFormField(
                        controller: _ctrl.durationMinutesCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: '60',
                          suffixText: 'minutes',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Required';
                          final n = int.tryParse(v.trim());
                          if (n == null || n <= 0) return 'Must be a positive number';
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Quick Select: ', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                          ...[30, 45, 60, 90, 120].map((mins) {
                            return ActionChip(
                              label: Text('$mins mins', style: const TextStyle(fontSize: 11)),
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                              onPressed: () => _ctrl.durationMinutesCtrl.text = mins.toString(),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.spaceBtwSections),

                // ── Section 3: Schedule Window & Timing ─────────────
                AdminSection(
                  title: '3. Schedule Window & Timing',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Quick Presets Wrap (Overflow-Proof)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Quick Presets: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ActionChip(
                            avatar: const Icon(Icons.bolt, size: 14, color: AppColors.success),
                            label: const Text('Go Live Now (12h)', style: TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            onPressed: _ctrl.applyLiveNowPreset,
                          ),
                          ActionChip(
                            avatar: const Icon(Iconsax.calendar_1_copy, size: 14, color: AppColors.primary),
                            label: const Text('Tomorrow 08:00', style: TextStyle(fontSize: 11)),
                            visualDensity: VisualDensity.compact,
                            onPressed: _ctrl.applyTomorrowPreset,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSizes.spaceBtwItems),

                      // Time Selection Cards
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _TimePickerCard(
                            title: 'Starts At (Pre-visibility begins 12h before)',
                            icon: Iconsax.calendar_copy,
                            timeText: startsAt != null ? _dateFormat.format(startsAt) : 'Select Start Date & Time',
                            isSelected: startsAt != null,
                            color: const Color(0xFF2563EB),
                            onTap: () async {
                              final picked = await _pickDateTime(_ctrl.startsAt.value);
                              if (picked != null) _ctrl.startsAt.value = picked;
                            },
                          ),
                          const SizedBox(height: AppSizes.md),
                          _TimePickerCard(
                            title: 'Ends At (Challenge Closes & Leaderboards Finalize)',
                            icon: Iconsax.calendar_tick_copy,
                            timeText: endsAt != null ? _dateFormat.format(endsAt) : 'Select End Date & Time',
                            isSelected: endsAt != null,
                            color: AppColors.success,
                            onTap: () async {
                              final picked = await _pickDateTime(_ctrl.endsAt.value);
                              if (picked != null) _ctrl.endsAt.value = picked;
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSizes.md),
                      Container(
                        padding: const EdgeInsets.all(AppSizes.sm + 4),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkContainer : AppColors.grey.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
                        ),
                        child: const Row(
                          children: [
                            Icon(Iconsax.info_circle_copy, size: 16, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pre-visibility: The challenge countdown tile will automatically appear on students\' apps 12 hours prior to the start time.',
                                style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      bottomNavigationBar: Obx(() {
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
                  child: OutlinedButton(
                    onPressed: _ctrl.isSaving.value ? null : _ctrl.saveAsDraft,
                    child: const Text('Save as Draft'),
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                    onPressed: _ctrl.isSaving.value ? null : _ctrl.scheduleAndPublish,
                    icon: _ctrl.isSaving.value
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Iconsax.calendar_tick_copy, size: AppSizes.iconSm),
                    label: const Text('Schedule & Publish'),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }
}

class _AudienceCard extends StatelessWidget {
  const _AudienceCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary.withValues(alpha: 0.12)
              : (dark ? AppColors.darkCard : AppColors.grey.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusSm),
          border: Border.all(
            color: selected ? AppColors.primary : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                color: selected ? AppColors.primary : (dark ? Colors.white70 : Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimePickerCard extends StatelessWidget {
  const _TimePickerCard({
    required this.title,
    required this.icon,
    required this.timeText,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final String timeText;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
      child: Container(
        padding: const EdgeInsets.all(AppSizes.md),
        decoration: BoxDecoration(
          color: dark ? AppColors.darkCard : AppColors.white,
          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.5) : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: dark ? 0.2 : 0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: AppSizes.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    timeText,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? (dark ? Colors.white : Colors.black87) : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: isSelected ? color : AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
