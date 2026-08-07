import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:m_admin/app.dart';
import 'package:m_admin/utils/themes/theme_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Startup sequence for the admin console.
///
/// Firebase auth was removed (mock login only). Supabase is kept for data:
/// payments, users, notifications, content, sessions, audit log, and settings
/// all call Supabase.instance.client directly.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await GetStorage.init();

  // ── .env ──────────────────────────────────────────────────────────
  // dotenv MUST be initialized before any AppEnv getter is called.
  // If the asset is absent (e.g. a CI build that injects secrets another way),
  // testLoad initialises dotenv with an empty map so dotenv.env never throws
  // NotInitializedError. Data screens will surface their own errors later.
  try {
    await dotenv.load(fileName: '.env');
  } catch (_) {
    dotenv.testLoad(fileInput: '');
  }

  Get.put(ThemeController(), permanent: true);

  // ── Supabase ──────────────────────────────────────────────────────
  // Always initialize so Supabase.instance.client never throws "not
  // initialized". With real keys data works normally; with blank/missing
  // keys a placeholder URL is used and each data screen shows its own
  // error state instead of crashing the app.
  try {
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    final key = dotenv.env['SUPABASE_API_KEY']?.trim() ?? '';
    await Supabase.initialize(
      url: url.isNotEmpty ? url : 'https://placeholder.supabase.co',
      publishableKey: key.isNotEmpty ? key : 'placeholder_anon_key',
    );
  } catch (_) {
    // Init failure is surfaced when screens try to load data.
  }

  runApp(const AdminApp());
}
