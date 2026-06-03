import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/bootstrap.dart';
import 'core/design_system/foundation/theme/app_theme.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/l10n_extension.dart';
import 'core/router/app_router_provider.dart';

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppBootstrap.themeController;
    final locale = AppBootstrap.localeController;

    if (!theme.isLoaded || !locale.isLoaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: L10nSetup.localizationsDelegates,
        supportedLocales: L10nSetup.supportedLocales,
        home: Scaffold(
          body: Center(
            child: CircularProgressIndicator(
              color: AppTheme.light.colorScheme.primary,
            ),
          ),
        ),
      );
    }

    final router = ref.watch(goRouterProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.l10n.appTitle,
      theme: theme.lightTheme,
      darkTheme: theme.darkTheme,
      themeMode: theme.flutterThemeMode,
      locale: locale.locale,
      routerConfig: router,
      localizationsDelegates: L10nSetup.localizationsDelegates,
      supportedLocales: L10nSetup.supportedLocales,
      localeResolutionCallback: L10nSetup.localeResolutionCallback,
    );
  }
}
