class ChallengeAttemptModel {
  final String id;
  final String challengeId;
  final String userId;
  final String stream;
  final DateTime startedAt;
  final DateTime? submittedAt;
  final int score;
  final int totalTimeSeconds;
  final String status; // 'in_progress', 'submitted', 'expired'

  ChallengeAttemptModel({
    required this.id,
    required this.challengeId,
    required this.userId,
    required this.stream,
    required this.startedAt,
    this.submittedAt,
    this.score = 0,
    this.totalTimeSeconds = 0,
    required this.status,
  });

  bool get isSubmitted => status == 'submitted';
  bool get isInProgress => status == 'in_progress';
  bool get isExpired => status == 'expired';

  factory ChallengeAttemptModel.fromJson(Map<String, dynamic> json) {
    return ChallengeAttemptModel(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      stream: json['stream']?.toString() ?? '',
      startedAt: json['started_at'] != null
          ? DateTime.tryParse(json['started_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      submittedAt: json['submitted_at'] != null
          ? DateTime.tryParse(json['submitted_at'].toString())
          : null,
      score: (json['score'] as num?)?.toInt() ?? 0,
      totalTimeSeconds: (json['total_time_seconds'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'in_progress',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'challenge_id': challengeId,
      'user_id': userId,
      'stream': stream,
      'started_at': startedAt.toIso8601String(),
      'submitted_at': submittedAt?.toIso8601String(),
      'score': score,
      'total_time_seconds': totalTimeSeconds,
      'status': status,
    };
  }
}
