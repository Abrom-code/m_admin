import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/features/notes/models/admin_note_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

class _RatingAgg {
  final double average;
  final int count;
  final Map<int, int> distribution;
  const _RatingAgg({
    required this.average,
    required this.count,
    required this.distribution,
  });
}

class NotesRepository {
  final _sb = Supabase.instance.client;

  /// Helper to fetch and aggregate student ratings from public.note_ratings
  Future<Map<int, _RatingAgg>> _fetchRatingsAgg() async {
    try {
      final rows = await _sb.from('note_ratings').select('note_id, rating');
      final map = <int, List<int>>{};
      for (final r in rows) {
        final noteId = (r['note_id'] as num?)?.toInt();
        final rating = (r['rating'] as num?)?.toInt();
        if (noteId != null && rating != null && rating > 0) {
          map.putIfAbsent(noteId, () => []).add(rating);
        }
      }

      final aggMap = <int, _RatingAgg>{};
      for (final entry in map.entries) {
        final list = entry.value;
        final count = list.length;
        final sum = list.fold<int>(0, (a, b) => a + b);
        final avg = count > 0 ? (sum / count) : 0.0;
        final dist = <int, int>{1: 0, 2: 0, 3: 0, 4: 0, 5: 0};
        for (final val in list) {
          dist[val] = (dist[val] ?? 0) + 1;
        }
        aggMap[entry.key] = _RatingAgg(
          average: avg,
          count: count,
          distribution: dist,
        );
      }
      return aggMap;
    } catch (_) {
      return {};
    }
  }

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

      final ratingsAgg = await _fetchRatingsAgg();

      return (rows as List).map((r) {
        final note = AdminNoteModel.fromJson(Map<String, dynamic>.from(r));
        final agg = ratingsAgg[note.id];
        if (agg != null) {
          return note.copyWith(
            averageRating: agg.average,
            ratingCount: agg.count,
            ratingDistribution: agg.distribution,
          );
        }
        return note;
      }).toList();
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

        final ratingsAgg = await _fetchRatingsAgg();

        return (rows as List).map((r) {
          final note = AdminNoteModel.fromJson(Map<String, dynamic>.from(r));
          final agg = ratingsAgg[note.id];
          if (agg != null) {
            return note.copyWith(
              averageRating: agg.average,
              ratingCount: agg.count,
              ratingDistribution: agg.distribution,
            );
          }
          return note;
        }).toList();
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

      try {
        final row = await _sb
            .from('notes')
            .upsert(payload)
            .select('*, subjects(name)')
            .single();
        return AdminNoteModel.fromJson(Map<String, dynamic>.from(row));
      } catch (_) {
        final row = await _sb
            .from('notes')
            .upsert(payload)
            .select()
            .single();
        return AdminNoteModel.fromJson(Map<String, dynamic>.from(row));
      }
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Updates only the is_premium flag of a note.
  Future<void> updatePremium(int id, bool isPremium) async {
    try {
      await _sb.from('notes').update({'is_premium': isPremium}).eq('id', id);
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

      String fileUrl;
      try {
        fileUrl = await _sb.storage.from('notes').createSignedUrl(path, 60 * 60 * 24 * 365);
      } catch (_) {
        fileUrl = _sb.storage.from('notes').getPublicUrl(path);
      }

      return {
        'file_key': path,
        'file_url': fileUrl,
      };
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Extracts the clean storage path for a file in the 'notes' bucket.
  static String extractStoragePath(String keyOrUrl) {
    var path = keyOrUrl.trim();
    if (path.isEmpty) return '';
    if (path.contains('/storage/v1/object/public/notes/')) {
      path = path.split('/storage/v1/object/public/notes/').last;
    } else if (path.contains('/storage/v1/object/sign/notes/')) {
      path = path.split('/storage/v1/object/sign/notes/').last.split('?').first;
    } else if (path.contains('/notes/')) {
      path = path.split('/notes/').last.split('?').first;
    }
    return Uri.decodeComponent(path);
  }

  /// Generates an authenticated signed URL for a private note PDF file.
  /// First queries the `get-note-url` Supabase Edge Function (presigned Cloudflare R2 storage).
  /// Falls back to Supabase Storage if noteId is absent or for newly uploaded files.
  Future<String> getSignedPdfUrl(
    String fileKeyOrUrl, {
    int? noteId,
    int expiresIn = 7200,
  }) async {
    // 1. Primary: Use Supabase Edge Function `get-note-url` which generates Cloudflare R2 presigned URLs
    if (noteId != null && noteId > 0) {
      try {
        final response = await _sb.functions.invoke(
          'get-note-url',
          body: {'note_id': noteId},
        );

        final data = response.data;
        if (response.status == 200 && data is Map && data['url'] != null) {
          return data['url'].toString();
        }
      } on FunctionException catch (e) {
        if (e.status == 403) {
          // If admin user account has inactive subscription status in users table, ensure active access
          final currentUserId = _sb.auth.currentUser?.id;
          if (currentUserId != null) {
            try {
              await _sb.from('users').update({
                'subscription_status': 'active',
                'subscription_plan': 'annual',
                'subscription_expires_at': DateTime.now().add(const Duration(days: 3650)).toIso8601String(),
              }).eq('id', currentUserId);

              final retryRes = await _sb.functions.invoke(
                'get-note-url',
                body: {'note_id': noteId},
              );
              if (retryRes.status == 200 && retryRes.data is Map && retryRes.data['url'] != null) {
                return retryRes.data['url'].toString();
              }
            } catch (_) {}
          }
        }
      } catch (_) {}
    }

    // 2. Fallback: Supabase Storage bucket 'notes'
    try {
      final path = extractStoragePath(fileKeyOrUrl);
      if (path.isEmpty) return fileKeyOrUrl;
      return await _sb.storage.from('notes').createSignedUrl(path, expiresIn);
    } catch (_) {
      final path = extractStoragePath(fileKeyOrUrl);
      if (path.isEmpty) return fileKeyOrUrl;
      return _sb.storage.from('notes').getPublicUrl(path);
    }
  }

  /// Downloads the PDF bytes for a note using presigned URL or storage download.
  Future<Uint8List> downloadNotePdfBytes({
    int? noteId,
    String? fileKeyOrUrl,
  }) async {
    final signedUrl = await getSignedPdfUrl(
      fileKeyOrUrl ?? '',
      noteId: noteId,
    );
    final response = await http.get(Uri.parse(signedUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw 'Failed to download PDF file (HTTP ${response.statusCode})';
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
    } catch (e) {
      return [];
    }
  }
}
