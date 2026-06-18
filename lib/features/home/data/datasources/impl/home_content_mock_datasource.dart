import '../../../../../core/shared/entities/loyalty.dart';
import '../../../../../core/shared/entities/media.dart';
import '../../../../../core/shared/entities/product.dart';
import '../../../../../core/shared/entities/user.dart';
import '../../../../../core/router/route_paths.dart';
import '../../../domain/entities/continue_shopping_item.dart';
import '../../../domain/entities/dynamic_block.dart';
import '../../../domain/entities/featured_store.dart';
import '../../../domain/entities/flash_deal.dart';
import '../../../domain/entities/hero_banner.dart';
import '../../../domain/entities/home_category.dart';
import '../../../domain/entities/home_content.dart';
import '../../../domain/entities/home_notification.dart';
import '../../../domain/entities/nearby_store.dart';
import '../../../domain/entities/search_suggestions.dart';
import '../home_content_datasource.dart';

/// Front-end-first mock of the home merchandising content.
///
/// Returns polished, deterministic sample data so the home page is fully alive
/// before the backend ships these surfaces. Image URLs use picsum seeds (stable
/// per id). Replace with a remote implementation when the endpoints exist — the
/// repository and everything above it stay untouched.
final class HomeContentMockDataSource implements HomeContentDataSource {
  const HomeContentMockDataSource();

  // Simulated network latency so skeleton states are exercised in dev.
  static const _latency = Duration(milliseconds: 650);

  static String _img(String seed, {int w = 600, int h = 750}) =>
      'https://picsum.photos/seed/$seed/$w/$h';

  @override
  Future<HomeContent> getHomeContent() async {
    await Future<void>.delayed(_latency);
    final now = DateTime.now();

    return HomeContent(
      heroBanners: _heroBanners,
      featuredCategories: _categories,
      flashDeals: _flashDeals(now),
      featuredStores: _stores,
      recentlyViewed: _recentlyViewed,
      continueShopping: _continueShopping,
      nearbyStores: _nearbyStores,
      dynamicBlocks: _dynamicBlocks,
      searchSuggestions: _searchSuggestions,
      notifications: _notifications,
      loyalty: _loyalty,
    );
  }

  // ── Sellers ────────────────────────────────────────────────────────────────
  static final _atelier = _seller('s1', 'Atelier Rose', verified: true);
  static final _maison = _seller('s2', 'Maison Lumière', verified: true);
  static final _bloom = _seller('s3', 'Bloom & Co', verified: false);
  static final _velvet = _seller('s4', 'Velvet Petals', verified: true);

  static User _seller(String id, String name, {bool verified = false}) => User(
        id: id,
        name: name,
        username: name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_'),
        phone: '',
        role: UserRole.seller,
        isVerified: verified,
        imageUrl: _img('logo-$id', w: 200, h: 200),
        followersCount: 12400,
        createdAt: DateTime(2023, 3, 14),
      );

  static Product _product({
    required String id,
    required String title,
    required double price,
    double? oldPrice,
    required String category,
    required User seller,
    double rating = 4.7,
    int stock = 32,
    int reviews = 184,
  }) {
    return Product(
      id: id,
      seller: seller,
      title: title,
      description:
          'Thoughtfully crafted $category, made to feel like it was designed just for you.',
      category: category,
      price: price,
      oldPrice: oldPrice,
      stock: stock,
      media: [MediaItem(url: _img('prod-$id'))],
      isFeatured: true,
      rating: rating,
      reviewsCount: reviews,
      viewsCount: 5400,
      likesCount: 890,
      ordersCount: 320,
      favoritesCount: 540,
      createdAt: DateTime(2024, 11, 2),
    );
  }

