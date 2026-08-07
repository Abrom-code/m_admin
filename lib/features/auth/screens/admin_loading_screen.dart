import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/common/widgets/loaders/circular_loading.dart';
import 'package:m_admin/data/services/admin_session_service.dart';
import 'package:m_admin/routes/routes.dart';

/// Cold-start route.
///
/// Firebase persists its own session across restarts, so a returning admin
/// should not have to retype a password. This silently re-exchanges the
/// Firebase token for a fresh Supabase JWT and re-verifies the `admins` row
/// before routing on.
///
/// The re-verification is the point: an admin deactivated in the database must
/// lose access on their next launch, not whenever their cached token happens
/// to expire.
class AdminLoadingScreen extends StatefulWidget {
  const AdminLoadingScreen({super.key});

  @override
  State<AdminLoadingScreen> createState() => _AdminLoadingScreenState();
}

class _AdminLoadingScreenState extends State<AdminLoadingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    final restored = await AdminSessionService.instance.restore();

    if (!mounted) return;

    Get.offAllNamed(restored ? AdminRoutes.shell : AdminRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: AppCircularLoading(title: 'Restoring session...'),
    );
  }
}
