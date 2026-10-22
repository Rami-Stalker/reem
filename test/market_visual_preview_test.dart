// Renders the Reem Market Evolution screens to PNGs so the design can be
// eyeballed without a session or a running backend. Not an assertion test in
// the usual sense — it writes `build/visual/market_*.png` and is meant to be
// run on demand.
//
//   flutter test test/market_visual_preview_test.dart
//
// The repository is faked from `test/fixtures/market.json`, a verbatim capture
// of real server responses for a real seeded shopper and a real seeded seller.
// So the bundles here were assembled by the commerce graph from products that
// are actually in stock, the wardrobe readings come from the life-cycle kernel
// over real closet rows, and the drop's invitation carries the reasons the
// graph itself produced — nothing on these screens is a number chosen to make
// a layout look good.
//
// It also asserts the four things a screenshot cannot check, each of which is
// a rule the whole phase turns on:
//
//   - every bundle piece states why it is in the set;
//   - a bundle names the shops it crosses;
//   - an invited drop says why she was invited;
//   - a mission's bar measures what she has done since being asked.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/features/market/data/models/market_mappers.dart';
import 'package:reem/features/market/domain/entities/market.dart';
import 'package:reem/features/market/domain/repositories/market_repository.dart';
import 'package:reem/features/market/presentation/providers/market_providers.dart';
import 'package:reem/features/market/presentation/screens/bundle_screen.dart';
import 'package:reem/features/market/presentation/screens/bundles_screen.dart';
import 'package:reem/features/market/presentation/screens/drops_screen.dart';
import 'package:reem/features/market/presentation/screens/missions_screen.dart';
import 'package:reem/features/market/presentation/screens/resale_market_screen.dart';
import 'package:reem/features/market/presentation/screens/seller_market_screen.dart';
import 'package:reem/features/market/presentation/screens/wardrobe_care_screen.dart';
import 'package:reem/features/market/presentation/widgets/market_pieces.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

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
        jsonDecode(File('test/fixtures/market.json').readAsStringSync())
            as Map<String, dynamic>;
  });

  // ── The screenshots ──────────────────────────────────────────────────────

  final screens = <String, Widget>{
    'bundles': const BundlesScreen(),
    'drops': const DropsScreen(),
    'wardrobe': const WardrobeCareScreen(),
    'resale': const ResaleMarketScreen(),
    'missions': const MissionsScreen(),
    'seller': const SellerMarketScreen(),
  };

  for (final entry in screens.entries) {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('renders ${entry.key} in ${mode.name}', (tester) async {
        tester.view.physicalSize = const Size(1125, 2436);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_Preview(themeMode: mode, screen: entry.value));
        await _settle(tester);
        await _capture(tester, 'market_${entry.key}_${mode.name}');
      });
    }
  }

  testWidgets('renders one assembled look', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: BundleScreen(bundleId: _bundle().id),
      ),
    );
    await _settle(tester);
    await _capture(tester, 'market_bundle_detail');
  });

  // ── The rules a screenshot cannot check ──────────────────────────────────

  testWidgets('every piece in a bundle states why it is there', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final bundle = _bundle();
    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: BundleScreen(bundleId: bundle.id),
      ),
    );
    await _settle(tester);

    for (final item in bundle.items) {
      expect(
        item.reason,
        isNotNull,
        reason: 'the server sent a piece with no reason: ${item.title}',
      );
      expect(
        find.text(item.reason!),
        findsWidgets,
        reason:
            'a bundle whose members cannot explain themselves is a gift basket',
      );
    }
  });

  testWidgets('a bundle names the shops it crosses', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final bundle = _bundle();
    expect(
      bundle.sellerCount,
      greaterThan(1),
      reason: 'the fixture should carry a genuinely cross-shop bundle',
    );

    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: BundleScreen(bundleId: bundle.id),
      ),
    );
    await _settle(tester);

    // Crossing sellers is what makes a bundle a marketplace feature rather
    // than one shop's upsell, and the page has to say so.
    expect(find.textContaining('${bundle.sellerCount} محلات'), findsWidgets);
    for (final item in bundle.items.where((i) => i.sellerName != null)) {
      expect(
        find.textContaining(item.sellerName!),
        findsWidgets,
        reason: 'a bundle piece with no shop named is an anonymous purchase',
      );
    }
  });

  testWidgets('an invited drop says why she was invited', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final drops = _drops();
    final invited = drops.where((d) => d.invitation != null).toList();
    expect(
      invited,
      isNotEmpty,
      reason: 'the fixture should carry a drop the shopper was invited to',
    );

    await tester.pumpWidget(
      const _Preview(themeMode: ThemeMode.light, screen: DropsScreen()),
    );
    await _settle(tester);

    final l10n = gen.AppLocalizations.of(
      tester.element(find.byType(DropsScreen)),
    );
    for (final drop in invited) {
      expect(
        drop.invitation!.reasons,
        isNotEmpty,
        reason: 'an invitation with no reason is a blast',
      );
      expect(
        find.text(dropReasonLabel(l10n!, drop.invitation!.reasons)),
        findsWidgets,
        reason: 'the reason the graph picked her must reach the card',
      );
    }
  });

  testWidgets('a mission bar measures what she did since being asked', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(themeMode: ThemeMode.light, screen: MissionsScreen()),
    );
    await _settle(tester);

    for (final mission in _missions().where((m) => !m.isComplete)) {
      // The number on the card is progress since the offer, so it can never
      // exceed the target — a lifetime count would, and would read as "15 من 2".
      expect(
        mission.done,
        lessThanOrEqualTo(mission.target),
        reason: 'the bar must not be pre-filled by her history',
      );
      expect(find.text('${mission.done} من ${mission.target}'), findsWidgets);
      // And nothing is ever asked that she cannot finish.
      expect(
        mission.possible,
        greaterThanOrEqualTo(mission.remaining),
        reason: 'a mission she cannot finish should never have been offered',
      );
    }
  });

  testWidgets('a wardrobe reading never prices a piece it says to restyle', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(themeMode: ThemeMode.light, screen: WardrobeCareScreen()),
    );
    await _settle(tester);

    final pieces = _wardrobe();
    expect(pieces, isNotEmpty);

    for (final piece in pieces) {
      if (piece.reading.disposition == Disposition.resell) continue;
      expect(
        piece.suggestedPriceSyp,
        isNull,
        reason:
            'a price beside "wear it again" turns a styling note into a nudge '
            'to sell: ${piece.title}',
      );
    }

    // And every piece on this screen has something to say. A card with no
    // sentence is a card that should not have been drawn.
    for (final piece in pieces) {
      expect(piece.reading.reason, isNotEmpty, reason: piece.title);
      expect(find.text(piece.reading.reason), findsWidgets);
    }
  });
}