  // ── Hero banners ─────────────────────────────────────────────────────────
  static const _heroBanners = <HeroBanner>[
    HeroBanner(
      id: 'h1',
      kind: HeroBannerKind.seasonal,
      eyebrow: 'Spring Atelier',
      title: 'Petals & Silk',
      subtitle: 'The new season collection has landed',
      ctaLabel: 'Explore collection',
      imageUrl: 'https://picsum.photos/seed/hero-spring/1200/800',
      badge: 'New season',
      targetRoute: RoutePaths.categories,
    ),
    HeroBanner(
      id: 'h2',
      kind: HeroBannerKind.promotion,
      eyebrow: 'Members only',
      title: 'Up to 40% off',
      subtitle: 'Beauty & fragrance, this weekend only',
      ctaLabel: 'Shop the edit',
      imageUrl: 'https://picsum.photos/seed/hero-beauty/1200/800',
      badge: '−40%',
      targetRoute: RoutePaths.search,
    ),
    HeroBanner(
      id: 'h3',
      kind: HeroBannerKind.personalized,
      eyebrow: 'Picked for you',
      title: 'Your kind of pretty',
      subtitle: 'Curated from the pieces you love',
      ctaLabel: 'See your edit',
      imageUrl: 'https://picsum.photos/seed/hero-personal/1200/800',
      targetRoute: RoutePaths.search,
    ),
    HeroBanner(
      id: 'h4',
      kind: HeroBannerKind.campaign,
      eyebrow: 'Reem x Local Makers',
      title: 'Made with love, locally',
      subtitle: 'Discover boutiques near you',
      ctaLabel: 'Meet the makers',
      imageUrl: 'https://picsum.photos/seed/hero-makers/1200/800',
      badge: 'Campaign',
      targetRoute: RoutePaths.categories,
    ),
  ];

  // ── Categories ─────────────────────────────────────────────────────────────
  static final _categories = <HomeCategory>[
    HomeCategory(id: 'c1', label: 'Dresses', imageUrl: _img('cat-dress', w: 300, h: 300), productCount: 1240, isFeatured: true),
    HomeCategory(id: 'c2', label: 'Fragrance', imageUrl: _img('cat-perfume', w: 300, h: 300), productCount: 860, isFeatured: true),
    HomeCategory(id: 'c3', label: 'Bags', imageUrl: _img('cat-bags', w: 300, h: 300), productCount: 540),
    HomeCategory(id: 'c4', label: 'Beauty', imageUrl: _img('cat-beauty', w: 300, h: 300), productCount: 2100, isFeatured: true),
    HomeCategory(id: 'c5', label: 'Jewelry', imageUrl: _img('cat-jewelry', w: 300, h: 300), productCount: 430),
    HomeCategory(id: 'c6', label: 'Shoes', imageUrl: _img('cat-shoes', w: 300, h: 300), productCount: 720),
    HomeCategory(id: 'c7', label: 'Abayas', imageUrl: _img('cat-abaya', w: 300, h: 300), productCount: 380),
    HomeCategory(id: 'c8', label: 'Gifts', imageUrl: _img('cat-gifts', w: 300, h: 300), productCount: 260),
  ];

  // ── Flash deals ──────────────────────────────────────────────────────────
  static List<FlashDeal> _flashDeals(DateTime now) => [
        FlashDeal(
          product: _product(id: 'fd1', title: 'Rosewater Silk Slip Dress', price: 189, oldPrice: 320, category: 'dress', seller: _atelier, rating: 4.9),
          endsAt: now.add(const Duration(hours: 3, minutes: 42)),
          soldCount: 78,
          totalQuantity: 100,
        ),
        FlashDeal(
          product: _product(id: 'fd2', title: 'Velvet Bloom Eau de Parfum', price: 95, oldPrice: 140, category: 'fragrance', seller: _velvet, rating: 4.8),
          endsAt: now.add(const Duration(hours: 5, minutes: 12)),
          soldCount: 44,
          totalQuantity: 60,
        ),
        FlashDeal(
          product: _product(id: 'fd3', title: 'Quilted Mini Shoulder Bag', price: 129, oldPrice: 210, category: 'bags', seller: _maison, rating: 4.7),
          endsAt: now.add(const Duration(hours: 1, minutes: 55)),
          soldCount: 92,
          totalQuantity: 100,
        ),
        FlashDeal(
          product: _product(id: 'fd4', title: 'Pearl Drop Earrings', price: 49, oldPrice: 85, category: 'jewelry', seller: _bloom, rating: 4.6),
          endsAt: now.add(const Duration(hours: 8)),
          soldCount: 30,
          totalQuantity: 120,
        ),
        FlashDeal(
          product: _product(id: 'fd5', title: 'Satin Bow Heeled Mules', price: 110, oldPrice: 175, category: 'shoes', seller: _atelier, rating: 4.8),
          endsAt: now.add(const Duration(hours: 4, minutes: 20)),
          soldCount: 65,
          totalQuantity: 80,
        ),
      ];

