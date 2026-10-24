// Renders the seller's product workspace and earnings page to PNGs so the
// design can be eyeballed without a seller session. Not an assertion test — it
// writes `build/visual/seller_*.png` and is meant to be run on demand.
//
//   flutter test test/seller_workspace_visual_preview_test.dart
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
import 'package:reem/core/shared/entities/category.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/seller_earnings/domain/entities/seller_earnings.dart';
import 'package:reem/features/seller_earnings/domain/repositories/seller_earnings_repository.dart';
import 'package:reem/features/seller_earnings/presentation/providers/seller_earnings_provider.dart';
import 'package:reem/features/seller_earnings/presentation/screens/seller_earnings_screen.dart';
import 'package:reem/features/seller_products/data/datasources/seller_products_remote_datasource.dart';
import 'package:reem/features/seller_products/data/models/managed_product_model.dart';
import 'package:reem/features/seller_products/data/models/managed_product_page_model.dart';
import 'package:reem/features/seller_products/domain/entities/product_draft.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';
import 'package:reem/features/seller_products/presentation/providers/seller_products_providers.dart';
import 'package:reem/features/seller_products/presentation/screens/my_products_screen.dart';
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
  // The earnings repository checks connectivity before it calls out. Report
  // "online" so it takes the normal path into the overridden repository.
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
    testWidgets('renders the seller product workspace in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(
          themeMode: mode,
          screen: const MyProductsScreen(),
          path: '/seller/products',
        ),
      );
      await _settle(tester);
      await _capture(tester, 'seller_products_${mode.name}');
    });

    testWidgets('renders the seller earnings page in ${mode.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _Preview(
          themeMode: mode,
          screen: const SellerEarningsScreen(),
          path: '/seller/earnings',
        ),
      );
      await _settle(tester);
      await _capture(tester, 'seller_earnings_${mode.name}');
    });
  }
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
        sellerProductsRemoteDataSourceProvider.overrideWithValue(
          const _FakeProductsSource(),
        ),
        sellerEarningsRepositoryProvider.overrideWithValue(
          const _FakeEarningsRepository(),
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

final _category = Category(
  id: 'c1',
  slug: 'dresses',
  nameAr: 'فساتين',
  nameEn: 'Dresses',
  level: 2,
);

/// A small shelf of listings across every status, so the filter bar and the
/// status chips can be judged rather than guessed at.
final class _FakeProductsSource implements SellerProductsRemoteDataSource {
  const _FakeProductsSource();

  static final _rows = <({String title, String price, int stock, ProductStatus status})>[
    (title: 'فستان حرير بماء الورد', price: '850000', stock: 23, status: ProductStatus.active),
    (title: 'عطر زهر المخمل', price: '430000', stock: 7, status: ProductStatus.active),
    (title: 'حقيبة كتف صغيرة مبطّنة', price: '580000', stock: 0, status: ProductStatus.outOfStock),
    (title: 'طقم أقراط لؤلؤ وكريستال', price: '220000', stock: 2, status: ProductStatus.active),
    (title: 'فستان كتّان ماكسي بلفّة', price: '700000', stock: 12, status: ProductStatus.draft),
    (title: 'حذاء ساتان بفيونكة', price: '495000', stock: 4, status: ProductStatus.archived),
  ];

  @override
  Future<ManagedProductPageModel> getMyProducts({
    int page = 1,
    int limit = 20,
    ProductStatus? status,
    String? query,
    String? sort,
  }) async {
    final rows = status == null
        ? _rows
        : _rows.where((row) => row.status == status).toList();
    return ManagedProductPageModel(
      items: [
        for (var i = 0; i < rows.length; i++)
          ManagedProductModel(
            id: 'offer-$i',
            productId: 'product-$i',
            title: rows[i].title,
            description: 'قطعة مصنوعة بعناية.',
            category: _category,
            price: _syp(rows[i].price),
            stock: rows[i].stock,
            status: rows[i].status,
            rating: 4.8,
            reviewsCount: 184,
            viewsCount: 5400,
            ordersCount: 97,
            offersCount: 1,
            media: const [MediaItem(url: '')],
            createdAt: DateTime(2026, 3, 12),
          ),
      ],
      page: 1,
      totalPages: 1,
      hasNextPage: false,
    );
  }

  @override
  Future<List<ManagedProductModel>> lowStock({int threshold = 5}) async =>
      const [];

  @override
  Future<ManagedProductModel> getOffer(String offerId) =>
      throw UnimplementedError();

  @override
  Future<ManagedProductModel> create(ProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<ManagedProductModel> updateOffer(String offerId, ProductDraft draft) =>
      throw UnimplementedError();

  @override
  Future<void> updateProduct(String productId, ProductDraft draft) async {}

  @override
  Future<void> archive(String offerId) async {}

  @override
  Future<ManagedProductModel> setStatus(String offerId, ProductStatus status) =>
      throw UnimplementedError();

  @override
  Future<ManagedProductModel> adjustStock(String offerId, int delta) =>
      throw UnimplementedError();
}

/// A statement with money in all three states — escrowed, payable and frozen —
/// because the page's job is to keep those apart.
final class _FakeEarningsRepository implements SellerEarningsRepository {
  const _FakeEarningsRepository();

  /// Enough released earnings for the withdrawal card to offer its button,
  /// which is the state worth looking at.
  @override
  Future<Result<PayoutAvailability>> payoutAvailability() async => Success(
    PayoutAvailability(
      claimable: _syp('12840000'),
      ordersIncluded: 7,
      canRequest: true,
    ),
  );

  @override
  Future<Result<PendingPayout>> requestPayout() => throw UnimplementedError();

  @override
  Future<Result<PendingPayout>> cancelPayout(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<List<PendingPayout>>> payoutHistory() async =>
      const Success([]);

  @override
  Future<Result<SellerEarnings>> load() async => Success(
    SellerEarnings(
      heldInEscrow: _syp('18400000'),
      availableForPayout: _syp('12840000'),
      frozenInDisputes: _syp('1960000'),
      lifetimePaid: _syp('184300000'),
      lifetimeCommission: _syp('22100000'),
      lifetimeGross: _syp('206400000'),
      movements: [
        EarningsMovement(
          id: 'm1',
          type: EarningsMovementType.escrowReleased,
          account: EarningsAccount.payable,
          description: 'أُفرج عن حجز الطلب #10284',
          amount: _syp('850000'),
          isTransfer: true,
          occurredAt: DateTime(2026, 8, 24, 9, 12),
        ),
        EarningsMovement(
          id: 'm2',
          type: EarningsMovementType.commissionEarned,
          account: EarningsAccount.escrow,
          description: 'عمولة المنصّة على الطلب #10284',
          amount: _syp('-102000'),
          occurredAt: DateTime(2026, 8, 24, 9, 12),
        ),
        EarningsMovement(
          id: 'm3',
          type: EarningsMovementType.payoutPaid,
          account: EarningsAccount.payable,
          description: 'تحويل أسبوعي إلى حسابكِ',
          amount: _syp('-4200000'),
          occurredAt: DateTime(2026, 8, 22, 14),
        ),
        EarningsMovement(
          id: 'm4',
          type: EarningsMovementType.disputeHeld,
          account: EarningsAccount.disputeHeld,
          description: 'تجميد بسبب نزاع على الطلب #10190',
          amount: _syp('580000'),
          isTransfer: true,
          occurredAt: DateTime(2026, 8, 21, 11, 30),
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
