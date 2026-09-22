import 'dart:convert';
import 'package:m_admin/utils/helpers/helper_functions.dart';

class QuestionReportAdminModel {
  final String id;
  final String userId;
  final String userName;
  final String userEmail;
  final int? questionId;
  final String? challengeQuestionId;
  final int? testId;
  final int? subjectId;
  final String? subjectName;
  final String? testTitle;
  final String questionText;
  final String? choiceA;
  final String? choiceB;
  final String? choiceC;
  final String? choiceD;
  final String? correctChoice;
  final String? explanation;
  final String? explanationEn;
  final String? explanationAm;
  final String reason;
  final String? comment;
  final String status;
  final String? adminNotes;
  final DateTime? createdAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;

  QuestionReportAdminModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userEmail,
    this.questionId,
    this.challengeQuestionId,
    this.testId,
    this.subjectId,
    this.subjectName,
    this.testTitle,
    required this.questionText,
    this.choiceA,
    this.choiceB,
    this.choiceC,
    this.choiceD,
    this.correctChoice,
    this.explanation,
    this.explanationEn,
    this.explanationAm,
    required this.reason,
    this.comment,
    this.status = 'pending',
    this.adminNotes,
    this.createdAt,
    this.resolvedAt,
    this.resolvedBy,
  });

  String get reasonLabel {
    switch (reason) {
      case 'wrong_answer':
        return 'Wrong Correct Answer';
      case 'typo':
        return 'Typo / Spelling Mistake';
      case 'unclear':
        return 'Confusing / Unclear Question';
      case 'broken_image':
        return 'Missing / Broken Image';
      case 'bad_explanation':
        return 'Inaccurate Explanation';
      default:
        return 'Other Issue';
    }
  }

  bool get isPending => status == 'pending';
  bool get isResolved => status == 'resolved';
  bool get isDismissed => status == 'dismissed';

  factory QuestionReportAdminModel.fromJson(Map<String, dynamic> json) {
    final user = json['users'] as Map<String, dynamic>? ?? {};
    final question = json['questions'] as Map<String, dynamic>? ?? {};
    final challengeQuestion = json['challenge_questions'] as Map<String, dynamic>? ?? {};
    final test = question['tests'] as Map<String, dynamic>? ?? {};
    final subject = test['subjects'] as Map<String, dynamic>? ?? {};

    final firstName = user['first_name']?.toString() ?? '';
    final lastName = user['last_name']?.toString() ?? '';
    final fullName = user['full_name']?.toString() ?? '';
    final resolvedName = fullName.isNotEmpty
        ? fullName
        : ('$firstName $lastName'.trim().isNotEmpty
            ? '$firstName $lastName'.trim()
            : 'Anonymous Student');

    final qText = question['question_text']?.toString() ??
        challengeQuestion['question_text']?.toString() ??
        'Question text unavailable';

    List<String> optionsList = [];
    final rawOptions = question['options'];
    if (rawOptions is List) {
      optionsList = rawOptions.map((e) => e.toString()).toList();
    } else if (rawOptions is String && rawOptions.trim().startsWith('[')) {
      try {
        final d = jsonDecode(rawOptions);
        if (d is List) optionsList = d.map((e) => e.toString()).toList();
      } catch (_) {}
    }

    if (optionsList.isEmpty) {
      final rawChoices = challengeQuestion['choices'];
      if (rawChoices is List) {
        optionsList = rawChoices.map((e) {
          if (e is Map) {
            return e['text']?.toString() ?? e.values.first?.toString() ?? '';
          }
          return e.toString();
        }).toList();
      } else if (rawChoices is String && rawChoices.trim().startsWith('[')) {
        try {
          final d = jsonDecode(rawChoices);
          if (d is List) optionsList = d.map((e) => e.toString()).toList();
        } catch (_) {}
      }
    }

    final cA = optionsList.isNotEmpty ? optionsList[0] : null;
    final cB = optionsList.length > 1 ? optionsList[1] : null;
    final cC = optionsList.length > 2 ? optionsList[2] : null;
    final cD = optionsList.length > 3 ? optionsList[3] : null;

    final correctIndex = AppHelperFunctions.toInt(question['correct_option_index']);
    String? correct;
    if (correctIndex != null && correctIndex >= 0 && correctIndex < 26) {
      correct = String.fromCharCode(65 + correctIndex);
    } else if (challengeQuestion['correct_choice'] != null) {
      correct = challengeQuestion['correct_choice']?.toString();
    }

    final explEn = question['explanation_en']?.toString() ?? challengeQuestion['explanation_en']?.toString();
    final explAm = question['explanation_am']?.toString() ?? challengeQuestion['explanation_am']?.toString();
    final expl = explEn ?? explAm ?? challengeQuestion['explanation']?.toString();

    return QuestionReportAdminModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      userName: resolvedName,
      userEmail: user['email']?.toString() ?? '',
      questionId: AppHelperFunctions.toInt(json['question_id']),
      challengeQuestionId: json['challenge_question_id']?.toString(),
      testId: AppHelperFunctions.toInt(json['test_id']) ?? AppHelperFunctions.toInt(question['test_id']),
      subjectId: AppHelperFunctions.toInt(subject['id']),
      subjectName: subject['name']?.toString(),
      testTitle: test['title']?.toString(),
      questionText: qText,
      choiceA: cA,
      choiceB: cB,
      choiceC: cC,
      choiceD: cD,
      correctChoice: correct,
      explanation: expl,
      explanationEn: explEn,
      explanationAm: explAm,
      reason: json['reason']?.toString() ?? 'other',
      comment: json['comment']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      adminNotes: json['admin_notes']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      resolvedAt: json['resolved_at'] != null ? DateTime.tryParse(json['resolved_at'].toString()) : null,
      resolvedBy: json['resolved_by']?.toString(),
    );
  }
}


