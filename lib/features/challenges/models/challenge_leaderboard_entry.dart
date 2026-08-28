class ChallengeLeaderboardEntry {
  final int rank;
  final String userId;
  final String firstName;
  final String lastName;
  final String stream;
  final int score;
  final int totalTimeSeconds;
  final int correctCount;
  final int incorrectCount;
  final int notDoneCount;
  final int challengesTaken;
  final String? periodStart;

  ChallengeLeaderboardEntry({
    required this.rank,
    required this.userId,
    required this.firstName,
    this.lastName = '',
    required this.stream,
    this.score = 0,
    this.totalTimeSeconds = 0,
    this.correctCount = 0,
    this.incorrectCount = 0,
    this.notDoneCount = 0,
    this.challengesTaken = 1,
    this.periodStart,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get formattedTime {
    final minutes = totalTimeSeconds ~/ 60;
    final seconds = totalTimeSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  factory ChallengeLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    final sc = (json['score'] as num?)?.toInt() ??
        (json['total_score'] as num?)?.toInt() ??
        0;
    return ChallengeLeaderboardEntry(
      rank: (json['rank'] as num?)?.toInt() ?? 1,
      userId: json['user_id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? 'Student',
      lastName: json['last_name']?.toString() ?? '',
      stream: json['stream']?.toString() ?? '',
      score: sc,
      totalTimeSeconds: (json['total_time_seconds'] as num?)?.toInt() ?? 0,
      correctCount: (json['correct_count'] as num?)?.toInt() ?? sc,
      incorrectCount: (json['incorrect_count'] as num?)?.toInt() ?? 0,
      notDoneCount: (json['not_done_count'] as num?)?.toInt() ?? 0,
      challengesTaken: (json['challenges_taken'] as num?)?.toInt() ?? 1,
      periodStart: json['period_start']?.toString(),
    );
  }
}
