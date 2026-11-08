import 'package:intl/intl.dart';

/// Model representing a Tip or News entry in the MatricMate Admin Console.
class AdminTipNewsModel {
  const AdminTipNewsModel({
    required this.id,
    required this.title,
    required this.content,
    required this.category,
    this.imageUrl,
    this.author = 'MatricMate Team',
    this.audience = 'both',
    this.isPinned = false,
    this.isPublished = true,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final String title;
  final String content;
  final String category; // 'news' or 'tip'
  final String? imageUrl;
  final String author;
  final String audience; // 'both', 'natural', 'social'
  final bool isPinned;
  final bool isPublished;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isNews => category.toLowerCase().trim() == 'news';
  bool get isTip => category.toLowerCase().trim() == 'tip';

  String get categoryLabel => isNews ? 'News' : 'Study Tip';

  String get audienceLabel {
    switch (audience.toLowerCase().trim()) {
      case 'natural':
        return 'Natural Science';
      case 'social':
        return 'Social Science';
      case 'both':
      default:
        return 'All Students';
    }
  }

  int get readingTimeMinutes {
    final words = content.trim().split(RegExp(r'\s+')).length;
    final mins = (words / 140).ceil();
    return mins < 1 ? 1 : mins;
  }

  String get snippet {
    final clean = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (clean.length <= 100) return clean;
    return '${clean.substring(0, 97)}...';
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    if (diff.inMinutes < 60) {
      if (diff.inMinutes <= 1) return 'Just now';
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(createdAt);
    }
  }

  factory AdminTipNewsModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic d) {
      if (d is DateTime) return d;
      if (d != null) {
        final parsed = DateTime.tryParse(d.toString());
        if (parsed != null) return parsed;
      }
      return DateTime.now();
    }

    return AdminTipNewsModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      category: (json['category']?.toString() ?? 'news').toLowerCase().trim(),
      imageUrl: json['image_url']?.toString(),
      author: json['author']?.toString() ?? 'MatricMate Team',
      audience: json['audience']?.toString() ?? 'both',
      isPinned: json['is_pinned'] == true || json['is_pinned'] == 1,
      isPublished: json['is_published'] == null ||
          json['is_published'] == true ||
          json['is_published'] == 1,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id > 0) 'id': id,
      'title': title,
      'content': content,
      'category': category.toLowerCase().trim(),
      'image_url': imageUrl?.trim().isEmpty == true ? null : imageUrl?.trim(),
      'author': author.trim().isEmpty ? 'MatricMate Team' : author.trim(),
      'audience': audience.toLowerCase().trim(),
      'is_pinned': isPinned,
      'is_published': isPublished,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toUpsertJson() {
    return {
      'title': title.trim(),
      'content': content.trim(),
      'category': category.toLowerCase().trim(),
      'image_url': (imageUrl == null || imageUrl!.trim().isEmpty)
          ? null
          : imageUrl!.trim(),
      'author': author.trim().isEmpty ? 'MatricMate Team' : author.trim(),
      'audience': audience.toLowerCase().trim(),
      'is_pinned': isPinned,
      'is_published': isPublished,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  AdminTipNewsModel copyWith({
    int? id,
    String? title,
    String? content,
    String? category,
    String? imageUrl,
    String? author,
    String? audience,
    bool? isPinned,
    bool? isPublished,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AdminTipNewsModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      category: category ?? this.category,
      imageUrl: imageUrl ?? this.imageUrl,
      author: author ?? this.author,
      audience: audience ?? this.audience,
      isPinned: isPinned ?? this.isPinned,
      isPublished: isPublished ?? this.isPublished,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
