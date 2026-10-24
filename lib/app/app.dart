import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ohara/app/app_chrome.dart';
import 'package:ohara/app/bootstrap.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/localization/l10n_extension.dart';
import 'package:ohara/core/notifications/push_coordinator.dart';
import 'package:ohara/core/platform/app_scroll_behavior.dart';
import 'package:ohara/core/platform/system_chrome_controller.dart';
import 'package:ohara/core/router/app_router_provider.dart';

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  Size? _lastWindowSize;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncOrientationPolicy();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// A foldable changes class in the user's hands, so the policy is re-read on
  /// every metric change rather than pinned once at launch.
  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    _syncOrientationPolicy();
  }

  void _syncOrientationPolicy() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) {
      return;
    }
    final size = view.physicalSize / view.devicePixelRatio;
    if (size.isEmpty || size == _lastWindowSize) {
      return;
    }
    _lastWindowSize = size;
    unawaited(AppSystemChrome.applyOrientationFor(size));
  }

  @override
  Widget build(BuildContext context) {
    final theme = AppBootstrap.themeController;
    final locale = AppBootstrap.localeController;

    if (!theme.isLoaded || !locale.isLoaded) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: L10nSetup.localizationsDelegates,
        supportedLocales: L10nSetup.supportedLocales,
        // The loading frame resolves its locale the same way the app does.
        // Without this it used Flutter's default algorithm, so the very first
        // frame could be laid out LTR and then flip.
        localeResolutionCallback: L10nSetup.localeResolutionCallback,
        // "Follow the device" means Arabic, not whatever the browser
        // reports: the interface English bundle is a deferred phase
        // (Q91), so an `en-US` laptop must not pick it up by accident.
        // An explicit choice in settings still wins.
        locale: locale.locale ?? L10nSetup.fallbackLocale,
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

    // Both controllers are ChangeNotifiers held outside the widget tree, so the
    // app has to listen to them. It previously did not: picking a language
    // saved the preference and notified, but nothing rebuilt MaterialApp — the
    // language switcher appeared to do nothing until some unrelated rebuild.
    // Above `MaterialApp.router` rather than inside its `builder`: the
    // coordinator has to outlive every route change, and anything mounted in
    // the builder is rebuilt — and its state discarded — whenever the
    // navigator swaps the page under it, which would drop the message that
    // launched the app.
    return PushCoordinator(
      child: ListenableBuilder(
        listenable: Listenable.merge([theme, locale]),
        builder: (context, _) => MaterialApp.router(
          debugShowCheckedModeBanner: false,
          onGenerateTitle: (context) => context.l10n.appTitle,
          theme: theme.lightTheme,
          darkTheme: theme.darkTheme,
          themeMode: theme.flutterThemeMode,
          // "Follow the device" means Arabic, not whatever the browser
          // reports: the interface English bundle is a deferred phase
          // (Q91), so an `en-US` laptop must not pick it up by accident.
          // An explicit choice in settings still wins.
          locale: locale.locale ?? L10nSetup.fallbackLocale,
          routerConfig: router,
          localizationsDelegates: L10nSetup.localizationsDelegates,
          supportedLocales: L10nSetup.supportedLocales,
          localeResolutionCallback: L10nSetup.localeResolutionCallback,
          // Overscroll, drag devices and default physics per platform. See
          // [AppScrollBehavior] — pages used to hardcode iOS bounce everywhere.
          scrollBehavior: const AppScrollBehavior(),
          // One frame above every route, pushed pages included: the offline
          // band, the clamped text scale, and the system-bar style. It belongs
          // here rather than in a page scaffold because none of the three is a
          // fact about the screen she happens to be on.
          builder: (context, child) =>
              AppChrome(child: child ?? const SizedBox.shrink()),
        ),
      ),
    );
  }
}
