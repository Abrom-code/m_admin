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

  final isDeleting = <int, bool>{}.obs;

  @override
  void onInit() {
    super.onInit();
    loadSubjects();
    loadNotes();
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

    return notes.where((note) {
      if (selectedGrade.value != null && note.grade != selectedGrade.value) {
        return false;
      }
      if (selectedSubjectId.value != null && note.subjectId != selectedSubjectId.value) {
        return false;
      }
      if (premiumFilter.value != null && note.isPremium != premiumFilter.value) {
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
      isDeleting.remove(note.id);
    }
  }

  Future<void> togglePremium(AdminNoteModel note) async {
    try {
      final updated = note.copyWith(isPremium: !note.isPremium);
      await _repo.upsertNote(updated.toJson());
      final index = notes.indexWhere((n) => n.id == note.id);
      if (index >= 0) {
        notes[index] = updated;
      }
      SnackbarHelper.success(
        'Updated',
        'Note is now ${updated.isPremium ? "Premium" : "Free"}.',
      );
    } catch (e) {
      SnackbarHelper.error('Update failed', e.toString());
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
    searchQuery.value = '';
  }
}
