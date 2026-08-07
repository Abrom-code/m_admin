import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/content_repository.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class TestEditorController extends GetxController {
  TestEditorController({this.testId, required this.subjectId});

  final int? testId; // null = create new
  final int subjectId;

  final _repo = ContentRepository();

  final isLoading = false.obs;
  final isSaving = false.obs;
  final questions = <Map<String, dynamic>>[].obs;
  final chapters = <Map<String, dynamic>>[].obs;

  // Form fields
  final titleCtrl = TextEditingController();
  final typeValue = 'chapter'.obs;
  final gradeCtrl = TextEditingController();
  final selectedChapterId = RxnInt();
  final timeCtrl = TextEditingController();
  final isUntimed = false.obs;

  final formKey = GlobalKey<FormState>();

  static const validTypes = ['chapter', 'grade', 'entrance', 'model'];

  @override
  void onInit() {
    super.onInit();
    _loadChapters();
    if (testId != null) _loadTest();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    gradeCtrl.dispose();
    timeCtrl.dispose();
    super.onClose();
  }

  Future<void> _loadChapters() async {
    try {
      final rows = await _repo.fetchChaptersForSubject(subjectId);
      chapters.value = rows;
    } catch (_) {}
  }

  /// Reloads test metadata and question list from Supabase.
  /// Called after a question is saved or deleted.
  Future<void> reload() => _loadTest();

  Future<void> _loadTest() async {
    try {
      isLoading.value = true;
      final data = await _repo.fetchTestDetail(testId!);
      titleCtrl.text = data['title']?.toString() ?? '';
      typeValue.value = data['type']?.toString() ?? 'chapter';
      gradeCtrl.text = data['grade']?.toString() ?? '';
      selectedChapterId.value = (data['chapter_id'] as num?)?.toInt();
      final time = (data['time'] as num?)?.toInt() ?? -1;
      isUntimed.value = time == -1;
      timeCtrl.text = time == -1 ? '' : time.toString();
      questions.value = await _repo.fetchQuestionsForTest(testId!);
    } catch (e) {
      SnackbarHelper.error('Load error', AppExceptionHandler.handle(e).message);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> saveTest() async {
    if (!formKey.currentState!.validate()) return;

    try {
      isSaving.value = true;

      final time = isUntimed.value
          ? -1
          : int.tryParse(timeCtrl.text.trim()) ?? -1;

      final data = <String, dynamic>{
        if (testId != null) 'id': testId,
        'subject_id': subjectId,
        'title': titleCtrl.text.trim(),
        'type': typeValue.value,
        'grade': int.tryParse(gradeCtrl.text.trim()),
        'chapter_id': typeValue.value == 'chapter'
            ? selectedChapterId.value
            : null,
        'time': time,
      };

      await _repo.upsertTest(data);
      SnackbarHelper.success('Saved', 'Test saved successfully.');
      Get.back(result: true);
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      isSaving.value = false;
    }
  }

  Future<void> deleteQuestion(int questionId) async {
    if (testId == null) return;
    try {
      await _repo.deleteQuestion(questionId, testId!);
      questions.removeWhere((q) => (q['id'] as num?)?.toInt() == questionId);
      SnackbarHelper.success('Deleted', 'Question removed.');
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    }
  }
}
