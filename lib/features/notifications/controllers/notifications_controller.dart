import 'dart:async';
import 'package:get/get.dart';
import 'package:m_admin/data/repositories/notifications_repository.dart';
import 'package:m_admin/features/notifications/models/admin_notification_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';

class NotificationsController extends GetxController {
  static NotificationsController get instance => Get.find();

  final _repo = NotificationsRepository();

  final rows = <AdminNotificationModel>[].obs;
  final isLoading = false.obs;
  final isSending = false.obs;
  final errorMessage = RxnString();
  final typeFilter = RxnString();
  final page = 0.obs;
  static const pageSize = 30;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    try {
      isLoading.value = true;
      errorMessage.value = null;
      rows.value = await _repo.fetchRecent(
        page: page.value,
        pageSize: pageSize,
        typeFilter: typeFilter.value,
      );
    } catch (e) {
      errorMessage.value = AppExceptionHandler.handle(e).message;
    } finally {
      isLoading.value = false;
    }
  }

  void setTypeFilter(String? type) {
    typeFilter.value = type;
    page.value = 0;
    load();
  }

  void changePage(int next) {
    page.value = next;
    load();
  }

  Future<bool> send({
    required String title,
    required String body,
    required String type,
    required String audience,
  }) async {
    try {
      isSending.value = true;
      await _repo.sendBroadcast(
        title: title,
        body: body,
        type: type,
        audience: audience,
      );
      SnackbarHelper.success('Sent', 'Notification delivered.');
      await load(); // refresh the list so the new row appears
      return true;
    } catch (e) {
      AppExceptionHandler.handleResponse(e);
      return false;
    } finally {
      isSending.value = false;
    }
  }
}
