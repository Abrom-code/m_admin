import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/data/repositories/notes_repository.dart';
import 'package:m_admin/features/notes/controllers/notes_controller.dart';
import 'package:m_admin/features/notes/models/admin_note_model.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class NoteEditorScreen extends StatefulWidget {
  const NoteEditorScreen({super.key, this.note});

  final AdminNoteModel? note;

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = NotesRepository();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _chapterNumCtrl;
  late final TextEditingController _orderIndexCtrl;
  late final TextEditingController _pageCountCtrl;

  int? _selectedSubjectId;
  int _selectedGrade = 12;
  int? _selectedChapterId;
  bool _isPremium = true;

  // File picking state
  Uint8List? _pickedBytes;
  String? _pickedFileName;
  int _fileSizeBytes = 0;
  String _fileType = 'pdf';
  String? _existingFileKey;
  String? _existingFileUrl;

  List<Map<String, dynamic>> _subjects = [];
  List<Map<String, dynamic>> _chapters = [];
  bool _isLoadingSubjects = true;
  bool _isSaving = false;

  bool get isEditing => widget.note != null;

  @override
  void initState() {
    super.initState();
    final n = widget.note;

    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _descCtrl = TextEditingController(text: n?.description ?? '');
    _chapterNumCtrl = TextEditingController(text: (n?.chapterNumber ?? 1).toString());
    _orderIndexCtrl = TextEditingController(text: (n?.orderIndex ?? 0).toString());
    _pageCountCtrl = TextEditingController(text: (n?.pageCount ?? 0).toString());

    _selectedSubjectId = n?.subjectId;
    _selectedGrade = n?.grade ?? 12;
    _selectedChapterId = n?.chapterId;
    _isPremium = n?.isPremium ?? true;

    _existingFileKey = n?.fileKey;
    _existingFileUrl = n?.fileUrl;
    _fileSizeBytes = n?.fileSizeBytes ?? 0;
    _fileType = n?.fileType ?? 'pdf';

    _loadInitialData();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _chapterNumCtrl.dispose();
    _orderIndexCtrl.dispose();
    _pageCountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final subs = await _repo.fetchSubjects();
      if (!mounted) return;
      setState(() {
        _subjects = subs;
        if (_selectedSubjectId == null && subs.isNotEmpty) {
          _selectedSubjectId = subs.first['id'] as int?;
        }
        _isLoadingSubjects = false;
      });

      if (_selectedSubjectId != null) {
        await _loadChapters();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoadingSubjects = false);
      }
    }
  }

  Future<void> _loadChapters() async {
    if (_selectedSubjectId == null) return;
    try {
      final chs = await _repo.fetchChapters(
        subjectId: _selectedSubjectId!,
        grade: _selectedGrade,
      );
      if (!mounted) return;
      setState(() {
        _chapters = chs;
        if (_selectedChapterId != null &&
            !chs.any((c) => c['id'] == _selectedChapterId)) {
          _selectedChapterId = null;
        }
      });
    } catch (_) {}
  }

  Future<void> _pickPdf() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      final size = file.lengthSync() ?? bytes.length;

      setState(() {
        _pickedBytes = bytes;
        _pickedFileName = file.name;
        _fileSizeBytes = size;
        _fileType = 'pdf';
      });

      SnackbarHelper.success('File Selected', '${file.name} (${_formatBytes(size)})');
    } catch (e) {
      SnackbarHelper.error('File Picker Error', e.toString());
    }
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    final mb = bytes / (1024 * 1024);
    if (mb < 0.1) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${mb.toStringAsFixed(2)} MB';
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedSubjectId == null || _selectedSubjectId! <= 0) {
      SnackbarHelper.warning('Required', 'Please select a subject.');
      return;
    }

    final hasFile = _pickedBytes != null ||
        (_existingFileKey != null && _existingFileKey!.isNotEmpty);
    if (!hasFile) {
      SnackbarHelper.warning('PDF Required', 'Please select a PDF file to upload.');
      return;
    }

    setState(() => _isSaving = true);

    try {
      String fileKey = _existingFileKey ?? '';
      String? fileUrl = _existingFileUrl;

      // Upload if a new file was chosen
      if (_pickedBytes != null && _pickedFileName != null) {
        final uploadResult = await _repo.uploadNotePdf(
          _pickedBytes!,
          _pickedFileName!,
        );
        fileKey = uploadResult['file_key'] ?? fileKey;
        fileUrl = uploadResult['file_url'] ?? fileUrl;
      }

      final payload = <String, dynamic>{
        'subject_id': _selectedSubjectId,
        'chapter_id': _selectedChapterId,
        'grade': _selectedGrade,
        'chapter_number': int.tryParse(_chapterNumCtrl.text.trim()) ?? 1,
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        'file_key': fileKey,
        'file_url': fileUrl,
        'file_type': _fileType,
        'file_size_bytes': _fileSizeBytes,
        'page_count': int.tryParse(_pageCountCtrl.text.trim()) ?? 0,
        'is_premium': _isPremium,
        'order_index': int.tryParse(_orderIndexCtrl.text.trim()) ?? 0,
      };

      if (isEditing && widget.note!.id > 0) {
        payload['id'] = widget.note!.id;
      }

      await _repo.upsertNote(payload);

      if (Get.isRegistered<NotesController>()) {
        NotesController.instance.loadNotes();
      }

      SnackbarHelper.success(
        'Saved',
        isEditing ? 'Note updated successfully.' : 'Note created successfully.',
      );
      Get.back(result: true);
    } catch (e) {
      SnackbarHelper.error('Save failed', e.toString());
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
        title: Text(isEditing ? 'Edit Note' : 'Create New Note'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: AdminScaffold(
        maxContentWidth: 900,
        body: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── General Information Card ─────────────────────────────
              AdminSection(
                title: 'Note Information',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Subject and Grade Row
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;

                        final subjectField = _isLoadingSubjects
                            ? const SizedBox(
                                height: 50,
                                child: Center(
                                  child: LinearProgressIndicator(),
                                ),
                              )
                            : Builder(
                                builder: (context) {
                                  final subjectItems = <DropdownMenuItem<int>>[];
                                  final existingSubjectIds = <int>{};

                                  for (final s in _subjects) {
                                    final id = (s['id'] as num?)?.toInt();
                                    if (id != null) {
                                      existingSubjectIds.add(id);
                                      subjectItems.add(
                                        DropdownMenuItem<int>(
                                          value: id,
                                          child: Text(
                                            s['name']?.toString() ?? 'Subject',
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ),
                                      );
                                    }
                                  }

                                  // If note has a subject not yet in fetched list, add placeholder item
                                  if (_selectedSubjectId != null &&
                                      !existingSubjectIds.contains(_selectedSubjectId)) {
                                    subjectItems.insert(
                                      0,
                                      DropdownMenuItem<int>(
                                        value: _selectedSubjectId,
                                        child: Text(
                                          'Subject #$_selectedSubjectId',
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                        ),
                                      ),
                                    );
                                  }

                                  final effectiveSubjectValue = _selectedSubjectId != null &&
                                          (existingSubjectIds.contains(_selectedSubjectId) ||
                                              widget.note != null)
                                      ? _selectedSubjectId
                                      : (subjectItems.isNotEmpty ? subjectItems.first.value : null);

                                  return DropdownButtonFormField<int>(
                                    key: ValueKey('subject_${effectiveSubjectValue}_${_subjects.length}'),
                                    initialValue: effectiveSubjectValue,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Subject *',
                                      prefixIcon: Icon(Iconsax.book_copy, size: 20),
                                    ),
                                    items: subjectItems,
                                    onChanged: (val) {
                                      setState(() => _selectedSubjectId = val);
                                      _loadChapters();
                                    },
                                    validator: (v) => v == null ? 'Subject is required' : null,
                                  );
                                },
                              );

                        final gradeField = Builder(
                          builder: (context) {
                            final validGrades = [9, 10, 11, 12];
                            final gradeItems = <DropdownMenuItem<int>>[
                              const DropdownMenuItem(value: 9, child: Text('Grade 9', overflow: TextOverflow.ellipsis)),
                              const DropdownMenuItem(value: 10, child: Text('Grade 10', overflow: TextOverflow.ellipsis)),
                              const DropdownMenuItem(value: 11, child: Text('Grade 11', overflow: TextOverflow.ellipsis)),
                              const DropdownMenuItem(value: 12, child: Text('Grade 12', overflow: TextOverflow.ellipsis)),
                            ];

                            if (!validGrades.contains(_selectedGrade)) {
                              gradeItems.insert(
                                0,
                                DropdownMenuItem(
                                  value: _selectedGrade,
                                  child: Text('Grade $_selectedGrade', overflow: TextOverflow.ellipsis),
                                ),
                              );
                            }

                            return DropdownButtonFormField<int>(
                              key: ValueKey('grade_$_selectedGrade'),
                              initialValue: _selectedGrade,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Grade *',
                                prefixIcon: Icon(Iconsax.teacher_copy, size: 20),
                              ),
                              items: gradeItems,
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedGrade = val);
                                  _loadChapters();
                                }
                              },
                            );
                          },
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              subjectField,
                              const SizedBox(height: AppSizes.spaceBtwInputFields),
                              gradeField,
                            ],
                          );
                        }

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: subjectField),
                            const SizedBox(width: AppSizes.spaceBtwInputFields),
                            Expanded(child: gradeField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // Chapter Number & Linked Chapter
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final isNarrow = constraints.maxWidth < 600;

                        final chapterNumField = TextFormField(
                          controller: _chapterNumCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                          decoration: const InputDecoration(
                            labelText: 'Chapter Number *',
                            prefixIcon: Icon(Iconsax.hashtag_copy, size: 20),
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Required';
                            return null;
                          },
                        );

                        final linkedChapterField = Builder(
                          builder: (context) {
                            final chapterItems = <DropdownMenuItem<int?>>[
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('None / Unlinked', overflow: TextOverflow.ellipsis, maxLines: 1),
                              ),
                            ];

                            final existingChapterIds = <int>{};
                            for (final ch in _chapters) {
                              final chId = (ch['id'] as num?)?.toInt();
                              if (chId != null) {
                                existingChapterIds.add(chId);
                                chapterItems.add(
                                  DropdownMenuItem<int?>(
                                    value: chId,
                                    child: Text(
                                      'Ch ${ch['chapter_number']}: ${ch['title']}',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                );
                              }
                            }

                            // Ensure currently selected chapter is always present in items
                            if (_selectedChapterId != null &&
                                !existingChapterIds.contains(_selectedChapterId)) {
                              chapterItems.add(
                                DropdownMenuItem<int?>(
                                  value: _selectedChapterId,
                                  child: Text(
                                    'Chapter #$_selectedChapterId (Linked)',
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
                                  ),
                                ),
                              );
                            }

                            return DropdownButtonFormField<int?>(
                              key: ValueKey('chapter_${_selectedChapterId}_${_chapters.length}'),
                              initialValue: _selectedChapterId,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Linked Chapter (Optional)',
                                prefixIcon: Icon(Iconsax.folder_2_copy, size: 20),
                              ),
                              items: chapterItems,
                              onChanged: (val) => setState(() => _selectedChapterId = val),
                            );
                          },
                        );

                        if (isNarrow) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              chapterNumField,
                              const SizedBox(height: AppSizes.spaceBtwInputFields),
                              linkedChapterField,
                            ],
                          );
                        }

                        return Row(
                          children: [
                            Expanded(child: chapterNumField),
                            const SizedBox(width: AppSizes.spaceBtwInputFields),
                            Expanded(flex: 2, child: linkedChapterField),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // Title
                    TextFormField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Note Title *',
                        hintText: 'e.g. Unit 1: Foundations of Biology',
                        prefixIcon: Icon(Iconsax.document_text_copy, size: 20),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Title is required';
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // Description
                    TextFormField(
                      controller: _descCtrl,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Description (Optional)',
                        hintText: 'Brief summary of what this note covers...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.spaceBtwSections),

              // ── Document File Card ──────────────────────────────────
              AdminSection(
                title: 'PDF Document',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSizes.md),
                      decoration: BoxDecoration(
                        color: dark ? AppColors.darkSurface : AppColors.lightGrey,
                        borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                        border: Border.all(
                          color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                            ),
                            child: const Icon(
                              Iconsax.document_upload_copy,
                              color: AppColors.primary,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: AppSizes.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _pickedFileName ??
                                      (_existingFileKey != null
                                          ? 'Existing: ${_existingFileKey!.split('/').last}'
                                          : 'No file selected'),
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _fileSizeBytes > 0
                                      ? '${_formatBytes(_fileSizeBytes)} • $_fileType.toUpperCase()'
                                      : 'Tap below to select a PDF from your computer',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _pickPdf,
                            icon: const Icon(Iconsax.folder_open_copy, size: 18),
                            label: Text(
                              _pickedBytes != null || _existingFileKey != null
                                  ? 'Change'
                                  : 'Browse',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSizes.spaceBtwInputFields),

                    // Page count and order index
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _pageCountCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Page Count',
                              hintText: 'e.g. 15',
                              prefixIcon: Icon(Iconsax.book_1_copy, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSizes.spaceBtwInputFields),
                        Expanded(
                          child: TextFormField(
                            controller: _orderIndexCtrl,
                            keyboardType: TextInputType.number,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: const InputDecoration(
                              labelText: 'Order Index',
                              hintText: '0',
                              prefixIcon: Icon(Iconsax.sort_copy, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.spaceBtwSections),

              // ── Access & Settings Card ──────────────────────────────
              AdminSection(
                title: 'Access Settings',
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isPremium,
                  onChanged: (val) => setState(() => _isPremium = val),
                  title: const Text(
                    'Premium Only',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(
                    'When enabled, only subscribed students can view and download this note.',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _isPremium
                          ? AppColors.warning.withValues(alpha: 0.12)
                          : AppColors.grey.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Iconsax.crown_copy,
                      color: _isPremium ? AppColors.warning : AppColors.darkGrey,
                      size: 20,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: AppSizes.spaceBtwSections * 1.5),

              // ── Actions ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: _isSaving ? null : () => Get.back(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSizes.spaceBtwItems),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: Text(_isSaving ? 'Saving...' : (isEditing ? 'Update Note' : 'Create Note')),
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
