// Renders the buyer's new bottom bar and the closet strip that sits under a
// feed post, to PNGs, so both can be eyeballed without booting the app. It
// also pins the few facts the pictures depend on: the four tabs are named,
// the create button sits among them, and the strip says the right sentence.
//
//   flutter test test/home_feed_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/experience/role_experience.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/router/app_shell.dart';
import 'package:reem/core/router/route_paths.dart';
import 'package:reem/core/sync/outbox_providers.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';
import 'package:reem/features/closet/domain/entities/closet_gap.dart';
import 'package:reem/features/closet/presentation/providers/closet_providers.dart';
import 'package:reem/features/experience/presentation/providers/role_experience_provider.dart';
import 'package:reem/features/home/presentation/widgets/post_closet_strip.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

Future<void> _loadFonts() async {
  for (final entry in const {
    'Cairo': 'assets/fonts/Cairo-VariableFont.ttf',
    'PlayfairDisplay': 'assets/fonts/PlayfairDisplay-VariableFont.ttf',
  }.entries) {
    final loader = FontLoader(entry.key)
      ..addFont(
        File(entry.value).readAsBytes().then((b) => ByteData.view(b.buffer)),
      );
    await loader.load();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    final file = File('${dir.path}/$name.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}

const _localizations = [
  gen.AppLocalizations.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The buyer's four tabs, each a placeholder page, inside the real shell.
GoRouter _shellRouter() {
  StatefulShellBranch branch(String path) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => const SizedBox.expand(),
      ),
    ],
  );

  return GoRouter(
    initialLocation: RoutePaths.home,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => RepaintBoundary(
          key: _captureKey,
          child: AppShell(navigationShell: shell),
        ),
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  testWidgets('the buyer bar: four tabs with create in the middle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            roleExperienceProvider.overrideWithValue(AppRoleExperience.buyer),
            cartCountProvider.overrideWithValue(0),
            outboxDrainProvider.overrideWithValue(null),
          ],
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            locale: const Locale('ar'),
            supportedLocales: L10nSetup.supportedLocales,
            localizationsDelegates: _localizations,
            routerConfig: _shellRouter(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final label in ['الرئيسية', 'اكتشفي', 'خزانتي', 'أنا']) {
        expect(find.byTooltip(label), findsOneWidget, reason: label);
      }
      expect(find.byTooltip('إنشاء'), findsOneWidget);
      // Rooms and Activity left the bar for the closet and the create button.
      expect(find.byTooltip('النشاط'), findsNothing);

      await _capture(tester, 'buyer_bar_${mode.name}');
    }
  });

  testWidgets('the closet strip under a post, in both of its voices', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    const pairs = ClosetPairing(
      slot: 'dress',
      score: 0.8,
      pairsWithItemIds: ['a', 'b', 'c'],
      completesLookIds: ['l1'],
    );
    const owned = ClosetPairing(slot: 'top', score: 0.9, alreadyOwned: 1);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            closetPairingProvider('p1').overrideWith((ref) async => pairs),
            closetPairingProvider('p2').overrideWith((ref) async => owned),
            closetPairingProvider('p3').overrideWith((ref) async => null),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            locale: const Locale('ar'),
            supportedLocales: L10nSetup.supportedLocales,
            localizationsDelegates: _localizations,
            home: RepaintBoundary(
              key: _captureKey,
              child: Builder(
                builder: (context) => Scaffold(
                  backgroundColor: context.dsColors.background,
                  body: const SafeArea(
                    child: Column(
                      children: [
                        SizedBox(height: DsSpacing.md),
                        PostClosetStrip(productId: 'p1'),
                        PostClosetStrip(productId: 'p2'),
                        // No answer from the closet draws nothing at all.
                        PostClosetStrip(productId: 'p3'),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('يُنسَّق مع 3 قطع من خزانتكِ'), findsOneWidget);
      expect(find.text('ويُكمل إطلالة محفوظة'), findsOneWidget);
      expect(find.text('عندكِ مثلها في خزانتكِ'), findsOneWidget);
      expect(find.text('خزانتي'), findsNWidgets(2));

      await _capture(tester, 'post_closet_strip_${mode.name}');
    }
  });
}
