// Every product, everywhere, carries its own interactions — and they are one
// set of facts about the product, not a per-screen copy.
//
// The rule the client set: a product supports Like, Share, Save, Repost and
// Comments whether or not it is being shown as a post. Told as a post, all
// five sit on the card. Told as a grid or a card, the like sits on the tile
// and the other four are on the product page.
//
// What these pin is the failure that rule was written against. The app had a
// heart on the grid, none on the mosaic, none on the four rails, none on
// search and none on favourites — and the one heart it did have wrote to
// `favoritesNotifierProvider` while the product page and the post card wrote
// to `productEngagementProvider`. Two stores, two meanings, one product: a
// piece saved from the home grid opened with an empty heart.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:reem/core/design_system/design_system.dart';
import 'package:reem/core/localization/app_localizations.dart';
import 'package:reem/core/presentation/providers/product_shape_provider.dart';
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
import 'package:reem/features/discovery/presentation/widgets/product_card_compact.dart';
import 'package:reem/features/product_social/domain/entities/product_engagement.dart';
import 'package:reem/features/product_social/domain/repositories/product_social_repository.dart';
import 'package:reem/features/product_social/presentation/providers/product_social_providers.dart';
import 'package:reem/features/product_social/presentation/widgets/product_actions_scope.dart';
import 'package:reem/features/product_social/presentation/widgets/product_like_button.dart';
import 'package:reem/features/product_social/presentation/widgets/product_post_card.dart';
import 'package:reem/features/product_social/presentation/widgets/product_shelf.dart';
import 'package:reem/l10n/app_localizations.dart' as gen;

