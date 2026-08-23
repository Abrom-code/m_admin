import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
import 'package:m_admin/features/challenges/models/challenge_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class ChallengeSchedulerController extends GetxController {
  ChallengeSchedulerController({this.challengeId, this.preselectedSetId, this.preselectedSubjectId});

  final String? challengeId;
  final String? preselectedSetId;
  final int? preselectedSubjectId;

  final _repo = ChallengeRepository();

  final isLoading = false.obs;
  final isSaving = false.obs;

  final titleCtrl = TextEditingController();
  final durationMinutesCtrl = TextEditingController(text: '60');
  final selectedAudience = 'both'.obs; // 'natural', 'social', 'both'
  final selectedSetId = RxnString();
  final selectedSubjectId = RxnInt();

  final startsAt = Rxn<DateTime>();
  final endsAt = Rxn<DateTime>();
  final currentStatus = 'draft'.obs;

  final questionSets = <ChallengeQuestionSetModel>[].obs;
  final formKey = GlobalKey<FormState>();

  ChallengeQuestionSetModel? get selectedSet {
    if (selectedSetId.value == null) return null;
    return questionSets.firstWhereOrNull((s) => s.id == selectedSetId.value);
  }

  @override
  void onInit() {
    super.onInit();
    selectedSetId.value = preselectedSetId;
    selectedSubjectId.value = preselectedSubjectId;
    _initData();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    durationMinutesCtrl.dispose();
    super.onClose();
  }

  Future<void> _initData() async {
    isLoading.value = true;
    try {
      questionSets.value = await _repo.fetchQuestionSets();

      if (challengeId != null && challengeId!.isNotEmpty) {
        final ch = await _repo.fetchChallengeDetail(challengeId!);
        titleCtrl.text = ch.title;
        selectedSetId.value = ch.setId;
        selectedSubjectId.value = ch.subjectId;
        selectedAudience.value = ch.audience;
        durationMinutesCtrl.text = (ch.durationSeconds ~/ 60).toString();
        startsAt.value = ch.startsAt;
        endsAt.value = ch.endsAt;
        currentStatus.value = ch.status;
      } else if (preselectedSetId != null) {
        onSetSelected(preselectedSetId);
      }
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> reloadQuestionSets() async {
    try {
      questionSets.value = await _repo.fetchQuestionSets();
    } catch (_) {}
  }

  void onSetSelected(String? setId) {
    selectedSetId.value = setId;
    if (setId != null) {
      final match = questionSets.firstWhereOrNull((s) => s.id == setId);
      if (match != null) {
        selectedSubjectId.value = match.subjectId;
        if (titleCtrl.text.isEmpty) {
          titleCtrl.text = match.title;
        }
      }
    }
  }

  // ── Presets ──────────────────────────────────────────────────────────────

  void applyLiveNowPreset() {
    final now = DateTime.now();
    startsAt.value = now;
    endsAt.value = now.add(const Duration(hours: 12)); // default 12 hour live window
    SnackbarHelper.info('Preset applied', 'Round set to go live immediately for 12 hours.');
  }

  void applyTomorrowPreset() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    startsAt.value = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 8, 0);
    endsAt.value = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 20, 0);
    SnackbarHelper.info('Preset applied', 'Scheduled for tomorrow 08:00 to 20:00.');
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> saveAsDraft() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedSetId.value == null || selectedSubjectId.value == null) {
      SnackbarHelper.warning('Missing data', 'Please select a question set');
      return;
    }

    final durationMins = int.tryParse(durationMinutesCtrl.text.trim()) ?? 60;

    isSaving.value = true;
    try {
      await _repo.upsertChallenge({
        if (challengeId != null && challengeId!.isNotEmpty) 'id': challengeId,
        'subject_id': selectedSubjectId.value,
        'set_id': selectedSetId.value,
        'title': titleCtrl.text.trim(),
        'audience': selectedAudience.value,
        'duration_seconds': durationMins * 60,
        if (startsAt.value != null) 'starts_at': startsAt.value!.toIso8601String(),
        if (endsAt.value != null) 'ends_at': endsAt.value!.toIso8601String(),
        'status': 'draft',
      });

      SnackbarHelper.success('Saved', 'Challenge saved as draft');
      Get.back(result: true);
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> scheduleAndPublish() async {
    if (!formKey.currentState!.validate()) return;
    if (selectedSetId.value == null || selectedSubjectId.value == null) {
      SnackbarHelper.warning('Missing data', 'Please select a question set');
      return;
    }

    if (startsAt.value == null || endsAt.value == null) {
      SnackbarHelper.warning('Required', 'Please select both start time and end time');
      return;
    }

    if (endsAt.value!.isBefore(startsAt.value!)) {
      SnackbarHelper.warning('Invalid Time', 'End time must be after start time');
      return;
    }

    final durationMins = int.tryParse(durationMinutesCtrl.text.trim()) ?? 60;

    isSaving.value = true;
    try {
      final challenge = await _repo.upsertChallenge({
        if (challengeId != null && challengeId!.isNotEmpty) 'id': challengeId,
        'subject_id': selectedSubjectId.value,
        'set_id': selectedSetId.value,
        'title': titleCtrl.text.trim(),
        'audience': selectedAudience.value,
        'duration_seconds': durationMins * 60,
        'starts_at': startsAt.value!.toIso8601String(),
        'ends_at': endsAt.value!.toIso8601String(),
        'status': 'draft',
      });

      final publishedStatus = await _repo.publishChallenge(challenge.id);

      SnackbarHelper.success(
        'Published!',
        publishedStatus == 'live'
            ? 'Challenge is now LIVE for students nationwide!'
            : 'Challenge scheduled successfully! Pre-visibility countdown will appear 12h before start.',
      );
      Get.back(result: true);
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      isSaving.value = false;
    }
  }
}
