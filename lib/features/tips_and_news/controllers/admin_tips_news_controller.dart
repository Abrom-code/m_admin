import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/common/widgets/dialogs/confirm_dialog_box.dart';
import 'package:m_admin/data/repositories/admin_tips_news_repository.dart';
import 'package:m_admin/features/tips_and_news/models/admin_tip_news_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

/// Controller managing state, filtering, search, and CRUD for Tips & News.
class AdminTipsNewsController extends GetxController {
  AdminTipsNewsController({AdminTipsNewsRepository? repository})
      : repo = repository ?? AdminTipsNewsRepository();

  static AdminTipsNewsController get instance => Get.find();

  final AdminTipsNewsRepository repo;

  // ── Reactive State ────────────────────────────────────────────────────────
  final items = <AdminTipNewsModel>[].obs;
  final isLoading = false.obs;
  final isSaving = false.obs;

  // Search & Filters
  final searchQuery = ''.obs;
  final selectedCategory = 'all'.obs; // 'all', 'news', 'tip'
  final selectedAudience = 'all'.obs; // 'all', 'both', 'natural', 'social'
  final selectedPublishStatus = 'all'.obs; // 'all', 'published', 'draft'

  // Multi-Selection for batch deletion
  final selectedIds = <int>{}.obs;
  bool get isSelectionMode => selectedIds.isNotEmpty;

  // ── Computed Statistics ───────────────────────────────────────────────────
  int get totalCount => items.length;
  int get newsCount => items.where((i) => i.isNews).length;
  int get tipsCount => items.where((i) => i.isTip).length;
  int get publishedCount => items.where((i) => i.isPublished).length;
  int get draftCount => items.where((i) => !i.isPublished).length;
  int get pinnedCount => items.where((i) => i.isPinned).length;