// ── Fixture decoding ──────────────────────────────────────────────────────

Map<String, dynamic> _section(String key) =>
    Map<String, dynamic>.from(_fixture[key] as Map);

List<Map<String, dynamic>> _rows(String key, String field) {
  final section = _fixture[key];
  if (section is! Map) return const [];
  final rows = section[field];
  return rows is List
      ? rows.whereType<Map<String, dynamic>>().toList(growable: false)
      : const [];
}

Bundle _bundle() => bundleFromJson(
  Map<String, dynamic>.from(_section('bundle')['bundle'] as Map),
);

List<Bundle> _bundles() =>
    _rows('bundles', 'bundles').map(bundleFromJson).toList(growable: false);

List<Drop> _drops() =>
    _rows('drops', 'drops').map(dropFromJson).toList(growable: false);

List<WardrobePiece> _wardrobe() => _rows('wardrobe_attention', 'items')
    .map(wardrobePieceFromJson)
    .toList(growable: false);

List<Mission> _missions() =>
    _rows('missions', 'missions').map(missionFromJson).toList(growable: false);

class _Preview extends StatelessWidget {
  const _Preview({required this.themeMode, required this.screen});

  final ThemeMode themeMode;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        marketRepositoryProvider.overrideWithValue(_FixtureRepository()),
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
class _FixtureRepository implements MarketRepository {
  @override
  Future<Result<List<Drop>>> openDrops() async => Success(_drops());

