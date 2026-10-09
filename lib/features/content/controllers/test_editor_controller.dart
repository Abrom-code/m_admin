import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/content_repository.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class TestEditorController extends GetxController {
  TestEditorController({
    this.testId,
    required this.subjectId,
    this.initialType,
    this.initialGrade,
    this.initialChapterId,
  });

  final int? testId; // null = create new
  final int subjectId;
  final String? initialType;
  final int? initialGrade;
  final int? initialChapterId;

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
  final descriptionCtrl = TextEditingController();
  final isUntimed = false.obs;
  final isPremium = true.obs;
  final statusValue = 'draft'.obs;

  final formKey = GlobalKey<FormState>();

  static const validTypes = ['chapter', 'grade', 'entrance', 'model'];
  static const validStatuses = ['draft', 'verification', 'published', 'inactive', 'archived'];

  @override
  void onInit() {
    super.onInit();
    if (initialType != null && validTypes.contains(initialType)) {
      typeValue.value = initialType!;
    }
    if (initialGrade != null && initialGrade! > 0) {
      gradeCtrl.text = initialGrade.toString();
    }
    if (initialChapterId != null && initialChapterId! > 0) {
      selectedChapterId.value = initialChapterId;
    }
    _loadChapters();
    if (testId != null) _loadTest();
  }

  @override
  void onClose() {
    titleCtrl.dispose();
    gradeCtrl.dispose();
    timeCtrl.dispose();
    descriptionCtrl.dispose();
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
      selectedChapterId.value = AppHelperFunctions.toInt(data['chapter_id']);
      final time = AppHelperFunctions.toInt(data['time']) ?? -1;
      isUntimed.value = time == -1;
      timeCtrl.text = time == -1 ? '' : time.toString();
      descriptionCtrl.text = data['description']?.toString() ?? '';

      statusValue.value = data['status']?.toString() ?? 'draft';

      // Premium flag — default true when absent (matches student app default).
      final rawPremium = data['is_premium'];
      isPremium.value = rawPremium == null
          ? true
          : (rawPremium == true ||
              rawPremium == 1 ||
              rawPremium == 'true' ||
              rawPremium == '1');

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
        'description': descriptionCtrl.text.trim().isEmpty
            ? null
            : descriptionCtrl.text.trim(),
        'is_premium': isPremium.value,
        'status': statusValue.value,
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
      questions.removeWhere((q) => AppHelperFunctions.toInt(q['id']) == questionId);
      SnackbarHelper.success('Deleted', 'Question removed.');
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    }
  }
}
