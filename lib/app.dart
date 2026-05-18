import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'routes/app_router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  
  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Reem Shop',
      theme: AppTheme.light,
      routeInformationParser: AppRouter.router.routeInformationParser,
      routerDelegate: AppRouter.router.routerDelegate,
      localizationsDelegates: L10nSetup.localizationsDelegates,
      supportedLocales: L10nSetup.supportedLocales,
      localeResolutionCallback: L10nSetup.localeResolutionCallback,
    );
  }
}