class QuestionReportGroupModel {
  final int? questionId;
  final String? challengeQuestionId;
  final int? testId;
  final int? subjectId;
  final String? subjectName;
  final String? testTitle;
  final String questionText;
  final String? choiceA;
  final String? choiceB;
  final String? choiceC;
  final String? choiceD;
  final String? correctChoice;
  final String? explanation;
  final String? explanationEn;
  final String? explanationAm;
  final List<QuestionReportAdminModel> reports;

  QuestionReportGroupModel({
    this.questionId,
    this.challengeQuestionId,
    this.testId,
    this.subjectId,
    this.subjectName,
    this.testTitle,
    required this.questionText,
    this.choiceA,
    this.choiceB,
    this.choiceC,
    this.choiceD,
    this.correctChoice,
    this.explanation,
    this.explanationEn,
    this.explanationAm,
    required this.reports,
  });

  int get reportCount => reports.length;
  bool get hasMultipleReports => reports.length > 1;
  DateTime? get latestReportDate => reports.isNotEmpty ? reports.first.createdAt : null;
  String get primaryReason => reports.isNotEmpty ? reports.first.reasonLabel : 'Reported';
  bool get hasPending => reports.any((r) => r.isPending);

  String get targetKey => questionId != null
      ? 'q_$questionId'
      : (challengeQuestionId != null ? 'cq_$challengeQuestionId' : (reports.isNotEmpty ? reports.first.id : ''));

  static List<QuestionReportGroupModel> groupReports(
    List<QuestionReportAdminModel> reports, {
    String sortBy = 'count_desc', // 'count_desc' | 'date_desc' | 'date_asc'
  }) {
    final Map<String, List<QuestionReportAdminModel>> map = {};
    for (final r in reports) {
      final key = r.questionId != null
          ? 'q_${r.questionId}'
          : (r.challengeQuestionId != null ? 'cq_${r.challengeQuestionId}' : 'r_${r.id}');
      map.putIfAbsent(key, () => []).add(r);
    }

    final List<QuestionReportGroupModel> groups = [];
    for (final entry in map.entries) {
      final list = entry.value;
      list.sort((a, b) => (b.createdAt ?? DateTime(1970)).compareTo(a.createdAt ?? DateTime(1970)));
      final first = list.first;
      groups.add(QuestionReportGroupModel(
        questionId: first.questionId,
        challengeQuestionId: first.challengeQuestionId,
        testId: first.testId,
        subjectId: first.subjectId,
        subjectName: first.subjectName,
        testTitle: first.testTitle,
        questionText: first.questionText,
        choiceA: first.choiceA,
        choiceB: first.choiceB,
        choiceC: first.choiceC,
        choiceD: first.choiceD,
        correctChoice: first.correctChoice,
        explanation: first.explanation,
        explanationEn: first.explanationEn,
        explanationAm: first.explanationAm,
        reports: list,
      ));
    }

    if (sortBy == 'count_desc') {
      groups.sort((a, b) {
        final cmp = b.reportCount.compareTo(a.reportCount);
        if (cmp != 0) return cmp;
        return (b.latestReportDate ?? DateTime(1970)).compareTo(a.latestReportDate ?? DateTime(1970));
      });
    } else if (sortBy == 'date_desc') {
      groups.sort((a, b) => (b.latestReportDate ?? DateTime(1970)).compareTo(a.latestReportDate ?? DateTime(1970)));
    } else if (sortBy == 'date_asc') {
      groups.sort((a, b) => (a.latestReportDate ?? DateTime(1970)).compareTo(b.latestReportDate ?? DateTime(1970)));
    }

    return groups;
  }
}
