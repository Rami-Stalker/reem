import 'package:flutter/material.dart';

import '../core/design_system/foundation/theme/theme_controller.dart';
import '../core/di/di.dart';
import '../core/localization/locale_controller.dart';

/// Application initialization — call once from [main].
abstract final class AppBootstrap {
  static final DsThemeController themeController = DsThemeController();
  static final LocaleController localeController = LocaleController();

  static Future<void> initialize() async {
    WidgetsFlutterBinding.ensureInitialized();
    await configureDependencies();
    await Future.wait([
      themeController.load(),
      localeController.load(),
    ]);
  }
}
