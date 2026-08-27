// Renders the seller's order queue and one parcel to PNGs so the screens can
// be judged without a seller session and a live sale. Not an assertion test in
// the usual sense — but it *is* the only place these two screens are actually
// built, so a layout that overflows or a token that does not exist fails here
// rather than on somebody's phone.
//
//   flutter test test/seller_orders_visual_preview_test.dart
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
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/seller_orders/domain/entities/seller_order.dart';
import 'package:reem/features/seller_orders/domain/repositories/seller_orders_repository.dart';
import 'package:reem/features/seller_orders/presentation/providers/seller_orders_provider.dart';
import 'package:reem/features/seller_orders/presentation/screens/seller_order_detail_screen.dart';
import 'package:reem/features/seller_orders/presentation/screens/seller_orders_screen.dart';
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
  // The notifier checks connectivity before calling out; report "online" so it
  // takes the normal path into the overridden repository.
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
    testWidgets('renders the seller order queue in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(
          themeMode: mode,
          screen: const SellerOrdersScreen(),
          path: '/seller/orders',
        ),
      );
      await _settle(tester);

      // The queue is the screen she works from: if the counts or the first
      // action are missing, the screenshot is pretty and useless.
      expect(find.text('طلباتي'), findsOneWidget);
      expect(find.text('قبول الطلب'), findsWidgets);

      await _capture(tester, 'seller_orders_${mode.name}');
    });

    testWidgets('renders one parcel in ${mode.name}', (tester) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(
          themeMode: mode,
          screen: const SellerOrderDetailScreen(orderId: 'o1'),
          path: '/seller/orders/o1',
        ),
      );
      await _settle(tester);

      // A courier parcel must show the explanation rather than a blank
      // address — the whole point of the panel.
      expect(find.textContaining('المندوب'), findsWidgets);

      await _capture(tester, 'seller_order_detail_${mode.name}');
    });
  }
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 120));
  }
}

/// Encoding a PNG is real async work, so it has to run outside the fake-async
/// zone `testWidgets` installs — without `runAsync` the await never resumes
/// and the test sits there until the framework's ten-minute timeout.
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

class _Preview extends StatelessWidget {
  _Preview({required this.themeMode, required this.screen, required this.path});

  final ThemeMode themeMode;
  final Widget screen;
  final String path;

