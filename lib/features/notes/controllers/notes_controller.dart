import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/notes_repository.dart';
import 'package:m_admin/features/notes/models/admin_note_model.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class NotesController extends GetxController {
  static NotesController get instance => Get.find();

  final NotesRepository _repo = NotesRepository();

  final notes = <AdminNoteModel>[].obs;
  final subjects = <Map<String, dynamic>>[].obs;

  final isLoading = false.obs;
  final error = RxnString();

  final selectedGrade = RxnInt();
  final selectedSubjectId = RxnInt();
  final premiumFilter = RxnBool();
  final searchQuery = ''.obs;
  final searchController = TextEditingController();

  /// Sort Options:
  /// - 'default': DB order (grade, chapter, order)
  /// - 'urgency': Needs Review (high student votes, low rating value first)
  /// - 'lowest_rating': Lowest average rating first
  /// - 'highest_rating': Highest average rating first
  /// - 'most_rated': Most rated by students first
  final sortOption = 'default'.obs;

  /// Rating Filter:
  /// - null: All notes
  /// - 'needs_attention': Notes with high reviews but low score (<3.0 / <3.5)
  /// - 'rated': Only notes with at least one rating
  /// - 'unrated': Notes without any ratings yet
  final ratingFilter = RxnString();

  final isDeleting = <int, bool>{}.obs;
  final isUpdatingPremium = <int, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadSubjects();
    loadNotes();
  }

  @override
  void onClose() {
    searchController.dispose();
    super.onClose();
  }

  Future<void> loadSubjects() async {
    try {
      final list = await _repo.fetchSubjects();
      subjects.assignAll(list);
    } catch (_) {}
  }

  Future<void> loadNotes() async {
    try {
      isLoading.value = true;
      error.value = null;

      final list = await _repo.fetchNotes(
        subjectId: selectedSubjectId.value,
        grade: selectedGrade.value,
      );
      notes.assignAll(list);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  List<AdminNoteModel> get filteredNotes {
    final query = searchQuery.value.trim().toLowerCase();

    final list = notes.where((note) {
      if (selectedGrade.value != null && note.grade != selectedGrade.value) {
        return false;
      }
      if (selectedSubjectId.value != null && note.subjectId != selectedSubjectId.value) {
        return false;
      }
      if (premiumFilter.value != null && note.isPremium != premiumFilter.value) {
        return false;
      }
      if (ratingFilter.value == 'needs_attention' && !note.isNeedsAttention) {
        return false;
      }
      if (ratingFilter.value == 'rated' && !note.hasRatings) {
        return false;
      }
      if (ratingFilter.value == 'unrated' && note.hasRatings) {
        return false;
      }
      if (query.isNotEmpty) {
        final titleMatch = note.title.toLowerCase().contains(query);
        final descMatch = note.description?.toLowerCase().contains(query) ?? false;
        final subjectMatch = note.subjectName?.toLowerCase().contains(query) ?? false;
        return titleMatch || descMatch || subjectMatch;
      }
      return true;
    }).toList();

    switch (sortOption.value) {
      case 'urgency':
        // High students rated it but rated value is small -> highest urgency score first!
        list.sort((a, b) => b.attentionUrgencyScore.compareTo(a.attentionUrgencyScore));
        break;
      case 'lowest_rating':
        // Lowest average rating first (only rated notes first, unrated at the end)
        list.sort((a, b) {
          if (a.hasRatings && !b.hasRatings) return -1;
          if (!a.hasRatings && b.hasRatings) return 1;
          if (!a.hasRatings && !b.hasRatings) return 0;
          return a.averageRating.compareTo(b.averageRating);
        });
        break;
      case 'highest_rating':
        list.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        break;
      case 'most_rated':
        list.sort((a, b) => b.ratingCount.compareTo(a.ratingCount));
        break;
      default:
        // Default DB sort
        break;
    }

    return list;
  }

  /// Groups notes by subject name (or "Subject #id" if unnamed)
  Map<String, List<AdminNoteModel>> get notesGroupedBySubject {
    final map = <String, List<AdminNoteModel>>{};
    for (final note in filteredNotes) {
      final key = note.subjectName ??
          (subjects.firstWhereOrNull((s) => s['id'] == note.subjectId)?['name'] as String?) ??
          'Subject #${note.subjectId}';
      map.putIfAbsent(key, () => []).add(note);
    }
    return map;
  }

  // Summary Metrics
  int get needsAttentionCount => notes.where((n) => n.isNeedsAttention).length;
  int get totalRatedNotesCount => notes.where((n) => n.hasRatings).length;
  int get totalStudentReviewsCount => notes.fold<int>(0, (sum, n) => sum + n.ratingCount);

  void setSortOption(String sort) {
    sortOption.value = sort;
  }

  void setRatingFilter(String? filter) {
    ratingFilter.value = filter;
  }

  Future<bool> deleteNote(AdminNoteModel note) async {
    try {
      isDeleting[note.id] = true;
      await _repo.deleteNote(note.id, fileKey: note.fileKey);
      notes.removeWhere((n) => n.id == note.id);
      SnackbarHelper.success('Deleted', 'Note "${note.title}" removed.');
      return true;
    } catch (e) {
      SnackbarHelper.error('Delete failed', e.toString());
      return false;
    } finally {
      isDeleting[note.id] = false;
    }
  }

  Future<bool> togglePremium(AdminNoteModel note) async {
    final target = !note.isPremium;
    try {
      isUpdatingPremium[note.id] = true;
      await _repo.updatePremium(note.id, target);

      final idx = notes.indexWhere((n) => n.id == note.id);
      if (idx != -1) {
        notes[idx] = note.copyWith(isPremium: target);
      }
      SnackbarHelper.success(
        'Updated',
        'Note "${note.title}" is now ${target ? "Premium" : "Free"}.',
      );
      return true;
    } catch (e) {
      SnackbarHelper.error('Update failed', e.toString());
      return false;
    } finally {
      isUpdatingPremium[note.id] = false;
    }
  }

  void setGradeFilter(int? grade) {
    selectedGrade.value = grade;
  }

  void setSubjectFilter(int? subjectId) {
    selectedSubjectId.value = subjectId;
  }

  void setPremiumFilter(bool? isPremium) {
    premiumFilter.value = isPremium;
  }

  void clearFilters() {
    selectedGrade.value = null;
    selectedSubjectId.value = null;
    premiumFilter.value = null;
    ratingFilter.value = null;
    sortOption.value = 'default';
    searchQuery.value = '';
  }
}
