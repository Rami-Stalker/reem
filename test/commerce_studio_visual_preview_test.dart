// Renders the cart, checkout and the composer to PNGs so the design can be
// eyeballed without a session or a running backend. Not an assertion test in
// the usual sense — it writes `build/visual/commerce_*.png` and is meant to be
// run on demand.
//
//   flutter test test/commerce_studio_visual_preview_test.dart
//
// The real screens are drawn; only the data sources behind them are faked —
// the cart, checkout and social repositories, the address book and the signed
// in account — so what the images show is the screens' own layout over a
// plausible basket: two boutiques, three pieces, one variant, one piece sold
// out.
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/result/result.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/auth/presentation/providers/auth_notifier.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_state.dart';
import 'package:reem/features/cart/domain/entities/cart.dart';
import 'package:reem/features/cart/domain/repositories/cart_repository.dart';
import 'package:reem/features/cart/domain/usecases/cart_usecases.dart';
import 'package:reem/features/cart/presentation/providers/cart_notifier.dart';
import 'package:reem/features/cart/presentation/providers/cart_providers.dart';
import 'package:reem/features/cart/presentation/screens/cart_screen.dart';
import 'package:reem/features/checkout/domain/entities/checkout.dart';
import 'package:reem/features/checkout/domain/repositories/checkout_repository.dart';
import 'package:reem/features/checkout/presentation/providers/checkout_providers.dart';
import 'package:reem/features/checkout/presentation/providers/saved_addresses_provider.dart';
import 'package:reem/features/checkout/presentation/screens/checkout_screen.dart';
import 'package:reem/features/settings/domain/entities/address_entity.dart';
import 'package:reem/features/social/domain/entities/content.dart';
import 'package:reem/features/social/domain/entities/content_draft.dart';
import 'package:reem/features/social/domain/repositories/social_repository.dart';
import 'package:reem/features/social/presentation/providers/composer_notifier.dart';
import 'package:reem/features/social/presentation/providers/social_providers.dart';
import 'package:reem/features/social/presentation/screens/content_composer_screen.dart';
import 'package:reem/features/social/presentation/widgets/create_sheet.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

final _captureKey = GlobalKey();

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

Money _syp(String raw) => Money(raw: raw, currency: Currency.syp);

CartLine _line(
  String id,
  String seller,
  String sellerName,
  String title,
  String unit,
  int qty, {
  String? variant,
  bool inStock = true,
}) {
  final total = (int.parse(unit) * qty).toString();
  return CartLine(
    id: id,
    offerId: 'o-$id',
    sellerId: seller,
    sellerName: sellerName,
    productId: 'p-$id',
    title: title,
    quantity: qty,
    unitPrice: _syp(unit),
    lineTotal: _syp(total),
    inStock: inStock,
    availableStock: inStock ? 6 : 0,
    variantName: variant,
  );
}

final _cart = Cart(
  items: [
    _line('a', 's1', 'بوتيك ياسمين', 'فستان سهرة مطرّز بالخرز', '850000', 1,
        variant: 'المقاس M · خمري'),
    _line('b', 's1', 'بوتيك ياسمين', 'شال حرير بنقشة الياسمين', '150000', 2),
    _line('c', 's2', 'دار الكحل', 'طقم مكياج سهرة', '320000', 1,
        inStock: false),
  ],
  sellerGroups: [
    CartSellerGroup(
      sellerId: 's1',
      sellerName: 'بوتيك ياسمين',
      itemIds: const ['a', 'b'],
      itemsCount: 3,
      subtotal: _syp('1150000'),
    ),
    CartSellerGroup(
      sellerId: 's2',
      sellerName: 'دار الكحل',
      itemIds: const ['c'],
      itemsCount: 1,
      subtotal: _syp('320000'),
    ),
  ],
  summary: CartSummary(
    subtotalsByCurrency: [_syp('1470000')],
    itemsCount: 3,
    sellersCount: 2,
    totalQuantity: 4,
  ),
);

