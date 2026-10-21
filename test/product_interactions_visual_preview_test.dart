// Renders every shape a product is shown in, with the interactions installed
// exactly as `AppChrome` installs them, so the rule can be eyeballed rather
// than only asserted. Not an assertion test — it writes `build/visual/*.png`.
//
//   flutter test test/product_interactions_visual_preview_test.dart
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
import 'package:reem/core/shared/entities/brand.dart';
import 'package:reem/core/shared/entities/category.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/core/shared/entities/seller_offer.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/auth/presentation/providers/auth_notifier.dart';
import 'package:reem/features/auth/presentation/providers/auth_provider.dart';
import 'package:reem/features/auth/presentation/providers/auth_state.dart';
import 'package:reem/features/product_social/domain/entities/product_engagement.dart';
import 'package:reem/features/product_social/domain/repositories/product_social_repository.dart';
import 'package:reem/features/product_social/presentation/providers/product_social_providers.dart';
import 'package:reem/features/product_social/presentation/widgets/product_actions_scope.dart';
import 'package:reem/features/product_social/presentation/widgets/product_post_card.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  for (final shape in _Shape.values) {
    testWidgets('renders ${shape.name} with the product interactions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1125, 2436);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_Preview(shape: shape));
      await tester.pump(const Duration(milliseconds: 300));
      await _capture(tester, 'product_interactions_${shape.name}');
    });
  }
}

enum _Shape { grid, mosaic, rail, post }

class _Preview extends StatelessWidget {
  const _Preview({required this.shape});

  final _Shape shape;

  @override
  Widget build(BuildContext context) {
    return ProviderScope(
      overrides: [
        productSocialRepositoryProvider.overrideWithValue(const _Engagement()),
        authNotifierProvider.overrideWith((ref) => _SignedIn()),
      ],
      child: MaterialApp(
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
        // Where the real app installs it: above the navigator, so every route
        // below gets the interactions without asking.
        builder: (context, navigator) =>
            ProductActionsScope(child: navigator ?? const SizedBox.shrink()),
        home: RepaintBoundary(
          key: _captureKey,
          child: Builder(
            builder: (context) => Scaffold(
              backgroundColor: context.dsColors.background,
              body: Stack(
                children: [
                  const Positioned.fill(child: CustomerBackdrop()),
                  _body(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body() {
    return switch (shape) {
      _Shape.rail => Padding(
        padding: EdgeInsets.only(top: 60),
        child: ProductRail(title: 'مختارة لكِ', products: _products),
      ),
      _Shape.grid => CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
          SliverProductGrid(products: _products),
        ],
      ),
      _Shape.mosaic => CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
          SliverProductMosaic(products: _products),
        ],
      ),
      _Shape.post => CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
          SliverProductPostCards(products: _products),
        ],
      ),
    };
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
  name: 'بوتيك ريم',
  username: 'reem_boutique',
  phone: '+963000000000',
  createdAt: DateTime(2026, 1, 1),
  isVerified: true,
);

const _category = Category(
  id: 'c1',
  slug: 'dresses',
  nameAr: 'فساتين',
  nameEn: 'Dresses',
  level: 3,
);

Product _product(String id, String title, int price, {int? was}) => Product(
  id: id,
  slug: id,
  title: title,
  description: 'قطعة من تشكيلة الموسم، بقَصّة تحتفي بالتفصيل.',
  category: _category,
  brand: const Brand(id: 'b1', slug: 'reem', nameAr: 'ريم', nameEn: 'Reem'),
  createdAt: DateTime(2026, 8, 1),
  rating: 4.6,
  reviewsCount: 18,
  offers: [
    SellerOffer(
      id: 'o$id',
      seller: _seller,
      status: OfferStatus.active,
      stock: 5,
      price: Money(raw: '$price', currency: Currency.syp),
      compareAtPrice: was == null
          ? null
          : Money(raw: '$was', currency: Currency.syp),
    ),
  ],
);

final _products = <Product>[
  _product('1', 'فستان سهرة مطرّز بالحرير', 850000, was: 1200000),
  _product('2', 'حقيبة يد جلد طبيعي', 420000),
  _product('3', 'عباية صوف بقَصّة واسعة', 610000),
];

/// The first piece is already liked, so a preview shows both states of the
/// heart rather than a page of empty ones.
class _Engagement implements ProductSocialRepository {
  const _Engagement();

  @override
  Future<Result<Map<String, ProductEngagement>>> engagement(
    List<String> ids,
  ) async => Success({
    for (final id in ids)
      id: ProductEngagement(
        likes: id == '1' ? 128 : 12,
        comments: id == '1' ? 9 : 0,
        isLiked: id == '1',
        isSaved: id == '2',
        viewerKnown: true,
      ),
  });

  @override
  Future<Result<int>> setLiked(String productId, {required bool liked}) async =>
      const Success(1);

  @override
  Future<Result<void>> setSaved(String productId, {required bool saved}) async =>
      const Success(null);

  @override
  Future<Result<int>> setPicked(
    String productId, {
    required bool picked,
    String? note,
  }) async => const Success(1);

  @override
  Future<Result<int>> recordShare(String productId) async => const Success(1);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

class _SignedIn extends StateNotifier<AuthState> implements AuthNotifier {
  _SignedIn()
    : super(
        AuthState(
          isInitialized: true,
          user: User(
            id: 'me',
            name: 'ريم',
            username: 'reem',
            phone: '+963111111111',
            createdAt: DateTime(2026, 1, 1),
          ),
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
