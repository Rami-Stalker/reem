// Renders the seller's returns desk and her analytics to PNGs, so two screens
// that did not exist a moment ago can be looked at rather than assumed.
//
//   flutter test test/seller_returns_analytics_visual_preview_test.dart
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
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/seller_analytics/domain/entities/seller_analytics_report.dart';
import 'package:ohara/features/seller_analytics/domain/repositories/seller_analytics_repository.dart';
import 'package:ohara/features/seller_analytics/presentation/providers/seller_analytics_provider.dart';
import 'package:ohara/features/seller_analytics/presentation/screens/seller_analytics_screen.dart';
import 'package:ohara/features/seller_returns/domain/entities/return_request.dart';
import 'package:ohara/features/seller_returns/domain/repositories/seller_returns_repository.dart';
import 'package:ohara/features/seller_returns/presentation/providers/seller_returns_provider.dart';
import 'package:ohara/features/seller_returns/presentation/screens/seller_returns_screen.dart';
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
    testWidgets('renders the returns desk in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(
          themeMode: mode,
          screen: const SellerReturnsScreen(),
          path: '/seller/returns',
        ),
      );
      await _settle(tester);
      await _capture(tester, 'seller_returns_${mode.name}');
    });

    testWidgets('renders the seller analytics in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(
          themeMode: mode,
          screen: const SellerAnalyticsScreen(),
          path: '/seller/analytics',
        ),
      );
      await _settle(tester);
      await _capture(tester, 'seller_analytics_${mode.name}');
    });
  }

  testWidgets('renders the analytics scrolled to the funnel', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _Preview(
        themeMode: ThemeMode.light,
        screen: const SellerAnalyticsScreen(),
        path: '/seller/analytics',
      ),
    );
    await _settle(tester);
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -900));
    await _settle(tester);
    await _capture(tester, 'seller_analytics_funnel');
  });
}

class _Preview extends StatelessWidget {
  _Preview({required this.themeMode, required this.screen, required this.path});

  final ThemeMode themeMode;
  final Widget screen;

  /// The route the screen is mounted at. `PremiumAppBar` branches on it.
  final String path;