class _CartRepo implements CartRepository {
  @override
  Future<Result<Cart>> getCart() async => Success(_cart);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _CheckoutRepo implements CheckoutRepository {
  @override
  Future<Result<List<Governorate>>> getGovernorates() async => Success([
    Governorate(
      name: 'دمشق',
      fee: _syp('15000'),
      etaHoursMin: 6,
      etaHoursMax: 24,
    ),
  ]);

  @override
  Future<Result<List<PaymentMethodOption>>> getPaymentMethods() async =>
      const Success([
        PaymentMethodOption(
          method: 'cod',
          label: 'cod',
          requiresOnlineConfirmation: false,
        ),
        PaymentMethodOption(
          method: 'syriatel_cash',
          label: 'syriatel_cash',
          requiresOnlineConfirmation: true,
          instructions: 'حوّلي المبلغ إلى الرقم 0944 000 111 واكتبي رقم الطلب.',
        ),
        PaymentMethodOption(
          method: 'platform_wallet',
          label: 'platform_wallet',
          requiresOnlineConfirmation: false,
        ),
      ]);

  @override
  Future<Result<DeliveryQuote>> getDeliveryQuote({
    required String governorate,
    Money? subtotal,
    String? district,
    bool isRural = false,
  }) async => Success(
    DeliveryQuote(
      deliveryFee: _syp('15000'),
      freeShipping: false,
      etaHoursMin: 6,
      etaHoursMax: 30,
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SocialRepo implements SocialRepository {
  @override
  Future<Result<List<ContentTypeOption>>> contentTypes() async => const Success([
    ContentTypeOption(key: 'post', name: 'post', format: ContentFormat.post),
    ContentTypeOption(
      key: 'reel',
      name: 'reel',
      format: ContentFormat.reel,
      videoRequired: true,
      maxMedia: 1,
    ),
    ContentTypeOption(
      key: 'story',
      name: 'story',
      format: ContentFormat.story,
      maxMedia: 1,
    ),
  ]);

  @override
  Future<Result<List<TaggableProduct>>> taggableProducts({
    int page = 1,
    int limit = 20,
  }) async => const Success([]);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _SignedOut extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedOut() : super(const AuthState(isInitialized: true));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final _overrides = [
  authNotifierProvider.overrideWith((ref) => _SignedOut()),
  cartNotifierProvider.overrideWith((ref) {
    final repo = _CartRepo();
    return CartNotifier(
      getCart: GetCartUseCase(repo),
      addToCart: AddToCartUseCase(repo),
      updateItem: UpdateCartItemUseCase(repo),
      removeItem: RemoveCartItemUseCase(repo),
      clearCart: ClearCartUseCase(repo),
    )..load();
  }),
  checkoutRepositoryProvider.overrideWithValue(_CheckoutRepo()),
  savedAddressesProvider.overrideWith(
    (ref) async => const [
      AddressEntity(
        id: 'home',
        label: 'البيت',
        recipientName: 'لمى الحسن',
        recipientPhone: '+963991234567',
        governorate: 'دمشق',
        city: 'دمشق',
        district: 'المزة',
        addressLine: 'المزة فيلات غربية، بناء ١٢، الطابق الثالث',
        isDefault: true,
      ),
      AddressEntity(
        id: 'work',
        label: 'العمل',
        recipientName: 'لمى الحسن',
        recipientPhone: '+963991234567',
        governorate: 'دمشق',
        city: 'دمشق',
        addressLine: 'الشعلان، شارع الحمرا، مقابل المصرف',
      ),
    ],
  ),
  composerProvider.overrideWith(
    (ref) => ComposerNotifier(_SocialRepo(), isSeller: false)..load(),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('renders the cart in ${mode.name}', (tester) async {
      await _render(tester, mode, const CartScreen(), 'commerce_cart_${mode.name}');
    });

    testWidgets('renders checkout in ${mode.name}', (tester) async {
      await _render(
        tester,
        mode,
        const CheckoutScreen(),
        'commerce_checkout_${mode.name}',
        height: 5200,
      );
    });

    testWidgets('renders the composer in ${mode.name}', (tester) async {
      await _render(
        tester,
        mode,
        const ContentComposerScreen(initialFormat: 'reel'),
        'commerce_composer_${mode.name}',
      );
    });
  }

  testWidgets('renders the create tiles', (tester) async {
    await _render(
      tester,
      ThemeMode.light,
      Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.dsColors.background,
          body: Padding(
            padding: const EdgeInsets.all(DsSpacing.lg),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    for (final format in CreateFormat.values) ...[
                      if (format != CreateFormat.post) DsGaps.hSm,
                      Expanded(
                        child: CreateFormatTile(format: format, onTap: () {}),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      'commerce_create_tiles',
      height: 1600,
    );
  });
}

Future<void> _render(
  WidgetTester tester,
  ThemeMode mode,
  Widget screen,
  String name, {
  double height = 2436,
}) async {
  tester.view.physicalSize = Size(1125, height);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: _overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        themeMode: mode,
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
    ),
  );
  await tester.pump();
  for (var i = 0; i < 16; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }

  await tester.runAsync(() async {
    final boundary =
        _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ImageByteFormat.png);
    final dir = Directory('build/visual')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(data!.buffer.asUint8List());
  });

  await tester.pumpWidget(const SizedBox.shrink());
}
