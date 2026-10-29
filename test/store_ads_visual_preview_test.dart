// Renders «مركز الإعلانات» to PNGs — the plan, the campaigns, the plans
// side by side and the composer with its live quote.
//
//   flutter test test/store_ads_visual_preview_test.dart
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
import 'package:ohara/features/store_ads/domain/entities/store_ads.dart';
import 'package:ohara/features/store_ads/domain/repositories/store_ads_repository.dart';
import 'package:ohara/features/store_ads/presentation/providers/store_ads_providers.dart';
import 'package:ohara/features/store_ads/presentation/screens/ad_plan_payment_screen.dart';
import 'package:ohara/features/store_ads/presentation/screens/ad_plans_screen.dart';
import 'package:ohara/features/store_ads/presentation/screens/ads_center_screen.dart';
import 'package:ohara/features/store_ads/presentation/screens/new_campaign_screen.dart';
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

  const screens = {
    'center': '/seller/ads',
    'plans': '/seller/ads/plans',
    'composer': '/seller/ads/new',
    'payment': '/seller/ads/payment',
  };

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    for (final entry in screens.entries) {
      testWidgets('renders ads ${entry.key} in ${mode.name}', (tester) async {
        tester.view.physicalSize = const Size(1125, 2436);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _Preview(themeMode: mode, initialLocation: entry.value),
        );
        await _settle(tester);
        await _capture(tester, 'store_ads_${entry.key}_${mode.name}');

        // And the rest of the page: the summary, the campaigns, the plans
        // further down.
        for (var page = 1; page <= 2; page++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -700),
          );
          await _settle(tester);
          await _capture(
            tester,
            'store_ads_${entry.key}_${mode.name}_scroll$page',
          );
        }
      });
    }
  }
}

class _Preview extends StatelessWidget {
  _Preview({required this.themeMode, required this.initialLocation});

  final ThemeMode themeMode;
  final String initialLocation;

