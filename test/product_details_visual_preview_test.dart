// Renders the product page to PNGs so the design can be eyeballed without
// booting the app. Not an assertion test — it writes `build/visual/*.png`.
//
//   flutter test test/product_details_visual_preview_test.dart
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
import 'package:ohara/core/shared/entities/brand.dart';
import 'package:ohara/core/shared/entities/category.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/product_variant.dart';
import 'package:ohara/core/shared/entities/seller_offer.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_detail_body.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_headline.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_option_pickers.dart';
import 'package:ohara/features/product_details/presentation/widgets/product_price_block.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(_loadFonts);

  testWidgets('renders the product page body in both themes', (tester) async {
    tester.view.physicalSize = const Size(1125, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      // A fresh key per mode, so the implicit animations inside the chips
      // start from the new theme rather than lerping out of the old one.
      await tester.pumpWidget(
        _Preview(key: ValueKey(mode), themeMode: mode),
      );
      await tester.pumpAndSettle();
      await _capture(tester, 'product_details_${mode.name}');
    }
  });
}

class _Preview extends StatefulWidget {
  const _Preview({super.key, required this.themeMode});

  final ThemeMode themeMode;

  @override
  State<_Preview> createState() => _PreviewState();
}

class _PreviewState extends State<_Preview> {
  SellerOffer _offer = _offers.first;
  OfferVariant _variant = _offers.first.variants.first;
  int _quantity = 2;

  @override
  Widget build(BuildContext context) {
    // The headline reads her bookmark from the shared engagement store, so
    // the page body needs the app's provider scope, as it has in the app.
    return ProviderScope(child: _app(context));
  }

  Widget _app(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: widget.themeMode,
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
      home: RepaintBoundary(
        key: _captureKey,
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.dsColors.background,
            body: Stack(
              children: [
                const Positioned.fill(child: CustomerBackdrop()),
                ListView(
                  padding: const EdgeInsets.all(DsSpacing.lg),
                  children: [
                    ProductHeadline(product: _product),
                    DsGaps.vLg,
                    ProductPriceBlock(product: _product, offer: _offer),
                    DsGaps.section,
                    ProductOfferPicker(
                      offers: _offers,
                      selected: _offer,
                      onSelect: (o) => setState(() => _offer = o),
                    ),
                    DsGaps.section,
                    ProductVariantPicker(
                      variants: _offer.variants,
                      selected: _variant,
                      onSelect: (v) => setState(() => _variant = v),
                    ),
                    DsGaps.vLg,
                    ProductQuantityPicker(
                      quantity: _quantity,
                      min: 1,
                      max: 6,
                      onChanged: (q) => setState(() => _quantity = q),
                    ),
                    DsGaps.section,
                    ProductDetailBody(product: _product),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

// ── Fixtures ────────────────────────────────────────────────────────────────

User _seller(String id, String name) => User(
      id: id,
      username: name,
      name: name,
      phone: '+963900000000',
      createdAt: DateTime(2026, 1, 1),
    );

OfferVariant _variantOf(String id, String size, String price, int stock) =>
    OfferVariant(
      id: id,
      variantId: 'v-$id',
      name: size,
      attributes: {'المقاس': size},
      price: Money.fromJson(price),
      stock: stock,
    );

final _offers = <SellerOffer>[
  SellerOffer(
    id: 'offer-1',
    seller: _seller('s1', 'أتيليه الورد'),
    price: Money.fromJson('420000'),
    compareAtPrice: Money.fromJson('560000'),
    stock: 6,
    status: OfferStatus.active,
    variants: [
      _variantOf('a', 'S', '420000', 2),
      _variantOf('b', 'M', '420000', 4),
      _variantOf('c', 'L', '440000', 0),
    ],
  ),
  SellerOffer(
    id: 'offer-2',
    seller: _seller('s2', 'بوتيك ياسمين'),
    price: Money.fromJson('465000'),
    stock: 3,
    status: OfferStatus.active,
    variants: [_variantOf('d', 'M', '465000', 3)],
  ),
];

final _product = Product(
  id: 'p1',
  slug: 'silk-midi',
  title: 'فستان حرير ميدي بأكمام منفوخة',
  description:
      'فستان من الحرير الطبيعي بقصّة ميدي وأكمام منفوخة، بخصر محدّد وسحّاب '
      'خفي في الظهر. مناسب للمناسبات المسائية والسهرات، ويُغسل جافاً فقط. '
      'العارضة تلبس مقاس M وطولها ١٧٠ سم.',
  category: const Category(
    id: 'c1',
    slug: 'dresses',
    nameAr: 'فساتين',
    nameEn: 'Dresses',
  ),
  brand: const Brand(id: 'b1', slug: 'reem', nameAr: 'أوهارا', nameEn: 'Ohara'),
  attributes: const {
    'الخامة': 'حرير طبيعي ١٠٠٪',
    'طول الكم': 'كم طويل منفوخ',
    'العناية': 'غسيل جاف فقط',
    'بلد الصنع': 'سوريا',
  },
  offers: _offers,
  offersCount: 2,
  priceFrom: Money.fromJson('420000'),
  priceTo: Money.fromJson('465000'),
  stock: 9,
  rating: 4.5,
  reviewsCount: 128,
  viewsCount: 18400,
  ordersCount: 96,
  createdAt: DateTime(2026, 8, 1),
);