void main() {
  late _RecordingProductSocial social;

  setUp(() => social = _RecordingProductSocial());

  /// The app as `AppChrome` assembles it: the interaction scope installed once
  /// above everything, exactly as the real tree does.
  Widget harness(
    Widget child, {
    bool withScope = true,
    bool signedIn = true,
    DsProductShape? shape,
  }) {
    final app = MaterialApp(
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
      builder: (context, navigator) => withScope
          ? ProductActionsScope(child: navigator ?? const SizedBox.shrink())
          : (navigator ?? const SizedBox.shrink()),
      home: Scaffold(body: child),
    );

    return ProviderScope(
      overrides: [
        productSocialRepositoryProvider.overrideWithValue(social),
        authNotifierProvider.overrideWith(
          (ref) => _Session(signedIn: signedIn),
        ),
        // Overridden rather than written from a builder: setting a provider
        // during build is illegal, and doing it anyway made the second pump
        // throw and the assertion read an empty page.
        if (shape != null) productShapeProvider.overrideWith((ref) => shape),
      ],
      child: app,
    );
  }

  /// Settles the post-frame seed and the store's 60 ms batching timer.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
  }

  /// A viewport tall enough to hold a grid tile *and* a post card at once.
  ///
  /// The default 800×600 surface fits one 4:5 tile and nothing else, so the
  /// sliver below it never builds — and a test asserting that two views of one
  /// product agree cannot assert it on a view that was never laid out.
  void tallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  // ── The rule, on every shape ──────────────────────────────────────────────

  group('every shape a product is shown in carries its interactions', () {
    testWidgets('a grid tile', (tester) async {
      await tester.pumpWidget(
        harness(
          CustomScrollView(slivers: [SliverProductGrid(products: _products)]),
        ),
      );
      await settle(tester);

      expect(find.byType(ProductLikeButton), findsNWidgets(_products.length));
    });

    testWidgets('a mosaic pane', (tester) async {
      await tester.pumpWidget(
        harness(
          CustomScrollView(slivers: [SliverProductMosaic(products: _products)]),
        ),
      );
      await settle(tester);

      expect(find.byType(ProductLikeButton), findsWidgets);
    });

    testWidgets('a rail card', (tester) async {
      // The tightest surface on the platform, and the one that had nothing:
      // «مختارة لكِ», «شوهدت مؤخراً», «قد يعجبكِ أيضاً» and the wishlist
      // highlights are all this card.
      await tester.pumpWidget(
        harness(ProductRail(title: 'مختارة لكِ', products: _products)),
      );
      await settle(tester);

      expect(find.byType(ProductCardCompact), findsWidgets);
      expect(find.byType(ProductLikeButton), findsWidgets);
    });

    testWidgets('a product told as a post carries all five', (tester) async {
      await tester.pumpWidget(
        harness(
          CustomScrollView(
            slivers: [SliverProductPostCards(products: [_products.first])],
          ),
        ),
      );
      await settle(tester);

      final bar = tester.widget<DsPostActionBar>(
        find.byType(DsPostActionBar).first,
      );
      // Like, Comments, Share, Save, Repost — the client's five, on the card,
      // outside the product page.
      expect(bar.onLike, isNotNull);
      expect(bar.onComment, isNotNull);
      expect(bar.onShare, isNotNull);
      expect(bar.onSave, isNotNull);
      expect(bar.onPick, isNotNull, reason: 'repost «أضيفي إلى صفحتي»');
    });

    testWidgets('a surface holding only an id is not an exception', (
      tester,
    ) async {
      // A bundle's piece and a drop's item are projections with a product id
      // and no `Product`. "Every product, without exception" has to include
      // them, or the exception is exactly where it was warned against.
      await tester.pumpWidget(
        harness(const ProductLikeButton.forId('1', showCount: false)),
      );
      await settle(tester);

      expect(social.engagementReads, contains('1'));
      await tester.tap(find.byType(ProductLikeButton));
      await settle(tester);
      expect(social.likes['1'], isTrue);
    });
  });

  // ── One shelf ─────────────────────────────────────────────────────────────

  group('the three shapes are three views of one set of pieces', () {
    /// Drives `SliverProductShelf` at [shape] and says which products it drew.
    Future<Set<String>> titlesAt(
      WidgetTester tester,
      DsProductShape shape,
    ) async {
      tallScreen(tester);
      await tester.pumpWidget(
        harness(
          CustomScrollView(
            slivers: [SliverProductShelf(products: _products)],
          ),
          shape: shape,
        ),
      );
      await settle(tester);
      return tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data ?? '')
          .where((text) => _products.any((p) => p.title == text))
          .toSet();
    }

    testWidgets('switching shape changes the rhythm, not the pieces', (
      tester,
    ) async {
      // The home showcase's post shape used to render the *feed* while its
      // mosaic and grid rendered the products unwrapped from it, so a switch
      // could quietly change what was on the page — in a widget whose own
      // documentation promised the opposite.
      final expected = _products.map((p) => p.title).toSet();
      for (final shape in DsProductShape.values) {
        expect(
          await titlesAt(tester, shape),
          expected,
          reason: '${shape.name} drew a different set of pieces',
        );
      }
    });

    // One test per shape: pumping three trees into one binding reuses the
    // element tree, and a shape that failed to draw its interactions could
    // pass on the widgets the previous shape left behind.
    for (final shape in DsProductShape.values) {
      testWidgets('${shape.name} carries the interactions', (tester) async {
        tallScreen(tester);
        await tester.pumpWidget(
          harness(
            CustomScrollView(
              slivers: [SliverProductShelf(products: _products)],
            ),
            shape: shape,
          ),
        );
        await settle(tester);

        final hasInteractions = shape == DsProductShape.posts
            ? find.byType(DsPostActionBar).evaluate().isNotEmpty
            : find.byType(ProductLikeButton).evaluate().isNotEmpty;
        expect(
          hasInteractions,
          isTrue,
          reason: '${shape.name} drew products with nothing to do to them',
        );
      });
    }
  });

  // ── One store ─────────────────────────────────────────────────────────────

  group('the state is the product\'s, not the screen\'s', () {
    testWidgets(
      'liking from a grid tile shows as liked on the same piece as a post',
      (tester) async {
        // The client's own example, in the direction that was broken.
        tallScreen(tester);
        await tester.pumpWidget(
          harness(
            CustomScrollView(
              slivers: [
                SliverProductGrid(products: [_products.first]),
                SliverProductPostCards(products: [_products.first]),
              ],
            ),
          ),
        );
        await settle(tester);

        var bar = tester.widget<DsPostActionBar>(
          find.byType(DsPostActionBar).first,
        );
        expect(bar.liked, isFalse);

        await tester.tap(find.byType(ProductLikeButton).first);
        await settle(tester);

        bar = tester.widget<DsPostActionBar>(
          find.byType(DsPostActionBar).first,
        );
        expect(
          bar.liked,
          isTrue,
          reason:
              'the tile and the post card are two views of one product; a '
              'heart filled on one has to be filled on the other',
        );
      },
    );

    testWidgets('and the other way round', (tester) async {
      tallScreen(tester);
      await tester.pumpWidget(
        harness(
          CustomScrollView(
            slivers: [
              SliverProductGrid(products: [_products.first]),
              SliverProductPostCards(products: [_products.first]),
            ],
          ),
        ),
      );
      await settle(tester);

      final bar = tester.widget<DsPostActionBar>(
        find.byType(DsPostActionBar).first,
      );
      bar.onLike();
      await settle(tester);

      final tile = tester.widget<ProductLikeButton>(
        find.byType(ProductLikeButton).first,
      );
      expect(
        ProviderScope.containerOf(
          tester.element(find.byType(ProductLikeButton).first),
        ).read(productEngagementOfProvider(tile.id))?.isLiked,
        isTrue,
      );
    });

    testWidgets('a saved piece reads as saved wherever it is drawn', (
      tester,
    ) async {
      social.saved.add('1');

      await tester.pumpWidget(
        harness(
          CustomScrollView(
            slivers: [SliverProductPostCards(products: [_products.first])],
          ),
        ),
      );
      await settle(tester);

      final bar = tester.widget<DsPostActionBar>(
        find.byType(DsPostActionBar).first,
      );
      // «المفضّلة» is read back through the same batch as the like, so the
      // bookmark on a post and the bookmark on the product page agree.
      expect(bar.saved, isTrue);
    });

    testWidgets('one batch read covers a whole page of products', (
      tester,
    ) async {
      // Forty tiles must not be forty requests. The seeding is the reason
      // every surface can carry interactions without costing anything.
      await tester.pumpWidget(
        harness(
          CustomScrollView(slivers: [SliverProductGrid(products: _products)]),
        ),
      );
      await settle(tester);

      expect(social.engagementCalls, 1);
      expect(social.engagementReads, containsAll(_products.map((p) => p.id)));
    });
  });

  // ── The guarantees around it ─────────────────────────────────────────────

  testWidgets('a guest is asked to sign in rather than shown a filled heart', (
    tester,
  ) async {
    await tester.pumpWidget(
      harness(
        CustomScrollView(
          slivers: [SliverProductGrid(products: [_products.first])],
        ),
        signedIn: false,
      ),
    );
    await settle(tester);

    await tester.tap(find.byType(ProductLikeButton).first);
    await tester.pumpAndSettle();

    expect(social.likes, isEmpty, reason: 'nothing was written');
  });

  testWidgets('a card still renders where no scope is installed', (
    tester,
  ) async {
    // Widget previews, goldens and the design-system sandbox mount cards on
    // their own. The slot is an addition, never a requirement.
    await tester.pumpWidget(
      harness(
        CustomScrollView(slivers: [SliverProductGrid(products: _products)]),
        withScope: false,
      ),
    );
    await settle(tester);

    expect(find.byType(ProductCardLuxe), findsWidgets);
    expect(find.byType(ProductLikeButton), findsNothing);
  });
}

