import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:m_admin/common/widgets/admin_scaffold.dart';
import 'package:m_admin/data/repositories/notes_repository.dart';
import 'package:m_admin/utils/constants/colors.dart';
import 'package:m_admin/utils/constants/sizes.dart';
import 'package:m_admin/utils/helpers/helper_functions.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class NotePdfPreviewScreen extends StatefulWidget {
  const NotePdfPreviewScreen({
    super.key,
    required this.title,
    required this.fileName,
    this.fileUrl,
    this.pdfBytes,
    this.fileKey,
    this.fileSizeBytes = 0,
    this.pageCount = 0,
    this.grade,
    this.subjectName,
    this.chapterNumber,
    this.isPremium = true,
  });

  final String title;
  final String fileName;
  final String? fileUrl;
  final Uint8List? pdfBytes;
  final String? fileKey;
  final int fileSizeBytes;
  final int pageCount;
  final int? grade;
  final String? subjectName;
  final int? chapterNumber;
  final bool isPremium;

  @override
  State<NotePdfPreviewScreen> createState() => _NotePdfPreviewScreenState();
}

class _NotePdfPreviewScreenState extends State<NotePdfPreviewScreen> {
  final _repo = NotesRepository();
  String? _resolvedUrl;
  bool _isLoadingUrl = false;

  @override
  void initState() {
    super.initState();
    _resolveUrl();
  }

