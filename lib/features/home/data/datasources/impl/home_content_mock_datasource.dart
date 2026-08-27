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
import '../../../../../core/shared/entities/category.dart';
import '../../../../../core/shared/entities/seller_offer.dart';
import '../../../../../core/shared/value_objects/money.dart';

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
  static final _atelier = _seller('s1', 'أتيليه الورد', verified: true);
  static final _maison = _seller('s2', 'دار النور', verified: true);
  static final _bloom = _seller('s3', 'بستان', verified: false);
  static final _velvet = _seller('s4', 'بتلات المخمل', verified: true);

  static const _handles = <String, String>{
    's1': 'atelier_alward',
    's2': 'dar_alnour',
    's3': 'bustan',
    's4': 'batalat_almakhmal',
  };

  static User _seller(String id, String name, {bool verified = false}) => User(
        id: id,
        name: name,
        // Derived handles used to be built by stripping non-latin characters,
        // which leaves an Arabic name with an empty username.
        username: _handles[id] ?? id,
        phone: '',
        role: UserRole.seller,
        isVerified: verified,
        imageUrl: _img('logo-$id', w: 200, h: 200),
        followersCount: 12400,
        createdAt: DateTime(2023, 3, 14),
      );

  /// Builds a canonical product with a single live offer.
  ///
  /// Prices are SYP, because that is what the platform charges in — the mock
  /// used to carry bare numbers that the UI rendered with a dollar sign.
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
    final offer = SellerOffer(
      id: 'offer-$id',
      seller: seller,
      price: Money(raw: price.toStringAsFixed(0), currency: Currency.syp),
      compareAtPrice: oldPrice == null
          ? null
          : Money(raw: oldPrice.toStringAsFixed(0), currency: Currency.syp),
      stock: stock,
      status: OfferStatus.active,
    );

    return Product(
      id: id,
      slug: id,
      title: title,
      description:
          'قطعة مصنوعة بعناية من فئة $category، كأنها صُمّمت خصيصاً لكِ.',
      category: Category(
        id: category,
        slug: category,
        nameAr: category,
        nameEn: category,
      ),
      media: [MediaItem(url: _img('prod-$id'))],
      offers: [offer],
      offersCount: 1,
      priceFrom: offer.price,
      priceTo: offer.price,
      stock: stock,
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
      eyebrow: 'أتيليه الربيع',
      title: 'بتلات وحرير',
      subtitle: 'وصلت تشكيلة الموسم الجديد',
      ctaLabel: 'اكتشفي التشكيلة',
      imageUrl: 'https://picsum.photos/seed/hero-spring/1200/800',
      badge: 'موسم جديد',
      targetRoute: RoutePaths.categories,
    ),
    HeroBanner(
      id: 'h2',
      kind: HeroBannerKind.promotion,
      eyebrow: 'للعضوات فقط',
      title: 'خصم حتى 40٪',
      subtitle: 'الجمال والعطور، هذا الأسبوع فقط',
      ctaLabel: 'تسوّقي المختارات',
      imageUrl: 'https://picsum.photos/seed/hero-beauty/1200/800',
      badge: '−40%',
      targetRoute: RoutePaths.search,
    ),
    HeroBanner(
      id: 'h3',
      kind: HeroBannerKind.personalized,
      eyebrow: 'مختارة لكِ',
      title: 'جمالٌ على ذوقكِ',
      subtitle: 'منتقاة من القطع التي أحببتِها',
      ctaLabel: 'شاهدي مختاراتكِ',
      imageUrl: 'https://picsum.photos/seed/hero-personal/1200/800',
      targetRoute: RoutePaths.search,
    ),
    HeroBanner(
      id: 'h4',
      kind: HeroBannerKind.campaign,
      eyebrow: 'ريم × صانعات محليات',
      title: 'صُنع بحبّ، هنا',
      subtitle: 'اكتشفي البوتيكات القريبة منكِ',
      ctaLabel: 'تعرّفي على الصانعات',
      imageUrl: 'https://picsum.photos/seed/hero-makers/1200/800',
      badge: 'حملة',
      targetRoute: RoutePaths.categories,
    ),
  ];

  // ── Categories ─────────────────────────────────────────────────────────────
  static final _categories = <HomeCategory>[
    HomeCategory(id: 'c1', label: 'فساتين', imageUrl: _img('cat-dress', w: 300, h: 300), productCount: 1240, isFeatured: true),
    HomeCategory(id: 'c2', label: 'عطور', imageUrl: _img('cat-perfume', w: 300, h: 300), productCount: 860, isFeatured: true),
    HomeCategory(id: 'c3', label: 'حقائب', imageUrl: _img('cat-bags', w: 300, h: 300), productCount: 540),
    HomeCategory(id: 'c4', label: 'مكياج', imageUrl: _img('cat-beauty', w: 300, h: 300), productCount: 2100, isFeatured: true),
    HomeCategory(id: 'c5', label: 'مجوهرات', imageUrl: _img('cat-jewelry', w: 300, h: 300), productCount: 430),
    HomeCategory(id: 'c6', label: 'أحذية', imageUrl: _img('cat-shoes', w: 300, h: 300), productCount: 720),
    HomeCategory(id: 'c7', label: 'عبايات', imageUrl: _img('cat-abaya', w: 300, h: 300), productCount: 380),
    HomeCategory(id: 'c8', label: 'هدايا', imageUrl: _img('cat-gifts', w: 300, h: 300), productCount: 260),
  ];

  // ── Flash deals ──────────────────────────────────────────────────────────
  static List<FlashDeal> _flashDeals(DateTime now) => [
        FlashDeal(
          product: _product(id: 'fd1', title: 'فستان حرير بماء الورد', price: 850000, oldPrice: 1440000, category: 'فساتين', seller: _atelier, rating: 4.9),
          endsAt: now.add(const Duration(hours: 3, minutes: 42)),
          soldCount: 78,
          totalQuantity: 100,
        ),
        FlashDeal(
          product: _product(id: 'fd2', title: 'عطر زهر المخمل', price: 430000, oldPrice: 630000, category: 'عطور', seller: _velvet, rating: 4.8),
          endsAt: now.add(const Duration(hours: 5, minutes: 12)),
          soldCount: 44,
          totalQuantity: 60,
        ),
        FlashDeal(
          product: _product(id: 'fd3', title: 'حقيبة كتف صغيرة مبطّنة', price: 580000, oldPrice: 945000, category: 'حقائب', seller: _maison, rating: 4.7),
          endsAt: now.add(const Duration(hours: 1, minutes: 55)),
          soldCount: 92,
          totalQuantity: 100,
        ),
        FlashDeal(
          product: _product(id: 'fd4', title: 'أقراط لؤلؤ متدلّية', price: 220000, oldPrice: 385000, category: 'مجوهرات', seller: _bloom, rating: 4.6),
          endsAt: now.add(const Duration(hours: 8)),
          soldCount: 30,
          totalQuantity: 120,
        ),
        FlashDeal(
          product: _product(id: 'fd5', title: 'حذاء ساتان بفيونكة', price: 495000, oldPrice: 790000, category: 'أحذية', seller: _atelier, rating: 4.8),
          endsAt: now.add(const Duration(hours: 4, minutes: 20)),
          soldCount: 65,
          totalQuantity: 80,
        ),
      ];

  // ── Featured stores ──────────────────────────────────────────────────────
  static final _stores = <FeaturedStore>[
    FeaturedStore(
      id: 's1',
      name: 'أتيليه الورد',
      tagline: 'أزياء رومانسية جاهزة، تُخاط يدوياً بكميّات قليلة',
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
      name: 'دار النور',
      tagline: 'جلديات وإكسسوارات بفخامة هادئة',
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
      name: 'بتلات المخمل',
      tagline: 'عطور نباتية وطقوس للمنزل',
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
      name: 'بستان',
      tagline: 'مجوهرات يومية لا تفارق بشرتكِ',
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
    _product(id: 'rv1', title: 'فستان تريكو مضلّع متوسط', price: 620000, category: 'فساتين', seller: _atelier),
    _product(id: 'rv2', title: 'عطر عود وعنبر للسفر', price: 280000, oldPrice: 350000, category: 'عطور', seller: _velvet),
    _product(id: 'rv3', title: 'محفظة بطاقات بنقشة الجلد', price: 245000, category: 'حقائب', seller: _maison),
    _product(id: 'rv4', title: 'ثلاثية زيوت الشفاه الملوّنة', price: 170000, category: 'مكياج', seller: _bloom),
    _product(id: 'rv5', title: 'خلخال مطلي بالذهب', price: 325000, oldPrice: 430000, category: 'مجوهرات', seller: _bloom),
    _product(id: 'rv6', title: 'صندل بكعب عريض وأحزمة', price: 440000, category: 'أحذية', seller: _atelier),
  ];

  // ── Continue shopping ────────────────────────────────────────────────────
  static final _continueShopping = <ContinueShoppingItem>[
    ContinueShoppingItem(product: _product(id: 'cs1', title: 'فستان كتّان ماكسي بلفّة', price: 700000, oldPrice: 880000, category: 'فساتين', seller: _atelier), note: 'في سلّتكِ'),
    ContinueShoppingItem(product: _product(id: 'cs2', title: 'طقم كريم يدين بالفاوانيا', price: 198000, category: 'مكياج', seller: _velvet), note: 'شاهدتِه قبل يومين'),
    ContinueShoppingItem(product: _product(id: 'cs3', title: 'حقيبة صغيرة بمقبض علوي', price: 640000, category: 'حقائب', seller: _maison, stock: 3), note: 'بقيت 3 قطع'),
    ContinueShoppingItem(product: _product(id: 'cs4', title: 'مشبك شعر بالكريستال', price: 126000, category: 'مجوهرات', seller: _bloom), note: 'عاد للمخزون'),
  ];

  // ── Nearby stores ────────────────────────────────────────────────────────
  static final _nearbyStores = <NearbyStore>[
    NearbyStore(id: 'n1', name: 'أتيليه الورد — أبو رمّانة', logoUrl: _img('logo-s1', w: 200, h: 200), area: 'دمشق · أبو رمّانة', distanceKm: 1.8, rating: 4.9),
    NearbyStore(id: 'n2', name: 'دار النور', logoUrl: _img('logo-s2', w: 200, h: 200), area: 'دمشق · المزّة', distanceKm: 3.4, rating: 4.8),
    NearbyStore(id: 'n3', name: 'بوتيك بتلات المخمل', logoUrl: _img('logo-s4', w: 200, h: 200), area: 'دمشق · الشعلان', distanceKm: 5.1, rating: 4.7, isOpen: false),
  ];

  // ── Dynamic content blocks (admin-configured) ─────────────────────────────
  static const _dynamicBlocks = <DynamicContentBlock>[
    DynamicContentBlock(
      id: 'd1',
      kind: DynamicBlockKind.spotlight,
      title: 'إطلالات المناسبات',
      subtitle: 'قطع تخطف الأنظار في كل احتفال هذا الموسم',
      imageUrl: 'https://picsum.photos/seed/block-wedding/1000/600',
      ctaLabel: 'اكتشفي',
      targetRoute: RoutePaths.categories,
    ),
    DynamicContentBlock(
      id: 'd2',
      kind: DynamicBlockKind.announcement,
      title: 'توصيل سريع مجاني',
      subtitle: 'على كل طلب فوق 350 ألف ل.س — يُطبَّق تلقائياً عند الدفع',
      ctaLabel: 'اعرفي المزيد',
    ),
  ];

  // ── Smart search ─────────────────────────────────────────────────────────
  static const _searchSuggestions = SearchSuggestions(
    trending: ['فستان ساتان', 'عطر عود', 'حلق ذهبي', 'إطلالة مناسبة', 'حقيبة فخامة هادئة'],
    recent: ['فستان كتّان', 'زيت شفاه'],
    suggested: ['ورود الربيع', 'تحت 200 ألف', 'جديد أتيليه الورد'],
  );

  // ── Notifications summary ──────────────────────────────────────────────────
  static const _notifications = NotificationSummary(
    unreadCount: 3,
    previews: [
      HomeNotificationPreview(id: 'no1', kind: HomeNotificationKind.order, title: 'طلبكِ رقم 10284 خرج للتوصيل', timeAgo: 'قبل 12 د'),
      HomeNotificationPreview(id: 'no2', kind: HomeNotificationKind.promo, title: 'عروض اليوم تنتهي قريباً — خصم حتى 40٪', timeAgo: 'قبل ساعة'),
      HomeNotificationPreview(id: 'no3', kind: HomeNotificationKind.social, title: 'أتيليه الورد نشرت ستوري جديدة', timeAgo: 'قبل 3 س', unread: false),
    ],
  );

  // ── Loyalty ────────────────────────────────────────────────────────────────
  static const _loyalty = LoyaltySummary(
    points: 2450,
    tier: LoyaltyTier.gold,
    nextTier: LoyaltyTier.platinum,
    pointsToNextTier: 550,
    availableCoupons: 4,
    rewardHint: '550 نقطة تفصلكِ عن البلاتينية — وتغليف هدية مجاني',
  );
}
