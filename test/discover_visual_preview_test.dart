// Renders the Discover tab to PNGs, signed in, so the hub can be eyeballed
// without booting the app, and checks it opens on the question and on what
// her rooms and closet say she needs.
//
//   flutter test test/discover_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/features/ai_stylist/domain/entities/stylist_conversation.dart';
import 'package:ohara/features/ai_stylist/presentation/providers/ai_stylist_providers.dart';
import 'package:ohara/features/auth/presentation/providers/auth_notifier.dart';
import 'package:ohara/features/auth/presentation/providers/auth_provider.dart';
import 'package:ohara/features/auth/presentation/providers/auth_state.dart';
import 'package:ohara/features/closet/domain/entities/closet_gap.dart';
import 'package:ohara/features/closet/domain/entities/closet_item.dart';
import 'package:ohara/features/closet/domain/entities/closet_overview.dart';
import 'package:ohara/features/closet/presentation/providers/closet_providers.dart';
import 'package:ohara/features/home/domain/entities/home_content.dart';
import 'package:ohara/features/home/domain/repositories/home_content_repository.dart';
import 'package:ohara/features/home/presentation/providers/home_content_provider.dart';
import 'package:ohara/features/rooms/domain/entities/room.dart';
import 'package:ohara/features/rooms/presentation/providers/rooms_providers.dart';
import 'package:ohara/features/search/presentation/screens/discover_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  testWidgets('Discover opens on the question and what she needs', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    // Two days out on the Damascus calendar, whenever the test runs.
    final inTwoDays = DateTime.now().toUtc().add(const Duration(days: 2));

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authNotifierProvider.overrideWith((ref) => _SignedIn(_me)),
            roomsProvider.overrideWith(
              (ref) async => [
                Room(
                  id: 'r1',
                  kind: RoomKind.occasion,
                  status: RoomStatus.deciding,
                  title: 'عرس سلمى',
                  occasionLabel: 'عرس',
                  targetDate: inTwoDays,
                ),
              ],
            ),
            closetOverviewProvider.overrideWith(
              (ref) async => const ClosetOverview(
                settings: ClosetSettings(id: 's1'),
                season: 'AUTUMN',
                seasonLabel: 'الخريف',
                itemsCount: 84,
                gaps: [
                  ClosetGap(
                    id: 'g1',
                    kind: ClosetGapKind.coverage,
                    slot: 'BOTTOM',
                    slotLabel: 'بنطال',
                    headline: 'بنطال بيج واسع',
                    rationale: 'يفتح 4 إطلالات لقمصان عندكِ ولا تلبسينها.',
                    priority: 0.9,
                    suggestedColours: [
                      ClosetTerm(key: 'beige', label: 'بيج'),
                      ClosetTerm(key: 'ivory', label: 'عاجي'),
                    ],
                  ),
                ],
              ),
            ),
            stylistBootstrapProvider.overrideWith(
              (ref) async => const StylistBootstrap(
                prompts: [
                  'عندي عرس بعد أسبوع',
                  'هدية لأمي تحت 50 ألف',
                  'لوك عمل للخريف',
                ],
              ),
            ),
            homeContentRepositoryProvider.overrideWithValue(_NoHomeContent()),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            themeMode: mode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            locale: const Locale('ar'),
            supportedLocales: L10nSetup.supportedLocales,
            localizationsDelegates: const [
              gen.AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: RepaintBoundary(
              key: _captureKey,
              child: const DiscoverScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('اسألي أوهارا'), findsOneWidget);
      expect(find.text('ما ينتظركِ'), findsOneWidget);
      expect(find.text('عرس سلمى'), findsOneWidget);
      expect(find.text('بعد يومين'), findsOneWidget);
      expect(find.text('بنطال بيج واسع'), findsOneWidget);
      expect(find.text('عندي عرس بعد أسبوع'), findsOneWidget);

      await _capture(tester, 'discover_${mode.name}');
    }
  });
}

final _me = User(
  id: 'u-me',
  name: 'ريم الأحمد',
  username: 'reem.ahmad',
  phone: '',
  createdAt: DateTime(2026, 1, 1),
);

/// Signed in as a shopper, without the session machinery behind it.
class _SignedIn extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedIn(User user) : super(AuthState(user: user, isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _NoHomeContent implements HomeContentRepository {
  @override
  Future<Result<HomeContent>> getHomeContent() async =>
      const Success(HomeContent());
}
