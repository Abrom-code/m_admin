import 'package:m_admin/utils/helpers/helper_functions.dart';

/// A row from `public.notifications`, matching the schema verified by the
/// Supabase access catalogue:
///   id bigint PK
///   user_id text? (null = broadcast)
///   title text
///   body text
///   type text  (announcement | payment | new_content | challenge | challenge_round | challenge_reward)
///   payload jsonb
///   is_read bool
///   is_archived bool
///   created_at timestamptz
///   target_stream text? (null = global broadcast)
class AdminNotificationModel {
  const AdminNotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.payload,
    this.userId,
    this.targetStream,
    this.createdAt,
    this.isArchived = false,
  });

  final int id;
  final String? userId;
  final String title;
  final String body;
  final String type; // 'announcement' | 'payment' | 'new_content' | 'challenge' | 'challenge_round' | 'challenge_reward'
  final Map<String, dynamic> payload;
  final bool isRead;
  final bool isArchived;
  final String? targetStream;
  final DateTime? createdAt;

  bool get isBroadcast => userId == null;

  bool get isChallenge =>
      type == 'challenge' ||
      type == 'challenge_round' ||
      type == 'challenge_reward' ||
      payload.containsKey('challenge_id');

  bool get isPayment => type == 'payment';

  bool get isNewContent => type == 'new_content';

  String get audienceLabel {
    if (userId != null) return 'User';
    if (targetStream != null && targetStream!.isNotEmpty) {
      return 'Stream: $targetStream';
    }
    return 'All students';
  }

  factory AdminNotificationModel.fromJson(Map<String, dynamic> json) {
    return AdminNotificationModel(
      id: AppHelperFunctions.toInt(json['id']) ?? 0,
      userId: json['user_id']?.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'announcement',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      isRead: json['is_read'] == true,
      isArchived: json['is_archived'] == true,
      targetStream: json['target_stream']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}
