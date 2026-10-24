// Renders the two Trend Engine dashboards to PNGs so the design can be
// eyeballed without a session or a running backend. Not an assertion test —
// it writes `build/visual/trends_*.png` and is meant to be run on demand.
//
//   flutter test test/trends_visual_preview_test.dart
//
// The repository is faked from `test/fixtures/trends_*_overview.json`, which
// are verbatim captures of the real pipeline run over the seeded shop. So what
// these images show is the real Arabic the templates wrote, the real scores
// the kernel computed, and the real gap in the assortment the search
// intelligence found — not mock text invented to make the layout look good.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/router/route_paths.dart';
import 'package:ohara/features/trends/data/models/trend_mappers.dart';
import 'package:ohara/features/trends/domain/entities/trend_entities.dart';
import 'package:ohara/features/trends/domain/repositories/trends_repository.dart';
import 'package:ohara/features/trends/presentation/providers/trends_providers.dart';
import 'package:ohara/features/trends/presentation/screens/admin_trends_screen.dart';
import 'package:ohara/features/trends/presentation/screens/seller_trends_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();
late final Map<String, dynamic> _sellerFixture;
late final Map<String, dynamic> _adminFixture;

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

  // The icon font too. Without it every icon renders as a tofu box, and on a
  // page where a severity icon and a trend arrow are load-bearing, a preview
  // full of empty squares is not a preview of the design. Skipped rather than
  // failed when the SDK layout differs — the text is still worth looking at.
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot == null) return;
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (!icons.existsSync()) return;
  await (FontLoader('MaterialIcons')
        ..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer))))
      .load();
}

void _stubPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.flutter.io/path_provider'),
    (call) async => Directory.systemTemp.createTempSync('reem_test').path,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _stubPlatformChannels();
    await _loadFonts();
    _sellerFixture =
        jsonDecode(
              File('test/fixtures/trends_seller_overview.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
    _adminFixture =
        jsonDecode(
              File('test/fixtures/trends_admin_overview.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the seller trend engine in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(
          themeMode: mode,
          screen: const SellerTrendsScreen(),
          path: RoutePaths.sellerTrends,
        ),
      );
      await _settle(tester);
      await _capture(tester, 'trends_seller_${mode.name}');
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the market intelligence page in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(
          themeMode: mode,
          screen: const AdminTrendsScreen(),
          path: RoutePaths.adminTrends,
        ),
      );
      await _settle(tester);
      await _capture(tester, 'trends_admin_${mode.name}');
    });
  }

  testWidgets('renders the unmet demand list', (tester) async {
    // The panel the whole Search Intelligence half of the feature exists for:
    // «فستان سهرة أخضر طويل», asked for and never answered.
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: const AdminTrendsScreen(),
        path: RoutePaths.adminTrends,
      ),
    );
    await _settle(tester);

    await tester.scrollUntilVisible(
      find.textContaining('فستان سهرة أخضر').first,
      400,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 120,
    );
    await _settle(tester);
    await _capture(tester, 'trends_unmet_demand');
  });

  testWidgets('renders the seller recommended actions', (tester) async {
    tester.view.physicalSize = const Size(1125, 2000);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: const SellerTrendsScreen(),
        path: RoutePaths.sellerTrends,
      ),
    );
    await _settle(tester);

    // Unfold the evidence under the first insight — the affordance that makes
    // a machine-written sentence something a seller can check rather than
    // take on faith.
    final reveal = find.text('اعرضي الأرقام');
    if (reveal.evaluate().isNotEmpty) {
      await tester.tap(reveal.first);
      await _settle(tester);
    }
    await _capture(tester, 'trends_seller_insight_evidence');
  });
}

class _Preview extends StatelessWidget {
  _Preview({required this.themeMode, required this.screen, required this.path});

  final ThemeMode themeMode;
  final Widget screen;

  /// The route the screen is mounted at. `PremiumAppBar` reads
  /// `GoRouterState` to decide its back affordance, so the preview needs a
  /// real router rather than a bare `home:`.
  final String path;

