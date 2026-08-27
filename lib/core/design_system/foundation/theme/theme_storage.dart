import 'package:reem/core/design_system/foundation/theme/theme_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themeModeKey = 'reem_theme_mode';

/// Persists user theme preference locally.
abstract final class DsThemeStorage {
  static Future<DsAppThemeMode> load() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_themeModeKey);
    return switch (value) {
      'light' => DsAppThemeMode.light,
      'dark' => DsAppThemeMode.dark,
      'system' => DsAppThemeMode.system,
      _ => DsAppThemeMode.system,
    };
  }

  static Future<void> save(DsAppThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final value = switch (mode) {
      DsAppThemeMode.light => 'light',
      DsAppThemeMode.dark => 'dark',
      DsAppThemeMode.system => 'system',
    };
    await prefs.setString(_themeModeKey, value);
  }
}
