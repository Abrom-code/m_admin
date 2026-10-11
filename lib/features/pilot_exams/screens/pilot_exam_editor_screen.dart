import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/data/repositories/pilot_exams_repository.dart';
import 'package:m_admin/features/pilot_exams/controllers/pilot_exams_controller.dart';
import 'package:m_admin/features/pilot_exams/models/admin_pilot_exam_model.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

/// Helper to classify subjects, streams, and defaults according to national curriculum standard.
class PilotSubjectConfig {
  static const naturalStreamKey = 'natural';
  static const socialStreamKey = 'social';
  static const commonStreamKey = 'common';
  static const bothStreamsKey = 'both';

  static bool isCommon(String name, {bool? dbCommon}) {
    if (dbCommon == true) return true;
    final n = name.toLowerCase();
    return n.contains('english') ||
        n.contains('aptitude') ||
        n.contains('sat') ||
        n.contains('scholastic');
  }

  static bool isNaturalOnly(String name, {bool? dbNatural}) {
    if (isCommon(name)) return false;
    final n = name.toLowerCase();
    if (n.contains('physics') ||
        n.contains('chemistry') ||
        n.contains('chemist') ||
        n.contains('biology') ||
        n.contains('bio')) {
      return true;
    }
    if (n.contains('math') && (n.contains('natural') || dbNatural == true)) {
      return true;
    }
    return dbNatural == true;
  }

  static bool isSocialOnly(String name, {bool? dbNatural}) {
    if (isCommon(name)) return false;
    final n = name.toLowerCase();
    if (n.contains('geography') ||
        n.contains('geog') ||
        n.contains('history') ||
        n.contains('histor') ||
        n.contains('economics') ||
        n.contains('econom')) {
      return true;
    }
    if (n.contains('math') && (n.contains('social') || dbNatural == false)) {
      return true;
    }
    return dbNatural == false;
  }

  static String getSubjectStream(String name, {bool? dbNatural, bool? dbCommon}) {
    if (isCommon(name, dbCommon: dbCommon)) return commonStreamKey;
    if (isSocialOnly(name, dbNatural: dbNatural)) return socialStreamKey;
    if (isNaturalOnly(name, dbNatural: dbNatural)) return naturalStreamKey;
    return naturalStreamKey;
  }

  /// Default questions count:
  /// - Physics: 60
  /// - Biology: 100
  /// - Geography: 100
  /// - History: 100
  /// - English: 100
  /// - Chemistry: 80
  /// - Economics: 80
  /// - Mathematics (Natural & Social): 60
  /// - Scholastic Aptitude (SAT): 60
  static int getDefaultQuestionCount(String name) {
    final n = name.toLowerCase();
    if (n.contains('physics')) return 60;
    if (n.contains('bio')) return 100;
    if (n.contains('geo')) return 100;
    if (n.contains('histor')) return 100;
    if (n.contains('english')) return 100;
    if (n.contains('chemist')) return 80;
    if (n.contains('econom')) return 80;
    if (n.contains('math')) return 60;
    if (n.contains('sat') || n.contains('aptitude') || n.contains('scholastic')) return 60;
    return 60;
  }

  /// Default time in minutes:
  /// - Mathematics (Natural & Social): 180 min
  /// - English: 120 min
  /// - Scholastic Aptitude (SAT): 120 min
  /// - Physics: 150 min
  /// - Chemistry: 150 min
  /// - Biology: 150 min
  /// - Geography: 150 min
  /// - History: 150 min
  /// - Economics: 150 min
  static int getDefaultTimeMinutes(String name) {
    final n = name.toLowerCase();
    if (n.contains('math')) return 180;
    if (n.contains('english')) return 120;
    if (n.contains('sat') || n.contains('aptitude') || n.contains('scholastic')) return 120;
    if (n.contains('physics')) return 150;
    if (n.contains('chemist')) return 150;
    if (n.contains('bio')) return 150;
    if (n.contains('geo')) return 150;
    if (n.contains('histor')) return 150;
    if (n.contains('econom')) return 150;
    return 120;
  }
}

class PilotExamEditorScreen extends StatefulWidget {
  const PilotExamEditorScreen({super.key, this.exam});

  final AdminPilotExamModel? exam;

  @override
  State<PilotExamEditorScreen> createState() => _PilotExamEditorScreenState();
}