  late final GoRouter _router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/seller/ads', builder: (_, _) => const AdsCenterScreen()),
      GoRoute(
        path: '/seller/ads/plans',
        builder: (_, _) => const AdPlansScreen(),
      ),
      GoRoute(
        path: '/seller/ads/payment',
        builder: (_, _) => const AdPlanPaymentScreen(),
      ),
      GoRoute(
        path: '/seller/ads/new',
        builder: (_, _) => NewCampaignScreen(suggestion: _suggestion),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        storeAdsRepositoryProvider.overrideWithValue(
          const _FakeAdsRepository(),
        ),
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

const _suggestion = AdSuggestion(
  offerId: 'o1',
  productId: 'p1',
  title: 'عباية كتّان مطرّزة',
  reason: AdSuggestionReason.lovedNotBought,
  placement: AdPlacement.homeSpotlight,
  days: 7,
  targetInterested: true,
  views: 122,
  favorites: 14,
);

const _plans = [
  AdPlan(
    tier: AdTier.free,
    price: 0,
    credit: 0,
    discountPercent: 0,
    maxActiveCampaigns: 1,
    placements: [AdPlacement.search, AdPlacement.category],
    targeting: AdTargeting.none,
    servingWeight: 1,
    notifiesFollowers: false,
    featuredStore: false,
  ),
  AdPlan(
    tier: AdTier.silver,
    price: 25000,
    credit: 30000,
    discountPercent: 10,
    maxActiveCampaigns: 3,
    placements: [AdPlacement.search, AdPlacement.category, AdPlacement.feedTop],
    targeting: AdTargeting.location,
    servingWeight: 2,
    notifiesFollowers: false,
    featuredStore: false,
  ),
  AdPlan(
    tier: AdTier.gold,
    price: 60000,
    credit: 80000,
    discountPercent: 20,
    maxActiveCampaigns: 6,
    placements: AdPlacement.values,
    targeting: AdTargeting.full,
    servingWeight: 3,
    notifiesFollowers: true,
    featuredStore: true,
  ),
  AdPlan(
    tier: AdTier.diamond,
    price: 120000,
    credit: 180000,
    discountPercent: 30,
    maxActiveCampaigns: 15,
    placements: AdPlacement.values,
    targeting: AdTargeting.full,
    servingWeight: 5,
    notifiesFollowers: true,
    featuredStore: true,
  ),
];

/// A Gold boutique two weeks into her plan, with one campaign that has sold
/// and one that is paused — enough to judge every part of the page.
final class _FakeAdsRepository implements StoreAdsRepository {
  const _FakeAdsRepository();

  static final _view = AdPlansView(
    current: AdCurrentPlan(
      tier: AdTier.gold,
      endsAt: DateTime.now().add(const Duration(days: 16)),
      creditGranted: 80000,
      creditUsed: 22400,
      creditRemaining: 57600,
      activeCampaigns: 1,
      maxActiveCampaigns: 6,
    ),
    plans: _plans,
    spendLast30Days: 160000,
    earningsBalance: 18000,
    pendingPurchase: const AdPlanPurchase(
      id: 'pp1',
      tier: AdTier.diamond,
      method: 'sham_cash',
      amount: 120000,
      status: AdPurchaseStatus.awaitingPayment,
      instructions: 'حوّلي إلى حساب شام كاش رقم 0999 123 456 باسم «أوهارا»',
    ),
    recommendation: const AdPlanRecommendation(
      tier: AdTier.diamond,
      saving: 12000,
      reason: AdRecommendationReason.wouldHaveSaved,
    ),
  );

  @override
  Future<Result<AdPlansView>> plans() async => Success(_view);

  @override
  Future<Result<AdPlansView>> subscribe(
    AdTier tier, {
    required String idempotencyKey,
  }) async => Success(_view);

  @override
  Future<Result<AdQuote>> quote(AdCampaignDraft draft) async => const Success(
    AdQuote(
      tier: AdTier.gold,
      allowed: true,
      price: AdPriceBreakdown(
        days: 7,
        dailyRate: 4000,
        listPrice: 22400,
        discount: 4480,
        total: 17920,
        creditApplied: 17920,
        toPay: 0,
      ),
      reach: 31,
      totalShoppers: 56,
      shareOfVoice: 0.64,
      competingCampaigns: 2,
    ),
  );

  @override
  Future<Result<AdCampaign>> launch(
    AdCampaignDraft draft, {
    required String idempotencyKey,
  }) async => Success(_campaigns.first);

  static final _campaigns = [
    AdCampaign(
      id: 'c1',
      placement: AdPlacement.homeSpotlight,
      status: AdCampaignStatus.active,
      isLive: true,
      fee: 22400,
      creditApplied: 22400,
      startsAt: DateTime.now().subtract(const Duration(days: 3)),
      endsAt: DateTime.now().add(const Duration(days: 4)),
      audience: AdAudience.everyone,
      productTitle: 'فستان حرير بماء الورد',
      impressions: 1840,
      clicks: 126,
      clickThroughRate: 0.068,
      reach: 612,
      attributedOrders: 9,
      attributedRevenue: 214000,
    ),
    AdCampaign(
      id: 'c2',
      placement: AdPlacement.feedTop,
      status: AdCampaignStatus.paused,
      isLive: false,
      fee: 6000,
      creditApplied: 0,
      startsAt: DateTime.now().subtract(const Duration(days: 1)),
      endsAt: DateTime.now().add(const Duration(days: 2)),
      audience: const AdAudience(targeted: true, governorates: ['دمشق']),
      productTitle: 'شال شتوي بنقشة هندسية',
      impressions: 310,
      clicks: 12,
      reach: 140,
    ),
  ];

  @override
  Future<Result<List<AdCampaign>>> campaigns() async => Success(_campaigns);

  @override
  Future<Result<AdCampaign>> setStatus(
    String id,
    AdCampaignStatus status,
  ) async => Success(_campaigns.first);

  @override
  Future<Result<List<AdSuggestion>>> suggestions() async => const Success([
    _suggestion,
    AdSuggestion(
      offerId: 'o2',
      productId: 'p2',
      title: 'حقيبة تسوق بتصميم كلاسيكي',
      reason: AdSuggestionReason.bestSeller,
      placement: AdPlacement.search,
      days: 7,
      targetInterested: false,
      sold: 12,
    ),
    AdSuggestion(
      offerId: 'o3',
      productId: 'p3',
      title: 'سلسال من الفضة',
      reason: AdSuggestionReason.hiddenGem,
      placement: AdPlacement.category,
      days: 7,
      targetInterested: false,
    ),
  ]);

  @override
  Future<Result<AdsOverview>> overview() async => const Success(
    AdsOverview(
      activeCampaigns: 1,
      totalCampaigns: 2,
      spend: 28400,
      creditUsed: 22400,
      impressions: 2150,
      clicks: 138,
      reach: 702,
      clickThroughRate: 0.064,
      attributedOrders: 9,
      attributedRevenue: 214000,
      returnOnAdSpend: 7.5,
      benchmarkCtr: 0.041,
      insight: AdInsight.aboveAverage,
    ),
  );

  @override
  Future<Result<AdPaymentOptions>> paymentOptions() async => const Success(
    AdPaymentOptions(
      earningsBalance: 18000,
      transferMethods: [
        AdTransferMethod(method: 'sham_cash', instructions: '0999 123 456'),
        AdTransferMethod(method: 'syriatel_cash', instructions: '0933 000 111'),
      ],
    ),
  );

  @override
  Future<Result<AdPurchaseResult>> purchase(
    AdTier tier,
    String method, {
    required String idempotencyKey,
  }) async => Success(AdPurchaseResult(plans: _view));

  @override
  Future<Result<AdPlanPurchase>> submitReference(
    String id,
    String reference,
  ) async => Success(_view.pendingPurchase!);

  @override
  Future<Result<AdPlanPurchase>> cancelPurchase(String id) async =>
      Success(_view.pendingPurchase!);

  @override
  Future<Result<List<AdGovernorate>>> governorates() async => const Success([
    AdGovernorate(name: 'دمشق', shoppers: 1240),
    AdGovernorate(name: 'حلب', shoppers: 860),
    AdGovernorate(name: 'حمص', shoppers: 310),
    AdGovernorate(name: 'اللاذقية', shoppers: 280),
  ]);
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
