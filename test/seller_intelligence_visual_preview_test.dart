// Renders the three Seller Intelligence screens to PNGs so the design can be
// eyeballed without a session or a running backend. Not an assertion test in
// the usual sense — it writes `build/visual/seller_intelligence_*.png` and is
// meant to be run on demand.
//
//   flutter test test/seller_intelligence_visual_preview_test.dart
//
// The repository is faked from `test/fixtures/seller_intelligence.json`, which
// is a verbatim capture of real server responses for a real seeded seller. So
// what these images show is the real arithmetic — a health score of 62.44 over
// three counted dimensions, listings that genuinely need photographs, and
// opportunities computed from the trend engine's own tables — not mock numbers
// chosen to make the layout look good.
//
// It does assert the things a screenshot cannot: that an unmeasured dimension
// renders as a dash rather than a zero, which is the one visual rule the whole
// feature turns on.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/features/seller_intelligence/data/models/intelligence_mappers.dart';
import 'package:ohara/features/seller_intelligence/domain/entities/intelligence.dart';
import 'package:ohara/features/seller_intelligence/domain/repositories/seller_intelligence_repository.dart';
import 'package:ohara/features/seller_intelligence/presentation/providers/intelligence_providers.dart';
import 'package:ohara/features/seller_intelligence/presentation/screens/demand_radar_screen.dart';
import 'package:ohara/features/seller_intelligence/presentation/screens/product_intelligence_screen.dart';
import 'package:ohara/features/seller_intelligence/presentation/screens/seller_health_screen.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();
late final Map<String, dynamic> _fixture;

/// The icon font is not bundled into `flutter test` the way the app bundles
/// it, so every `Icon` renders as an empty square unless it is loaded here —
/// which makes a preview look broken in a way the real screen is not.
String? _materialIconsPath() {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final candidates = <String>[
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    if (flutterRoot != null)
      '$flutterRoot/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
    'C:/src/flutter/bin/cache/dart-sdk/bin/resources/devtools/assets/fonts/MaterialIcons-Regular.otf',
    'C:/src/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
  ];
  for (final path in candidates) {
    if (File(path).existsSync()) return path;
  }
  return null;
}

