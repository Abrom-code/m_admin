import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/challenge_repository.dart';
import 'package:m_admin/features/challenges/models/challenge_question_model.dart';
import 'package:m_admin/features/challenges/screens/challenge_scheduler_screen.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class ChallengeEditorController extends GetxController {
  ChallengeEditorController({String? setId, required this.subjectId}) {
    currentSetId.value = setId;
  }

  final int subjectId;
  final currentSetId = RxnString();

  final _repo = ChallengeRepository();

  final isLoading = false.obs;
  final isSaving = false.obs;

  final titleCtrl = TextEditingController();
  final selectedSubjectId = RxnInt();
  final subjects = <Map<String, dynamic>>[].obs;

  final questions = <ChallengeQuestionModel>[].obs;
  final formKey = GlobalKey<FormState>();

  bool get isSetSaved => currentSetId.value != null && currentSetId.value!.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    selectedSubjectId.value = subjectId;
    _loadInitialData();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    super.onClose();
  }

  Future<void> _loadInitialData() async {
    isLoading.value = true;
    try {
      subjects.value = await _repo.fetchSubjects();
      if (isSetSaved) {
        final setDetail = await _repo.fetchQuestionSetDetail(currentSetId.value!);
        titleCtrl.text = setDetail.title;
        selectedSubjectId.value = setDetail.subjectId;
        questions.value = await _repo.fetchQuestionsForSet(currentSetId.value!);
      }
    } catch (e) {
      SnackbarHelper.error('Load error', AppExceptionHandler.handle(e).message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> reloadQuestions() async {
    if (!isSetSaved) return;
    try {
      questions.value = await _repo.fetchQuestionsForSet(currentSetId.value!);
    } catch (_) {}
  }

  Future<String?> saveQuestionSet({bool showFeedback = true}) async {
    if (!formKey.currentState!.validate()) return null;
    if (selectedSubjectId.value == null) {
      SnackbarHelper.warning('Required', 'Please select a subject');
      return null;
    }

    try {
      isSaving.value = true;
      final saved = await _repo.upsertQuestionSet(
        id: currentSetId.value,
        subjectId: selectedSubjectId.value!,
        title: titleCtrl.text.trim(),
      );
      currentSetId.value = saved.id;
      if (showFeedback) {
        SnackbarHelper.success('Saved', 'Question set saved successfully. You can now add questions below.');
      }
      return saved.id;
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> saveAndScheduleRound() async {
    final savedId = await saveQuestionSet(showFeedback: false);
    if (savedId == null) return;

    if (questions.isEmpty) {
      SnackbarHelper.warning(
        'Empty Set',
        'Please add at least 1 question to this set before scheduling a live round.',
      );
      return;
    }

    Get.to(
      () => ChallengeSchedulerScreen(
        preselectedSetId: savedId,
        preselectedSubjectId: selectedSubjectId.value,
      ),
    );
  }

  Future<void> deleteQuestion(String questionId) async {
    try {
      await _repo.deleteQuestion(questionId);
      questions.removeWhere((q) => q.id == questionId);
      SnackbarHelper.success('Deleted', 'Question removed');
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    }
  }
}
