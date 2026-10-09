class AdminPilotExamModel {
  final int id;
  final String title;
  final String description;
  final String edition;
  final int grade;
  final bool isPremium;
  final bool isActive;
  final String status;
  final DateTime? createdAt;
  final List<AdminPilotExamSubjectModel> subjects;

  const AdminPilotExamModel({
    required this.id,
    required this.title,
    this.description = '',
    this.edition = '2019 E.C.',
    this.grade = 12,
    this.isPremium = true,
    this.isActive = true,
    this.status = 'published',
    this.createdAt,
    this.subjects = const [],
  });

  bool get isDraft => status.toLowerCase() == 'draft' || status.toLowerCase() == 'verification' || !isActive;
  bool get isPublished => status.toLowerCase() == 'published' && isActive;

  int get subjectCount => subjects.length;

  int get totalQuestions =>
      subjects.fold(0, (sum, s) => sum + s.questionCount);

  int get totalMinutes =>
      subjects.fold(0, (sum, s) => sum + s.timeMinutes);

  factory AdminPilotExamModel.fromJson(
    Map<String, dynamic> map, {
    List<AdminPilotExamSubjectModel> subjects = const [],
  }) {
    DateTime? parsedCreatedAt;
    final rawCreatedAt = map['created_at']?.toString();
    if (rawCreatedAt != null && rawCreatedAt.trim().isNotEmpty) {
      parsedCreatedAt = DateTime.tryParse(rawCreatedAt.trim());
    }

    final rawPremium = map['is_premium'];
    final isPrem = rawPremium == null ||
        rawPremium == true ||
        rawPremium == 1 ||
        rawPremium == '1' ||
        rawPremium == 'true';

    final rawActive = map['is_active'];
    final isAct = rawActive == null ||
        rawActive == true ||
        rawActive == 1 ||
        rawActive == '1' ||
        rawActive == 'true';

    final rawStatus = map['status']?.toString() ?? (isAct ? 'published' : 'draft');

    // If subjects was joined in the JSON query
    List<AdminPilotExamSubjectModel> joinedSubjects = subjects;
    if (map['pilot_exam_subjects'] is List) {
      joinedSubjects = (map['pilot_exam_subjects'] as List)
          .map((s) => AdminPilotExamSubjectModel.fromJson(Map<String, dynamic>.from(s)))
          .toList();
    }

    return AdminPilotExamModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      title: map['title']?.toString() ?? 'Pilot Exam',
      description: map['description']?.toString() ?? '',
      edition: map['edition']?.toString() ?? '2019 E.C.',
      grade: (map['grade'] as num?)?.toInt() ?? 12,
      isPremium: isPrem,
      isActive: isAct,
      status: rawStatus,
      createdAt: parsedCreatedAt,
      subjects: joinedSubjects,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'title': title,
      'description': description,
      'edition': edition,
      'grade': grade,
      'is_premium': isPremium,
      'is_active': isActive,
      'status': status,
    };
    if (includeId && id > 0) {
      map['id'] = id;
    }
    return map;
  }

  AdminPilotExamModel copyWith({
    int? id,
    String? title,
    String? description,
    String? edition,
    int? grade,
    bool? isPremium,
    bool? isActive,
    String? status,
    DateTime? createdAt,
    List<AdminPilotExamSubjectModel>? subjects,
  }) {
    return AdminPilotExamModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      edition: edition ?? this.edition,
      grade: grade ?? this.grade,
      isPremium: isPremium ?? this.isPremium,
      isActive: isActive ?? this.isActive,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      subjects: subjects ?? this.subjects,
    );
  }
}

class AdminPilotExamSubjectModel {
  final int id;
  final int pilotExamId;
  final int subjectId;
  final String subjectName;
  final String stream; // 'natural', 'social', 'common'
  final int? testId;
  final int orderIndex;
  final int questionCount;
  final int timeMinutes;

  const AdminPilotExamSubjectModel({
    required this.id,
    required this.pilotExamId,
    required this.subjectId,
    required this.subjectName,
    required this.stream,
    this.testId,
    this.orderIndex = 1,
    this.questionCount = 60,
    this.timeMinutes = 90,
  });

  bool get isCommon =>
      stream.toLowerCase() == 'common' || stream.toLowerCase() == 'both';
  bool get isNatural => stream.toLowerCase() == 'natural';
  bool get isSocial => stream.toLowerCase() == 'social';

  String get streamLabel {
    if (isCommon) return 'Common';
    if (isNatural) return 'Natural';
    if (isSocial) return 'Social';
    return stream.toUpperCase();
  }

  factory AdminPilotExamSubjectModel.fromJson(Map<String, dynamic> map) {
    String subName = map['subject_name']?.toString() ?? '';
    if (subName.isEmpty && map['subjects'] is Map) {
      subName = map['subjects']['name']?.toString() ?? '';
    }
    if (subName.isEmpty) subName = 'Subject #${map['subject_id']}';

    return AdminPilotExamSubjectModel(
      id: (map['id'] as num?)?.toInt() ?? 0,
      pilotExamId: (map['pilot_exam_id'] as num?)?.toInt() ?? 0,
      subjectId: (map['subject_id'] as num?)?.toInt() ?? 0,
      subjectName: subName,
      stream: map['stream']?.toString() ?? 'natural',
      testId: (map['test_id'] as num?)?.toInt(),
      orderIndex: (map['order_index'] as num?)?.toInt() ?? 1,
      questionCount: (map['question_count'] as num?)?.toInt() ?? 60,
      timeMinutes: (map['time_minutes'] as num?)?.toInt() ?? 90,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'pilot_exam_id': pilotExamId,
      'subject_id': subjectId,
      'subject_name': subjectName,
      'stream': stream.toLowerCase(),
      'test_id': testId,
      'order_index': orderIndex,
      'question_count': questionCount,
      'time_minutes': timeMinutes,
    };
    if (includeId && id > 0) {
      map['id'] = id;
    }
    return map;
  }

  AdminPilotExamSubjectModel copyWith({
    int? id,
    int? pilotExamId,
    int? subjectId,
    String? subjectName,
    String? stream,
    int? testId,
    int? orderIndex,
    int? questionCount,
    int? timeMinutes,
  }) {
    return AdminPilotExamSubjectModel(
      id: id ?? this.id,
      pilotExamId: pilotExamId ?? this.pilotExamId,
      subjectId: subjectId ?? this.subjectId,
      subjectName: subjectName ?? this.subjectName,
      stream: stream ?? this.stream,
      testId: testId ?? this.testId,
      orderIndex: orderIndex ?? this.orderIndex,
      questionCount: questionCount ?? this.questionCount,
      timeMinutes: timeMinutes ?? this.timeMinutes,
    );
  }
}
