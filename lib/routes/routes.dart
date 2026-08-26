/// Route path constants for the admin console.
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

  static const challenges = '/challenges';
  static const subjectChallenges = '/challenges/subject';
  static const challengeEditor = '/challenges/editor';
  static const challengeScheduler = '/challenges/scheduler';
  static const challengeLeaderboard = '/challenges/leaderboard';

  static const sessions = '/sessions';
  static const settings = '/settings';
}
