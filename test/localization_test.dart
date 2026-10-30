import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/l10n/app_localizations_ar.dart';

/// Guards the two things that are easy to regress silently: the Arabic copy
/// addressing the customer as a woman, and Arabic being the fallback locale.
void main() {
  group('locale resolution', () {
    test('an unsupported device locale falls back to Arabic, not English', () {
      // Flutter falls back to `supportedLocales.first`, so this is really a
      // test that the list is ordered Arabic-first.
      final resolved = L10nSetup.localeResolutionCallback(
        const Locale('fr', 'FR'),
        L10nSetup.supportedLocales,
      );
      expect(resolved.languageCode, 'ar');
      expect(L10nSetup.supportedLocales.first.languageCode, 'ar');
    });

    test('a null device locale falls back to Arabic', () {
      final resolved = L10nSetup.localeResolutionCallback(
        null,
        L10nSetup.supportedLocales,
      );
      expect(resolved.languageCode, 'ar');
    });

    test('regional Arabic variants all resolve to the Arabic bundle', () {
      for (final locale in const [
        Locale('ar'),
        Locale('ar', 'SY'),
        Locale('ar', 'EG'),
      ]) {
        expect(
          L10nSetup.localeResolutionCallback(locale, L10nSetup.supportedLocales)
              .languageCode,
          'ar',
        );
      }
    });
  });

  group('Arabic copy', () {
    late AppLocalizationsAr ar;

    setUp(() => ar = AppLocalizationsAr());

    test('addresses the customer as a woman, not a man', () {
      // Q69 P2: "بصيغة المؤنث دائماً". The masculine forms these replaced are
      // listed so a regression is obvious in the diff.
      expect(ar.addToCart, 'ضيفي عالسلّة'); // was: أضف إلى السلة
      expect(ar.buyNow, 'اشتريها هلّق');
      expect(ar.writeComment, 'اكتبي تعليق…');
      expect(ar.shareMoment, 'شاركي لحظتكِ');
      expect(ar.welcomeToOhara, 'يا هلا فيكِ بأوهارا'); // was: مرحباً بك
      expect(ar.contactSupport, 'احكي مع الدعم');
      expect(ar.followDeviceLanguage, 'متل لغة الجهاز'); // was ungrammatical
    });

    test('no Arabic string uses a masculine second-person address', () {
      // Undiacritised, the masculine ـكَ and feminine ـكِ suffixes are both a
      // bare ك, so this cannot be a substring search — "الكل" and "الإلكتروني"
      // would both trip it. The known masculine word-forms are matched as
      // whole tokens instead, and their feminine counterparts (بكِ، لكِ) carry
      // the kasra that tells them apart.
      const masculineForms = {
        'بك', 'لك', 'معك', 'إليك', 'عليك', 'جهازك', 'لحظتك', 'دخولك',
        'عودتك', 'سلتك', 'مفضلتك', 'تفضيلك', 'لغتك', 'حسابك', 'طلبك',
      };

      final offenders = <String>[];
      for (final entry in _arbEntries()) {
        final tokens = entry.value.split(RegExp(r'[^؀-ۿ]+'));
        if (tokens.any(masculineForms.contains)) {
          offenders.add('${entry.key}: ${entry.value}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'masculine address found:\n${offenders.join('\n')}');
    });

    test('plurals cover the Arabic categories, not just one and other', () {
      // Arabic distinguishes zero, one, two, few, many and other. A naive
      // `$count عنصر` would read wrong for two thirds of the number line.
      expect(ar.itemsCount(0), contains('ما في'));
      expect(ar.itemsCount(1), 'قطعة وحدة');
      expect(ar.itemsCount(2), 'قطعتين');
      expect(ar.itemsCount(3), contains('قطع'));
      expect(ar.itemsCount(11), contains('11'));

      expect(ar.sellersOffering(1), 'بائعة وحدة');
      expect(ar.sellersOffering(2), 'بائعتين');
    });

    test('English and Arabic define exactly the same keys', () {
      final en = _keysOf('app_en.arb');
      final arKeys = _keysOf('app_ar.arb');
      expect(arKeys.difference(en), isEmpty, reason: 'Arabic has extra keys');
      expect(en.difference(arKeys), isEmpty, reason: 'Arabic is missing keys');
    });

    test('every Arabic value is actually Arabic', () {
      final latinOnly = <String>[];
      for (final entry in _arbEntries()) {
        final stripped = entry.value.replaceAll(RegExp(r'[^A-Za-z]'), '');
        final hasArabic = RegExp(r'[؀-ۿ]').hasMatch(entry.value);
        // Allow keys that are legitimately Latin (the English language name).
        if (!hasArabic && stripped.isNotEmpty && entry.key != 'en') {
          latinOnly.add('${entry.key}: ${entry.value}');
        }
      }
      expect(latinOnly, isEmpty,
          reason: 'untranslated strings:\n${latinOnly.join('\n')}');
    });
  });
}

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

Set<String> _keysOf(String name) => _arb(name)
    .keys
    .where((k) => !k.startsWith('@'))
    .toSet();

Iterable<MapEntry<String, String>> _arbEntries() sync* {
  for (final entry in _arb('app_ar.arb').entries) {
    if (entry.key.startsWith('@')) continue;
    yield MapEntry(entry.key, entry.value as String);
  }
}
