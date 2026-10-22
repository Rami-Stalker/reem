import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/features/home/presentation/widgets/home_greeting.dart';
import 'package:reem/features/home/presentation/widgets/living/aura_palette.dart';
import 'package:reem/features/home/presentation/widgets/living/live_countdown.dart';

void main() {
  group('the home sky follows the Damascus hour', () {
    test('each part of a light day has its own sky, all with dark ink', () {
      final skies = {
        for (final slot in [
          HomeGreetingSlot.morning,
          HomeGreetingSlot.midday,
          HomeGreetingSlot.evening,
        ])
          slot: AuraPalette.of(slot, isDark: false),
      };
      expect(skies.values.toSet(), hasLength(3), reason: 'three distinct skies');
      for (final sky in skies.values) {
        expect(sky.isDeep, isFalse);
        expect(sky.ink, isNot(DsColors.onMedia));
      }
    });

    test('night is deep with light ink, and dark mode keeps the night sky', () {
      final night = AuraPalette.of(HomeGreetingSlot.night, isDark: false);
      expect(night.isDeep, isTrue);
      expect(night.ink, DsColors.onMedia);
      // A bright sky under a dark app reads as a mistake, not a mood.
      expect(
        AuraPalette.of(HomeGreetingSlot.morning, isDark: true),
        same(night),
      );
    });

    test('slots split the day where the greeting does', () {
      DateTime at(int hour) => DateTime.utc(2026, 10, 22, hour);
      expect(HomeGreetingSlot.at(at(9)), HomeGreetingSlot.morning);
      expect(HomeGreetingSlot.at(at(14)), HomeGreetingSlot.midday);
      expect(HomeGreetingSlot.at(at(19)), HomeGreetingSlot.evening);
      expect(HomeGreetingSlot.at(at(23)), HomeGreetingSlot.night);
    });
  });

  group('a live countdown', () {
    test('reads HH:MM:SS with Western digits and does not wrap at a day', () {
      expect(
        LiveCountdown.format(const Duration(hours: 27, minutes: 4, seconds: 9)),
        '27:04:09',
      );
      expect(LiveCountdown.format(const Duration(seconds: 59)), '00:00:59');
    });

    test('never goes negative once the moment has passed', () {
      expect(LiveCountdown.format(const Duration(seconds: -5)), '00:00:00');
    });

    testWidgets('ticks once a second', (tester) async {
      final endsAt = DateTime.now().add(const Duration(minutes: 1));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: LiveCountdown(
            endsAt: endsAt,
            builder: (_, left) => Text(left),
          ),
        ),
      );
      final first = tester.widget<Text>(find.byType(Text)).data;
      expect(first, matches(RegExp(r'^00:0[01]:\d\d$')));
      await tester.pump(const Duration(seconds: 1));
      expect(find.byType(Text), findsOneWidget);
    });
  });
}
