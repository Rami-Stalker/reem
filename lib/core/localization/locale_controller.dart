import 'package:flutter/material.dart';

import 'package:ohara/core/localization/locale_storage.dart';

/// Manages app locale with persistence and [MaterialApp] integration.
class LocaleController extends ChangeNotifier {
  LocaleController();

  /// `null` = follow device locale (via resolution callback).
  Locale? _locale;
  bool _loaded = false;

  Locale? get locale => _locale;
  bool get isLoaded => _loaded;

  bool get isArabic => _locale?.languageCode == 'ar';
  bool get isEnglish => _locale?.languageCode == 'en';
  bool get followsSystem => _locale == null;

  /// Load saved preference — call once during app bootstrap.
  Future<void> load() async {
    final code = await LocaleStorage.load();
    _locale = switch (code) {
      'en' => const Locale('en'),
      'ar' => const Locale('ar'),
      _ => null,
    };
    _loaded = true;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    await LocaleStorage.save(locale.languageCode);
  }

  Future<void> setEnglish() => setLocale(const Locale('en'));

  Future<void> setArabic() => setLocale(const Locale('ar'));

  Future<void> setSystem() async {
    if (_locale == null) return;
    _locale = null;
    notifyListeners();
    await LocaleStorage.save('system');
  }
}
