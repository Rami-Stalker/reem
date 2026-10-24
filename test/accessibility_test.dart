// Accessibility guarantees the design system is supposed to give the whole
// app for free. These are the properties that break silently: a control that
// announces nothing, and a layout that survives only at 100% text.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';

Widget _host(Widget child, {double textScale = 1.0}) {
  return MaterialApp(
    theme: AppTheme.light,
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  group('controls announce themselves', () {
    testWidgets('a button is a button, with its label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(DsButton(label: 'أضيفي إلى السلة', onPressed: () {})),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('أضيفي إلى السلة')),
        matchesSemantics(
          label: 'أضيفي إلى السلة',
          isButton: true,
          isEnabled: true,
          hasEnabledState: true,
          hasTapAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('a disabled button still says it is there', (tester) async {
      // Announcing nothing would leave her unable to tell an unavailable
      // control from a missing one.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(const DsButton(label: 'الدفع', onPressed: null)),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('الدفع')),
        matchesSemantics(
          label: 'الدفع',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('an icon button is named by its tooltip', (tester) async {
      // An icon carries no text, so the tooltip is the only thing a screen
      // reader can read. Without it the control is unusable without sight.
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          DsIconButton(
            icon: Icons.favorite_border_rounded,
            tooltip: 'إضافة إلى المفضّلة',
            onPressed: () {},
          ),
        ),
      );

      expect(find.bySemanticsLabel('إضافة إلى المفضّلة'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('an avatar is named by its person, not called an avatar',
        (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const DsAvatar(name: 'أتيليه الورد')));

      expect(find.bySemanticsLabel('أتيليه الورد'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a chip reports selection and availability', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              DsChip(label: 'M', selected: true, onTap: () {}),
              const DsChip(label: 'L', enabled: false),
            ],
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('M')),
        matchesSemantics(
          label: 'M',
          isButton: true,
          hasSelectedState: true,
          isSelected: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('L')),
        matchesSemantics(
          label: 'L',
          isButton: true,
          hasSelectedState: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });
  });

  group('the type scale survives large text', () {
    // Ohara's buyers include women who run their phones at 150-200%. A control
    // whose height is fixed while its text grows is one that swallows its own
    // label, and the failure is invisible at 100%.
    for (final scale in [1.0, 1.5, 2.0]) {
      testWidgets('a button at ${scale}x does not overflow', (tester) async {
        await tester.pumpWidget(
          _host(
            const SizedBox(
              width: 200,
              child: DsButton(label: 'أضيفي إلى السلة', onPressed: null),
            ),
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('a badge at ${scale}x does not overflow', (tester) async {
        await tester.pumpWidget(
          _host(const DsBadge(label: 'جديد'), textScale: scale),
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('a chip at ${scale}x does not overflow', (tester) async {
        await tester.pumpWidget(
          _host(
            const SizedBox(width: 120, child: DsChip(label: 'فساتين سهرة')),
            textScale: scale,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('touch targets', () {
    testWidgets('an icon button meets the minimum tappable size',
        (tester) async {
      // 48dp is the WCAG / Material floor. Below it, a tap is a coin toss for
      // anyone with less than perfect motor control.
      await tester.pumpWidget(
        _host(
          DsIconButton(icon: Icons.close_rounded, onPressed: () {}),
        ),
      );

      final size = tester.getSize(find.byType(DsIconButton));
      expect(
        size.width,
        greaterThanOrEqualTo(DsSizes.controlMd),
        reason: 'a control smaller than this is hard to hit',
      );
      expect(size.height, greaterThanOrEqualTo(DsSizes.controlMd));
    });
  });
}