  late final GoRouter _router = GoRouter(
    initialLocation: path,
    routes: [GoRoute(path: path, builder: (_, _) => screen)],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sellerReturnsRepositoryProvider.overrideWithValue(
          const _FakeReturnsRepository(),
        ),
        sellerAnalyticsRepositoryProvider.overrideWithValue(
          const _FakeAnalyticsRepository(),
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

Money _syp(String amount) => Money(raw: amount, currency: Currency.syp);

/// One return in each of the states the seller can act on, so the tab counts,
/// the status colours and the inline action all have something to show.
final class _FakeReturnsRepository implements SellerReturnsRepository {
  const _FakeReturnsRepository();

  static ReturnRequest _row({
    required String id,
    required String number,
    required ReturnStatus status,
    required ReturnReason reason,
    required String title,
    int quantity = 1,
    String? note,
    bool settled = false,
  }) => ReturnRequest(
    id: id,
    number: number,
    status: status,
    reason: reason,
    reasonNote: note,
    parcel: ReturnParcel(
      orderId: 'o-$id',
      orderNumber: 'ORD-0${id.hashCode.abs() % 9000 + 1000}',
      sellerOrderId: 'so-$id',
      sellerOrderNumber: 'SO-0${id.hashCode.abs() % 9000 + 1000}',
    ),
    items: [
      ReturnLine(orderItemId: 'i-$id', title: title, quantity: quantity),
    ],
    refund: RefundQuote(
      amount: _syp('850000'),
      settled: settled,
      goods: _syp('900000'),
      returnShippingFee: _syp('50000'),
      borneBy: ReturnCostBearer.customer,
    ),
    createdAt: DateTime(2026, 8, 24, 14, 5),
  );

  static final _rows = [
    _row(
      id: '1',
      number: 'RET-000412',
      status: ReturnStatus.requested,
      reason: ReturnReason.defective,
      title: 'فستان حرير بماء الورد',
      note: 'الخياطة مفتوحة من الجهة اليسرى.',
    ),
    _row(
      id: '2',
      number: 'RET-000410',
      status: ReturnStatus.approved,
      reason: ReturnReason.sizeIssue,
      title: 'عباءة كتّان مطرّزة',
      quantity: 2,
    ),
    _row(
      id: '3',
      number: 'RET-000407',
      status: ReturnStatus.inTransit,
      reason: ReturnReason.changedMind,
      title: 'حقيبة كتف صغيرة مبطّنة',
    ),
    _row(
      id: '4',
      number: 'RET-000399',
      status: ReturnStatus.received,
      reason: ReturnReason.wrongItem,
      title: 'طقم أقراط لؤلؤ وكريستال',
    ),
    _row(
      id: '5',
      number: 'RET-000381',
      status: ReturnStatus.refunded,
      reason: ReturnReason.damagedInTransit,
      title: 'عطر زهر المخمل',
      settled: true,
    ),
  ];

  @override
  Future<Result<List<ReturnRequest>>> queue({ReturnStatus? status}) async =>
      Success(_rows);

  @override
  Future<Result<ReturnRequest>> detail(String id) async =>
      Success(_rows.firstWhere((row) => row.id == id));

  @override
  Future<Result<ReturnRequest>> act(
    String id,
    ReturnAction action, {
    String? reason,
    String? note,
    bool? restock,
    ReturnCostBearer? shippingBorneBy,
  }) async => Success(_rows.firstWhere((row) => row.id == id));
}

/// A month with a shape to it: a real curve, a funnel that narrows plausibly,
/// and revenue in one currency so the multi-currency stacking is not the thing
/// being judged here.
final class _FakeAnalyticsRepository implements SellerAnalyticsRepository {
  const _FakeAnalyticsRepository();

  @override
  Future<Result<SellerAnalyticsReport>> dashboard(
    AnalyticsPeriod period,
  ) async {
    final end = DateTime(2026, 8, 30);
    const shape = [
      3, 5, 4, 8, 11, 9, 6, 7, 12, 15, 11, 9, 13, 18,
      16, 12, 14, 21, 19, 17, 15, 22, 26, 23, 19, 21, 28, 25, 24, 31,
    ];

    return Success(
      SellerAnalyticsReport(
        start: end.subtract(Duration(days: period.days)),
        end: end,
        sales: SalesBreakdown(
          totalOrders: 214,
          paidOrders: 186,
          averageOrderValue: [_syp('612000')],
          byStatus: const {'delivered': 152, 'shipping': 34, 'preparing': 28},
          series: [
            for (var i = 0; i < shape.length; i++)
              SalesSeriesPoint(
                date: end.subtract(Duration(days: shape.length - 1 - i)),
                orders: shape[i],
                revenue: [_syp('${shape[i] * 612000}')],
              ),
          ],
        ),
        revenue: RevenueBreakdown(
          gross: [_syp('131000000')],
          paid: [_syp('118400000')],
          refunds: [_syp('4250000')],
          net: [_syp('126750000')],
        ),
        topProducts: [
          ProductPerformanceRow(
            productId: 'p1',
            title: 'فستان حرير بماء الورد',
            units: 62,
            revenue: [_syp('52700000')],
          ),
          ProductPerformanceRow(
            productId: 'p2',
            title: 'عباءة كتّان مطرّزة',
            units: 41,
            revenue: [_syp('28700000')],
          ),
          ProductPerformanceRow(
            productId: 'p3',
            title: 'طقم أقراط لؤلؤ وكريستال',
            units: 38,
            revenue: [_syp('8360000')],
          ),
          ProductPerformanceRow(
            productId: 'p4',
            title: 'عطر زهر المخمل',
            units: 29,
            revenue: [_syp('12470000')],
          ),
        ],
        customers: CustomerBreakdown(
          activeCustomers: 168,
          newCustomers: 94,
          repeatCustomers: 74,
          repeatRate: 44.0,
          averageCustomerValue: [_syp('779000')],
        ),
        conversion: const ConversionBreakdown(
          productViews: 8420,
          cartAdds: 1310,
          checkoutStarts: 402,
          orders: 214,
          viewToCartRate: 15.6,
          cartToCheckoutRate: 30.7,
          checkoutToOrderRate: 53.2,
          overallRate: 2.5,
        ),
        funnel: const [
          FunnelStep(step: 'Product view', count: 8420),
          FunnelStep(step: 'Add to cart', count: 1310),
          FunnelStep(step: 'Checkout start', count: 402),
          FunnelStep(step: 'Order placed', count: 214),
        ],
        retention: const RetentionBreakdown(
          customers: 168,
          retained7d: 39,
          retained30d: 74,
          retention7dRate: 23.2,
          retention30dRate: 44.0,
        ),
        realtime: RealtimeSnapshot(
          todayOrders: 9,
          todayRevenue: [_syp('5510000')],
          activeCarts: 23,
          refreshedAt: end,
        ),
      ),
    );
  }
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