  late final GoRouter _router = GoRouter(
    initialLocation: path,
    routes: [GoRoute(path: path, builder: (_, _) => screen)],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        trendsRepositoryProvider.overrideWithValue(_FixtureRepository()),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
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
        routerConfig: _router,
        builder: (context, child) =>
            RepaintBoundary(key: _captureKey, child: child),
      ),
    );
  }
}

/// Replays the captured server responses.
class _FixtureRepository implements TrendsRepository {
  @override
  Future<Result<SellerTrendOverview>> sellerOverview(TrendWindow window) async =>
      Success(TrendMappers.sellerOverview(_sellerFixture));

  @override
  Future<Result<AdminTrendOverview>> adminOverview(TrendWindow window) async =>
      Success(TrendMappers.adminOverview(_adminFixture));

  @override
  Future<Result<List<MarketOpportunity>>> adminOpportunities(
    TrendWindow window, {
    int limit = 20,
  }) async {
    // Built from the fixture's own unmet demand, so the panel shows the same
    // gaps the rest of the page is talking about.
    final overview = TrendMappers.adminOverview(_adminFixture);
    return Success([
      for (final signal in overview.unmetDemand.take(5))
        MarketOpportunity(
          kind: 'UNMET_SEARCH',
          titleAr: signal.display,
          detailAr: signal.suggestionAr ?? '',
          score: signal.demandScore,
          subjectId: null,
        ),
    ]);
  }

  @override
  Future<Result<List<SellerPerformanceRow>>> adminSellers({
    int days = 30,
    int limit = 25,
  }) async => const Success([]);

  @override
  Future<Result<List<SellerTrendProduct>>> sellerProducts(
    TrendWindow window, {
    TrendStage? stage,
    int limit = 50,
  }) async =>
      Success(TrendMappers.sellerOverview(_sellerFixture).trending);

  @override
  Future<Result<TrendForecast>> sellerForecast({int horizonDays = 14}) async =>
      Success(TrendMappers.sellerOverview(_sellerFixture).forecast);

  @override
  Future<Result<List<TrendInsight>>> sellerInsights({int limit = 25}) async =>
      Success(TrendMappers.sellerOverview(_sellerFixture).recommendedActions);

  @override
  Future<Result<TrendInsight>> updateSellerInsight(
    String id,
    InsightStatus status,
  ) async =>
      Success(TrendMappers.sellerOverview(_sellerFixture).recommendedActions.first);

  @override
  Future<Result<List<AdminTrendProduct>>> adminProducts(
    TrendWindow window, {
    TrendStage? stage,
    String? categoryId,
    int limit = 50,
  }) async =>
      Success(TrendMappers.adminOverview(_adminFixture).emergingProducts);

  @override
  Future<Result<List<CategoryTrend>>> adminCategories(
    TrendWindow window, {
    int limit = 30,
  }) async => Success(TrendMappers.adminOverview(_adminFixture).categoryTrends);

  @override
  Future<Result<List<AttributeTrend>>> adminAttributes({
    required String dimension,
    int days = 7,
    int limit = 20,
  }) async => Success(TrendMappers.adminOverview(_adminFixture).colourTrends);

  @override
  Future<Result<List<SearchTermTrend>>> adminSearchTerms({
    int days = 30,
    int limit = 50,
    bool rising = false,
  }) async => Success(TrendMappers.adminOverview(_adminFixture).searchTrends);

  @override
  Future<Result<List<UnmetDemand>>> adminUnmetDemand({
    UnmetDemandStatus? status,
    int limit = 50,
  }) async => Success(TrendMappers.adminOverview(_adminFixture).unmetDemand);

  @override
  Future<Result<UnmetDemand>> reviewUnmetDemand(
    String id,
    UnmetDemandStatus status, {
    String? note,
  }) async =>
      Success(TrendMappers.adminOverview(_adminFixture).unmetDemand.first);

  @override
  Future<Result<List<TrendInsight>>> adminInsights({int limit = 25}) async =>
      Success(TrendMappers.adminOverview(_adminFixture).insights);

  @override
  Future<Result<TrendInsight>> updateAdminInsight(
    String id,
    InsightStatus status,
  ) async => Success(TrendMappers.adminOverview(_adminFixture).insights.first);

  @override
  Future<Result<void>> recompute({int lookbackDays = 3}) async =>
      const Success(null);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
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
