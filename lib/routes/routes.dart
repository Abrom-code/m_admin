/// Route path constants for the admin console.
///
/// Naming note: the parent app has these two files inverted — its
/// `routes/app_routes.dart` holds the constants and `routes/routes.dart` holds
/// the page list. This app uses the conventional arrangement:
///   routes.dart      -> AdminRoutes (the path strings)
///   app_routes.dart  -> AdminAppRoutes.pages (the GetPage list) + observer
class AdminRoutes {
  AdminRoutes._();

  // ── Bootstrap / auth ────────────────────────────────────────────────
  static const loading = '/loading';
  static const login = '/login';

  // ── Shell ───────────────────────────────────────────────────────────
  static const shell = '/shell';

  // ── Features ────────────────────────────────────────────────────────
  static const dashboard = '/dashboard';

  static const payments = '/payments';
  static const paymentDetail = '/payments/detail';

  static const notifications = '/notifications';
  static const notificationCompose = '/notifications/compose';

  static const users = '/users';
  static const userDetail = '/users/detail';

  static const content = '/content';
  static const contentSubject = '/content/subject';
  static const contentChapter = '/content/chapter';
  static const contentTest = '/content/test';
  static const contentQuestion = '/content/question';

  static const sessions = '/sessions';
  static const settings = '/settings';
}
