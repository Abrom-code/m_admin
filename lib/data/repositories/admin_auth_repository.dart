import 'package:get/get.dart';
import 'package:m_admin/utils/exceptions/app_failure_model.dart';
import 'package:m_admin/utils/exceptions/exception_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Authentication for the admin console via Supabase Auth.
///
/// The admin must have a real account in Supabase Auth (auth.users). Signing
/// in through Supabase gives the session a valid UUID that satisfies the
/// `reviewed_by` FK on `payment_receipts`.
class AdminAuthRepository extends GetxController {
  static AdminAuthRepository get instance => Get.find();

  final _supabase = Supabase.instance.client;

  Future<void> loginWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      await _supabase.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
    } on AuthException catch (e) {
      throw AppFailure(title: 'Sign-in Failed', message: e.message);
    } catch (e) {
      throw AppExceptionHandler.handle(e);
    }
  }

  Future<void> logout() async {
    await _supabase.auth.signOut();
  }
}
