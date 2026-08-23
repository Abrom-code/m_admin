import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
import 'package:m_admin/features/challenges/models/challenge_question_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class ChallengeEditorController extends GetxController {
  ChallengeEditorController({this.challengeId, this.initialSubjectId});

  final String? challengeId;
  final int? initialSubjectId;

  final _repo = ChallengeRepository();

  final isLoading = false.obs;
  final isSaving = false.obs;

  // Challenge Details
  final currentChallengeId = RxnString();
  final currentSetId = RxnString();
  final titleCtrl = TextEditingController();
  final durationCtrl = TextEditingController(text: '40');
  final selectedSubjectId = RxnInt();
  final audience = 'both'.obs; // 'natural', 'social', 'both'
  final status = 'draft'.obs;

  final startsAt = Rxn<DateTime>();
  final endsAt = Rxn<DateTime>();

  final subjects = <Map<String, dynamic>>[].obs;
  final questions = <ChallengeQuestionModel>[].obs;
  final formKey = GlobalKey<FormState>();

  bool get isEditingExisting => currentChallengeId.value != null && currentChallengeId.value!.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    currentChallengeId.value = challengeId;
    selectedSubjectId.value = initialSubjectId;

    // Default dates: starts in 1 hour, ends in 13 hours
    final now = DateTime.now();
    startsAt.value = now.add(const Duration(hours: 1));
    endsAt.value = now.add(const Duration(hours: 13));

    _loadData();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    durationCtrl.dispose();
    super.onClose();
  }

  Future<void> _loadData() async {
    isLoading.value = true;
    try {
      subjects.value = await _repo.fetchSubjects();

      if (challengeId != null && challengeId!.isNotEmpty) {
        final c = await _repo.fetchChallengeDetail(challengeId!);
        currentChallengeId.value = c.id;
        currentSetId.value = c.setId;
        titleCtrl.text = c.title;
        selectedSubjectId.value = c.subjectId;
        audience.value = c.audience;
        durationCtrl.text = '${c.durationMinutes}';
        status.value = c.status;
        startsAt.value = c.startsAt;
        endsAt.value = c.endsAt;

        if (c.setId.isNotEmpty) {
          questions.value = await _repo.fetchQuestionsForSet(c.setId);
        }
      }
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> reloadQuestions() async {
    if (currentSetId.value == null) return;
    try {
      questions.value = await _repo.fetchQuestionsForSet(currentSetId.value!);
    } catch (_) {}
  }

  Future<String?> saveChallenge({bool isPublish = false}) async {
    if (!formKey.currentState!.validate()) return null;
    if (selectedSubjectId.value == null) {
      SnackbarHelper.warning('Subject Required', 'Please choose a subject for this challenge');
      return null;
    }

    final durationMins = int.tryParse(durationCtrl.text.trim()) ?? 40;
    if (durationMins <= 0) {
      SnackbarHelper.warning('Invalid Duration', 'Duration must be greater than 0 minutes');
      return null;
    }

    if (isPublish) {
      if (startsAt.value == null || endsAt.value == null) {
        SnackbarHelper.warning('Dates Required', 'Please set both Start and End date/time');
        return null;
      }
      if (endsAt.value!.isBefore(startsAt.value!)) {
        SnackbarHelper.warning('Invalid Time Window', 'End date must be after start date');
        return null;
      }
      if (questions.isEmpty) {
        SnackbarHelper.warning('Questions Required', 'Please add at least 1 question before publishing');
        return null;
      }
    }

    isSaving.value = true;
    try {
      // 1. Ensure question set exists
      final setTitle = titleCtrl.text.trim();
      final savedSet = await _repo.upsertQuestionSet(
        id: currentSetId.value,
        subjectId: selectedSubjectId.value!,
        title: setTitle,
      );
      currentSetId.value = savedSet.id;

      // 2. Upsert challenge record
      final payload = <String, dynamic>{
        if (currentChallengeId.value != null && currentChallengeId.value!.isNotEmpty)
          'id': currentChallengeId.value,
        'set_id': savedSet.id,
        'subject_id': selectedSubjectId.value!,
        'title': setTitle,
        'audience': audience.value,
        'duration_seconds': durationMins * 60,
        'status': isPublish ? 'scheduled' : (status.value.isEmpty ? 'draft' : status.value),
        if (startsAt.value != null) 'starts_at': startsAt.value!.toUtc().toIso8601String(),
        if (endsAt.value != null) 'ends_at': endsAt.value!.toUtc().toIso8601String(),
      };

      final savedChallenge = await _repo.upsertChallenge(payload);
      currentChallengeId.value = savedChallenge.id;
      status.value = savedChallenge.status;

      if (isPublish) {
        final publishState = await _repo.publishChallenge(savedChallenge.id);
        status.value = publishState;
        SnackbarHelper.success('Published!', 'Challenge has been successfully ${publishState == 'live' ? 'launched LIVE' : 'scheduled'}!');
      } else {
        SnackbarHelper.success('Saved', 'Challenge saved as draft. You can add more questions or publish when ready.');
      }

      return savedChallenge.id;
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteQuestion(String questionId) async {
    try {
      await _repo.deleteQuestion(questionId);
      questions.removeWhere((q) => q.id == questionId);
      SnackbarHelper.success('Deleted', 'Question removed from challenge');
    } catch (e) {
      SnackbarHelper.error('Error', AppExceptionHandler.handle(e).message);
    }
  }
}
