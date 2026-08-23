class ChallengeQuestionSetModel {
  final String id;
  final int subjectId;
  final String title;
  final String? subjectName;
  final String? createdBy;
  final DateTime createdAt;
  final int questionCount;

  ChallengeQuestionSetModel({
    required this.id,
    required this.subjectId,
    required this.title,
    this.subjectName,
    this.createdBy,
    required this.createdAt,
    this.questionCount = 0,
  });

  factory ChallengeQuestionSetModel.fromJson(Map<String, dynamic> json) {
    return ChallengeQuestionSetModel(
      id: json['id']?.toString() ?? '',
      subjectId: (json['subject_id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      subjectName: json['subjects'] != null && json['subjects'] is Map
          ? json['subjects']['name']?.toString()
          : json['subject_name']?.toString(),
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      questionCount: (json['question_count'] as num?)?.toInt() ??
          ((json['challenge_questions'] as List?)?.length ?? 0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'subject_id': subjectId,
      'title': title,
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}

class LeaderboardChallengeModel {
  final String id;
  final String setId;
  final int subjectId;
  final String? subjectName;
  final String? setTitle;
  final String audience; // 'natural', 'social', 'both'
  final String title;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int durationSeconds;
  final String status; // 'draft', 'scheduled', 'live', 'closed', 'archived'
  final String? createdBy;
  final DateTime createdAt;
  final int questionCount;
  final int attemptCount;

  LeaderboardChallengeModel({
    required this.id,
    required this.setId,
    required this.subjectId,
    this.subjectName,
    this.setTitle,
    required this.audience,
    required this.title,
    this.startsAt,
    this.endsAt,
    this.durationSeconds = 3600,
    required this.status,
    this.createdBy,
    required this.createdAt,
    this.questionCount = 0,
    this.attemptCount = 0,
  });

  bool get isDraft => status == 'draft';
  bool get isScheduled => status == 'scheduled';
  bool get isLive => status == 'live';
  bool get isClosed => status == 'closed';
  bool get isArchived => status == 'archived';

  /// Pre-visibility window: scheduled & starts_at is within 12 hours
  bool get isUpcomingVisible {
    if (status != 'scheduled' || startsAt == null) return false;
    final now = DateTime.now();
    final difference = startsAt!.difference(now);
    return difference.inHours <= 12 && difference.inSeconds > 0;
  }

  factory LeaderboardChallengeModel.fromJson(Map<String, dynamic> json) {
    return LeaderboardChallengeModel(
      id: json['id']?.toString() ?? '',
      setId: json['set_id']?.toString() ?? '',
      subjectId: (json['subject_id'] as num?)?.toInt() ?? 0,
      subjectName: json['subjects'] != null && json['subjects'] is Map
          ? json['subjects']['name']?.toString()
          : json['subject_name']?.toString(),
      setTitle: json['challenge_question_sets'] != null &&
              json['challenge_question_sets'] is Map
          ? json['challenge_question_sets']['title']?.toString()
          : json['set_title']?.toString(),
      audience: json['audience']?.toString() ?? 'both',
      title: json['title']?.toString() ?? '',
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'].toString())
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())
          : null,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 3600,
      status: json['status']?.toString() ?? 'draft',
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      questionCount: (json['question_count'] as num?)?.toInt() ?? 0,
      attemptCount: (json['attempt_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'set_id': setId,
      'subject_id': subjectId,
      'audience': audience,
      'title': title,
      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'status': status,
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}
