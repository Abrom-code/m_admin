import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/features/content/models/question_report_admin_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';

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
          id, test_id, subject_id, grade, chapter_id, question_order, image_url, explanation_image_url,
          question_text, options, correct_option_index, explanation_en, explanation_am,
          tests(id, title, type, grade, chapter_id, subject_id, subjects(id, name))
        ),
        challenge_questions(
          id, question_text, choices, correct_choice, explanation, explanation_en, explanation_am, challenge_id, image_url
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

      // Batch enrich with chapter metadata (number & title)
      final chapterIds = list
          .map((r) => r.chapterId)
          .whereType<int>()
          .where((id) => id > 0)
          .toSet();

      if (chapterIds.isNotEmpty) {
        try {
          final chapterRows = await _sb
              .from('chapters')
              .select('id, chapter_number, title, grade')
              .inFilter('id', chapterIds.toList())
              .timeout(const Duration(seconds: 15));

          final Map<int, Map<String, dynamic>> chapterMap = {
            for (final ch in (chapterRows as List))
              AppHelperFunctions.toInt(ch['id']) ?? 0: Map<String, dynamic>.from(ch),
          };

          list = list.map((r) {
            if (r.chapterId != null && chapterMap.containsKey(r.chapterId)) {
              final ch = chapterMap[r.chapterId]!;
              final chNum = AppHelperFunctions.toInt(ch['chapter_number']);
              final chTitle = ch['title']?.toString();
              final chGrade = AppHelperFunctions.toInt(ch['grade']);
              return r.copyWith(
                chapterNumber: chNum,
                chapterTitle: chTitle,
                grade: r.grade ?? chGrade,
              );
            }
            return r;
          }).toList();
        } catch (_) {}
      }

      // Batch enrich challenge questions with challenge title & subject
      final challengeIds = list
          .map((r) => r.challengeId)
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet();

      if (challengeIds.isNotEmpty) {
        try {
          final challengeRows = await _sb
              .from('leaderboard_challenges')
              .select('id, title, subject_id, subjects(id, name)')
              .inFilter('id', challengeIds.toList())
              .timeout(const Duration(seconds: 15));

          final Map<String, Map<String, dynamic>> challengeMap = {
            for (final c in (challengeRows as List))
              c['id'].toString(): Map<String, dynamic>.from(c),
          };

          list = list.map((r) {
            if (r.challengeId != null && challengeMap.containsKey(r.challengeId)) {
              final c = challengeMap[r.challengeId]!;
              final cTitle = c['title']?.toString();
              final cSub = c['subjects'] as Map<String, dynamic>?;
              final cSubName = cSub?['name']?.toString();
              final cSubId = AppHelperFunctions.toInt(c['subject_id']);
              return r.copyWith(
                challengeTitle: cTitle,
                subjectId: r.subjectId ?? cSubId,
                subjectName: r.subjectName ?? cSubName,
              );
            }
            return r;
          }).toList();
        } catch (_) {}
      }

      if (search != null && search.trim().isNotEmpty) {
        final term = search.trim().toLowerCase();
        list = list.where((r) {
          return r.questionText.toLowerCase().contains(term) ||
              r.userName.toLowerCase().contains(term) ||
              r.userEmail.toLowerCase().contains(term) ||
              (r.comment?.toLowerCase().contains(term) ?? false) ||
              (r.testTitle?.toLowerCase().contains(term) ?? false) ||
              (r.subjectName?.toLowerCase().contains(term) ?? false) ||
              (r.chapterTitle?.toLowerCase().contains(term) ?? false);
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

  Future<void> deleteReport(String reportId) async {
    try {
      await _sb
          .from('question_reports')
          .delete()
          .eq('id', reportId)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> deleteReportsForQuestion({
    int? questionId,
    String? challengeQuestionId,
  }) async {
    try {
      if (questionId != null) {
        await _sb
            .from('question_reports')
            .delete()
            .eq('question_id', questionId)
            .timeout(const Duration(seconds: 15));
      } else if (challengeQuestionId != null) {
        await _sb
            .from('question_reports')
            .delete()
            .eq('challenge_question_id', challengeQuestionId)
            .timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> saveQuestion({
    int? questionId,
    String? challengeQuestionId,
    int? testId,
    int? subjectId,
    String? challengeId,
    required String questionText,
    required List<String> options,
    required String correctChoice,
    String? explanationEn,
    String? explanationAm,
    int? grade,
    String? imageUrl,
  }) async {
    try {
      if (questionId != null) {
        int correctIndex = 0;
        if (correctChoice.length == 1) {
          final charCode = correctChoice.toUpperCase().codeUnitAt(0);
          if (charCode >= 65 && charCode <= 90) {
            correctIndex = charCode - 65;
          }
        }
        if (correctIndex >= options.length) correctIndex = 0;

        final data = <String, dynamic>{
          'id': questionId,
          'test_id': ?testId,
          'subject_id': ?subjectId,
          'question_text': questionText.trim(),
          'options': options,
          'correct_option_index': correctIndex,
          'explanation_en': explanationEn?.trim() ?? '',
          'explanation_am': explanationAm?.trim() ?? '',
          if (grade != null && grade > 0) 'grade': grade,
          if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        };
        await _sb.from('questions').upsert(data).timeout(const Duration(seconds: 15));
      } else if (challengeQuestionId != null) {
        final payload = <String, dynamic>{
          'id': challengeQuestionId,
          if (challengeId != null && challengeId.isNotEmpty) 'challenge_id': challengeId,
          'question_text': questionText.trim(),
          'choices': options,
          'correct_choice': correctChoice,
          'explanation_en': explanationEn?.trim() ?? '',
          'explanation_am': explanationAm?.trim() ?? '',
          'explanation': (explanationEn?.trim().isNotEmpty ?? false)
              ? explanationEn!.trim()
              : (explanationAm?.trim() ?? ''),
          if (imageUrl != null && imageUrl.isNotEmpty) 'image_url': imageUrl.trim(),
        };
        await _sb.from('challenge_questions').upsert(payload).timeout(const Duration(seconds: 15));
      }
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }
}
