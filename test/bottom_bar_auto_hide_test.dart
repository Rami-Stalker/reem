// The buyer's bottom bar folds away while she scrolls Home or her profile,
// leaving one button in the middle that brings it back.
//
//   flutter test test/bottom_bar_auto_hide_test.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/experience/role_experience.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/router/app_shell.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/core/sync/outbox_providers.dart';
import 'package:ohara/features/cart/presentation/providers/cart_providers.dart';
import 'package:ohara/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;
import 'package:ohara/l10n/app_localizations_ar.dart';

final _l10n = AppLocalizationsAr();

Widget _longPage(String name) => ListView.builder(
  key: ValueKey(name),
  itemCount: 60,
  itemBuilder: (_, i) => SizedBox(height: 120, child: Text('$name $i')),
);

GoRouter _router() {
  StatefulShellBranch branch(String path) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => _longPage(path))],
  );
  return GoRouter(
    initialLocation: RoutePaths.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          branch(RoutePaths.home),
          branch(RoutePaths.search),
          branch(RoutePaths.closet),
          branch(RoutePaths.profile),
        ],
      ),
    ],
  );
}

Future<void> _pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        roleExperienceProvider.overrideWithValue(AppRoleExperience.buyer),
        cartCountProvider.overrideWithValue(0),
        outboxDrainProvider.overrideWithValue(null),
      ],
      child: MaterialApp.router(
        theme: AppTheme.light,
        locale: const Locale('ar'),
        supportedLocales: L10nSetup.supportedLocales,
        localizationsDelegates: const [
          gen.AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        routerConfig: _router(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Whether the bar is folded: the restore button has risen to full size.
bool _folded(WidgetTester tester) {
  final scale = tester.widget<AnimatedScale>(
    find.ancestor(
      of: find.byTooltip(_l10n.navShowBar),
      matching: find.byType(AnimatedScale),
    ),
  );
  return scale.scale == 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (_) async => null);
  });

  testWidgets('scrolling Home down folds the bar; the button brings it back', (
    tester,
  ) async {
    await _pump(tester);
    expect(_folded(tester), isFalse);

    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(_folded(tester), isTrue);

    // Scrolling back up a little keeps it folded — she is still reading.
    await tester.drag(find.byType(ListView), const Offset(0, 150));
    await tester.pumpAndSettle();
    expect(_folded(tester), isTrue);

    await tester.tap(find.byTooltip(_l10n.navShowBar));
    await tester.pumpAndSettle();
    expect(_folded(tester), isFalse);
    expect(find.text('الرئيسية'), findsOneWidget);
  });

  testWidgets('back at the top of the page, the bar returns by itself', (
    tester,
  ) async {
    await _pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(_folded(tester), isTrue);

    await tester.drag(find.byType(ListView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    expect(_folded(tester), isFalse);
  });

  testWidgets('pages other than Home and her profile keep the bar', (
    tester,
  ) async {
    await _pump(tester);
    await tester.tap(find.text('اكتشفي'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byType(ListView).hitTestable(),
      const Offset(0, -700),
    );
    await tester.pumpAndSettle();
    expect(_folded(tester), isFalse);
  });
}