  Future<void> _resolveUrl({bool forceRefresh = false}) async {
    final key = widget.fileKey?.trim();
    final url = widget.fileUrl?.trim();
    final candidate = (key != null && key.isNotEmpty) ? key : url;
    if (candidate == null || candidate.isEmpty) return;

    setState(() {
      _isLoadingUrl = true;
    });

    try {
      final signedUrl = await _repo.getSignedPdfUrl(candidate, expiresIn: 7200);
      if (mounted) {
        setState(() {
          _resolvedUrl = signedUrl;
          _isLoadingUrl = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _resolvedUrl = url;
          _isLoadingUrl = false;
        });
      }
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

  Future<void> _openPdf() async {
    if (_isLoadingUrl) {
      SnackbarHelper.info('Generating link', 'Please wait while we generate a secure signed URL...');
      return;
    }
    final url = _resolvedUrl ?? widget.fileUrl;
    if (url != null && url.trim().isNotEmpty) {
      try {
        await AppHelperFunctions.openUrl(url.trim());
      } catch (e) {
        SnackbarHelper.error('Error', 'Could not open PDF: $e');
      }
    } else {
      if (widget.pdfBytes != null) {
        SnackbarHelper.info(
          'Local File',
          'This file is currently in memory. Save the note to upload and view via cloud URL.',
        );
      } else {
        SnackbarHelper.warning('No PDF', 'No valid PDF link available.');
      }
    }
  }

  void _copyUrl(BuildContext context) {
    final url = _resolvedUrl ?? widget.fileUrl;
    if (url != null && url.trim().isNotEmpty) {
      Clipboard.setData(ClipboardData(text: url.trim()));
      SnackbarHelper.success('Copied', 'Authenticated PDF URL copied to clipboard.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);
    final hasRemoteUrl = (_resolvedUrl != null && _resolvedUrl!.isNotEmpty) ||
        (widget.fileUrl != null && widget.fileUrl!.trim().isNotEmpty) ||
        (widget.fileKey != null && widget.fileKey!.trim().isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF Document Preview'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
        actions: [
          if (hasRemoteUrl) ...[
            IconButton(
              tooltip: 'Copy PDF Link',
              icon: const Icon(Iconsax.copy_copy, size: 20),
              onPressed: () => _copyUrl(context),
            ),
            IconButton(
              tooltip: 'Open in Browser / External App',
              icon: const Icon(Iconsax.export_copy, size: 20),
              onPressed: _openPdf,
            ),
            const SizedBox(width: AppSizes.sm),
          ],
        ],
      ),
      body: AdminScaffold(
        maxContentWidth: 850,
        body: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: AppSizes.spaceBtwSections * 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Showcase Card ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: dark
                        ? [
                            AppColors.darkSurface,
                            AppColors.darkSurface.withValues(alpha: 0.8),
                          ]
                        : [
                            AppColors.white,
                            AppColors.primary.withValues(alpha: 0.04),
                          ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
                  border: Border.all(
                    color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: dark ? 0.2 : 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                            border: Border.all(
                              color: Colors.redAccent.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Icon(
                            Icons.picture_as_pdf_rounded,
                            color: Colors.redAccent,
                            size: 32,
                          ),
                        ),
                        const SizedBox(width: AppSizes.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title.isNotEmpty ? widget.title : 'Untitled Note',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Iconsax.document_1_copy,
                                    size: 14,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      widget.fileName,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontFamily: 'monospace',
                                        color: dark ? Colors.grey[300] : Colors.grey[800],
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.spaceBtwItems),
                    const Divider(),
                    const SizedBox(height: AppSizes.sm),

                    // Badges row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (widget.grade != null)
                          _Badge(
                            label: 'Grade ${widget.grade}',
                            icon: Iconsax.teacher_copy,
                            color: AppColors.primary,
                          ),
                        if (widget.subjectName != null && widget.subjectName!.isNotEmpty)
                          _Badge(
                            label: widget.subjectName!,
                            icon: Iconsax.book_1_copy,
                            color: Colors.teal,
                          ),
                        if (widget.chapterNumber != null)
                          _Badge(
                            label: 'Chapter ${widget.chapterNumber}',
                            icon: Iconsax.folder_2_copy,
                            color: Colors.indigo,
                          ),
                        if (widget.pageCount > 0)
                          _Badge(
                            label: '${widget.pageCount} pages',
                            icon: Iconsax.book_copy,
                            color: Colors.orange,
                          ),
                        if (widget.fileSizeBytes > 0)
                          _Badge(
                            label: _formatBytes(widget.fileSizeBytes),
                            icon: Iconsax.document_upload_copy,
                            color: Colors.purple,
                          ),
                        _Badge(
                          label: widget.isPremium ? 'PREMIUM' : 'FREE',
                          icon: widget.isPremium ? Iconsax.crown_copy : Iconsax.unlock_copy,
                          color: widget.isPremium ? AppColors.warning : AppColors.success,
                        ),
                        const _Badge(
                          label: 'PRIVATE & SECURE',
                          icon: Iconsax.shield_tick_copy,
                          color: AppColors.info,
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.spaceBtwSections),

              // ── Document Access & Actions ───────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkSurface : AppColors.white,
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
                  border: Border.all(
                    color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document Access',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasRemoteUrl
                          ? 'This PDF document is stored securely in private Supabase Storage. A temporary authenticated signed link is generated automatically for previewing and downloading.'
                          : 'This PDF document is loaded in the editor from your computer and will be uploaded to private Supabase Storage upon saving.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),

                    if (hasRemoteUrl) ...[
                      // Selectable URL Box
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSizes.md,
                          vertical: AppSizes.sm,
                        ),
                        decoration: BoxDecoration(
                          color: dark ? AppColors.darkCard : AppColors.lightGrey,
                          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                          border: Border.all(
                            color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.link_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSizes.sm),
                            Expanded(
                              child: _isLoadingUrl
                                  ? const Row(
                                      children: [
                                        SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Generating secure authenticated link...',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    )
                                  : SelectableText(
                                      _resolvedUrl ?? widget.fileUrl ?? 'No URL generated',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                      ),
                                      maxLines: 1,
                                    ),
                            ),
                            const SizedBox(width: AppSizes.sm),
                            if (!_isLoadingUrl && (_resolvedUrl != null || widget.fileUrl != null))
                              TextButton.icon(
                                onPressed: () => _copyUrl(context),
                                icon: const Icon(Iconsax.copy_copy, size: 14),
                                label: const Text('Copy'),
                                style: TextButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSizes.spaceBtwItems),

                      // Action Buttons
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        children: [
                          FilledButton.icon(
                            onPressed: _openPdf,
                            icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                            label: const Text('Open PDF in Browser / Reader'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 18,
                                vertical: 12,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => _copyUrl(context),
                            icon: const Icon(Iconsax.copy_copy, size: 16),
                            label: const Text('Copy Direct Link'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _isLoadingUrl ? null : () => _resolveUrl(forceRefresh: true),
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Refresh Link'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      // Local file badge
                      Container(
                        padding: const EdgeInsets.all(AppSizes.md),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppSizes.borderRadiusMd),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Iconsax.info_circle_copy,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: AppSizes.sm + 4),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Local File Pending Upload',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Size: ${_formatBytes(widget.fileSizeBytes)} • Return to the editor and tap "Update Note" or "Create Note" to complete the cloud upload.',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.spaceBtwSections),

              // ── Technical Metadata Card ─────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  color: dark ? AppColors.darkSurface : AppColors.white,
                  borderRadius: BorderRadius.circular(AppSizes.borderRadiusLg),
                  border: Border.all(
                    color: dark ? AppColors.darkBorder : AppColors.borderPrimary,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Document Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    _DetailRow(
                      label: 'Document Title',
                      value: widget.title.isNotEmpty ? widget.title : '—',
                    ),
                    _DetailRow(label: 'File Name', value: widget.fileName),
                    _DetailRow(
                      label: 'Grade Level',
                      value: widget.grade != null ? 'Grade ${widget.grade}' : '—',
                    ),
                    _DetailRow(
                      label: 'Subject',
                      value: widget.subjectName ?? '—',
                    ),
                    _DetailRow(
                      label: 'Chapter Number',
                      value: widget.chapterNumber != null ? 'Chapter ${widget.chapterNumber}' : '—',
                    ),
                    _DetailRow(
                      label: 'Page Count',
                      value: widget.pageCount > 0 ? '${widget.pageCount} pages' : '—',
                    ),
                    _DetailRow(
                      label: 'File Size',
                      value: _formatBytes(widget.fileSizeBytes),
                    ),
                    _DetailRow(
                      label: 'Access Level',
                      value: widget.isPremium ? 'Premium (Subscribers only)' : 'Free (Open access)',
                    ),
                    if (widget.fileKey != null && widget.fileKey!.isNotEmpty)
                      _DetailRow(label: 'Storage Path', value: widget.fileKey!),
                    const _DetailRow(label: 'Storage Bucket', value: 'notes (Private - Authenticated)'),
                  ],
                ),
              ),

              const SizedBox(height: AppSizes.spaceBtwSections),

              // Bottom Dismiss Button
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton(
                  onPressed: () => Get.back(),
                  child: const Text('Back to Editor'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final dark = AppHelperFunctions.isDark(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: dark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
