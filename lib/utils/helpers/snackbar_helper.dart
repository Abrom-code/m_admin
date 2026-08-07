import 'package:m_admin/common/widgets/toast/app_toast.dart';

/// Thin shim — delegates to [AppToast] so existing call sites need no changes.
/// For new code prefer calling [AppToast] directly.
class SnackbarHelper {
  SnackbarHelper._();

  static void success(String title, String message) =>
      AppToast.success(title, message: message);

  static void error(String title, String message) =>
      AppToast.error(title, message: message);

  static void warning(String title, String message) =>
      AppToast.warning(title, message: message);

  static void info(String title, String message) =>
      AppToast.info(title, message: message);
}