Future<void> _loadFonts() async {
  final icons = _materialIconsPath();
  if (icons != null) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(File(icons).readAsBytes().then((b) => ByteData.view(b.buffer)));
    await loader.load();
  }

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
    _fixture =
        jsonDecode(
              File('test/fixtures/seller_intelligence.json').readAsStringSync(),
            )
            as Map<String, dynamic>;
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders store health in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(themeMode: mode, screen: const SellerHealthScreen()),
      );
      await _settle(tester);
      await _capture(tester, 'seller_intelligence_health_${mode.name}');
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders product intelligence in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(themeMode: mode, screen: const ProductIntelligenceScreen()),
      );
      await _settle(tester);
      await _capture(tester, 'seller_intelligence_products_${mode.name}');
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the demand radar in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(themeMode: mode, screen: const DemandRadarScreen()),
      );
      await _settle(tester);
      await _capture(tester, 'seller_intelligence_radar_${mode.name}');
    });
  }

  testWidgets('a listing opens to show its axes and the rest of its advice', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(
        themeMode: ThemeMode.light,
        screen: ProductIntelligenceScreen(),
      ),
    );
    await _settle(tester);

    // The first card is the weakest listing — the one the work queue exists
    // to put in front of her.
    await tester.tap(find.byType(SellerPanel).at(1));
    await _settle(tester);
    await _capture(tester, 'seller_intelligence_product_open');
  });

  testWidgets('the listing metadata line reads as one sentence', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(
        themeMode: ThemeMode.light,
        screen: ProductIntelligenceScreen(),
      ),
    );
    await _settle(tester);

    final list = IntelligenceMappers.productList(
      Map<String, dynamic>.from(_fixture['products'] as Map),
    );
    final first = list.rows.first;

    // Read the rendered string back rather than trusting the screenshot: at
    // preview resolution a separator and a digit are hard to tell apart, and
    // an Arabic screen mixing numeral systems would be a real defect.
    final line = tester
        .widgetList<Text>(find.byType(Text))
        .map((t) => t.data)
        .whereType<String>()
        .firstWhere((t) => t.contains('مشاهدات'));

    expect(line, contains('مشاهدات: ${first.views}'));
    expect(line, contains('طلبات: ${first.orders}'));
    expect(
      RegExp(r'[٠-٩]').hasMatch(line),
      isFalse,
      reason: 'digits must not switch to Arabic-Indic mid-sentence: "$line"',
    );
  });

  // ── The rule a screenshot cannot check ─────────────────────────────────

  testWidgets('an unmeasured dimension reads as a dash, never as zero', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(themeMode: ThemeMode.light, screen: SellerHealthScreen()),
    );
    await _settle(tester);

    final health = IntelligenceMappers.sellerHealth(
      Map<String, dynamic>.from(_fixture['health'] as Map),
    );
    final unmeasured = health.dimensions.where((d) => d.score == null).toList();
    expect(
      unmeasured,
      isNotEmpty,
      reason: 'the fixture should carry at least one unmeasured dimension',
    );

    // The section is well below the fold, and a sliver list does not build
    // what it has not scrolled to — so scroll to it the way she would.
    await tester.dragUntilVisible(
      find.text('اللي عنّا لسّا ما بيكفي'),
      find.byType(CustomScrollView),
      const Offset(0, -300),
    );
    await _settle(tester);

    expect(find.text('اللي عنّا لسّا ما بيكفي'), findsOneWidget);

    // Each unmeasured dimension is still listed, and each says what it is
    // waiting for rather than showing a score.
    for (final dimension in unmeasured) {
      expect(
        find.text(dimension.label),
        findsWidgets,
        reason: 'the ${dimension.key} row should still be shown',
      );
    }
    expect(
      find.textContaining('لسّا ما في شي نقيسه'),
      findsWidgets,
      reason: 'an unmeasured dimension explains itself instead of showing 0',
    );
    expect(
      find.text('0'),
      findsNothing,
      reason: 'nothing unmeasured may be drawn as a zero',
    );
  });

  testWidgets('a provisional shop is told so rather than shown a verdict', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(themeMode: ThemeMode.light, screen: SellerHealthScreen()),
    );
    await _settle(tester);

    final health = IntelligenceMappers.sellerHealth(
      Map<String, dynamic>.from(_fixture['health'] as Map),
    );

    if (health.isProvisional) {
      expect(
        find.textContaining('لسّا ما في طلبات كفاية'),
        findsOneWidget,
        reason: 'a BUILDING shop must be told the score is not a verdict yet',
      );
    } else {
      expect(find.text(health.bandLabel), findsWidgets);
    }
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.themeMode, required this.screen});

  final ThemeMode themeMode;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sellerIntelligenceRepositoryProvider.overrideWithValue(
          _FixtureRepository(),
        ),
      ],
      child: MaterialApp(
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
        home: RepaintBoundary(key: _captureKey, child: screen),
      ),
    );
  }
}

/// Replays the captured server responses.
class _FixtureRepository implements SellerIntelligenceRepository {
  Map<String, dynamic> _section(String key) =>
      Map<String, dynamic>.from(_fixture[key] as Map);

  @override
  Future<Result<DemandRadar>> radar({int? days}) async =>
      Success(IntelligenceMappers.radar(_section('radar')));

  @override
  Future<Result<ProductHealthList>> products({int? days, int? limit}) async =>
      Success(IntelligenceMappers.productList(_section('products')));

  @override
  Future<Result<ProductHealth>> product(String productId, {int? days}) async =>
      Success(IntelligenceMappers.productDetail(_section('product_detail')));

  /// The advisor reads live order rows rather than the nightly pipeline, so
  /// the capture has no section for it. Empty is the honest replay: the
  /// health screen draws nothing at all when nothing is declining.
  @override
  Future<Result<List<DecliningListing>>> declining() async =>
      Success(IntelligenceMappers.declining(
        _fixture['declining'] as List? ?? const [],
      ));

  @override
  Future<Result<SellerHealth>> health({int? days}) async =>
      Success(IntelligenceMappers.sellerHealth(_section('health')));

  @override
  Future<Result<List<HealthPoint>>> healthHistory({int? days}) async =>
      const Success([]);

  @override
  Future<Result<void>> snapshot() async => const Success(null);
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