// ── Fixtures ────────────────────────────────────────────────────────────────

final _seller = User(
  id: 's1',
  name: 'بوتيك ريم',
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

Product _product(String id, String title, int price) => Product(
  id: id,
  slug: id,
  title: title,
  description: 'قطعة من تشكيلة الموسم.',
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
    ),
  ],
);

final _products = <Product>[
  _product('1', 'فستان سهرة مطرّز بالحرير', 850000),
  _product('2', 'حقيبة يد جلد طبيعي', 420000),
];

/// Remembers what was asked of it, so a test can assert on the traffic rather
/// than only on the pixels.
class _RecordingProductSocial implements ProductSocialRepository {
  final List<String> engagementReads = [];
  final Map<String, bool> likes = {};
  final Set<String> saved = {};
  int engagementCalls = 0;

  @override
  Future<Result<Map<String, ProductEngagement>>> engagement(
    List<String> ids,
  ) async {
    engagementCalls += 1;
    engagementReads.addAll(ids);
    return Success({
      for (final id in ids)
        id: ProductEngagement(
          isLiked: likes[id] ?? false,
          isSaved: saved.contains(id),
          viewerKnown: true,
        ),
    });
  }

  @override
  Future<Result<int>> setLiked(String productId, {required bool liked}) async {
    likes[productId] = liked;
    return const Success(1);
  }

  @override
  Future<Result<void>> setSaved(
    String productId, {
    required bool saved,
  }) async {
    if (saved) {
      this.saved.add(productId);
    } else {
      this.saved.remove(productId);
    }
    return const Success(null);
  }

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

class _Session extends StateNotifier<AuthState> implements AuthNotifier {
  _Session({required bool signedIn})
    : super(
        AuthState(
          isInitialized: true,
          user: signedIn
              ? User(
                  id: 'me',
                  name: 'ريم',
                  username: 'reem',
                  phone: '+963111111111',
                  createdAt: DateTime(2026, 1, 1),
                )
              : null,
        ),
      );

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}