  // ── Featured stores ──────────────────────────────────────────────────────
  static final _stores = <FeaturedStore>[
    FeaturedStore(
      id: 's1',
      name: 'Atelier Rose',
      tagline: 'Romantic ready-to-wear, handmade in small batches',
      logoUrl: _img('logo-s1', w: 200, h: 200),
      coverUrl: _img('cover-s1', w: 800, h: 400),
      isVerified: true,
      rating: 4.9,
      productCount: 248,
      followerCount: 32400,
      previewImages: [_img('pv-s1a', w: 200, h: 200), _img('pv-s1b', w: 200, h: 200), _img('pv-s1c', w: 200, h: 200)],
    ),
    FeaturedStore(
      id: 's2',
      name: 'Maison Lumière',
      tagline: 'Quiet-luxury leather goods & accessories',
      logoUrl: _img('logo-s2', w: 200, h: 200),
      coverUrl: _img('cover-s2', w: 800, h: 400),
      isVerified: true,
      rating: 4.8,
      productCount: 132,
      followerCount: 18900,
      isFollowing: true,
      previewImages: [_img('pv-s2a', w: 200, h: 200), _img('pv-s2b', w: 200, h: 200), _img('pv-s2c', w: 200, h: 200)],
    ),
    FeaturedStore(
      id: 's4',
      name: 'Velvet Petals',
      tagline: 'Botanical fragrance & home rituals',
      logoUrl: _img('logo-s4', w: 200, h: 200),
      coverUrl: _img('cover-s4', w: 800, h: 400),
      isVerified: true,
      rating: 4.7,
      productCount: 86,
      followerCount: 9700,
      previewImages: [_img('pv-s4a', w: 200, h: 200), _img('pv-s4b', w: 200, h: 200), _img('pv-s4c', w: 200, h: 200)],
    ),
    FeaturedStore(
      id: 's3',
      name: 'Bloom & Co',
      tagline: 'Everyday jewelry that never leaves your skin',
      logoUrl: _img('logo-s3', w: 200, h: 200),
      coverUrl: _img('cover-s3', w: 800, h: 400),
      rating: 4.6,
      productCount: 204,
      followerCount: 14200,
      previewImages: [_img('pv-s3a', w: 200, h: 200), _img('pv-s3b', w: 200, h: 200), _img('pv-s3c', w: 200, h: 200)],
    ),
  ];

  // ── Recently viewed ──────────────────────────────────────────────────────
  static final _recentlyViewed = <Product>[
    _product(id: 'rv1', title: 'Ribbed Knit Midi Dress', price: 138, category: 'dress', seller: _atelier),
    _product(id: 'rv2', title: 'Amber Oud Travel Spray', price: 62, oldPrice: 78, category: 'fragrance', seller: _velvet),
    _product(id: 'rv3', title: 'Croc-Effect Card Holder', price: 54, category: 'bags', seller: _maison),
    _product(id: 'rv4', title: 'Tinted Lip Oil Trio', price: 38, category: 'beauty', seller: _bloom),
    _product(id: 'rv5', title: 'Gold Vermeil Anklet', price: 72, oldPrice: 96, category: 'jewelry', seller: _bloom),
    _product(id: 'rv6', title: 'Strappy Block Sandals', price: 98, category: 'shoes', seller: _atelier),
  ];

