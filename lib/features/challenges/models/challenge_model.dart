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
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
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

  /// Time-aware: scheduled only if start time hasn't passed yet.
  bool get isScheduled {
    if (status == 'scheduled') {
      if (startsAt != null && !DateTime.now().isBefore(startsAt!)) {
        return false;
      }
      return true;
    }
    return false;
  }

  /// Time-aware: live if status says so and end hasn't passed,
  /// OR if scheduled but start time has passed and end hasn't.
  bool get isLive {
    final now = DateTime.now();
    if (status == 'live') {
      if (endsAt != null && now.isAfter(endsAt!)) {
        return false;
      }
      return true;
    }
    if (status == 'scheduled') {
      if (startsAt != null && !now.isBefore(startsAt!)) {
        if (endsAt != null && now.isAfter(endsAt!)) {
          return false;
        }
        return true;
      }
    }
    return false;
  }

  /// Time-aware: closed if status is closed/archived or end time has passed.
  bool get isClosed {
    if (status == 'closed' || status == 'archived') return true;
    if (endsAt != null && DateTime.now().isAfter(endsAt!)) return true;
    return false;
  }

  bool get isArchived => status == 'archived';
  int get durationMinutes => durationSeconds ~/ 60;

  /// Pre-visibility window: scheduled & starts_at is within 12 hours
  bool get isUpcomingVisible {
    if (startsAt == null) return false;
    final now = DateTime.now();
    if (now.isAfter(startsAt!)) return false;
    final difference = startsAt!.difference(now);
    return difference.inHours <= 12 && difference.inSeconds > 0;
  }

  factory LeaderboardChallengeModel.fromJson(Map<String, dynamic> json) {
    final rawId = json['id']?.toString() ?? json['challenge_id']?.toString() ?? '';
    final rawSetId = json['set_id']?.toString() ?? rawId;
    final finalId = rawId.isNotEmpty ? rawId : rawSetId;

    int sId = (json['subject_id'] as num?)?.toInt() ?? 0;
    if (sId == 0 && json['subjects'] != null && json['subjects'] is Map) {
      sId = (json['subjects']['id'] as num?)?.toInt() ?? 0;
    }

    final subjName = json['subjects'] != null && json['subjects'] is Map
        ? json['subjects']['name']?.toString()
        : json['subject_name']?.toString();

    final sTitle = json['challenge_question_sets'] != null &&
            json['challenge_question_sets'] is Map
        ? json['challenge_question_sets']['title']?.toString()
        : json['set_title']?.toString();

    int qCount = (json['question_count'] as num?)?.toInt() ?? 0;
    if (qCount == 0 && json['challenge_question_sets'] is Map) {
      final setMap = json['challenge_question_sets'] as Map;
      if (setMap['challenge_questions'] is List) {
        qCount = (setMap['challenge_questions'] as List).length;
      }
    }
    if (qCount == 0 && json['challenge_questions'] is List) {
      qCount = (json['challenge_questions'] as List).length;
    }

    int attempts = (json['attempt_count'] as num?)?.toInt() ?? 0;
    if (attempts == 0 && json['challenge_attempts'] != null) {
      if (json['challenge_attempts'] is List) {
        final list = json['challenge_attempts'] as List;
        if (list.isNotEmpty && list.first is Map && list.first.containsKey('count')) {
          attempts = (list.first['count'] as num?)?.toInt() ?? 0;
        } else {
          attempts = list.length;
        }
      } else if (json['challenge_attempts'] is Map && json['challenge_attempts'].containsKey('count')) {
        attempts = (json['challenge_attempts']['count'] as num?)?.toInt() ?? 0;
      }
    }

    return LeaderboardChallengeModel(
      id: finalId,
      setId: rawSetId,
      subjectId: sId,
      subjectName: subjName,
      setTitle: sTitle,
      audience: json['audience']?.toString() ?? 'both',
      title: json['title']?.toString() ?? '',
      startsAt: json['starts_at'] != null
          ? DateTime.tryParse(json['starts_at'].toString())?.toLocal()
          : null,
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())?.toLocal()
          : null,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 3600,
      status: json['status']?.toString() ?? 'draft',
      createdBy: json['created_by']?.toString(),
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
      questionCount: qCount,
      attemptCount: attempts,
    );
  }

  LeaderboardChallengeModel copyWith({
    String? id,
    String? setId,
    int? subjectId,
    String? subjectName,
    String? setTitle,
    String? audience,
    String? title,
    DateTime? startsAt,
    DateTime? endsAt,
    int? durationSeconds,
    String? status,
    String? createdBy,
    DateTime? createdAt,
    int? questionCount,
    int? attemptCount,
  }) {
    return LeaderboardChallengeModel(
      id: id ?? this.id,
      setId: setId ?? this.setId,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      setTitle: setTitle ?? this.setTitle,
      audience: audience ?? this.audience,
      title: title ?? this.title,
      startsAt: startsAt ?? this.startsAt,
      endsAt: endsAt ?? this.endsAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      status: status ?? this.status,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      questionCount: questionCount ?? this.questionCount,
      attemptCount: attemptCount ?? this.attemptCount,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'set_id': setId,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'set_title': setTitle,
      'audience': audience,
      'title': title,
      'starts_at': startsAt?.toIso8601String(),
      'ends_at': endsAt?.toIso8601String(),
      'duration_seconds': durationSeconds,
      'status': status,
      'question_count': questionCount,
      'attempt_count': attemptCount,
      'created_at': createdAt.toIso8601String(),
      if (createdBy != null) 'created_by': createdBy,
    };
  }
}
