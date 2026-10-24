// Renders the new home catalogue surfaces to PNGs so the design can be
// eyeballed without booting the app. Not an assertion test — it writes
// `build/visual/*.png` and is meant to be run on demand.
//
//   flutter test test/home_visual_preview_test.dart
import 'dart:io';
import 'dart:ui' show ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/shared/entities/brand.dart';
import 'package:ohara/core/shared/entities/category.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/seller_offer.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
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

  testWidgets('renders the explore grid in both themes', (tester) async {
    tester.view.physicalSize = const Size(1125, 2436);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await tester.pumpWidget(_Preview(themeMode: mode));
      await tester.pump(const Duration(milliseconds: 300));
      await _capture(tester, 'explore_grid_${mode.name}');
    }
  });
}

class _Preview extends StatelessWidget {
  const _Preview({required this.themeMode});

  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
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
      home: RepaintBoundary(
        key: _captureKey,
        child: Builder(
        builder: (context) => Scaffold(
          backgroundColor: context.dsColors.background,
          body: Stack(
            children: [
              const Positioned.fill(child: CustomerBackdrop()),
              CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  SliverProductGrid(products: _products, onTapProduct: (_) {}),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                  const SliverProductGrid(isLoading: true, skeletonCount: 2),
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

final _seller = User(
  id: 's1',
  name: 'بوتيك أوهارا',
  username: 'reem_boutique',
  phone: '+963000000000',
  createdAt: DateTime(2026, 1, 1),
);

final _category = Category(
  id: 'c1',
  slug: 'dresses',
  nameAr: 'فساتين',
  nameEn: 'Dresses',
  level: 3,
);

Product _product(String id, String title, int price, {int? was}) {
  return Product(
    id: id,
    slug: id,
    title: title,
    description: '',
    category: _category,
    brand: const Brand(id: 'b1', slug: 'reem', nameAr: 'أوهارا', nameEn: 'Ohara'),
    createdAt: DateTime(2026, 8, 1),
    media: const [],
    rating: 4.6,
    offers: [
      SellerOffer(
        id: 'o$id',
        seller: _seller,
        status: OfferStatus.active,
        stock: 5,
        price: Money(raw: '$price', currency: Currency.syp),
        compareAtPrice:
            was == null ? null : Money(raw: '$was', currency: Currency.syp),
      ),
    ],
  );
}

final _products = <Product>[
  _product('1', 'فستان سهرة مطرّز بالحرير', 850000, was: 1200000),
  _product('2', 'حقيبة يد جلد طبيعي', 420000),
  _product('3', 'عطر شرقي فاخر ٥٠ مل', 310000, was: 380000),
  _product('4', 'طقم إكسسوارات ذهبي', 190000),
];
