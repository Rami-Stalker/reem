// The three doors into a conversation, built and asserted.
//
// Before this batch there were none: the chat feature was complete but
// unreachable, because nothing anywhere called `startConversation`. These
// tests build the two screens that now carry the way in — a buyer's order and
// a product page — and check that the action is really on them, per parcel and
// per seller. Neither screen was built by any test before, which is precisely
// how a mocked inbox survived in the app for so long.
//
//   flutter test test/message_seller_entry_points_test.dart
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
import 'package:ohara/core/errors/failure.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/category.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/seller_offer.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/catalog/domain/repositories/catalog_repository.dart';
import 'package:ohara/features/catalog/presentation/providers/catalog_provider.dart';
import 'package:ohara/features/checkout/domain/entities/order.dart';
import 'package:ohara/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:ohara/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:ohara/features/checkout/presentation/screens/order_detail_screen.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_seller_card.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

const _syp = Currency.syp;
const _zero = Money(raw: '0', currency: _syp);

Money _money(String raw) => Money(raw: raw, currency: _syp);

/// An order split across two boutiques — the case that makes a single
/// order-level "contact seller" button wrong.
final _order = OrderDetail(
  id: 'o-1',
  number: 'REEM-1001',
  status: OrderStatus.partiallyShipped,
  itemsSubtotal: _money('450000'),
  discountTotal: _zero,
  shippingTotal: _money('25000'),
  walletApplied: _zero,
  grandTotal: _money('475000'),
  fxRate: '1',
  fxFrozenAt: DateTime(2026, 8, 20),
  sellersCount: 2,
  itemsCount: 2,
  createdAt: DateTime(2026, 8, 20),
  shipping: const OrderShipping(
    recipientName: 'ريم الحسن',
    recipientPhone: '+963900000000',
    governorate: 'دمشق',
    city: 'المزة',
    addressLine: 'شارع الجلاء',
  ),
  sellerOrders: [
    SellerOrder(
      id: 'so-1',
      number: 'REEM-1001-1',
      sellerId: 's-1',
      sellerName: 'أتيليه لجين',
      status: SellerOrderStatus.preparing,
      itemsSubtotal: _money('300000'),
      discountTotal: _zero,
      shippingCost: _money('15000'),
      items: [
        OrderItemLine(
          id: 'l-1',
          title: 'فستان سهرة مطرّز',
          sellerName: 'أتيليه لجين',
          quantity: 1,
          unitPrice: _money('300000'),
          lineTotal: _money('300000'),
        ),
      ],
    ),
    SellerOrder(
      id: 'so-2',
      number: 'REEM-1001-2',
      sellerId: 's-2',
      sellerName: 'بوتيك الوردة',
      status: SellerOrderStatus.delivered,
      itemsSubtotal: _money('150000'),
      discountTotal: _zero,
      shippingCost: _money('10000'),
      items: [
        OrderItemLine(
          id: 'l-2',
          title: 'شال حرير',
          sellerName: 'بوتيك الوردة',
          quantity: 1,
          unitPrice: _money('150000'),
          lineTotal: _money('150000'),
        ),
      ],
    ),
  ],
);

final _seller = User(
  id: 's-1',
  name: 'أتيليه لجين',
  username: 'lujain',
  phone: '+963911111111',
  role: UserRole.seller,
  createdAt: DateTime(2026, 1, 1),
);

final _product = Product(
  id: 'p-1',
  slug: 'evening-dress',
  title: 'فستان سهرة مطرّز',
  description: 'قطعة مطرّزة يدوياً',
  category: const Category(
    id: 'c-1',
    slug: 'dresses',
    nameAr: 'فساتين',
    nameEn: 'Dresses',
  ),
  createdAt: DateTime(2026, 8, 1),
  offers: [
    SellerOffer(
      id: 'off-1',
      seller: _seller,
      price: _money('300000'),
      stock: 4,
    ),
  ],
  offersCount: 1,
);

void _stubPlatformChannels() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(
    const MethodChannel('plugins.it_nomads.com/flutter_secure_storage'),
    (call) async => call.method == 'readAll' ? <String, String>{} : null,
  );
  messenger.setMockMethodCallHandler(
    const MethodChannel('dev.fluttercommunity.plus/connectivity'),
    (call) async => ['wifi'],
  );
}

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    _stubPlatformChannels();
    await _loadFonts();
  });

  testWidgets('every parcel carries its own way to reach its boutique', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 2800);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          checkoutRepositoryProvider.overrideWithValue(const _FakeCheckout()),
        ],
        child: _Preview(
          path: '/order/o-1',
          screen: const OrderDetailScreen(orderId: 'o-1'),
        ),
      ),
    );
    await _settle(tester);

    expect(find.text('أتيليه لجين'), findsWidgets);
    expect(find.text('بوتيك الوردة'), findsWidgets);

    // One button per parcel, not one per order: «أين طلبي؟» is only answerable
    // by the boutique actually holding that box.
    expect(find.text('راسلي المتجر بخصوص الطلب'), findsNWidgets(2));

    await _capture(tester, 'order_detail_message_seller');
  });

  testWidgets('a product names its boutique and offers to ask her', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1125, 900);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          catalogRepositoryProvider.overrideWithValue(const _FakeCatalog()),
        ],
        child: _Preview(
          path: '/product',
          // The card reads the same notifier the product screen fills, and
          // `_LoadedProduct` fills it the same way that screen does — so this
          // exercises the real path without dragging in the rest of a page
          // that carries defects of its own (see the notes on this batch).
          screen: const _LoadedProduct(productId: 'p-1'),
        ),
      ),
    );
    await _settle(tester);

    // The product page never named the seller at all before this card.
    expect(find.text('تبيعه'), findsOneWidget);
    expect(find.text('أتيليه لجين'), findsOneWidget);
    expect(find.text('زوري المتجر'), findsOneWidget);
    expect(find.text('اسألي عن هذه القطعة'), findsOneWidget);

    await _capture(tester, 'product_seller_card');
  });
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

/// Renders the seller card over the product the details provider loads — the
/// same product, from the same repository, that the product page shows.
class _LoadedProduct extends ConsumerWidget {
  const _LoadedProduct({required this.productId});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final product = ref.watch(
      productDetailsNotifierProvider(productId).select((s) => s.product),
    );

    return Scaffold(
      body: SafeArea(
        child: product == null
            ? const SizedBox.shrink()
            : Padding(
                padding: const EdgeInsets.all(DsSpacing.lg),
                child: ProductSellerCard(product: product),
              ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  _Preview({required this.path, required this.screen});

  final String path;
  final Widget screen;

  late final GoRouter _router = GoRouter(
    initialLocation: path,
    routes: [
      GoRoute(
        path: path,
        builder: (_, _) => RepaintBoundary(key: _captureKey, child: screen),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: L10nSetup.supportedLocales,
      localizationsDelegates: const [
        gen.AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      routerConfig: _router,
    );
  }
}

class _FakeCheckout implements CheckoutRepository {
  const _FakeCheckout();

  @override
  Future<Result<OrderDetail>> getOrder(String id) async => Success(_order);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('not used in this test')));
}

class _FakeCatalog implements CatalogRepository {
  const _FakeCatalog();

  @override
  Future<Result<Product>> getProductById(String id) async => Success(_product);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      Future.value(const Error<Never>(ServerFailure('not used in this test')));
}
