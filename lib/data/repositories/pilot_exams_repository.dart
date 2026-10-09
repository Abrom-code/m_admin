import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/features/pilot_exams/models/admin_pilot_exam_model.dart';
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
    try {
      final payload = Map<String, dynamic>.from(data);
      if (payload['id'] == null || payload['id'] == 0) {
        payload.remove('id');
      }

      final row = await _sb.from('pilot_exams').upsert(payload).select().single();
      return AdminPilotExamModel.fromJson(Map<String, dynamic>.from(row));
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
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Deletes a pilot exam and its associated subject configurations.
  Future<void> deletePilotExam(int id) async {
    try {
      await _sb.from('pilot_exam_subjects').delete().eq('pilot_exam_id', id);
      await _sb.from('pilot_exams').delete().eq('id', id);
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
      if (payload['id'] == null || payload['id'] == 0) {
        payload.remove('id');
      }

      final row = await _sb
          .from('pilot_exam_subjects')
          .upsert(payload)
          .select()
          .single();

      return AdminPilotExamSubjectModel.fromJson(
        Map<String, dynamic>.from(row),
      );
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Deletes a single subject configuration from a pilot exam.
  Future<void> deletePilotExamSubject(int id) async {
    try {
      await _sb.from('pilot_exam_subjects').delete().eq('id', id);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Fetches all subjects for dropdowns.
  Future<List<Map<String, dynamic>>> fetchSubjects() async {
    try {
      final rows = await _sb
          .from('subjects')
          .select('id, name')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Fetches tests for a subject to link a pilot exam subject to a test.
  Future<List<Map<String, dynamic>>> fetchTestsForSubject(int subjectId) async {
    try {
      final rows = await _sb
          .from('tests')
          .select('id, title, question_count, time')
          .eq('subject_id', subjectId)
          .order('title', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }
}
