// Renders what a shopper sees of «إعلانات المتاجر»: the home spotlight, the
// tier badge on a featured store, and a sponsored post at the top of the feed.
//
//   flutter test test/store_ads_shopper_visual_preview_test.dart
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
import 'package:ohara/core/shared/models/product_model.dart';
import 'package:ohara/features/home/domain/entities/featured_store.dart';
import 'package:ohara/features/home/domain/entities/home_content.dart';
import 'package:ohara/features/home/domain/entities/sponsored_spotlight.dart';
import 'package:ohara/features/home/domain/repositories/home_content_repository.dart';
import 'package:ohara/features/home/presentation/providers/home_content_provider.dart';
import 'package:ohara/features/home/presentation/widgets/home_featured_stores.dart';
import 'package:ohara/features/home/presentation/widgets/home_sponsored_spotlight.dart';
import 'package:ohara/features/social/data/models/content_model.dart';
import 'package:ohara/features/social/presentation/widgets/content_card.dart';
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
  // Material's icon font ships with the SDK, not the app, so a widget test
  // draws every icon as a box unless it is loaded by hand.
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (root != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(icons.readAsBytes().then((b) => ByteData.view(b.buffer)));
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
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => ['wifi'],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _stubPlatformChannels();
    await _loadFonts();
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders sponsored surfaces in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Preview(themeMode: mode));
      await _settle(tester);
      await _capture(tester, 'store_ads_shopper_${mode.name}');
    });
  }
}

Map<String, dynamic> _fixtureProduct(int index) {
  final feed =
      jsonDecode(File('test/fixtures/posts_feed.json').readAsStringSync())
          as Map<String, dynamic>;
  final products = [
    for (final row in (feed['data'] as List).cast<Map<String, dynamic>>())
      if (row['product'] case final Map<String, dynamic> product) product,
  ];
  return products[index % products.length];
}

class _Preview extends StatelessWidget {
  _Preview({required this.themeMode});

  final ThemeMode themeMode;

  late final GoRouter _router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, _) => const _Page())],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [homeContentRepositoryProvider.overrideWithValue(_FakeHome())],
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

class _Page extends StatelessWidget {
  const _Page();

  @override
  Widget build(BuildContext context) {
    final post = ContentModel.fromJson({
      'id': 'c1',
      'author': {
        'id': 's1',
        'name': 'أتيليه رهف',
        'username': 'rahaf',
        'role': 'seller',
        'is_verified': true,
        'created_at': '2026-01-01T00:00:00.000Z',
      },
      'author_kind': 'seller',
      'content_type': 'product_post',
      'body': 'تشكيلة الخريف وصلت 🍂',
      'status': 'published',
      'visibility': 'public',
      'moderation_state': 'active',
      'published_at': '2026-10-28T10:00:00.000Z',
      'created_at': '2026-10-28T10:00:00.000Z',
      'media': const [],
      'product_tags': [
        {'id': 't1', 'product': _fixtureProduct(0), 'sort_order': 0},
      ],
      'analytics': {'reactions': 84, 'replies': 6},
      'sponsored': {
        'promotion_id': 'p1',
        'offer_id': 'o1',
        'placement': 'feed_top',
        'store_tier': 'diamond',
      },
    });
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(top: DsSpacing.xxl),
        children: [
          const HomeSponsoredSpotlight(),
          const HomeFeaturedStores(),
          DsGaps.vXl,
          ContentCard(
            content: post,
            onOpenAuthor: (_) {},
            onOpenProduct: (_) {},
            onLike: () {},
            onSave: () {},
            onComment: () {},
            onShare: () {},
            onReshare: () {},
            onMore: () {},
          ),
        ],
      ),
    );
  }
}

final class _FakeHome implements HomeContentRepository {
  @override
  Future<Result<HomeContent>> getHomeContent() async => Success(
    HomeContent(
      sponsoredSpotlight: [
        for (final (i, tier) in const [(1, 'diamond'), (2, 'gold')].indexed)
          SponsoredSpotlight(
            product: ProductModel.fromJson(_fixtureProduct(tier.$1)),
            offerId: 'o$i',
            storeId: 's$i',
            storeName: i == 0 ? 'أتيليه رهف' : 'بيت الحرير',
            storeTier: tier.$2,
          ),
      ],
      featuredStores: const [
        FeaturedStore(
          id: 's1',
          name: 'أتيليه رهف',
          tagline: 'فساتين سهرة مطرّزة يدوياً',
          logoUrl: '',
          coverUrl: '',
          isVerified: true,
          rating: 4.8,
          adTier: 'diamond',
        ),
        FeaturedStore(
          id: 's2',
          name: 'بيت الحرير',
          tagline: 'أوشحة وشالات',
          logoUrl: '',
          coverUrl: '',
          adTier: 'gold',
        ),
      ],
    ),
  );
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
        _captureKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    final file = File('${dir.path}/$name.png')
      ..writeAsBytesSync(data!.buffer.asUint8List());
    // ignore: avoid_print
    print('wrote ${file.path}');
  });
}
