import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/features/pilot_exams/models/admin_pilot_exam_model.dart';
import 'package:m_admin/utils/exceptions/app_failure_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

class PilotExamsRepository {
  final _sb = Supabase.instance.client;

  /// Fetches all pilot exams, optionally filtered by [grade].
  Future<List<AdminPilotExamModel>> fetchPilotExams({int? grade}) async {
    try {
      var query = _sb.from('pilot_exams').select('*, pilot_exam_subjects(*)');

      if (grade != null && grade > 0) {
        query = query.eq('grade', grade);
      }

      final rows = await query.order('id', ascending: true);

      return (rows as List)
          .map((r) => AdminPilotExamModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      // Fallback query if joined foreign key syntax differs
      try {
        var query = _sb.from('pilot_exams').select();
        if (grade != null && grade > 0) {
          query = query.eq('grade', grade);
        }
        final examsRows = await query.order('id', ascending: true);

        final subjectsRows = await _sb
            .from('pilot_exam_subjects')
            .select()
            .order('order_index', ascending: true);

        final subjectsByExam = <int, List<AdminPilotExamSubjectModel>>{};
        for (final s in subjectsRows as List) {
          final model = AdminPilotExamSubjectModel.fromJson(
            Map<String, dynamic>.from(s),
          );
          subjectsByExam.putIfAbsent(model.pilotExamId, () => []).add(model);
        }

        return (examsRows as List).map((r) {
          final id = (r['id'] as num?)?.toInt() ?? 0;
          return AdminPilotExamModel.fromJson(
            Map<String, dynamic>.from(r),
            subjects: subjectsByExam[id] ?? [],
          );
        }).toList();
      } catch (fallbackError) {
        throw AppExceptionHandler.handle(fallbackError);
      }
    }
  }

  /// Inserts or updates a pilot exam.
  Future<AdminPilotExamModel> upsertPilotExam(Map<String, dynamic> data) async {
    final payload = Map<String, dynamic>.from(data);
    final id = (payload['id'] as num?)?.toInt();
    if (id == null || id <= 0) {
      payload.remove('id');
    }

    try {
      final Map<String, dynamic> row;
      if (id != null && id > 0) {
        row = await _sb.from('pilot_exams').upsert(payload).select().single();
      } else {
        row = await _sb.from('pilot_exams').insert(payload).select().single();
      }
      return AdminPilotExamModel.fromJson(Map<String, dynamic>.from(row));
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const AppFailure(
          title: 'Permission Denied (RLS 42501)',
          message: 'The database Row-Level Security policy blocked modifying pilot exams. Please ensure your admin account is registered in the admins table.',
          code: '42501',
        );
      }
      // If the 'grade' column is not yet migrated in the DB table, retry without it
      final isGradeError = e.message.toLowerCase().contains('grade') ||
          (e.details?.toString().toLowerCase().contains('grade') ?? false);
      if (isGradeError && payload.containsKey('grade')) {
        payload.remove('grade');
        final Map<String, dynamic> row;
        if (id != null && id > 0) {
          row = await _sb.from('pilot_exams').upsert(payload).select().single();
        } else {
          row = await _sb.from('pilot_exams').insert(payload).select().single();
        }
        return AdminPilotExamModel.fromJson(Map<String, dynamic>.from(row));
      }
      throw AppExceptionHandler.handle(e);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Updates the status and active flag of a pilot exam.
  Future<void> updatePilotExamStatus(int id, String status) async {
    try {
      final s = status.trim().toLowerCase();
      final isAct = s == 'published' || s == 'active';
      await _sb.from('pilot_exams').update({
        'status': s,
        'is_active': isAct,
      }).eq('id', id);
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const AppFailure(
          title: 'Permission Denied (RLS 42501)',
          message: 'The database Row-Level Security policy blocked updating the pilot exam status.',
          code: '42501',
        );
      }
      throw AppExceptionHandler.handle(e);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Deletes a pilot exam and its associated subject configurations.
  Future<void> deletePilotExam(int id) async {
    try {
      await _sb.from('pilot_exam_subjects').delete().eq('pilot_exam_id', id);
      await _sb.from('pilot_exams').delete().eq('id', id);
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const AppFailure(
          title: 'Permission Denied (RLS 42501)',
          message: 'The database Row-Level Security policy blocked deleting the pilot exam.',
          code: '42501',
        );
      }
      throw AppExceptionHandler.handle(e);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Fetches subjects linked to a specific pilot exam.
  Future<List<AdminPilotExamSubjectModel>> fetchPilotExamSubjects(
    int pilotExamId,
  ) async {
    try {
      final rows = await _sb
          .from('pilot_exam_subjects')
          .select('*, subjects(name)')
          .eq('pilot_exam_id', pilotExamId)
          .order('order_index', ascending: true);

      return (rows as List)
          .map((r) =>
              AdminPilotExamSubjectModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      // Fallback without join
      try {
        final rows = await _sb
            .from('pilot_exam_subjects')
            .select()
            .eq('pilot_exam_id', pilotExamId)
            .order('order_index', ascending: true);

        return (rows as List)
            .map((r) => AdminPilotExamSubjectModel.fromJson(
                Map<String, dynamic>.from(r)))
            .toList();
      } catch (fallbackError) {
        throw AppExceptionHandler.handle(fallbackError);
      }
    }
  }

  /// Inserts or updates a pilot exam subject configuration.
  Future<AdminPilotExamSubjectModel> upsertPilotExamSubject(
    Map<String, dynamic> data,
  ) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      final id = (payload['id'] as num?)?.toInt();
      if (id == null || id <= 0) {
        payload.remove('id');
      }

      final row = await _sb
          .from('pilot_exam_subjects')
          .upsert(payload, onConflict: 'pilot_exam_id, subject_id, stream')
          .select()
          .single();

      return AdminPilotExamSubjectModel.fromJson(
        Map<String, dynamic>.from(row),
      );
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const AppFailure(
          title: 'Permission Denied (RLS 42501)',
          message: 'The database Row-Level Security policy blocked modifying pilot exam subjects.',
          code: '42501',
        );
      }
      throw AppExceptionHandler.handle(e);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Synchronizes the subject list for a pilot exam by removing stale subjects
  /// and upserting the current configured subjects.
  Future<void> syncPilotExamSubjects({
    required int pilotExamId,
    required List<Map<String, dynamic>> subjectsData,
  }) async {
    try {
      // 1. Fetch current subject records from DB
      final existingRows = await _sb
          .from('pilot_exam_subjects')
          .select('id, subject_id, stream')
          .eq('pilot_exam_id', pilotExamId);

      final activeKeys = <String>{};
      for (final s in subjectsData) {
        final subId = s['subject_id'];
        final stream = (s['stream'] ?? '').toString().toLowerCase();
        activeKeys.add('$subId-$stream');
      }

      // Delete subjects that were removed in the editor
      for (final row in existingRows as List) {
        final rowId = (row['id'] as num).toInt();
        final subId = row['subject_id'];
        final stream = (row['stream'] ?? '').toString().toLowerCase();
        if (!activeKeys.contains('$subId-$stream')) {
          await _sb.from('pilot_exam_subjects').delete().eq('id', rowId);
        }
      }

      // 2. Upsert each subject
      for (var i = 0; i < subjectsData.length; i++) {
        final s = Map<String, dynamic>.from(subjectsData[i]);
        s['pilot_exam_id'] = pilotExamId;
        s['order_index'] = i + 1;
        await upsertPilotExamSubject(s);
      }
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const AppFailure(
          title: 'Permission Denied (RLS 42501)',
          message: 'The database Row-Level Security policy blocked syncing pilot exam subjects.',
          code: '42501',
        );
      }
      throw AppExceptionHandler.handle(e);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Deletes a single subject configuration from a pilot exam.
  Future<void> deletePilotExamSubject(int id) async {
    try {
      await _sb.from('pilot_exam_subjects').delete().eq('id', id);
    } on PostgrestException catch (e) {
      if (e.code == '42501') {
        throw const AppFailure(
          title: 'Permission Denied (RLS 42501)',
          message: 'The database Row-Level Security policy blocked deleting the pilot exam subject.',
          code: '42501',
        );
      }
      throw AppExceptionHandler.handle(e);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Fetches all subjects with stream flags for dropdowns & selection.
  Future<List<Map<String, dynamic>>> fetchSubjects() async {
    try {
      final rows = await _sb
          .from('subjects')
          .select('id, name, is_natural, is_common')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      try {
        final fallbackRows = await _sb
            .from('subjects')
            .select('id, name')
            .order('name', ascending: true);
        return List<Map<String, dynamic>>.from(fallbackRows);
      } catch (err) {
        throw AppExceptionHandler.handle(err);
      }
    }
  }

  /// Fetches tests for a subject to link a pilot exam subject to a test.
  Future<List<Map<String, dynamic>>> fetchTestsForSubject(int subjectId) async {
    try {
      final rows = await _sb
          .from('tests')
          .select('id, title, question_count, time')
          .eq('subject_id', subjectId)
          .order('id', ascending: false);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }

  /// Fetches a specific test by its ID across the tests database.
  Future<Map<String, dynamic>?> fetchTestById(int testId) async {
    try {
      final row = await _sb
          .from('tests')
          .select('id, title, question_count, time, subject_id')
          .eq('id', testId)
          .maybeSingle();
      return row != null ? Map<String, dynamic>.from(row) : null;
    } catch (_) {
      return null;
    }
  }
}
