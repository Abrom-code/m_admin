import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/features/content/models/question_report_admin_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

class QuestionReportsRepository {
  final SupabaseClient _sb = Supabase.instance.client;

  Future<List<QuestionReportAdminModel>> fetchReports({
    String? status,
    String? reason,
    String? search,
    int page = 0,
    int pageSize = 30,
  }) async {
    try {
      var query = _sb.from('question_reports').select('''
        id, user_id, question_id, challenge_question_id, test_id,
        reason, comment, status, admin_notes, created_at, resolved_at, resolved_by,
        users(first_name, last_name, full_name, email),
        questions(
          id, test_id, question_text, choice_a, choice_b, choice_c, choice_d,
          correct_choice, explanation,
          tests(id, title, subject_id, subjects(id, name))
        ),
        challenge_questions(
          id, question_text, choice_a, choice_b, choice_c, choice_d,
          correct_choice, explanation, challenge_id
        )
      ''');

      if (status != null && status.isNotEmpty) {
        query = query.eq('status', status);
      }
      if (reason != null && reason.isNotEmpty) {
        query = query.eq('reason', reason);
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(page * pageSize, (page + 1) * pageSize - 1)
          .timeout(const Duration(seconds: 20));

      var list = (rows as List)
          .map((r) => QuestionReportAdminModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim().toLowerCase();
        list = list.where((r) {
          return r.questionText.toLowerCase().contains(term) ||
              r.userName.toLowerCase().contains(term) ||
              r.userEmail.toLowerCase().contains(term) ||
              (r.comment?.toLowerCase().contains(term) ?? false) ||
              (r.testTitle?.toLowerCase().contains(term) ?? false);
        }).toList();
      }

      return list;
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<int> countPendingReports() async {
    try {
      final res = await _sb
          .from('question_reports')
          .select('id')
          .eq('status', 'pending')
          .count(CountOption.exact)
          .timeout(const Duration(seconds: 15));
      return res.count;
    } catch (_) {
      return 0;
    }
  }

  Future<void> updateStatus(
    String reportId, {
    required String status,
    String? adminNotes,
  }) async {
    try {
      final user = _sb.auth.currentUser;
      await _sb
          .from('question_reports')
          .update({
            'status': status,
            if (adminNotes != null) 'admin_notes': adminNotes.trim(),
            'resolved_at': DateTime.now().toIso8601String(),
            'resolved_by': user?.id,
          })
          .eq('id', reportId)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }
}
