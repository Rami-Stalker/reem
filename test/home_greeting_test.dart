// The hello at the top of the home page has two jobs it used to fail at: it
// must follow Damascus's clock rather than the handset's, and it must not open
// with the same four words every single morning.
//
// Both are easy to regress invisibly — nothing crashes when a greeting is
// wrong, it just quietly says «مساء الخير» over someone's breakfast — so the
// slot boundaries and the rotation are pinned here.
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/utils/damascus_time.dart';
import 'package:ohara/features/home/presentation/widgets/home_greeting.dart';
import 'package:ohara/l10n/app_localizations_ar.dart';

void main() {
  final l10n = AppLocalizationsAr();

  /// 08:00 in Damascus is 05:00 UTC.
  DateTime utc(int hour, {int day = 1}) => DateTime.utc(2026, 9, day, hour);

  group('Damascus clock', () {
    test('carries Syria\'s fixed +03:00 offset', () {
      expect(damascusNow(clock: utc(5)).hour, 8);
      expect(damascusOffset, const Duration(hours: 3));
    });

    test('a handset on a European clock still gets her morning', () {
      // 08:30 in Damascus, held by a phone set to Berlin (07:30 local).
      final berlinMorning = DateTime.utc(2026, 9, 1, 5, 30);
      expect(
        HomeGreetingSlot.at(damascusNow(clock: berlinMorning)),
        HomeGreetingSlot.morning,
      );
    });
  });

  group('slots', () {
    test('run morning, midday, evening, night around the clock', () {
      final expected = <int, HomeGreetingSlot>{
        0: HomeGreetingSlot.night,
        4: HomeGreetingSlot.night,
        5: HomeGreetingSlot.morning,
        11: HomeGreetingSlot.morning,
        12: HomeGreetingSlot.midday,
        16: HomeGreetingSlot.midday,
        17: HomeGreetingSlot.evening,
        21: HomeGreetingSlot.evening,
        22: HomeGreetingSlot.night,
        23: HomeGreetingSlot.night,
      };
      for (final entry in expected.entries) {
        expect(
          HomeGreetingSlot.at(DateTime.utc(2026, 9, 1, entry.key)),
          entry.value,
          reason: 'hour ${entry.key}',
        );
      }
    });

    test('every slot carries more than one way of saying it', () {
      for (final slot in HomeGreetingSlot.values) {
        final phrases = slot.phrases(l10n);
        expect(phrases.length, greaterThan(1), reason: slot.name);
        expect(phrases.toSet().length, phrases.length, reason: 'no repeats');
        expect(phrases.every((phrase) => phrase.trim().isNotEmpty), isTrue);
      }
    });
  });

  group('rotation', () {
    test('does not move while the page rebuilds', () {
      final at = utc(6);
      expect(
        HomeGreetingCopy.of(l10n, clock: at),
        HomeGreetingCopy.of(l10n, clock: at.add(const Duration(minutes: 4))),
      );
    });

    test('works through the whole bouquet over a run of days', () {
      final morning = HomeGreetingSlot.morning.phrases(l10n).toSet();
      final seen = {
        for (var day = 1; day <= 10; day++)
          HomeGreetingCopy.of(l10n, clock: utc(6, day: day)),
      };
      expect(seen, morning, reason: 'every morning phrase gets its turn');
    });

    test('a morning and its own evening never land on the same wording', () {
      for (var day = 1; day <= 14; day++) {
        expect(
          HomeGreetingCopy.of(l10n, clock: utc(6, day: day)),
          isNot(HomeGreetingCopy.of(l10n, clock: utc(16, day: day))),
        );
      }
    });
  });
}
