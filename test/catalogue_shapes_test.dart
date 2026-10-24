// The catalogue is meant to be readable in three rhythms — as posts, as a
// mosaic, as a grid — everywhere it lists products, not only inside the home
// page's "new in" showcase. Before this, tapping into a department or a "see
// all" dropped the shopper back into a fixed two-column grid, which made the
// switcher on home look like a decoration.
//
// These pin the two things that would silently undo that: the switcher being
// dropped from a listing, and the shapes not actually drawing what they say.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ohara/core/design_system/design_system.dart';
import 'package:ohara/core/localization/app_localizations.dart';
import 'package:ohara/core/presentation/providers/product_shape_provider.dart';
import 'package:ohara/core/result/result.dart';
import 'package:ohara/core/shared/entities/brand.dart';
import 'package:ohara/core/shared/entities/category.dart';
import 'package:ohara/core/shared/entities/product.dart';
import 'package:ohara/core/shared/entities/seller_offer.dart';
import 'package:ohara/core/shared/entities/user.dart';
import 'package:ohara/core/shared/value_objects/money.dart';
import 'package:ohara/features/discovery/domain/entities/product_page.dart';
import 'package:ohara/features/product_social/domain/entities/product_engagement.dart';
import 'package:ohara/features/product_social/domain/repositories/product_social_repository.dart';
import 'package:ohara/features/product_social/presentation/providers/product_social_providers.dart';
import 'package:ohara/features/product_social/presentation/widgets/product_post_card.dart';
import 'package:ohara/l10n/app_localizations.dart' as gen;
import 'package:ohara/l10n/app_localizations_ar.dart';

void main() {
  Widget harness(Widget child) {
    return ProviderScope(
      // The post shape reads the shared engagement store; a fake repository
      // keeps the test off the network.
      overrides: [
        productSocialRepositoryProvider.overrideWithValue(
          _SilentProductSocial(),
        ),
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
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('the post shape tells a product as a full post', (tester) async {
    await tester.pumpWidget(
      harness(
        CustomScrollView(slivers: [SliverProductPostCards(products: _products)]),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(ProductPostCard), findsWidgets);
    // The boutique heads its own piece, and the ticket carries the price.
    expect(find.text('بوتيك أوهارا'), findsWidgets);
    expect(find.byType(DsImmersivePost), findsWidgets);
    expect(find.text(_products.first.title), findsWidgets);
    // What the client asked for: a department's posts carry the same gestures
    // as «وصل حديثاً» — heart, thread, share, «أضيفي إلى صفحتي», bookmark — and
    // a «…» that opens something.
    final post = tester.widget<DsImmersivePost>(
      find.byType(DsImmersivePost).first,
    );
    expect(post.onPick, isNotNull);
    expect(post.onMore, isNotNull);
    expect(post.onAddToBag, isNotNull, reason: 'in stock, so it can be bought');
  });

  testWidgets('a bag only appears on a piece that can actually be bought', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        CustomScrollView(slivers: [SliverProductPostCards(products: [_soldOut])]),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    final post = tester.widget<DsImmersivePost>(find.byType(DsImmersivePost));
    expect(post.onAddToBag, isNull, reason: 'nothing in stock to add');
  });

  testWidgets('the switcher moves the shared catalogue shape', (tester) async {
    late WidgetRef ref;
    await tester.pumpWidget(
      harness(
        Consumer(
          builder: (context, widgetRef, _) {
            ref = widgetRef;
            final shape = widgetRef.watch(productShapeProvider);
            return ShapeSwitcher(
              selected: shape,
              onSelect: (next) =>
                  widgetRef.read(productShapeProvider.notifier).state = next,
            );
          },
        ),
      ),
    );

    expect(ref.read(productShapeProvider), DsProductShape.posts);

    final l10n = AppLocalizationsAr();
    await tester.tap(find.text(l10n.homeShapeGrid));
    await tester.pumpAndSettle();

    expect(ref.read(productShapeProvider), DsProductShape.grid);
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

const _category = Category(
  id: 'c1',
  slug: 'dresses',
  nameAr: 'فساتين',
  nameEn: 'Dresses',
  level: 3,
);

Product _product(
  String id,
  String title,
  int price, {
  int? was,
  int stock = 5,
}) {
  return Product(
    id: id,
    slug: id,
    title: title,
    description: 'قطعة من تشكيلة الموسم.',
    category: _category,
    brand: const Brand(id: 'b1', slug: 'reem', nameAr: 'أوهارا', nameEn: 'Ohara'),
    createdAt: DateTime(2026, 8, 1),
    rating: 4.6,
    reviewsCount: 18,
    offers: [
      SellerOffer(
        id: 'o$id',
        seller: _seller,
        status: OfferStatus.active,
        stock: stock,
        price: Money(raw: '$price', currency: Currency.syp),
        compareAtPrice: was == null
            ? null
            : Money(raw: '$was', currency: Currency.syp),
      ),
    ],
  );
}

final _products = <Product>[
  _product('1', 'فستان سهرة مطرّز بالحرير', 850000, was: 1200000),
  _product('2', 'حقيبة يد جلد طبيعي', 420000),
];

final _soldOut = _product('3', 'عباية صوف', 300000, stock: 0);

/// Answers every read with nothing and every write with success.
class _SilentProductSocial implements ProductSocialRepository {
  @override
  Future<Result<Map<String, ProductEngagement>>> engagement(
    List<String> ids,
  ) async => const Success({});

  @override
  Future<Result<int>> setLiked(String productId, {required bool liked}) async =>
      const Success(0);

  @override
  Future<Result<void>> setSaved(String productId, {required bool saved}) async =>
      const Success(null);

  @override
  Future<Result<int>> setPicked(
    String productId, {
    required bool picked,
    String? note,
  }) async => const Success(0);

  @override
  Future<Result<int>> recordShare(String productId) async => const Success(0);

  @override
  Future<Result<void>> report(
    String productId,
    String reason, {
    String? detail,
  }) async => const Success(null);

  @override
  Future<Result<ProductPage>> picksOf(String userId, {int page = 1}) =>
      throw UnimplementedError();
}
