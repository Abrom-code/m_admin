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

    final cA = question['choice_a']?.toString() ?? challengeQuestion['choice_a']?.toString();
    final cB = question['choice_b']?.toString() ?? challengeQuestion['choice_b']?.toString();
    final cC = question['choice_c']?.toString() ?? challengeQuestion['choice_c']?.toString();
    final cD = question['choice_d']?.toString() ?? challengeQuestion['choice_d']?.toString();
    final correct = question['correct_choice']?.toString() ?? challengeQuestion['correct_choice']?.toString();
    final expl = question['explanation']?.toString() ?? challengeQuestion['explanation']?.toString();

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
