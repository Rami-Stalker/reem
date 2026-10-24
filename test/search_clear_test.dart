// The X inside the search field cleared the results and left the word she had
// typed sitting in the box — so the button looked broken, and the only way out
// was the backspace key. It clears the field now, and the button itself is
// driven by the field rather than by a debounced copy of it.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/features/search/presentation/screens/search_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;
import 'package:ohara/l10n/app_localizations_ar.dart';

void main() {
  testWidgets('the clear button empties the field, not only the results', (
    tester,
  ) async {
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => const SearchScreen()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          locale: const Locale('ar'),
          supportedLocales: L10nSetup.supportedLocales,
          localizationsDelegates: const [
            gen.AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();

    final field = find.byType(TextField);
    expect(field, findsOneWidget);

    final l10n = AppLocalizationsAr();
    // Nothing typed yet: no X to press.
    expect(find.byTooltip(l10n.searchClear), findsNothing);

    await tester.enterText(field, 'فستان');
    await tester.pump();

    // It appears with the first character, without waiting out the debounce.
    expect(find.byTooltip(l10n.searchClear), findsOneWidget);

    await tester.tap(find.byTooltip(l10n.searchClear));
    await tester.pump();

    expect(tester.widget<TextField>(field).controller?.text, isEmpty);
    expect(find.byTooltip(l10n.searchClear), findsNothing);
  });
}