  // ── Continue shopping ────────────────────────────────────────────────────
  static final _continueShopping = <ContinueShoppingItem>[
    ContinueShoppingItem(product: _product(id: 'cs1', title: 'Linen Wrap Maxi Dress', price: 156, oldPrice: 195, category: 'dress', seller: _atelier), note: 'In your bag'),
    ContinueShoppingItem(product: _product(id: 'cs2', title: 'Peony Hand Cream Set', price: 44, category: 'beauty', seller: _velvet), note: 'Viewed 2d ago'),
    ContinueShoppingItem(product: _product(id: 'cs3', title: 'Mini Top-Handle Bag', price: 142, category: 'bags', seller: _maison, stock: 3), note: 'Only 3 left'),
    ContinueShoppingItem(product: _product(id: 'cs4', title: 'Crystal Hair Claw', price: 28, category: 'jewelry', seller: _bloom), note: 'Back in stock'),
  ];

  // ── Nearby stores ────────────────────────────────────────────────────────
  static final _nearbyStores = <NearbyStore>[
    NearbyStore(id: 'n1', name: 'Atelier Rose — Olaya', logoUrl: _img('logo-s1', w: 200, h: 200), area: 'Riyadh · Al Olaya', distanceKm: 1.8, rating: 4.9),
    NearbyStore(id: 'n2', name: 'Maison Lumière', logoUrl: _img('logo-s2', w: 200, h: 200), area: 'Riyadh · Al Nakheel', distanceKm: 3.4, rating: 4.8),
    NearbyStore(id: 'n3', name: 'Velvet Petals Boutique', logoUrl: _img('logo-s4', w: 200, h: 200), area: 'Riyadh · Hittin', distanceKm: 5.1, rating: 4.7, isOpen: false),
  ];

  // ── Dynamic content blocks (admin-configured) ─────────────────────────────
  static const _dynamicBlocks = <DynamicContentBlock>[
    DynamicContentBlock(
      id: 'd1',
      kind: DynamicBlockKind.spotlight,
      title: 'The Wedding Guest Edit',
      subtitle: 'Show-stopping pieces for every celebration this season',
      imageUrl: 'https://picsum.photos/seed/block-wedding/1000/600',
      ctaLabel: 'Discover',
      targetRoute: RoutePaths.categories,
    ),
    DynamicContentBlock(
      id: 'd2',
      kind: DynamicBlockKind.announcement,
      title: 'Free express delivery',
      subtitle: 'On all orders over \$75 — automatically at checkout',
      ctaLabel: 'Learn more',
    ),
  ];

  // ── Smart search ─────────────────────────────────────────────────────────
  static const _searchSuggestions = SearchSuggestions(
    trending: ['Satin slip dress', 'Oud perfume', 'Gold hoops', 'Wedding guest', 'Quiet luxury bag'],
    recent: ['Linen dress', 'Lip oil'],
    suggested: ['Spring florals', 'Under \$50', 'New from Atelier Rose'],
  );

  // ── Notifications summary ──────────────────────────────────────────────────
  static const _notifications = NotificationSummary(
    unreadCount: 3,
    previews: [
      HomeNotificationPreview(id: 'no1', kind: HomeNotificationKind.order, title: 'Your order #10284 is out for delivery', timeAgo: '12m'),
      HomeNotificationPreview(id: 'no2', kind: HomeNotificationKind.promo, title: 'Flash deals end soon — up to 40% off', timeAgo: '1h'),
      HomeNotificationPreview(id: 'no3', kind: HomeNotificationKind.social, title: 'Atelier Rose posted a new story', timeAgo: '3h', unread: false),
    ],
  );

  // ── Loyalty ────────────────────────────────────────────────────────────────
  static const _loyalty = LoyaltySummary(
    points: 2450,
    tier: LoyaltyTier.gold,
    nextTier: LoyaltyTier.platinum,
    pointsToNextTier: 550,
    availableCoupons: 4,
    rewardHint: '550 pts until Platinum — and a free gift wrap',
  );
}
