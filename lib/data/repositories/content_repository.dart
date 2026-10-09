import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class ContentRepository {
  final _sb = Supabase.instance.client;

  // â”€â”€ Tests â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<Map<String, dynamic>>> fetchTestsForSubject(
    int subjectId, {
    String? type,
  }) async {
    try {
      var q = _sb
          .from('tests')
          .select('id, title, type, grade, chapter_id, time, question_count, '
              'is_premium, description, status, created_at, updated_at')
          .eq('subject_id', subjectId);

      if (type != null && type.isNotEmpty) {
        q = q.eq('type', type);
      }

      final rows = await q.order('created_at', ascending: false);
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<Map<String, dynamic>> fetchTestDetail(int testId) async {
    try {
      final row = await _sb
          .from('tests')
          .select('*, subjects!inner(name)')
          .eq('id', testId)
          .maybeSingle();

      if (row == null) {
        throw AppExceptionHandler.handle(
          Exception('Test #$testId not found'),
        );
      }

      return Map<String, dynamic>.from(row);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> upsertTest(Map<String, dynamic> data) async {
    try {
      // Validate type.
      final type = data['type']?.toString();
      if (type == null ||
          !['chapter', 'grade', 'entrance', 'model'].contains(type)) {
        throw Exception(
          'Invalid test type. Must be chapter|grade|entrance|model.',
        );
      }

      // Validate time: -1 means untimed, never write 0.
      if (data['time'] == 0) data['time'] = -1;

      // Default status to draft if omitted (verification flow).
      if (!data.containsKey('status') || data['status'] == null) {
        data['status'] = 'draft';
      }

      // Ensure updated_at is bumped (critical for sync).
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await _sb.from('tests').upsert(data);

      // Recompute question_count after every mutation.
      if (data['id'] != null) {
        await recountTestQuestions(AppHelperFunctions.toInt(data['id']) ?? 0);
      }
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> updateTestStatus(int testId, String status) async {
    try {
      await _sb.from('tests').update({
        'status': status,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', testId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> deleteTest(int testId) async {
    try {
      // Questions cascade-delete via FK, so deleting a test destroys
      // its questions. Warn the user explicitly before calling this.
      await _sb.from('tests').delete().eq('id', testId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  // â”€â”€ Questions â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<Map<String, dynamic>>> fetchQuestionsForTest(int testId) async {
    try {
      final rows = await _sb
          .from('questions')
          .select('*, question_sections(title)')
          .eq('test_id', testId)
          .order('question_order');

      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<Map<String, dynamic>> fetchQuestionDetail(int questionId) async {
    try {
      final row = await _sb
          .from('questions')
          .select('*, question_sections(title), passages(content, title)')
          .eq('id', questionId)
          .maybeSingle();

      if (row == null) {
        throw AppExceptionHandler.handle(
          Exception('Question #$questionId not found'),
        );
      }

      return Map<String, dynamic>.from(row);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> upsertQuestion(Map<String, dynamic> data) async {
    try {
      // Validate options: must be a JSON array of 2-6 strings.
      final options = data['options'];
      if (options is! List || options.length < 2 || options.length > 6) {
        throw Exception('Options must be a JSON array of 2-6 strings.');
      }

      // Validate correct_option_index: 0-based, must be < options.length.
      final correctIdx = data['correct_option_index'];
      if (correctIdx is! int || correctIdx < 0 || correctIdx >= options.length) {
        throw Exception(
          'correct_option_index must be 0-based and < options.length.',
        );
      }

      // Ensure updated_at is bumped (critical for sync).
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();

      await _sb.from('questions').upsert(data);

      // Recompute test question_count.
      if (data['test_id'] != null) {
        await recountTestQuestions(AppHelperFunctions.toInt(data['test_id']) ?? 0);
      }
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> deleteQuestion(int questionId, int testId) async {
    try {
      await _sb.from('questions').delete().eq('id', questionId);
      await recountTestQuestions(testId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> reorderQuestions(int testId, List<int> orderedIds) async {
    try {
      for (int i = 0; i < orderedIds.length; i++) {
        await _sb
            .from('questions')
            .update({'question_order': i + 1})
            .eq('id', orderedIds[i]);
      }
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Recompute and write the question_count for a test.
  /// Critical: the student UI trusts this value.
  Future<void> recountTestQuestions(int testId) async {
    try {
      final result = await _sb
          .from('questions')
          .select('id')
          .eq('test_id', testId)
          .count(CountOption.exact);

      await _sb
          .from('tests')
          .update({
            'question_count': result.count,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', testId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  // â”€â”€ Subjects & Chapters â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<Map<String, dynamic>>> fetchSubjects() async {
    try {
      final rows = await _sb
          .from('subjects')
          .select('id, name, is_natural, is_common')
          .order('name');

      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Creates or updates a subject. Bumps updated_at so the student app's
  /// delta sync picks up the change on the next background refresh.
  Future<void> upsertSubject(Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _sb.from('subjects').upsert(data);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> deleteSubject(int subjectId) async {
    try {
      // Tests and questions cascade-delete via FK if set up; warn the caller.
      await _sb.from('subjects').delete().eq('id', subjectId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<List<Map<String, dynamic>>> fetchChaptersForSubject(
    int subjectId, {
    int? grade,
  }) async {
    try {
      var query = _sb.from('chapters').select().eq('subject_id', subjectId);
      if (grade != null && grade > 0) {
        query = query.eq('grade', grade);
      }
      final rows = await query
          .order('grade', ascending: true)
          .order('chapter_number', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<Map<String, dynamic>> upsertChapter(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      if (payload['id'] == null || payload['id'] == 0) {
        payload.remove('id');
      }
      final row = await _sb.from('chapters').upsert(payload).select().single();
      return Map<String, dynamic>.from(row);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> deleteChapter(int chapterId) async {
    try {
      // Null out chapter_id on any tests that reference this chapter so
      // deleting the chapter row doesn't break the student's chapter filter.
      await _sb
          .from('tests')
          .update({'chapter_id': null})
          .eq('chapter_id', chapterId);
      await _sb.from('chapters').delete().eq('id', chapterId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  // â”€â”€ Question sections â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<Map<String, dynamic>>> fetchQuestionSections() async {
    try {
      final rows = await _sb
          .from('question_sections')
          .select('id, title')
          .order('title');
      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> upsertQuestionSection(Map<String, dynamic> data) async {
    try {
      await _sb.from('question_sections').upsert(data);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> deleteQuestionSection(int sectionId) async {
    try {
      // Detach questions from this section so the student join returns null
      // gracefully instead of throwing a FK violation.
      await _sb
          .from('questions')
          .update({'section_id': null, 'section_title': null})
          .eq('section_id', sectionId);
      await _sb.from('question_sections').delete().eq('id', sectionId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  // â”€â”€ Passages â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€

  Future<List<Map<String, dynamic>>> fetchPassages() async {
    try {
      final rows = await _sb
          .from('passages')
          .select('id, title, content, updated_at')
          .order('updated_at', ascending: false);

      return rows.map((r) => Map<String, dynamic>.from(r)).toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> upsertPassage(Map<String, dynamic> data) async {
    try {
      data['updated_at'] = DateTime.now().toUtc().toIso8601String();
      await _sb.from('passages').upsert(data);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> deletePassage(int passageId) async {
    try {
      // Check if referenced by any question first.
      final refs = await _sb
          .from('questions')
          .select('id')
          .eq('passage_id', passageId)
          .limit(1);

      if (refs.isNotEmpty) {
        throw Exception(
          'Cannot delete passage â€” it is referenced by questions.',
        );
      }

      await _sb.from('passages').delete().eq('id', passageId);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

}
