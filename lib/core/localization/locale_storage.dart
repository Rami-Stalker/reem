import 'package:shared_preferences/shared_preferences.dart';

const _localeKey = 'reem_locale';

/// Persists user language preference locally.
abstract final class LocaleStorage {
  /// Returns `en`, `ar`, or `system`.
  static Future<String> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_localeKey) ?? 'system';
  }

  static Future<void> save(String code) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, code);
  }
}