  @override
  Future<Result<void>> markDropOpened(String dropId) async =>
      const Success(null);

  @override
  Future<Result<List<Bundle>>> bundles({String? occasion, int? limit}) async {
    final all = _bundles();
    return Success(
      occasion == null
          ? all
          : all.where((b) => b.occasion == occasion).toList(growable: false),
    );
  }

  @override
  Future<Result<Bundle>> bundle(String bundleId) async => Success(_bundle());

  @override
  Future<Result<List<BundleAlternative>>> bundleAlternatives(
    String bundleId,
  ) async => Success(
    _rows('bundle_alternatives', 'alternatives')
        .map(bundleAlternativeFromJson)
        .toList(growable: false),
  );

  @override
  Future<
    Result<
      ({List<({String offerId, int quantity})> lines, List<String> unavailable})
    >
  >
  bundleCheckoutLines(String bundleId) async => const Success((
    lines: <({String offerId, int quantity})>[],
    unavailable: <String>[],
  ));

  @override
  Future<Result<WardrobeSummary>> wardrobeSummary() async =>
      Success(wardrobeSummaryFromJson(_section('wardrobe_summary')));

  @override
  Future<Result<List<WardrobePiece>>> wardrobeAttention({int? limit}) async =>
      Success(_wardrobe());

  @override
  Future<Result<WardrobePiece>> wardrobeItem(String closetItemId) async =>
      Success(_wardrobe().first);

  @override
  Future<Result<ResaleListing>> draftListing(
    String closetItemId, {
    required String condition,
    double? priceSyp,
    String? title,
    String? note,
  }) async => Success(_myListings().first);

  @override
  Future<Result<ResaleListing>> setListingStatus(
    String listingId,
    String status,
  ) async => Success(_myListings().first);

  @override
  Future<Result<List<ResaleListing>>> myListings() async =>
      Success(_myListings());

  @override
  Future<Result<List<ResaleListing>>> resaleMarket({
    String? slot,
    int? limit,
  }) async => Success(
    _rows('resale_market', 'listings')
        .map(resaleListingFromJson)
        .toList(growable: false),
  );

  List<ResaleListing> _myListings() => _rows('resale_mine', 'listings')
      .map(resaleListingFromJson)
      .toList(growable: false);

  @override
  Future<Result<List<Mission>>> missions() async => Success(_missions());

  @override
  Future<Result<void>> declineMission(String key) async => const Success(null);

  @override
  Future<Result<List<MarketOpportunity>>> sellerOpportunities({
    int? limit,
  }) async => Success(
    _rows('seller_opportunities', 'opportunities')
        .map(opportunityFromJson)
        .toList(growable: false),
  );

  @override
  Future<Result<List<DropCandidate>>> dropCandidates({int? limit}) async =>
      Success(
        _rows('drop_candidates', 'candidates')
            .map(dropCandidateFromJson)
            .toList(growable: false),
      );

  @override
  Future<Result<List<Drop>>> sellerDrops() async => Success(
    _rows('seller_drops', 'drops').map(dropFromJson).toList(growable: false),
  );

  @override
  Future<Result<Drop>> createDrop({
    required String title,
    required String audience,
    required DateTime startsAt,
    required List<String> productIds,
    DateTime? earlyAccessAt,
    DateTime? endsAt,
    String? note,
  }) async => Success(_drops().first);

  @override
  Future<Result<int>> buildDropAudience(String dropId, {int? limit}) async =>
      const Success(0);

  @override
  Future<Result<Drop>> setDropStatus(String dropId, String status) async =>
      Success(_drops().first);
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
