import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Typed, validated access to the values in `.env`.
///
/// Unlike the parent app — which does `dotenv.env['SUPABASE_URL'] ?? ''` and
/// silently initialises Supabase against an empty URL when the key is missing
/// — this fails loudly. A misconfigured admin build must not reach a login
/// screen and then mysteriously 401; it must say which key is missing.
class AppEnv {
  AppEnv._();

  static const _supabaseUrl = 'SUPABASE_URL';
  static const _supabaseApiKey = 'SUPABASE_API_KEY';
  static const _pushWebhookSecret = 'PUSH_WEBHOOK_SECRET';
  static const _adminFunctionsBaseUrl = 'ADMIN_FUNCTIONS_BASE_URL';
  static const _mockAdminEmail = 'MOCK_ADMIN_EMAIL';
  static const _mockAdminPassword = 'MOCK_ADMIN_PASSWORD';

  /// Every key the app requires to run.
  static const requiredKeys = <String>[
    _supabaseUrl,
    _supabaseApiKey,
    _pushWebhookSecret,
    _adminFunctionsBaseUrl,
  ];

  static String get supabaseUrl => _read(_supabaseUrl);
  static String get supabaseApiKey => _read(_supabaseApiKey);

  /// Shared secret for the `x-webhook-secret` gate added to `send-push`
  /// in Phase 2a. Without it every push call returns 401.
  static String get pushWebhookSecret => _read(_pushWebhookSecret);

  /// Base URL for edge functions, e.g.
  /// `https://<project-ref>.supabase.co/functions/v1`
  static String get adminFunctionsBaseUrl =>
      _read(_adminFunctionsBaseUrl).replaceAll(RegExp(r'/+$'), '');

  /// Mock admin credentials for local development.
  /// Falls back to hardcoded defaults if not set in .env.
  static String get mockAdminEmail =>
      _readOptional(_mockAdminEmail, 'howdes404@gmail.com');

  static String get mockAdminPassword =>
      _readOptional(_mockAdminPassword, r'$Abroma*96*');

  /// Names of the required keys that are absent or blank.
  ///
  /// `main()` calls this before `Supabase.initialize` and renders a visible
  /// error screen listing the results rather than booting a broken app.
  static List<String> missingKeys() {
    return requiredKeys
        .where((k) => (dotenv.env[k] ?? '').trim().isEmpty)
        .toList();
  }

  static bool get isValid => missingKeys().isEmpty;

  static String _read(String key) {
    final value = (dotenv.env[key] ?? '').trim();
    if (value.isEmpty) {
      throw StateError(
        'Missing required environment key "$key". '
        'Add it to the .env file at the project root.',
      );
    }
    return value;
  }

  /// Reads an optional key, returning [fallback] when absent or blank.
  static String _readOptional(String key, String fallback) {
    final value = (dotenv.env[key] ?? '').trim();
    return value.isEmpty ? fallback : value;
  }
}
