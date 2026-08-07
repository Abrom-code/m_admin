import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:m_admin/bindings/admin_general_binding.dart';
import 'package:m_admin/common/widgets/toast/app_toast.dart';
import 'package:m_admin/routes/app_routes.dart';
import 'package:m_admin/routes/routes.dart';
import 'package:m_admin/utils/themes/app_theme.dart';
import 'package:m_admin/utils/themes/theme_controller.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => GetMaterialApp(
        title: 'MatricMate Admin',
        initialBinding: AdminGeneralBinding(),
        debugShowCheckedModeBanner: false,
        themeMode: ThemeController.instance.themeMode.value,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        initialRoute: AdminRoutes.loading,
        getPages: AdminAppRoutes.pages,
        navigatorObservers: [appRouteObserver],
        builder: (context, child) => ToastHost(child: child ?? const SizedBox()),
      ),
    );
  }
}
