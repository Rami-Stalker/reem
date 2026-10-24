import 'package:flutter/material.dart';

import 'package:ohara/core/design_system/foundation/theme/theme_controller.dart';
import 'package:ohara/core/di/di.dart';
import 'package:ohara/core/localization/locale_controller.dart';
import 'package:ohara/core/platform/system_chrome_controller.dart';

/// Application initialization — call once from [main].
abstract final class AppBootstrap {
  static final DsThemeController themeController = DsThemeController();
  static final LocaleController localeController = LocaleController();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Before the first frame, so the app never paints one frame letterboxed
    // between opaque system bars and then jumps.
    await AppSystemChrome.configure();
    await configureDependencies();
    await Future.wait([themeController.load(), localeController.load()]);
  }
}