  late final GoRouter _router = GoRouter(
    initialLocation: path,
    routes: [GoRoute(path: path, builder: (_, _) => screen)],
  );

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        sellerOrdersRepositoryProvider.overrideWithValue(
          const _FakeSellerOrders(),
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

/// A morning's work: something to accept, something to pack, something on the
/// road, and one parcel she is carrying herself — so every branch of the card
/// (masking, cash on delivery, the action row) is on screen at once.
final class _FakeSellerOrders implements SellerOrdersRepository {
  const _FakeSellerOrders();

  static final _masked = SellerOrderCustomer(
    name: 'ريم',
    isMasked: true,
    governorate: 'دمشق',
    city: 'دمشق',
    deliveryInstructions: 'اتصلي قبل الوصول',
    maskedBecause: 'الشحن عبر مندوب المنصة — العنوان مع المندوب وليس مع البائعة',
  );

  static final _open = SellerOrderCustomer(
    name: 'ليلى الحسن',
    isMasked: false,
    phone: '+963900111222',
    governorate: 'حلب',
    city: 'حلب',
    district: 'الفرقان',
    addressLine: 'شارع النيل، بناء 4',
    landmark: 'مقابل الحديقة',
  );

  static List<SellerOrderSummary> get _rows => [
    SellerOrderSummary(
      id: 'o1',
      number: 'REEM-MB7K2X481-1',
      status: SellerOrderStatus.awaitingSellerConfirmation,
      fulfilmentMode: FulfilmentMode.platformCourier,
      placedAt: DateTime(2026, 8, 26, 9, 12),
      itemsCount: 3,
      net: _syp('340000'),
      commission: _syp('60000'),
      customer: _masked,
      actions: const [SellerOrderAction.confirm, SellerOrderAction.cancel],
      paymentMethod: 'COD',
      paymentStatus: 'PENDING',
      trackingCode: 'REM-7F3K9QX2',
    ),
    SellerOrderSummary(
      id: 'o2',
      number: 'REEM-MB7K2X902-1',
      status: SellerOrderStatus.preparing,
      fulfilmentMode: FulfilmentMode.platformCourier,
      placedAt: DateTime(2026, 8, 26, 8, 4),
      itemsCount: 1,
      net: _syp('722500'),
      commission: _syp('127500'),
      customer: _masked,
      actions: const [SellerOrderAction.ready, SellerOrderAction.cancel],
      paymentMethod: 'SYRIATEL_CASH',
      paymentStatus: 'PAID',
    ),
    SellerOrderSummary(
      id: 'o3',
      number: 'REEM-MB7K1A330-1',
      status: SellerOrderStatus.readyToShip,
      fulfilmentMode: FulfilmentMode.sellerShips,
      placedAt: DateTime(2026, 8, 25, 17, 40),
      itemsCount: 2,
      net: _syp('170000'),
      commission: _syp('30000'),
      customer: _open,
      actions: const [SellerOrderAction.handOver, SellerOrderAction.cancel],
      paymentMethod: 'COD',
      paymentStatus: 'PENDING',
    ),
    SellerOrderSummary(
      id: 'o4',
      number: 'REEM-MB7J8C120-1',
      status: SellerOrderStatus.inTransit,
      fulfilmentMode: FulfilmentMode.platformCourier,
      placedAt: DateTime(2026, 8, 24, 11, 15),
      itemsCount: 4,
      net: _syp('1105000'),
      commission: _syp('195000'),
      customer: _masked,
      actions: const [],
      paymentMethod: 'COD',
      paymentStatus: 'PENDING',
      trackingCode: 'REM-2K8M4PQ7',
    ),
  ];

  @override
  Future<Result<SellerOrderQueue>> queue({
    SellerQueueTab? tab,
    int page = 1,
    int limit = 20,
  }) async => Success(
    SellerOrderQueue(
      orders: _rows,
      counts: const {
        'new': 3,
        'preparing': 1,
        'ready': 2,
        'shipping': 4,
        'returns': 1,
        'completed': 27,
      },
    ),
  );

  @override
  Future<Result<SellerOrderDetail>> detail(String id) async =>
      Success(_detail);

  @override
  Future<Result<SellerOrderDetail>> act(
    String id,
    SellerOrderAction action, {
    String? reason,
    String? collected,
    String? carrier,
  }) async => Success(_detail);

  static SellerOrderDetail get _detail => SellerOrderDetail(
    summary: _rows.first,
    orderNumber: 'REEM-MB7K2X481',
    currency: Currency.syp,
    itemsSubtotal: _syp('400000'),
    discountTotal: _syp('0'),
    shippingCost: _syp('25000'),
    commissionBase: _syp('400000'),
    escrowReleased: false,
    escrowReleaseAt: DateTime(2026, 9, 2, 14, 30),
    confirmedAt: DateTime(2026, 8, 26, 9, 40),
    items: [
      SellerOrderLine(
        id: 'i1',
        title: 'عباءة مطرّزة بخيط ذهبي',
        quantity: 2,
        unitPrice: _syp('150000'),
        lineTotal: _syp('300000'),
        variant: 'مقاس M',
      ),
      SellerOrderLine(
        id: 'i2',
        title: 'وشاح حرير',
        quantity: 1,
        unitPrice: _syp('100000'),
        lineTotal: _syp('100000'),
        customisation: const {'التطريز': 'ر.د'},
      ),
    ],
    shipment: const SellerParcelShipment(
      trackingCode: 'REM-7F3K9QX2',
      status: 'created',
      isAssigned: false,
    ),
  );
}
