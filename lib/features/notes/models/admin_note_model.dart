class AdminNoteModel {
  final int id;
  final int subjectId;
  final int? chapterId;
  final int grade;
  final int chapterNumber;
  final String title;
  final String? description;
  final String fileKey;
  final String? fileUrl;
  final String fileType;
  final int fileSizeBytes;
  final int pageCount;
  final bool isPremium;
  final int orderIndex;
  final DateTime? createdAt;
  final String? subjectName;
  final String? chapterTitle;

  const AdminNoteModel({
    required this.id,
    required this.subjectId,
    this.chapterId,
    required this.grade,
    required this.chapterNumber,
    required this.title,
    this.description,
    required this.fileKey,
    this.fileUrl,
    this.fileType = 'pdf',
    this.fileSizeBytes = 0,
    this.pageCount = 0,
    this.isPremium = true,
    this.orderIndex = 0,
    this.createdAt,
    this.subjectName,
    this.chapterTitle,
  });

  /// Human-readable file size in MB or KB
  String get formattedSize {
    if (fileSizeBytes <= 0) {
      if (pageCount > 0) {
        final estimatedMb = (pageCount * 120 * 1024) / (1024 * 1024);
        final val = estimatedMb.clamp(0.2, 50.0);
        return '${val.toStringAsFixed(1)} MB';
      }
      return '0 MB';
    }
    final mb = fileSizeBytes / (1024 * 1024);
    if (mb < 0.1) {
      final kb = fileSizeBytes / 1024;
      return '${kb.toStringAsFixed(0)} KB';
    }
    return '${mb.toStringAsFixed(1)} MB';
  }

  /// Human-readable page count
  String get formattedPages {
    if (pageCount <= 0) return '—';
    return '$pageCount ${pageCount == 1 ? 'page' : 'pages'}';
  }

  factory AdminNoteModel.fromJson(Map<String, dynamic> map) {
    final rawKey = map['file_key']?.toString();
    final rawUrl = map['file_url']?.toString();
    final key = (rawKey != null && rawKey.trim().isNotEmpty)
        ? rawKey.trim()
        : (rawUrl?.trim() ?? '');

    DateTime? parsedCreatedAt;
    final rawCreatedAt = map['created_at']?.toString();
    if (rawCreatedAt != null && rawCreatedAt.trim().isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt.trim());
    }

    String? subjectName;
    if (map['subjects'] is Map) {
      subjectName = map['subjects']['name']?.toString();
    } else if (map['subject_name'] != null) {
      subjectName = map['subject_name']?.toString();
    }

    String? chapterTitle;
    if (map['chapters'] is Map) {
      chapterTitle = map['chapters']['title']?.toString();
    } else if (map['chapter_title'] != null) {
      chapterTitle = map['chapter_title']?.toString();
    }

    return AdminNoteModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      subjectId: (map['subject_id'] as num?)?.toInt() ?? 0,
      chapterId: (map['chapter_id'] as num?)?.toInt(),
      grade: (map['grade'] as num?)?.toInt() ?? 9,
      chapterNumber: (map['chapter_number'] as num?)?.toInt() ?? 1,
      title: map['title']?.toString() ?? '',
      description: map['description']?.toString(),
      fileKey: key,
      fileUrl: rawUrl,
      fileType: map['file_type']?.toString() ?? 'pdf',
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt() ??
          (map['file_size'] as num?)?.toInt() ??
          0,
      pageCount: (map['page_count'] as num?)?.toInt() ?? 0,
      isPremium: map['is_premium'] == null
          ? true
          : (map['is_premium'] == true ||
              map['is_premium'] == 1 ||
              map['is_premium'] == '1' ||
              map['is_premium'] == 'true'),
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 0,
      createdAt: parsedCreatedAt,
      subjectName: subjectName,
      chapterTitle: chapterTitle,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'subject_id': subjectId,
      'chapter_id': chapterId,
      'grade': grade,
      'chapter_number': chapterNumber,
      'title': title,
      'description': description,
      'file_key': fileKey,
      'file_url': fileUrl ?? fileKey,
      'file_type': fileType,
      'file_size_bytes': fileSizeBytes,
      'page_count': pageCount,
      'is_premium': isPremium,
      'order_index': orderIndex,
    };
    if (includeId && id > 0) {
      map['id'] = id;
    }
    return map;
  }

  AdminNoteModel copyWith({
    int? id,
    int? subjectId,
    int? chapterId,
    int? grade,
    int? chapterNumber,
    String? title,
    String? description,
    String? fileKey,
    String? fileUrl,
    String? fileType,
    int? fileSizeBytes,
    int? pageCount,
    bool? isPremium,
    int? orderIndex,
    DateTime? createdAt,
    String? subjectName,
    String? chapterTitle,
  }) {
    return AdminNoteModel(
      id: id ?? this.id,
      subjectId: subjectId ?? this.subjectId,
      chapterId: chapterId ?? this.chapterId,
      grade: grade ?? this.grade,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      title: title ?? this.title,
      description: description ?? this.description,
      fileKey: fileKey ?? this.fileKey,
      fileUrl: fileUrl ?? this.fileUrl,
      fileType: fileType ?? this.fileType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      pageCount: pageCount ?? this.pageCount,
      isPremium: isPremium ?? this.isPremium,
      orderIndex: orderIndex ?? this.orderIndex,
      createdAt: createdAt ?? this.createdAt,
      subjectName: subjectName ?? this.subjectName,
      chapterTitle: chapterTitle ?? this.chapterTitle,
    );
  }
}
