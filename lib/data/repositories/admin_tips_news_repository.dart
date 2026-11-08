import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:m_admin/features/tips_and_news/models/admin_tip_news_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';

/// Repository for Admin CRUD and toggles on `public.tips_and_news`.
class AdminTipsNewsRepository {
  AdminTipsNewsRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _sb => _client ?? Supabase.instance.client;

  /// Fetches all tips and news entries ordered by pinned status and created_at.
  Future<List<AdminTipNewsModel>> fetchAll({
    String? search,
    String? category,
    String? audience,
  }) async {
    try {
      var query = _sb.from('tips_and_news').select('*');

      if (category != null && category.isNotEmpty && category != 'all') {
        query = query.eq('category', category.toLowerCase());
      }
      if (audience != null && audience.isNotEmpty && audience != 'all') {
        query = query.eq('audience', audience.toLowerCase());
      }
      if (search != null && search.trim().isNotEmpty) {
        query = query.or('title.ilike.%${search.trim()}%,content.ilike.%${search.trim()}%');
      }

      final rows = await query
          .order('is_pinned', ascending: false)
          .order('created_at', ascending: false)
          .timeout(const Duration(seconds: 15));

      return (rows as List)
          .map((r) => AdminTipNewsModel.fromJson(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Inserts a new tip or news entry.
  Future<AdminTipNewsModel> create(AdminTipNewsModel item) async {
    try {
      final payload = item.toUpsertJson();
      final res = await _sb
          .from('tips_and_news')
          .insert(payload)
          .select()
          .single()
          .timeout(const Duration(seconds: 15));

      return AdminTipNewsModel.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Updates an existing tip or news entry by ID.
  Future<AdminTipNewsModel> update(AdminTipNewsModel item) async {
    try {
      final payload = item.toUpsertJson();
      final res = await _sb
          .from('tips_and_news')
          .update(payload)
          .eq('id', item.id)
          .select()
          .single()
          .timeout(const Duration(seconds: 15));

      return AdminTipNewsModel.fromJson(Map<String, dynamic>.from(res));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Toggles the pinned broadcast status of an item.
  Future<void> togglePin(int id, bool isPinned) async {
    try {
      await _sb.from('tips_and_news').update({
        'is_pinned': isPinned,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Toggles the published/draft visibility of an item.
  Future<void> togglePublish(int id, bool isPublished) async {
    try {
      await _sb.from('tips_and_news').update({
        'is_published': isPublished,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', id).timeout(const Duration(seconds: 10));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Deletes a single item by ID.
  Future<void> deleteSingle(int id) async {
    try {
      await _sb
          .from('tips_and_news')
          .delete()
          .eq('id', id)
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  /// Deletes a batch of items by IDs.
  Future<void> deleteBatch(List<int> ids) async {
    if (ids.isEmpty) return;
    try {
      await _sb
          .from('tips_and_news')
          .delete()
          .inFilter('id', ids)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }
}
