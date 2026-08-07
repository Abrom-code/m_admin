import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:m_admin/utils/exceptions/app_failure_model.dart';
import 'package:m_admin/utils/exceptions/format_exceptions.dart';
import 'package:m_admin/utils/exceptions/platform_exceptions.dart';
import 'package:m_admin/utils/exceptions/sqflite_exceptions.dart';
import 'package:m_admin/utils/exceptions/supabase_exception.dart';
import 'package:m_admin/utils/helpers/snackbar_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppExceptionHandler {
  AppExceptionHandler._();

  static void handleResponse(dynamic e) {
    final failure = handle(e is Object ? e : Exception(e.toString()));
    SnackbarHelper.error(failure.title, failure.message);
  }

  static AppFailure handle(Object e) {
    if (e is AppFailure) return e;

    // ── Supabase PostgREST (database) ────────────────────────────
    if (e is PostgrestException) {
      debugPrint('[DB ERROR] code=${e.code} message=${e.message} details=${e.details} hint=${e.hint}');
      if (kDebugMode) {
        final parts = [
          'code: ${e.code}',
          e.message,
          if (e.hint != null && e.hint!.isNotEmpty) 'hint: ${e.hint}',
          if (e.details != null) '${e.details}',
        ];
        return AppFailure(
          title: 'DB Error [${e.code}]',
          message: parts.join('\n'),
          code: e.code,
        );
      }
      return AppFailure(
        title: 'Database Error',
        message: SupabaseDbExceptions.fromException(e).message,
        code: e.code,
      );
    }

    // ── Supabase Auth ────────────────────────────────────────────
    if (e is AuthException) {
      return _handleSupabaseAuth(e);
    }

    // ── Supabase Storage ─────────────────────────────────────────
    if (e is StorageException) {
      return AppFailure(
        title: 'Upload Error',
        message: _storageMessage(e.statusCode),
      );
    }

    // ── Network / HTTP ───────────────────────────────────────────
    if (e is SocketException || _isNetworkError(e)) {
      return const AppFailure(
        title: 'No Internet',
        message: 'Check your connection and try again.',
      );
    }

    if (e is http.ClientException) {
      return const AppFailure(
        title: 'Connection Error',
        message: 'Could not reach the server. Check your internet connection.',
      );
    }

    if (e is TimeoutException) {
      return const AppFailure(
        title: 'Request Timed Out',
        message: 'The request took too long. Please try again.',
      );
    }

    // ── SQLite ───────────────────────────────────────────────────
    if (e.toString().contains('DatabaseException')) {
      return AppFailure(
        title: 'Local Database Error',
        message: SqfliteDbExceptions.fromException(e).message,
      );
    }

    // ── Format ───────────────────────────────────────────────────
    if (e is FormatException) {
      return AppFailure(
        title: 'Format Error',
        message: const FormatExceptions().formattedMessage,
      );
    }

    // ── Platform ─────────────────────────────────────────────────
    if (e is PlatformException) {
      return AppFailure(
        title: 'Platform Error',
        message: PlatformExceptions(e.code).message,
        code: e.code,
      );
    }

    // ── Fallback ─────────────────────────────────────────────────
    if (kDebugMode) {
      return AppFailure(
        title: 'Unexpected Error [DEBUG]',
        message: '${e.runtimeType}: $e',
      );
    }
    return const AppFailure(
      title: 'Something Went Wrong',
      message: 'An unexpected error occurred. Please try again.',
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────

  static AppFailure _handleSupabaseAuth(AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('invalid') || msg.contains('credentials')) {
      return const AppFailure(
        title: 'Authentication Error',
        message: 'Invalid credentials. Please check and try again.',
      );
    }
    if (msg.contains('expired') || msg.contains('session')) {
      return const AppFailure(
        title: 'Session Expired',
        message: 'Your session has expired. Please log in again.',
      );
    }
    if (msg.contains('rate') || msg.contains('limit')) {
      return const AppFailure(
        title: 'Too Many Attempts',
        message: 'Please wait a moment before trying again.',
      );
    }
    return const AppFailure(
      title: 'Authentication Error',
      message: 'An authentication error occurred. Please try again.',
    );
  }

  static String _storageMessage(String? statusCode) {
    switch (statusCode) {
      case '400':
        return 'The file could not be uploaded. Please check the file and try again.';
      case '403':
        return 'You do not have permission to upload files.';
      case '404':
        return 'Storage location not found.';
      case '413':
        return 'The file is too large to upload.';
      default:
        return 'File upload failed. Please try again.';
    }
  }

  /// Catches errors that wrap a SocketException inside a ClientException
  /// or other wrapper types from the http/dio stack.
  static bool _isNetworkError(Object e) {
    final s = e.toString().toLowerCase();
    return s.contains('socketexception') ||
        s.contains('failed host lookup') ||
        s.contains('network is unreachable') ||
        s.contains('connection refused') ||
        s.contains('connection reset') ||
        s.contains('connection timed out') ||
        s.contains('no address associated');
  }
}
