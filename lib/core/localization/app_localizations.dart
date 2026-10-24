import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:ohara/l10n/app_localizations.dart';

final class L10nSetup {
  L10nSetup._();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  /// Arabic is first, and that ordering is load-bearing: Flutter falls back to
  /// `supportedLocales.first` for any locale it cannot match. Ohara is an
  /// Arabic-first Syrian platform whose customers are addressed in Arabic, so a
  /// device set to French must land on Arabic RTL — not on English.
  ///
  /// English is kept in the list because the picker offers it, but the client
  /// deferred the English interface to a later phase (Q91).
  static const List<Locale> supportedLocales = [
    Locale('ar'),
    Locale('en'),
  ];

  static const Locale fallbackLocale = Locale('ar');

  /// Matches on language code, ignoring country and script: `ar-SY`, `ar-EG`
  /// and bare `ar` all resolve to the same Arabic bundle.
  ///
  /// A device whose language is neither Arabic nor English lands on Arabic.
  ///
  /// An `en-US` device does *not* reach this callback any more: "follow the
  /// device" is resolved to Arabic before `MaterialApp` is built (see
  /// `OharaApp`), because the client deferred the English interface (Q91) and a
  /// Syrian customer opening Ohara in a browser that reports `en-US` was being
  /// handed a half-translated product. English stays a deliberate choice made
  /// in settings, and that choice arrives here as an explicit `Locale('en')`.
  static Locale localeResolutionCallback(
    Locale? locale,
    Iterable<Locale> supportedLocales,
  ) {
    if (locale == null) return fallbackLocale;

    for (final supported in supportedLocales) {
      if (supported.languageCode == locale.languageCode) return supported;
    }
    return fallbackLocale;
  }
}