  // ── Filtered Items Getter ─────────────────────────────────────────────────
  List<AdminTipNewsModel> get filteredItems {
    final query = searchQuery.value.trim().toLowerCase();
    final cat = selectedCategory.value.trim().toLowerCase();
    final aud = selectedAudience.value.trim().toLowerCase();
    final pub = selectedPublishStatus.value.trim().toLowerCase();

    return items.where((item) {
      // 1. Category filter
      if (cat != 'all' && item.category.toLowerCase() != cat) {
        return false;
      }

      // 2. Audience filter
      if (aud != 'all' && item.audience.toLowerCase() != aud) {
        return false;
      }

      // 3. Publish status filter
      if (pub == 'published' && !item.isPublished) {
        return false;
      }
      if (pub == 'draft' && item.isPublished) {
        return false;
      }

      // 4. Search query (title, content, author)
      if (query.isNotEmpty) {
        final inTitle = item.title.toLowerCase().contains(query);
        final inContent = item.content.toLowerCase().contains(query);
        final inAuthor = item.author.toLowerCase().contains(query);
        if (!inTitle && !inContent && !inAuthor) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  @override
  void onInit() {
    super.onInit();
    loadItems();
  }

  // ── Selection Management ──────────────────────────────────────────────────
  void toggleSelection(int id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
  }

  void selectAll() {
    selectedIds.addAll(filteredItems.map((e) => e.id));
  }

  void deselectAll() {
    selectedIds.clear();
  }

  void clearSelection() {
    selectedIds.clear();
  }

  // ── Load All Items ────────────────────────────────────────────────────────
  Future<void> loadItems() async {
    try {
      isLoading.value = true;
      final result = await repo.fetchAll();
      items.assignAll(result);
    } catch (e) {
      final appEx = AppExceptionHandler.handle(e);
      SnackbarHelper.error('Load Error', appEx.message);
    } finally {
      isLoading.value = false;
    }
  }

  // ── Create or Update Item ─────────────────────────────────────────────────
  Future<bool> saveItem(AdminTipNewsModel item) async {
    try {
      isSaving.value = true;
      if (item.id <= 0) {
        // Insert
        final created = await repo.create(item);
        items.insert(0, created);
        // Ensure pinned sort order
        items.sort((a, b) {
          if (a.isPinned != b.isPinned) {
            return b.isPinned ? 1 : -1;
          }
          return b.createdAt.compareTo(a.createdAt);
        });
        SnackbarHelper.success(
          'Published Successfully',
          '${created.isNews ? "News" : "Tip"} broadcast created.',
        );
      } else {
        // Update
        final updated = await repo.update(item);
        final index = items.indexWhere((i) => i.id == updated.id);
        if (index != -1) {
          items[index] = updated;
        }
        items.sort((a, b) {
          if (a.isPinned != b.isPinned) {
            return b.isPinned ? 1 : -1;
          }
          return b.createdAt.compareTo(a.createdAt);
        });
        SnackbarHelper.success(
          'Updated Successfully',
          '${updated.isNews ? "News" : "Tip"} broadcast updated.',
        );
      }
      return true;
    } catch (e) {
      final appEx = AppExceptionHandler.handle(e);
      SnackbarHelper.error('Save Failed', appEx.message);
      return false;
    } finally {
      isSaving.value = false;
    }
  }

  // ── Inline Pin Toggle ─────────────────────────────────────────────────────
  Future<void> togglePin(AdminTipNewsModel item) async {
    final nextState = !item.isPinned;
    final originalIndex = items.indexWhere((i) => i.id == item.id);
    if (originalIndex == -1) return;

    // Optimistic UI update
    final updatedItem = item.copyWith(isPinned: nextState);
    items[originalIndex] = updatedItem;
    items.sort((a, b) {
      if (a.isPinned != b.isPinned) {
        return b.isPinned ? 1 : -1;
      }
      return b.createdAt.compareTo(a.createdAt);
    });

    try {
      await repo.togglePin(item.id, nextState);
      SnackbarHelper.success(
        nextState ? 'Pinned to Top' : 'Unpinned',
        '"${item.title}" is ${nextState ? "now pinned" : "no longer pinned"}.',
      );
    } catch (e) {
      // Revert on failure
      items[originalIndex] = item;
      items.sort((a, b) {
        if (a.isPinned != b.isPinned) {
          return b.isPinned ? 1 : -1;
        }
        return b.createdAt.compareTo(a.createdAt);
      });
      final appEx = AppExceptionHandler.handle(e);
      SnackbarHelper.error('Pin Failed', appEx.message);
    }
  }

  // ── Inline Publish/Draft Toggle ───────────────────────────────────────────
  Future<void> togglePublish(AdminTipNewsModel item) async {
    final nextState = !item.isPublished;
    final originalIndex = items.indexWhere((i) => i.id == item.id);
    if (originalIndex == -1) return;

    // Optimistic UI update
    items[originalIndex] = item.copyWith(isPublished: nextState);

    try {
      await repo.togglePublish(item.id, nextState);
      SnackbarHelper.success(
        nextState ? 'Item Published' : 'Moved to Draft',
        '"${item.title}" is ${nextState ? "now visible to students" : "now hidden from students"}.',
      );
    } catch (e) {
      // Revert on failure
      items[originalIndex] = item;
      final appEx = AppExceptionHandler.handle(e);
      SnackbarHelper.error('Update Failed', appEx.message);
    }
  }

  // ── Delete Single Item ────────────────────────────────────────────────────
  Future<void> deleteItem(AdminTipNewsModel item) async {
    final confirmed = await AppDialogBoxes.confirm(
      title: 'Delete ${item.isNews ? "News" : "Tip"}?',
      message:
          'Are you sure you want to delete "${item.title}"? This action cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
      detail: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            item.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            item.snippet,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    if (!confirmed) return;

    try {
      await repo.deleteSingle(item.id);
      items.removeWhere((i) => i.id == item.id);
      selectedIds.remove(item.id);
      SnackbarHelper.success(
        'Deleted',
        '${item.isNews ? "News" : "Tip"} removed successfully.',
      );
    } catch (e) {
      final appEx = AppExceptionHandler.handle(e);
      SnackbarHelper.error('Delete Failed', appEx.message);
    }
  }

  // ── Delete Batch Selected Items ───────────────────────────────────────────
  Future<void> deleteSelected() async {
    final count = selectedIds.length;
    if (count == 0) return;

    final confirmed = await AppDialogBoxes.confirm(
      title: 'Delete $count Selected Items?',
      message:
          'Are you sure you want to permanently delete $count broadcast item(s)? This action cannot be undone.',
      confirmLabel: 'Delete Selected',
      isDestructive: true,
    );

    if (!confirmed) return;

    try {
      final idsToDelete = selectedIds.toList();
      await repo.deleteBatch(idsToDelete);
      items.removeWhere((i) => idsToDelete.contains(i.id));
      selectedIds.clear();
      SnackbarHelper.success('Deleted', '$count items deleted successfully.');
    } catch (e) {
      final appEx = AppExceptionHandler.handle(e);
      SnackbarHelper.error('Batch Delete Failed', appEx.message);
    }
  }
}
