class ChallengeRewardModel {
  final String id;
  final String? challengeId;
  final String userId;
  final int? rank;
  final String rewardType;
  final String? rewardValue;
  final String? period;
  final String? periodStart;
  final String? grantedBy;
  final DateTime grantedAt;

  ChallengeRewardModel({
    required this.id,
    this.challengeId,
    required this.userId,
    this.rank,
    required this.rewardType,
    this.rewardValue,
    this.period,
    this.periodStart,
    this.grantedBy,
    required this.grantedAt,
  });

  factory ChallengeRewardModel.fromJson(Map<String, dynamic> json) {
    return ChallengeRewardModel(
      id: json['id']?.toString() ?? '',
      challengeId: json['challenge_id']?.toString(),
      userId: json['user_id']?.toString() ?? '',
      rank: (json['rank'] as num?)?.toInt(),
      rewardType: json['reward_type']?.toString() ?? 'premium_days',
      rewardValue: json['reward_value']?.toString(),
      period: json['period']?.toString(),
      periodStart: json['period_start']?.toString(),
      grantedBy: json['granted_by']?.toString(),
      grantedAt: json['granted_at'] != null
          ? (DateTime.tryParse(json['granted_at'].toString())?.toLocal() ?? DateTime.now())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      if (challengeId != null) 'challenge_id': challengeId,
      'user_id': userId,
      if (rank != null) 'rank': rank,
      'reward_type': rewardType,
      if (rewardValue != null) 'reward_value': rewardValue,
      if (period != null) 'period': period,
      if (periodStart != null) 'period_start': periodStart,
      if (grantedBy != null) 'granted_by': grantedBy,
    };
  }
}
