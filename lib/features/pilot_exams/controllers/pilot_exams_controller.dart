import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/pilot_exams_repository.dart';
import 'package:m_admin/features/pilot_exams/models/admin_pilot_exam_model.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class PilotExamsController extends GetxController {
  static PilotExamsController get instance => Get.find();

  final PilotExamsRepository _repo = PilotExamsRepository();

  final exams = <AdminPilotExamModel>[].obs;
  final isLoading = false.obs;
  final error = RxnString();

  final selectedGrade = RxnInt();
  final statusFilter = RxnString(); // null = all, 'active', 'premium'
  final searchQuery = ''.obs;
  final searchController = TextEditingController();

  final isDeleting = <int, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadPilotExams();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadPilotExams() async {
    try {
      isLoading.value = true;
      error.value = null;

      final list = await _repo.fetchPilotExams(grade: selectedGrade.value);
      exams.assignAll(list);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  List<AdminPilotExamModel> get filteredExams {
    final query = searchQuery.value.trim().toLowerCase();

    return exams.where((exam) {
      if (selectedGrade.value != null && exam.grade != selectedGrade.value) {
        return false;
      }
      if (statusFilter.value == 'active' && !exam.isActive) {
        return false;
      }
      if (statusFilter.value == 'premium' && !exam.isPremium) {
        return false;
      }
      if (query.isNotEmpty) {
        final titleMatch = exam.title.toLowerCase().contains(query);
        final editionMatch = exam.edition.toLowerCase().contains(query);
        final descMatch = exam.description.toLowerCase().contains(query);
        return titleMatch || editionMatch || descMatch;
      }
      return true;
    }).toList();
  }

  Future<bool> deletePilotExam(AdminPilotExamModel exam) async {
    try {
      isDeleting[exam.id] = true;
      await _repo.deletePilotExam(exam.id);
      exams.removeWhere((e) => e.id == exam.id);
      SnackbarHelper.success('Deleted', 'Pilot Exam "${exam.title}" deleted.');
      return true;
    } catch (e) {
      SnackbarHelper.error('Delete failed', e.toString());
      return false;
    } finally {
      isDeleting.remove(exam.id);
    }
  }

  Future<void> toggleActive(AdminPilotExamModel exam) async {
    try {
      final newActive = !exam.isActive;
      final newStatus = newActive ? 'published' : 'draft';
      final updated = exam.copyWith(
        isActive: newActive,
        status: newStatus,
      );
      await _repo.upsertPilotExam(updated.toJson());
      final index = exams.indexWhere((e) => e.id == exam.id);
      if (index >= 0) {
        exams[index] = updated;
      }
      SnackbarHelper.success(
        'Updated',
        newActive
            ? 'Pilot Exam verified & published (live for students).'
            : 'Pilot Exam marked as draft (hidden from students).',
      );
    } catch (e) {
      SnackbarHelper.error('Update failed', e.toString());
    }
  }

  Future<void> togglePremium(AdminPilotExamModel exam) async {
    try {
      final updated = exam.copyWith(isPremium: !exam.isPremium);
      await _repo.upsertPilotExam(updated.toJson());
      final index = exams.indexWhere((e) => e.id == exam.id);
      if (index >= 0) {
        exams[index] = updated;
      }
      SnackbarHelper.success(
        'Updated',
        'Pilot Exam is now ${updated.isPremium ? "Premium" : "Free"}.',
      );
    } catch (e) {
      SnackbarHelper.error('Update failed', e.toString());
    }
  }

  void setGradeFilter(int? grade) {
    selectedGrade.value = grade;
    loadPilotExams();
  }

  void setStatusFilter(String? status) {
    statusFilter.value = status;
  }

  void clearFilters() {
    selectedGrade.value = null;
    statusFilter.value = null;
    searchQuery.value = '';
    loadPilotExams();
  }
}
