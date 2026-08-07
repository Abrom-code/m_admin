import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseDbExceptions implements Exception {
  final String code;
  final String? rawMessage;

  SupabaseDbExceptions(this.code, {this.rawMessage});

  factory SupabaseDbExceptions.fromException(Object e) {
    if (e is PostgrestException) {
      return SupabaseDbExceptions(
        e.code ?? 'unknown',
        rawMessage: 'PostgrestException — code: ${e.code}, message: ${e.message}, details: ${e.details}, hint: ${e.hint}',
      );
    }
    return SupabaseDbExceptions('unknown', rawMessage: e.toString());
  }

  String get message {
    switch (code) {
      // --- Integrity & Constraints ---
      case '23505':
        return 'This record already exists.';
      case '23503':
        return 'This action cannot be completed because it is linked to another record.';
      case '23502':
        return 'A required field is missing. Please fill in all necessary info.';
      case '23514':
        return 'The information provided does not meet the required format.';

      // --- Permissions & Security ---
      case '42501':
        return 'You do not have permission to perform this action.';

      // --- API & Request Errors (PGRST) ---
      case 'PGRST116':
        return 'Could not find the requested information.';
      case 'PGRST100':
        return 'The search filter is invalid. Please check your query.';
      case 'PGRST102':
        return 'The data sent was malformed. Please try again.';
      case 'PGRST301':
        return 'Your session has expired. Please log in again.';

      // --- Database/Table Issues ---
      case '42P01':
        return 'The requested resource could not be found on the server.';
      case '42703':
        return 'One of the data fields is invalid or missing.';

      // --- Connection & Server ---
      case '08001':
      case '08006':
      case 'PGRST000':
        return 'Connection error. Please check your internet and try again.';
      case '57014':
        return 'The request took too long and was cancelled.';

      default:
        return rawMessage ?? 'Unknown error (code: $code)';
    }
  }
}
