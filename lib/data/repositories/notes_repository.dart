import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/features/notes/models/admin_note_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

class NotesRepository {
  final _sb = Supabase.instance.client;

  /// Fetches notes optionally filtered by [subjectId] and/or [grade].
  Future<List<AdminNoteModel>> fetchNotes({
    int? subjectId,
    int? grade,
  }) async {
    try {
      var query = _sb.from('notes').select('*, subjects(name)');

      if (subjectId != null && subjectId > 0) {
        query = query.eq('subject_id', subjectId);
      }
      if (grade != null && grade > 0) {
        query = query.eq('grade', grade);
      }

      final rows = await query
          .order('grade', ascending: true)
          .order('chapter_number', ascending: true)
          .order('order_index', ascending: true);

      return (rows as List)
          .map((r) => AdminNoteModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      // Fallback without relation join if foreign key alias differs
      try {
        var fallbackQuery = _sb.from('notes').select();
        if (subjectId != null && subjectId > 0) {
          fallbackQuery = fallbackQuery.eq('subject_id', subjectId);
        }
        if (grade != null && grade > 0) {
          fallbackQuery = fallbackQuery.eq('grade', grade);
        }
        final rows = await fallbackQuery
            .order('grade', ascending: true)
            .order('chapter_number', ascending: true);
        return (rows as List)
            .map((r) => AdminNoteModel.fromJson(Map<String, dynamic>.from(r)))
            .toList();
      } catch (fallbackError) {
        throw AppExceptionHandler.handle(fallbackError);
      }
    }
  }

  /// Inserts or updates a note record.
  Future<AdminNoteModel> upsertNote(Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      if (payload['id'] == null || payload['id'] == 0) {
        payload.remove('id');
      }

      final row = await _sb
          .from('notes')
          .upsert(payload)
          .select('*, subjects(name)')
          .single();

      return AdminNoteModel.fromJson(Map<String, dynamic>.from(row));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Deletes a note and optionally its PDF from Supabase storage.
  Future<void> deleteNote(int id, {String? fileKey}) async {
    try {
      await _sb.from('notes').delete().eq('id', id);

      if (fileKey != null && fileKey.trim().isNotEmpty) {
        try {
          await _sb.storage.from('notes').remove([fileKey.trim()]);
        } catch (_) {
          // Non-critical: table record is already deleted
        }
      }
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Uploads a note PDF to the `notes` bucket.
  /// Returns a map with `file_key` and `file_url`.
  Future<Map<String, String>> uploadNotePdf(
    Uint8List bytes,
    String fileName,
  ) async {
    try {
      final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

      await _sb.storage.from('notes').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/pdf',
              upsert: true,
            ),
          );

      final publicUrl = _sb.storage.from('notes').getPublicUrl(path);

      return {
        'file_key': path,
        'file_url': publicUrl,
      };
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Fetches all subjects for dropdowns.
  Future<List<Map<String, dynamic>>> fetchSubjects() async {
    try {
      final rows = await _sb
          .from('subjects')
          .select('id, name')
          .order('name', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Fetches chapters for a subject and optional grade.
  Future<List<Map<String, dynamic>>> fetchChapters({
    required int subjectId,
    int? grade,
  }) async {
    try {
      var query = _sb.from('chapters').select().eq('subject_id', subjectId);
      if (grade != null && grade > 0) {
        query = query.eq('grade', grade);
      }
      final rows = await query.order('chapter_number', ascending: true);
      return List<Map<String, dynamic>>.from(rows);
    } catch (_) {
      return [];
    }
  }
}