class _PilotExamEditorScreenState extends State<PilotExamEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = PilotExamsRepository();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _editionCtrl;
  late final TextEditingController _descCtrl;

  int? _selectedGrade;
  bool _isPremium = true;
  String _status = 'draft';

  // Stream mode: 'natural', 'social', or 'both'
  String _selectedStream = 'natural';

  final List<AdminPilotExamSubjectModel> _subjectsList = [];
  List<Map<String, dynamic>> _availableSubjects = [];
  final Map<int, String> _testTitles = {};
  bool _isSaving = false;
  bool _loadingAvailableSubjects = false;

  bool get isEditing => widget.exam != null;

  @override
  void initState() {
    super.initState();
    final e = widget.exam;

    _titleCtrl = TextEditingController(text: e?.title ?? '');
    _editionCtrl = TextEditingController(text: e?.edition ?? '2019 E.C.');
    _descCtrl = TextEditingController(text: e?.description ?? '');

    _selectedGrade = (e != null && e.grade > 0 && e.grade <= 12) ? e.grade : 12;
    _isPremium = e?.isPremium ?? true;
    _status = e?.status ?? (e?.isActive == true ? 'published' : 'draft');
    if (_status.isEmpty) _status = 'draft';

    if (e != null && e.subjects.isNotEmpty) {
      _subjectsList.addAll(e.subjects);

      final hasNat = e.subjects.any((s) => s.isNatural);
      final hasSoc = e.subjects.any((s) => s.isSocial);
      if (hasNat && !hasSoc) {
        _selectedStream = 'natural';
      } else if (hasSoc && !hasNat) {
        _selectedStream = 'social';
      } else {
        _selectedStream = 'both';
      }

      // Preload test titles for already linked tests
      for (final s in e.subjects) {
        if (s.testId != null && s.testId! > 0) {
          _preloadTestTitle(s.testId!);
        }
      }
    }

    _loadAvailableSubjects();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _editionCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _preloadTestTitle(int testId) async {
    if (_testTitles.containsKey(testId)) return;
    try {
      final test = await _repo.fetchTestById(testId);
      if (test != null && mounted) {
        setState(() {
          _testTitles[testId] = test['title']?.toString() ?? 'Test #$testId';
        });
      }
    } catch (_) {}
  }

  Future<void> _loadAvailableSubjects() async {
    setState(() => _loadingAvailableSubjects = true);
    try {
      final list = await _repo.fetchSubjects();
      if (!mounted) return;
      setState(() {
        _availableSubjects = list;
        _loadingAvailableSubjects = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingAvailableSubjects = false);
    }
  }

  /// Switch streams and enforce stream-based mutual exclusivity.
  /// If natural is picked, remove social subjects.
  /// If social is picked, remove natural subjects.
  void _onStreamChanged(String stream) {
    setState(() {
      _selectedStream = stream;
      if (stream == 'natural') {
        _subjectsList.removeWhere(
          (s) => PilotSubjectConfig.isSocialOnly(s.subjectName),
        );
      } else if (stream == 'social') {
        _subjectsList.removeWhere(
          (s) => PilotSubjectConfig.isNaturalOnly(s.subjectName),
        );
      }
    });
  }

  /// Toggles a subject:
  /// If already in [_subjectsList], REMOVES it.
  /// If not in [_subjectsList], ADDS it with specified default questions & time.
  void _toggleSubject(Map<String, dynamic> subjectMap) {
    final subId = subjectMap['id'] as int;
    final subName = subjectMap['name']?.toString() ?? 'Subject';
    final existingIdx = _subjectsList.indexWhere((s) => s.subjectId == subId);

    setState(() {
      if (existingIdx != -1) {
        // Already selected -> Remove it
        _subjectsList.removeAt(existingIdx);
      } else {
        // Not selected -> Add with default questions and time
        final defaultQs = PilotSubjectConfig.getDefaultQuestionCount(subName);
        final defaultTime = PilotSubjectConfig.getDefaultTimeMinutes(subName);
        final stream = PilotSubjectConfig.getSubjectStream(
          subName,
          dbNatural: subjectMap['is_natural'] == true || subjectMap['is_natural'] == 1,
          dbCommon: subjectMap['is_common'] == true || subjectMap['is_common'] == 1,
        );

        _subjectsList.add(
          AdminPilotExamSubjectModel(
            id: 0,
            pilotExamId: widget.exam?.id ?? 0,
            subjectId: subId,
            subjectName: subName,
            stream: stream,
            testId: null,
            orderIndex: _subjectsList.length + 1,
            questionCount: defaultQs,
            timeMinutes: defaultTime,
          ),
        );
      }
    });
  }

  /// Whether all standard subjects for the currently active stream are selected.
  bool get _isAllStreamSubjectsSelected {
    final target = _filteredAvailableSubjects;
    if (target.isEmpty) return false;
    return target.every((s) => _subjectsList.any((item) => item.subjectId == s['id']));
  }

  /// Toggles between selecting all stream subjects and deselecting all stream subjects.
  void _toggleSelectAllStreamSubjects() {
    final targetSubjects = _filteredAvailableSubjects;
    if (targetSubjects.isEmpty) return;

    setState(() {
      if (_isAllStreamSubjectsSelected) {
        // All selected -> Deselect all subjects for this stream
        final targetIds = targetSubjects.map((s) => s['id'] as int).toSet();
        _subjectsList.removeWhere((item) => targetIds.contains(item.subjectId));
      } else {
        // Not all selected -> Select all
        for (final s in targetSubjects) {
          final subId = s['id'] as int;
          final subName = s['name']?.toString() ?? 'Subject';
          final exists = _subjectsList.any((item) => item.subjectId == subId);
          if (!exists) {
            final defaultQs = PilotSubjectConfig.getDefaultQuestionCount(subName);
            final defaultTime = PilotSubjectConfig.getDefaultTimeMinutes(subName);
            final stream = PilotSubjectConfig.getSubjectStream(
              subName,
              dbNatural: s['is_natural'] == true || s['is_natural'] == 1,
              dbCommon: s['is_common'] == true || s['is_common'] == 1,
            );

            _subjectsList.add(
              AdminPilotExamSubjectModel(
                id: 0,
                pilotExamId: widget.exam?.id ?? 0,
                subjectId: subId,
                subjectName: subName,
                stream: stream,
                testId: null,
                orderIndex: _subjectsList.length + 1,
                questionCount: defaultQs,
                timeMinutes: defaultTime,
              ),
            );
          }
        }
      }
    });
  }

  /// Auto-selects all standard subjects for the currently active stream.
  void _autoSelectStreamSubjects() {
    _toggleSelectAllStreamSubjects();
  }

  List<Map<String, dynamic>> get _filteredAvailableSubjects {
    if (_availableSubjects.isEmpty) return [];

    if (_selectedStream == 'natural') {
      return _availableSubjects.where((s) {
        final name = s['name']?.toString() ?? '';
        final dbCommon = s['is_common'] == true || s['is_common'] == 1;
        final dbNatural = s['is_natural'] == true || s['is_natural'] == 1;
        return PilotSubjectConfig.isCommon(name, dbCommon: dbCommon) ||
            PilotSubjectConfig.isNaturalOnly(name, dbNatural: dbNatural);
      }).toList();
    } else if (_selectedStream == 'social') {
      return _availableSubjects.where((s) {
        final name = s['name']?.toString() ?? '';
        final dbCommon = s['is_common'] == true || s['is_common'] == 1;
        final dbNatural = s['is_natural'] == true || s['is_natural'] == 1;
        return PilotSubjectConfig.isCommon(name, dbCommon: dbCommon) ||
            PilotSubjectConfig.isSocialOnly(name, dbNatural: dbNatural);
      }).toList();
    } else {
      return _availableSubjects;
    }
  }

  void _openTestPickerForSubject(int index) {
    if (index < 0 || index >= _subjectsList.length) return;
    final subject = _subjectsList[index];

    showDialog<Map<String, dynamic>?>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _SearchableTestPickerDialog(
        subjectId: subject.subjectId,
        subjectName: subject.subjectName,
        currentTestId: subject.testId,
        repo: _repo,
      ),
    ).then((result) {
      if (result != null && mounted) {
        final newTestId = result['id'] as int?;
        final newTestTitle = result['title']?.toString() ?? '';
        setState(() {
          if (newTestId != null) {
            _testTitles[newTestId] = newTestTitle;
          }
          _subjectsList[index] = _subjectsList[index].copyWith(
            testId: newTestId,
          );
        });
      }
    });
  }

  void _openSubjectDialog({AdminPilotExamSubjectModel? existing, int? index}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _PilotSubjectDialog(
        existing: existing,
        availableSubjects: _availableSubjects,
        repo: _repo,
        onSaved: (subjectModel) {
          setState(() {
            if (index != null && index >= 0 && index < _subjectsList.length) {
              _subjectsList[index] = subjectModel;
            } else {
              // If already exists, replace or update
              final existingIdx = _subjectsList.indexWhere(
                (s) => s.subjectId == subjectModel.subjectId && s.stream == subjectModel.stream,
              );
              if (existingIdx != -1) {
                _subjectsList[existingIdx] = subjectModel;
              } else {
                _subjectsList.add(subjectModel);
              }
            }
          });
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_subjectsList.isEmpty) {
      SnackbarHelper.warning(
        'Subjects Required',
        'Please select at least 1 subject to include in this pilot exam.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final examPayload = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'edition': _editionCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'grade': _selectedGrade ?? 12,
        'is_premium': _isPremium,
        'is_active': _status == 'published',
        'status': _status,
      };

      if (isEditing && widget.exam!.id > 0) {
        examPayload['id'] = widget.exam!.id;
      }

      final savedExam = await _repo.upsertPilotExam(examPayload);
      final examId = savedExam.id;

      // Sync linked subjects safely without duplicates or constraint violations
      final subjectsData = <Map<String, dynamic>>[];
      for (var i = 0; i < _subjectsList.length; i++) {
        final s = _subjectsList[i];
        subjectsData.add({
          if (s.id > 0) 'id': s.id,
          'pilot_exam_id': examId,
          'subject_id': s.subjectId,
          'subject_name': s.subjectName,
          'stream': s.stream.toLowerCase(),
          'test_id': s.testId,
          'order_index': i + 1,
          'question_count': s.questionCount,
          'time_minutes': s.timeMinutes,
        });
      }

      await _repo.syncPilotExamSubjects(
        pilotExamId: examId,
        subjectsData: subjectsData,
      );

      if (Get.isRegistered<PilotExamsController>()) {
        PilotExamsController.instance.loadPilotExams();
      }

      SnackbarHelper.success(
        'Saved Successfully',
        isEditing
            ? 'Pilot Exam updated with ${_subjectsList.length} subjects.'
            : 'Pilot Exam created with ${_subjectsList.length} subjects.',
      );
      Get.back(result: true);
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Pilot Exam' : 'Create Pilot Exam'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: AdminScaffold(
        maxContentWidth: 920,
        body: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── General Details Section ──────────────────────────────────
              AdminSection(
                title: 'General Details',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;
                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextFormField(
                                controller: _titleCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Exam Title *',
                                  hintText: 'e.g. 1st Semester Pilot Model Exam',
                                  prefixIcon: Icon(Iconsax.award_copy, size: 20),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Title is required';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: AppSizes.spaceBtwInputFields),
                              TextFormField(
                                controller: _editionCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Edition / Year *',
                                  hintText: 'e.g. 2019 E.C.',
                                  prefixIcon: Icon(Iconsax.calendar_1_copy, size: 20),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Edition is required';
                                  }
                                  return null;
                                },
                              ),
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: _titleCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Exam Title *',
                                  hintText: 'e.g. 1st Semester Pilot Model Exam',
                                  prefixIcon: Icon(Iconsax.award_copy, size: 20),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Title is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: AppSizes.spaceBtwInputFields),
                            Expanded(
                              child: TextFormField(
                                controller: _editionCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Edition / Year *',
                                  hintText: 'e.g. 2019 E.C.',
                                  prefixIcon: Icon(Iconsax.calendar_1_copy, size: 20),
                                ),
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Edition is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // Grade dropdown
                    DropdownButtonFormField<int?>(
                      initialValue: _selectedGrade,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Grade Level (Optional)',
                        prefixIcon: Icon(Iconsax.teacher_copy, size: 20),
                      ),
                      items: const [
                        DropdownMenuItem<int?>(
                          value: null,
                          child: Text('All Grades / National (Optional)'),
                        ),
                        DropdownMenuItem(value: 9, child: Text('Grade 9')),
                        DropdownMenuItem(value: 10, child: Text('Grade 10')),
                        DropdownMenuItem(value: 11, child: Text('Grade 11')),
                        DropdownMenuItem(value: 12, child: Text('Grade 12 (Matric Entrance)')),
                      ],
                      onChanged: (val) {
                        setState(() => _selectedGrade = val);
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Simulates the nationwide entrance model examination standard...',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // 1. Exam Status Dropdown (Dedicated Full Row)
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Exam Status *',
                        helperText: _status == 'published'
                            ? 'Live for students nationwide'
                            : _status == 'inactive'
                                ? 'Temporarily deactivated / hidden'
                                : _status == 'archived'
                                    ? 'Archived exam'
                                    : 'Draft / Unverified (hidden from students)',
                        helperMaxLines: 2,
                        prefixIcon: Icon(
                          _status == 'published'
                              ? Icons.cloud_done_rounded
                              : _status == 'inactive'
                                  ? Icons.pause_circle_outline_rounded
                                  : _status == 'archived'
                                      ? Icons.archive_outlined
                                      : Icons.edit_note_rounded,
                          size: 20,
                          color: _status == 'published'
                              ? AppColors.success
                              : _status == 'inactive'
                                  ? AppColors.grey
                                  : _status == 'archived'
                                      ? AppColors.secondary
                                      : AppColors.warning,
                        ),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'draft',
                          child: Text('Draft (Unverified / Hidden from Students)'),
                        ),
                        DropdownMenuItem(
                          value: 'published',
                          child: Text('Published (Live for Students Nationwide)'),
                        ),
                        DropdownMenuItem(
                          value: 'inactive',
                          child: Text('Inactive (Deactivated)'),
                        ),
                        DropdownMenuItem(
                          value: 'archived',
                          child: Text('Archived'),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _status = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // 2. Premium Access Switch (Dedicated Full Row Card)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkSurface : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                        border: Border.all(
                          color: _isPremium
                              ? AppColors.amberAccent.withValues(alpha: 0.6)
                              : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (_isPremium ? AppColors.amberAccent : AppColors.grey).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              _isPremium ? Iconsax.crown_copy : Icons.lock_open_rounded,
                              size: 20,
                              color: _isPremium ? AppColors.amberAccent : AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Premium Access Exam',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _isPremium
                                      ? 'Students require an active subscription to access this pilot exam'
                                      : 'Free exam — accessible to all registered students without subscription',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: dark ? AppColors.darkGrey : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Switch(
                            value: _isPremium,
                            activeThumbColor: AppColors.amberAccent,
                            onChanged: (v) => setState(() => _isPremium = v),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.spaceBtwSections),

              // ── Stream & Subject Breakdown Section ────────────────────────
              AdminSection(
                title: 'Exam Stream & Subjects Configuration',
                trailing: TextButton.icon(
                  onPressed: () => _openSubjectDialog(),
                  icon: const Icon(Iconsax.add_circle_copy, size: 16),
                  label: const Text('Custom Subject', style: TextStyle(fontSize: 12)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Stream Selector Filter
                    Container(
                      padding: const EdgeInsets.all(AppSizes.sm),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkSurface : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                        border: Border.all(
                          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Iconsax.category_copy, size: 16, color: AppColors.primary),
                              const SizedBox(width: 8),
                              const Text(
                                'Select Academic Stream:',
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  _selectedStream == 'natural'
                                      ? 'Natural Sciences'
                                      : _selectedStream == 'social'
                                          ? 'Social Sciences'
                                          : 'Both Streams (10)',
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          LayoutBuilder(
                            builder: (context, streamTabConstraints) {
                              final isNarrowTabs = streamTabConstraints.maxWidth < 540;
                              if (isNarrowTabs) {
                                return Column(
                                  children: [
                                    _StreamSelectTab(
                                      label: 'Natural Stream (6)',
                                      icon: Icons.biotech_rounded,
                                      color: AppColors.success,
                                      isSelected: _selectedStream == 'natural',
                                      onTap: () => _onStreamChanged('natural'),
                                    ),
                                    const SizedBox(height: 6),
                                    _StreamSelectTab(
                                      label: 'Social Stream (6)',
                                      icon: Icons.history_edu_rounded,
                                      color: AppColors.warning,
                                      isSelected: _selectedStream == 'social',
                                      onTap: () => _onStreamChanged('social'),
                                    ),
                                    const SizedBox(height: 6),
                                    _StreamSelectTab(
                                      label: 'Both Streams (All 10)',
                                      icon: Icons.public_rounded,
                                      color: AppColors.info,
                                      isSelected: _selectedStream == 'both',
                                      onTap: () => _onStreamChanged('both'),
                                    ),
                                  ],
                                );
                              }

                              return Row(
                                children: [
                                  Expanded(
                                    child: _StreamSelectTab(
                                      label: 'Natural Stream',
                                      icon: Icons.biotech_rounded,
                                      color: AppColors.success,
                                      isSelected: _selectedStream == 'natural',
                                      onTap: () => _onStreamChanged('natural'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StreamSelectTab(
                                      label: 'Social Stream',
                                      icon: Icons.history_edu_rounded,
                                      color: AppColors.warning,
                                      isSelected: _selectedStream == 'social',
                                      onTap: () => _onStreamChanged('social'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _StreamSelectTab(
                                      label: 'Both Streams',
                                      icon: Icons.public_rounded,
                                      color: AppColors.info,
                                      isSelected: _selectedStream == 'both',
                                      onTap: () => _onStreamChanged('both'),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),

                          // Stream Subject Quick Pickers (Toggle on/off)
                          const Text(
                            'Click a subject to add it. Clicking an already added subject removes it:',
                            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                          ),
                          const SizedBox(height: 8),

                          if (_loadingAvailableSubjects)
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            )
                          else if (_filteredAvailableSubjects.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'No subjects found for this stream in the database.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            )
                          else
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _filteredAvailableSubjects.map((s) {
                                final subId = s['id'] as int;
                                final subName = s['name']?.toString() ?? 'Subject';
                                final isSelected = _subjectsList.any((item) => item.subjectId == subId);
                                final defaultQs = PilotSubjectConfig.getDefaultQuestionCount(subName);
                                final defaultMins = PilotSubjectConfig.getDefaultTimeMinutes(subName);

                                Color streamColor = AppColors.info;
                                if (PilotSubjectConfig.isNaturalOnly(subName)) streamColor = AppColors.success;
                                if (PilotSubjectConfig.isSocialOnly(subName)) streamColor = AppColors.warning;

                                return InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => _toggleSubject(s),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? streamColor.withValues(alpha: dark ? 0.25 : 0.12)
                                          : (dark ? AppColors.darkCard : Colors.white),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isSelected
                                            ? streamColor
                                            : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
                                        width: isSelected ? 1.5 : 1,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isSelected ? Icons.check_circle_rounded : Icons.add_circle_outline_rounded,
                                          size: 16,
                                          color: isSelected ? streamColor : AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          subName,
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                            color: isSelected
                                                ? (dark ? Colors.white : streamColor)
                                                : (dark ? Colors.white70 : AppColors.textPrimary),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          decoration: BoxDecoration(
                                            color: dark ? Colors.black26 : Colors.black12,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '$defaultQs Qs • ${defaultMins}m',
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),

                          // Bottom Actions Bar for Subject Selection
                          LayoutBuilder(
                            builder: (context, actionConstraints) {
                              final isNarrowAction = actionConstraints.maxWidth < 480;
                              final allStreamCount = _selectedStream == 'both' ? 10 : 6;
                              final isAllSelected = _subjectsList.length >= allStreamCount;

                              final countBadge = Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isAllSelected
                                      ? AppColors.success.withValues(alpha: 0.12)
                                      : (dark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isAllSelected
                                        ? AppColors.success.withValues(alpha: 0.4)
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isAllSelected ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                                      size: 13,
                                      color: isAllSelected ? AppColors.success : AppColors.textSecondary,
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${_subjectsList.length} of $allStreamCount subjects selected',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: isAllSelected
                                            ? AppColors.success
                                            : (dark ? Colors.white70 : AppColors.textPrimary),
                                      ),
                                    ),
                                  ],
                                ),
                              );

                              final actionButtons = Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (_subjectsList.isNotEmpty)
                                    OutlinedButton.icon(
                                      style: OutlinedButton.styleFrom(
                                        visualDensity: VisualDensity.compact,
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                                        foregroundColor: AppColors.error,
                                      ),
                                      onPressed: () {
                                        setState(() => _subjectsList.clear());
                                      },
                                      icon: const Icon(Icons.clear_all_rounded, size: 15),
                                      label: const Text('Clear All', style: TextStyle(fontSize: 11.5)),
                                    ),
                                  FilledButton.icon(
                                    style: FilledButton.styleFrom(
                                      visualDensity: VisualDensity.compact,
                                      backgroundColor: _isAllStreamSubjectsSelected
                                          ? (dark ? Colors.white12 : const Color(0xFFE2E8F0))
                                          : AppColors.primary,
                                      foregroundColor: _isAllStreamSubjectsSelected
                                          ? (dark ? Colors.white : AppColors.textPrimary)
                                          : Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    ),
                                    onPressed: _toggleSelectAllStreamSubjects,
                                    icon: Icon(
                                      _isAllStreamSubjectsSelected
                                          ? Icons.remove_done_rounded
                                          : Icons.playlist_add_check_rounded,
                                      size: 16,
                                      color: _isAllStreamSubjectsSelected
                                          ? AppColors.warning
                                          : Colors.white,
                                    ),
                                    label: Text(
                                      _isAllStreamSubjectsSelected
                                          ? (_selectedStream == 'both'
                                              ? 'Deselect All 10 Subjects'
                                              : 'Deselect All 6 Subjects')
                                          : (_selectedStream == 'both'
                                              ? 'Select All 10 Subjects'
                                              : 'Select All 6 Subjects'),
                                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              );

                              if (isNarrowAction) {
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    countBadge,
                                    const SizedBox(height: 8),
                                    actionButtons,
                                  ],
                                );
                              }

                              return Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  countBadge,
                                  actionButtons,
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSizes.spaceBtwSections),

                    // Configured Subjects Breakdown List
                    Text(
                      'Configured Exam Subjects (${_subjectsList.length})',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.sm),

                    if (_subjectsList.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(AppSizes.lg),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                          border: Border.all(
                            color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Iconsax.book_1_copy,
                                size: 36,
                                color: dark ? Colors.white30 : AppColors.darkGrey.withValues(alpha: 0.4),
                              ),
                              const SizedBox(height: AppSizes.sm),
                              const Text(
                                'No subjects configured yet',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Click subjects from the stream picker above or use "Select All 6 Subjects" to populate standard subjects.',
                                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: AppSizes.md),
                              FilledButton.icon(
                                onPressed: _autoSelectStreamSubjects,
                                icon: const Icon(Icons.playlist_add_check, size: 16),
                                label: const Text('Auto-Populate 6 Stream Subjects'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _subjectsList.length,
                        onReorderItem: (oldIndex, newIndex) {
                          setState(() {
                            final item = _subjectsList.removeAt(oldIndex);
                            _subjectsList.insert(newIndex, item);
                          });
                        },
                        itemBuilder: (context, idx) {
                          final s = _subjectsList[idx];
                          Color streamColor = AppColors.info;
                          if (s.isNatural) streamColor = AppColors.success;
                          if (s.isSocial) streamColor = AppColors.warning;

                          final linkedTitle = s.testId != null ? _testTitles[s.testId] : null;

                          return Container(
                            key: ValueKey('configured_sub_${s.subjectId}_${s.stream}_$idx'),
                            margin: const EdgeInsets.only(bottom: AppSizes.sm),
                            padding: const EdgeInsets.all(AppSizes.sm + 2),
                            decoration: BoxDecoration(
                              color: dark ? AppColors.darkSurface : Colors.white,
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                              border: Border.all(
                                color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.02),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: LayoutBuilder(
                              builder: (context, cardConstraints) {
                                final isNarrowCard = cardConstraints.maxWidth < 620;

                                if (isNarrowCard) {
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      // Tier 1: Drag handle, #index, Subject Name, Stream badge, Spacer, Actions
                                      Row(
                                        children: [
                                          ReorderableDragStartListener(
                                            index: idx,
                                            child: const Icon(
                                              Icons.drag_indicator,
                                              size: 20,
                                              color: AppColors.textSecondary,
                                            ),
                                          ),
                                          const SizedBox(width: AppSizes.xs),
                                          Text(
                                            '#${idx + 1}',
                                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                          ),
                                          const SizedBox(width: AppSizes.xs),
                                          Flexible(
                                            child: Text(
                                              s.subjectName,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: streamColor.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              s.streamLabel,
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w700,
                                                color: streamColor,
                                              ),
                                            ),
                                          ),
                                          const Spacer(),
                                          IconButton(
                                            icon: const Icon(Iconsax.edit_2_copy, size: 16),
                                            tooltip: 'Edit Subject Configuration',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () => _openSubjectDialog(existing: s, index: idx),
                                          ),
                                          IconButton(
                                            icon: const Icon(Iconsax.trash_copy, size: 16, color: AppColors.error),
                                            tooltip: 'Remove Subject',
                                            visualDensity: VisualDensity.compact,
                                            onPressed: () {
                                              setState(() => _subjectsList.removeAt(idx));
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),

                                      // Tier 2: Linked Test button, Questions input, Minutes input
                                      Row(
                                        children: [
                                          Expanded(
                                            child: InkWell(
                                              borderRadius: BorderRadius.circular(6),
                                              onTap: () => _openTestPickerForSubject(idx),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: s.testId != null
                                                      ? AppColors.primary.withValues(alpha: 0.08)
                                                      : (dark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: s.testId != null
                                                        ? AppColors.primary.withValues(alpha: 0.3)
                                                        : Colors.transparent,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      s.testId != null ? Iconsax.task_copy : Iconsax.search_normal_1_copy,
                                                      size: 12,
                                                      color: s.testId != null ? AppColors.primary : AppColors.textSecondary,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        s.testId != null
                                                            ? 'Test #${s.testId}${linkedTitle != null ? ' • $linkedTitle' : ''}'
                                                            : 'Link Test (ID Search)',
                                                        style: TextStyle(
                                                          fontSize: 10.5,
                                                          fontWeight: s.testId != null ? FontWeight.bold : FontWeight.normal,
                                                          color: s.testId != null ? AppColors.primary : AppColors.textSecondary,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 2),
                                                    const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.textSecondary),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          SizedBox(
                                            width: 78,
                                            child: TextFormField(
                                              key: ValueKey('q_input_${s.subjectId}_${s.questionCount}'),
                                              initialValue: s.questionCount.toString(),
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              decoration: const InputDecoration(
                                                labelText: 'Qs',
                                                labelStyle: TextStyle(fontSize: 10),
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                              ),
                                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                              onChanged: (val) {
                                                final count = int.tryParse(val.trim());
                                                if (count != null && count > 0) {
                                                  _subjectsList[idx] = s.copyWith(questionCount: count);
                                                }
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          SizedBox(
                                            width: 78,
                                            child: TextFormField(
                                              key: ValueKey('time_input_${s.subjectId}_${s.timeMinutes}'),
                                              initialValue: s.timeMinutes.toString(),
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                              decoration: const InputDecoration(
                                                labelText: 'Min',
                                                labelStyle: TextStyle(fontSize: 10),
                                                isDense: true,
                                                contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                              ),
                                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold),
                                              onChanged: (val) {
                                                final mins = int.tryParse(val.trim());
                                                if (mins != null && mins > 0) {
                                                  _subjectsList[idx] = s.copyWith(timeMinutes: mins);
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  );
                                }

                                return Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: idx,
                                      child: const Icon(
                                        Icons.drag_indicator,
                                        size: 20,
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.sm),
                                    Text(
                                      '#${idx + 1}',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
                                    ),
                                    const SizedBox(width: AppSizes.sm),

                                    // Subject Name & Stream Badge
                                    Expanded(
                                      flex: 3,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Row(
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  s.subjectName,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                decoration: BoxDecoration(
                                                  color: streamColor.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  s.streamLabel,
                                                  style: TextStyle(
                                                    fontSize: 9.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: streamColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 4),

                                          // Linked Test pill button (with Search by ID)
                                          InkWell(
                                            borderRadius: BorderRadius.circular(6),
                                            onTap: () => _openTestPickerForSubject(idx),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: s.testId != null
                                                    ? AppColors.primary.withValues(alpha: 0.08)
                                                    : (dark ? Colors.white10 : Colors.black.withValues(alpha: 0.04)),
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: s.testId != null
                                                      ? AppColors.primary.withValues(alpha: 0.3)
                                                      : Colors.transparent,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    s.testId != null ? Iconsax.task_copy : Iconsax.search_normal_1_copy,
                                                    size: 12,
                                                    color: s.testId != null ? AppColors.primary : AppColors.textSecondary,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Flexible(
                                                    child: Text(
                                                      s.testId != null
                                                          ? 'Test #${s.testId}${linkedTitle != null ? ' • $linkedTitle' : ''}'
                                                          : 'Link Test (ID Search)',
                                                      style: TextStyle(
                                                        fontSize: 10.5,
                                                        fontWeight: s.testId != null ? FontWeight.bold : FontWeight.normal,
                                                        color: s.testId != null ? AppColors.primary : AppColors.textSecondary,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 4),
                                                  const Icon(Icons.arrow_drop_down, size: 14, color: AppColors.textSecondary),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.sm),

                                    // Questions count input (Editable)
                                    SizedBox(
                                      width: 86,
                                      child: TextFormField(
                                        key: ValueKey('q_input_${s.subjectId}_${s.questionCount}'),
                                        initialValue: s.questionCount.toString(),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        decoration: const InputDecoration(
                                          labelText: 'Questions',
                                          labelStyle: TextStyle(fontSize: 10),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        onChanged: (val) {
                                          final count = int.tryParse(val.trim());
                                          if (count != null && count > 0) {
                                            _subjectsList[idx] = s.copyWith(questionCount: count);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.sm),

                                    // Time in minutes input (Editable)
                                    SizedBox(
                                      width: 86,
                                      child: TextFormField(
                                        key: ValueKey('time_input_${s.subjectId}_${s.timeMinutes}'),
                                        initialValue: s.timeMinutes.toString(),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                        decoration: const InputDecoration(
                                          labelText: 'Minutes',
                                          labelStyle: TextStyle(fontSize: 10),
                                          isDense: true,
                                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                        ),
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        onChanged: (val) {
                                          final mins = int.tryParse(val.trim());
                                          if (mins != null && mins > 0) {
                                            _subjectsList[idx] = s.copyWith(timeMinutes: mins);
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: AppSizes.sm),

                                    // Edit Subject Details button
                                    IconButton(
                                      icon: const Icon(Iconsax.edit_2_copy, size: 16),
                                      tooltip: 'Edit Subject Configuration',
                                      onPressed: () => _openSubjectDialog(existing: s, index: idx),
                                    ),

                                    // Remove Subject button
                                    IconButton(
                                      icon: const Icon(Iconsax.trash_copy, size: 16, color: AppColors.error),
                                      tooltip: 'Remove Subject',
                                      onPressed: () {
                                        setState(() => _subjectsList.removeAt(idx));
                                      },
                                    ),
                                  ],
                                );
                              },
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.spaceBtwSections * 1.5),

              // ── Save Actions ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  SizedBox(
                    height: 38,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: _isSaving ? null : () => Get.back(),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: AppSizes.spaceBtwItems),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: _isSaving ? null : _save,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check, size: 16),
                      label: Text(
                        _isSaving
                            ? 'Saving...'
                            : (isEditing ? 'Update Pilot Exam' : 'Create Pilot Exam'),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSizes.spaceBtwSections),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreamSelectTab extends StatelessWidget {
  const _StreamSelectTab({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: dark ? 0.30 : 0.15)
              : (dark ? AppColors.darkCard : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : (dark ? AppColors.darkBorder : AppColors.borderPrimary),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? color : AppColors.textSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected
                      ? (dark ? Colors.white : color)
                      : (dark ? Colors.white70 : AppColors.textPrimary),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog for selecting and searching tests by Test ID and by Title.
class _SearchableTestPickerDialog extends StatefulWidget {
  const _SearchableTestPickerDialog({
    required this.subjectId,
    required this.subjectName,
    this.currentTestId,
    required this.repo,
  });

  final int subjectId;
  final String subjectName;
  final int? currentTestId;
  final PilotExamsRepository repo;

  @override
  State<_SearchableTestPickerDialog> createState() => _SearchableTestPickerDialogState();
}

class _SearchableTestPickerDialogState extends State<_SearchableTestPickerDialog> {
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _tests = [];
  bool _isLoading = true;
  String _searchQuery = '';
  bool _isSearchingDirect = false;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTests() async {
    setState(() => _isLoading = true);
    try {
      final list = await widget.repo.fetchTestsForSubject(widget.subjectId);

      // If currentTestId is not among subject tests, fetch it directly
      if (widget.currentTestId != null && !list.any((t) => t['id'] == widget.currentTestId)) {
        final currentTest = await widget.repo.fetchTestById(widget.currentTestId!);
        if (currentTest != null) {
          list.insert(0, currentTest);
        }
      }

      if (!mounted) return;
      setState(() {
        _tests = list;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchDirectId(int testId) async {
    setState(() => _isSearchingDirect = true);
    try {
      final direct = await widget.repo.fetchTestById(testId);
      if (!mounted) return;
      if (direct != null) {
        setState(() {
          if (!_tests.any((t) => t['id'] == direct['id'])) {
            _tests.insert(0, direct);
          }
          _isSearchingDirect = false;
        });
      } else {
        setState(() => _isSearchingDirect = false);
        SnackbarHelper.warning('Not Found', 'No test with ID #$testId was found in the database.');
      }
    } catch (_) {
      if (mounted) setState(() => _isSearchingDirect = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_searchQuery.isEmpty) return _tests;

    final q = _searchQuery.trim().toLowerCase();
    final cleanId = q.replaceAll('#', '').trim();

    return _tests.where((t) {
      final idStr = t['id']?.toString() ?? '';
      final titleStr = (t['title'] ?? '').toString().toLowerCase();

      final matchesId = idStr == cleanId || idStr.contains(cleanId);
      final matchesTitle = titleStr.contains(q);

      return matchesId || matchesTitle;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final cleanQueryId = int.tryParse(_searchQuery.replaceAll('#', '').trim());

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      title: Row(
        children: [
          const Icon(Iconsax.task_copy, size: 20, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Test for ${widget.subjectName}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Search tests by Test ID or title',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 520,
        height: 440,
        child: Column(
          children: [
            // Search Input with ID Searching
            TextField(
              controller: _searchCtrl,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Search by Test ID (e.g. 104) or title...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Iconsax.search_normal_1_copy, size: 16),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
              ),
              style: const TextStyle(fontSize: 13),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
            const SizedBox(height: 10),

            // Direct ID Search Action if query is an ID not found in list
            if (cleanQueryId != null && !_filtered.any((t) => t['id'] == cleanQueryId))
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: _isSearchingDirect ? null : () => _searchDirectId(cleanQueryId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 16, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Lookup Test ID #$cleanQueryId in Database...',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                          ),
                        ),
                        if (_isSearchingDirect)
                          const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ),
                  ),
                ),
              ),

            // Test List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        // Unlink / None option
                        ListTile(
                          dense: true,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          leading: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: dark ? Colors.white10 : Colors.black12,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.block, size: 16, color: AppColors.textSecondary),
                          ),
                          title: const Text('None (No Linked Test)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          subtitle: const Text('Questions configured manually or offline', style: TextStyle(fontSize: 10.5)),
                          trailing: widget.currentTestId == null
                              ? const Icon(Icons.check, size: 18, color: AppColors.primary)
                              : null,
                          onTap: () => Navigator.of(context).pop({'id': null, 'title': ''}),
                        ),
                        const Divider(height: 8),

                        if (_filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(24),
                            child: Center(
                              child: Text(
                                'No matching tests found.',
                                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                            ),
                          )
                        else
                          ..._filtered.map((t) {
                            final tid = t['id'] as int;
                            final isCur = widget.currentTestId == tid;
                            final qCount = t['question_count'] ?? 0;
                            final timeMins = t['time'] ?? 0;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              decoration: BoxDecoration(
                                color: isCur
                                    ? AppColors.primary.withValues(alpha: dark ? 0.20 : 0.08)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                dense: true,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                leading: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '#$tid',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  t['title']?.toString() ?? 'Untitled Test',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: isCur ? FontWeight.bold : FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '$qCount Questions • $timeMins Mins',
                                  style: const TextStyle(fontSize: 10.5, color: AppColors.textSecondary),
                                ),
                                trailing: isCur
                                    ? const Icon(Icons.check_circle_rounded, size: 18, color: AppColors.primary)
                                    : null,
                                onTap: () => Navigator.of(context).pop({
                                  'id': tid,
                                  'title': t['title']?.toString() ?? 'Test #$tid',
                                }),
                              ),
                            );
                          }),
                      ],
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _PilotSubjectDialog extends StatefulWidget {
  const _PilotSubjectDialog({
    this.existing,
    required this.availableSubjects,
    required this.repo,
    required this.onSaved,
  });

  final AdminPilotExamSubjectModel? existing;
  final List<Map<String, dynamic>> availableSubjects;
  final PilotExamsRepository repo;
  final void Function(AdminPilotExamSubjectModel model) onSaved;

  @override
  State<_PilotSubjectDialog> createState() => _PilotSubjectDialogState();
}

class _PilotSubjectDialogState extends State<_PilotSubjectDialog> {
  final _formKey = GlobalKey<FormState>();

  int? _subjectId;
  String _stream = 'natural';
  late final TextEditingController _qCountCtrl;
  late final TextEditingController _timeCtrl;
  int? _testId;
  String? _testTitle;

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _subjectId = ex?.subjectId ?? (widget.availableSubjects.isNotEmpty ? widget.availableSubjects.first['id'] as int? : null);
    _stream = ex?.stream.toLowerCase() ?? 'natural';

    final subName = _getCurrentSubjectName();
    final defaultQs = PilotSubjectConfig.getDefaultQuestionCount(subName);
    final defaultTime = PilotSubjectConfig.getDefaultTimeMinutes(subName);

    _qCountCtrl = TextEditingController(text: (ex?.questionCount ?? defaultQs).toString());
    _timeCtrl = TextEditingController(text: (ex?.timeMinutes ?? defaultTime).toString());
    _testId = ex?.testId;

    if (_testId != null) {
      widget.repo.fetchTestById(_testId!).then((t) {
        if (t != null && mounted) {
          setState(() => _testTitle = t['title']?.toString());
        }
      });
    }
  }

  @override
  void dispose() {
    _qCountCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  String _getCurrentSubjectName() {
    return widget.availableSubjects.firstWhereOrNull(
          (s) => s['id'] == _subjectId,
        )?['name']?.toString() ??
        'Subject';
  }

  void _onSubjectSelected(int? val) {
    if (val != null) {
      setState(() {
        _subjectId = val;
        _testId = null;
        _testTitle = null;

        final subName = _getCurrentSubjectName();
        final dbSub = widget.availableSubjects.firstWhereOrNull((s) => s['id'] == val);
        _stream = PilotSubjectConfig.getSubjectStream(
          subName,
          dbNatural: dbSub?['is_natural'] == true || dbSub?['is_natural'] == 1,
          dbCommon: dbSub?['is_common'] == true || dbSub?['is_common'] == 1,
        );

        // Apply national standard defaults
        _qCountCtrl.text = PilotSubjectConfig.getDefaultQuestionCount(subName).toString();
        _timeCtrl.text = PilotSubjectConfig.getDefaultTimeMinutes(subName).toString();
      });
    }
  }

  void _openTestPicker() {
    if (_subjectId == null) return;
    showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (_) => _SearchableTestPickerDialog(
        subjectId: _subjectId!,
        subjectName: _getCurrentSubjectName(),
        currentTestId: _testId,
        repo: widget.repo,
      ),
    ).then((res) {
      if (res != null && mounted) {
        setState(() {
          _testId = res['id'] as int?;
          _testTitle = res['title']?.toString();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing != null ? 'Edit Exam Subject' : 'Add Exam Subject'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 480,
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: _subjectId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Subject *',
                    prefixIcon: Icon(Iconsax.book_copy, size: 20),
                  ),
                  items: widget.availableSubjects.map((s) {
                    return DropdownMenuItem<int>(
                      value: s['id'] as int?,
                      child: Text(s['name']?.toString() ?? 'Subject'),
                    );
                  }).toList(),
                  onChanged: _onSubjectSelected,
                  validator: (v) => v == null ? 'Required' : null,
                ),
                const SizedBox(height: AppSizes.spaceBtwInputFields),

                DropdownButtonFormField<String>(
                  initialValue: _stream,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Stream *',
                    prefixIcon: Icon(Iconsax.category_copy, size: 20),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'natural', child: Text('Natural Stream')),
                    DropdownMenuItem(value: 'social', child: Text('Social Stream')),
                    DropdownMenuItem(value: 'common', child: Text('Common (Both Streams)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _stream = val);
                  },
                ),
                const SizedBox(height: AppSizes.spaceBtwInputFields),

                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qCountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Questions Count',
                          prefixIcon: Icon(Iconsax.hashtag_copy, size: 18),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                    const SizedBox(width: AppSizes.spaceBtwInputFields),
                    Expanded(
                      child: TextFormField(
                        controller: _timeCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        decoration: const InputDecoration(
                          labelText: 'Time (Minutes)',
                          prefixIcon: Icon(Iconsax.clock_copy, size: 18),
                        ),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSizes.spaceBtwInputFields),

                // Linked Test Button (Searchable by ID)
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _openTestPicker,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Linked Test (Optional, ID Search)',
                      prefixIcon: Icon(Iconsax.task_copy, size: 18),
                      suffixIcon: Icon(Icons.search, size: 18),
                    ),
                    child: Text(
                      _testId != null
                          ? 'Test #$_testId${_testTitle != null ? ' • $_testTitle' : ''}'
                          : 'None / Tap to search tests by ID or title',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _testId != null ? FontWeight.bold : FontWeight.normal,
                        color: _testId != null ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) return;

            final subName = _getCurrentSubjectName();
            final model = AdminPilotExamSubjectModel(
              id: widget.existing?.id ?? 0,
              pilotExamId: widget.existing?.pilotExamId ?? 0,
              subjectId: _subjectId!,
              subjectName: subName,
              stream: _stream,
              testId: _testId,
              orderIndex: widget.existing?.orderIndex ?? 1,
              questionCount: int.tryParse(_qCountCtrl.text.trim()) ?? 60,
              timeMinutes: int.tryParse(_timeCtrl.text.trim()) ?? 90,
            );

            widget.onSaved(model);
            Navigator.of(context).pop();
          },
          child: const Text('Save Subject'),
        ),
      ],
    );
  }
}
