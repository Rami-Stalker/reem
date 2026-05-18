import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:reem/l10n/app_localizations.dart';
final class L10nSetup {
  L10nSetup._();

  static const List<LocalizationsDelegate<dynamic>>
      localizationsDelegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = [
    Locale('en'),
    Locale('ar'),
  ];

  static Locale localeResolutionCallback(
    Locale? locale,
    Iterable<Locale> supportedLocales,
  ) {
    if (locale == null) {
      return supportedLocales.first;
    }

    for (final supportedLocale in supportedLocales) {
      if (supportedLocale.languageCode ==
          locale.languageCode) {
        return supportedLocale;
      }
    }

    return supportedLocales.first;
  }
}