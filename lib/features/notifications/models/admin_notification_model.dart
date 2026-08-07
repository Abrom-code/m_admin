/// A row from `public.notifications`, matching the schema verified by the
/// Supabase access catalogue:
///   id bigint PK
///   user_id text? (null = broadcast)
///   title text
///   body text
///   type text  (announcement | payment | new_content)
///   payload jsonb
///   is_read bool
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
  });

  final int id;
  final String? userId;
  final String title;
  final String body;
  final String type; // 'announcement' | 'payment' | 'new_content'
  final Map<String, dynamic> payload;
  final bool isRead;
  final String? targetStream;
  final DateTime? createdAt;

  bool get isBroadcast => userId == null;

  String get audienceLabel {
    if (userId != null) return 'User';
    if (targetStream != null && targetStream!.isNotEmpty) {
      return 'Stream: $targetStream';
    }
    return 'All students';
  }

  factory AdminNotificationModel.fromJson(Map<String, dynamic> json) {
    return AdminNotificationModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: json['user_id']?.toString(),
      title: json['title']?.toString() ?? '',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'announcement',
      payload: json['payload'] is Map
          ? Map<String, dynamic>.from(json['payload'] as Map)
          : const {},
      isRead: json['is_read'] == true,
      targetStream: json['target_stream']?.toString(),
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
    );
  }
}
