// Renders the seller command centre to PNGs so the design can be eyeballed
// without a seller session. Not an assertion test — it writes
// `build/visual/seller_home_*.png` and is meant to be run on demand.
//
//   flutter test test/seller_home_visual_preview_test.dart
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/features/seller_dashboard/data/datasources/impl/seller_dashboard_mock_datasource.dart';
import 'package:reem/features/seller_dashboard/data/datasources/seller_dashboard_datasource.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_dashboard_data.dart';
import 'package:reem/features/seller_dashboard/domain/entities/seller_store_info.dart';
import 'package:reem/features/seller_dashboard/presentation/providers/seller_dashboard_provider.dart';
import 'package:reem/features/seller_dashboard/presentation/screens/seller_home_screen.dart';
import 'package:reem/features/seller_dashboard/presentation/screens/seller_profile_screen.dart';
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

/// Silences the two plugins these screens reach for that have no
/// implementation in a widget test.
///
/// `path_provider` — `CachedNetworkImage` wants a cache folder. `secure_storage`
/// — the auth interceptor wants device headers for the commission call the
/// profile's payout card makes. Either exception lands mid-pump and derails
/// the entrance animations, so captures came out blank at random. Stubbed,
/// both fail gracefully: the image falls back to its glyph and the payout card
/// falls back to the store's own figures, exactly as they would offline.
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
  });

  // One test per theme rather than a loop: mounting a second tree in the same
  // test left the first one's animation tickers pending at teardown, which
  // failed the test even though both captures were correct.
  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the seller command centre in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Preview(themeMode: mode));
      await _settle(tester);
      await _capture(tester, 'seller_home_${mode.name}');
    });
  }

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the seller store profile in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(themeMode: mode, screen: const SellerProfileScreen()),
      );
      await _settle(tester);
      await _capture(tester, 'seller_profile_${mode.name}');
    });
  }

  testWidgets('renders the seller store profile scrolled to the menu', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      const _Preview(
        themeMode: ThemeMode.light,
        screen: SellerProfileScreen(),
      ),
    );
    await _settle(tester);
    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -1800),
      warnIfMissed: false,
    );
    await _settle(tester);
    await _capture(tester, 'seller_profile_menu');
  });

  testWidgets('renders the seller command centre scrolled to the charts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const _Preview(themeMode: ThemeMode.light));
    await _settle(tester);

    await tester.drag(
      find.byType(CustomScrollView),
      const Offset(0, -520),
      warnIfMissed: false,
    );
    await _settle(tester);
    await _capture(tester, 'seller_home_charts');
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.themeMode, this.screen = const SellerHomeScreen()});

  final ThemeMode themeMode;
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        // The command centre against the mock store, so the preview needs
        // neither a seller session nor a running backend.
        sellerDashboardDataSourceProvider.overrideWithValue(
          const _OfflineMockDashboard(),
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

/// The mock store with its remote logo stripped.
///
/// A `CachedNetworkImage` in the tree keeps `flutter_cache_manager` scheduling
/// timers that outlive the widget tree, which fails the test even though the
/// capture itself is fine. Offline the logo could never load anyway — the
/// header falls back to its storefront glyph, exactly as it would on a phone
/// with no signal.
final class _OfflineMockDashboard implements SellerDashboardDataSource {
  const _OfflineMockDashboard();

  @override
  Future<SellerDashboardData> getDashboard() async {
    final data = await const SellerDashboardMockDataSource().getDashboard();
    final store = data.storeInfo;
    return SellerDashboardData(
      storeInfo: SellerStoreInfo(
        id: store.id,
        name: store.name,
        tagline: store.tagline,
        description: store.description,
        logoUrl: '',
        coverUrl: '',
        isVerified: store.isVerified,
        rating: store.rating,
        reviewsCount: store.reviewsCount,
        totalRevenue: store.totalRevenue,
        totalOrders: store.totalOrders,
        productsCount: store.productsCount,
        followersCount: store.followersCount,
        storeScore: store.storeScore,
        memberSince: store.memberSince,
        subscriptionPlan: store.subscriptionPlan,
        withdrawableBalance: store.withdrawableBalance,
      ),
      revenue: data.revenue,
      orders: data.orders,
      charts: data.charts,
      topProducts: data.topProducts,
      lowStock: data.lowStock,
      storeScore: data.storeScore,
      conversionMetrics: data.conversionMetrics,
      aiInsights: data.aiInsights,
      pendingTasks: data.pendingTasks,
      goals: data.goals,
      recentReviews: data.recentReviews,
      campaigns: data.campaigns,
    );
  }
}

/// Lets the dashboard future resolve and every entrance animation finish, so a
/// capture never catches a section still faded out.
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
