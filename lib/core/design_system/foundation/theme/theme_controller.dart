import 'package:flutter/material.dart';

import 'dark_theme.dart';
import 'light_theme.dart';
import 'theme_mode.dart';
import 'theme_storage.dart';

/// Manages theme mode with persistence and [MaterialApp] integration.
class DsThemeController extends ChangeNotifier {
  DsThemeController({DsAppThemeMode initialMode = DsAppThemeMode.system})
      : _mode = initialMode;

  DsAppThemeMode _mode;
  bool _loaded = false;

  DsAppThemeMode get mode => _mode;
  bool get isLoaded => _loaded;

  ThemeMode get flutterThemeMode => _mode.toFlutterThemeMode();

  ThemeData get lightTheme => DsLightTheme.data;
  ThemeData get darkTheme => DsDarkTheme.data;

  /// Load saved preference — call once during app bootstrap.
  Future<void> load() async {
    _mode = await DsThemeStorage.load();
    _loaded = true;
    notifyListeners();
  }

  Future<void> setMode(DsAppThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    await DsThemeStorage.save(mode);
  }

  void toggleLightDark() {
    setMode(_mode.isDark ? DsAppThemeMode.light : DsAppThemeMode.dark);
  }
}
