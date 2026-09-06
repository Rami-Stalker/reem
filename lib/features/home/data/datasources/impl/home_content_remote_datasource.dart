import 'package:reem/core/network/api_endpoints.dart';
import 'package:reem/core/network/base_remote_datasource.dart';
import 'package:reem/core/shared/entities/loyalty.dart';
import 'package:reem/core/shared/models/product_model.dart';
import 'package:reem/features/home/data/datasources/home_content_datasource.dart';
import 'package:reem/features/home/domain/entities/continue_shopping_item.dart';
import 'package:reem/features/home/domain/entities/featured_store.dart';
import 'package:reem/features/home/domain/entities/flash_deal.dart';
import 'package:reem/features/home/domain/entities/hero_banner.dart';
import 'package:reem/features/home/domain/entities/home_category.dart';
import 'package:reem/features/home/domain/entities/home_content.dart';
import 'package:reem/features/home/domain/entities/home_notification.dart';
import 'package:reem/features/home/domain/entities/nearby_store.dart';
import 'package:reem/features/home/domain/entities/search_suggestions.dart';

/// The home page, read from the server.
///
/// This replaces a mock that shipped to production: for months the first thing
/// a customer saw was invented — banners for campaigns nobody ran, stores that
/// did not exist, a points balance that was not hers.
///
/// Sections the platform has no data for come back empty from the server and
/// are left empty here. `HomeContent` defaults every list, so an empty section
/// simply does not render, which is the honest outcome — filling them in the
/// client is exactly how the mock survived this long.
final class HomeContentRemoteDataSource extends BaseRemoteDataSource
    implements HomeContentDataSource {
  const HomeContentRemoteDataSource(super.dio);

  @override
  Future<HomeContent> getHomeContent() async {
    final json = await getJson(ApiEndpoints.homeContent);

    return HomeContent(
      heroBanners: _list(json['hero_banners']).map(_banner).toList(),
      featuredCategories: _list(
        json['featured_categories'],
      ).map(_category).toList(),
      flashDeals: _list(json['flash_deals']).map(_deal).nonNulls.toList(),
      featuredStores: _list(json['featured_stores']).map(_store).toList(),
      continueShopping: _list(
        json['continue_shopping'],
      ).map(_continueItem).nonNulls.toList(),
      nearbyStores: _list(json['nearby_stores']).map(_nearbyStore).toList(),
      searchSuggestions: _suggestions(json['search_suggestions']),
      notifications: _notifications(json['notifications']),
      loyalty: _loyalty(json['loyalty']),
    );
  }

  HeroBanner _banner(Map<String, dynamic> json) => HeroBanner(
    id: json['id'] as String? ?? '',
    kind: switch (json['kind'] as String?) {
      'campaign' => HeroBannerKind.campaign,
      'seasonal' => HeroBannerKind.seasonal,
      'personalized' => HeroBannerKind.personalized,
      _ => HeroBannerKind.promotion,
    },
    title: json['title'] as String? ?? '',
    subtitle: json['subtitle'] as String? ?? '',
    ctaLabel: json['cta_label'] as String? ?? '',
    imageUrl: json['image_url'] as String? ?? '',
    eyebrow: json['eyebrow'] as String?,
    badge: json['badge'] as String?,
    targetRoute: json['target_route'] as String?,
  );

  HomeCategory _category(Map<String, dynamic> json) => HomeCategory(
    id: json['id'] as String? ?? '',
    slug: json['slug'] as String? ?? '',
    label: json['label'] as String? ?? '',
    imageUrl: json['image_url'] as String? ?? '',
    productCount: (json['product_count'] as num?)?.toInt() ?? 0,
    isFeatured: json['is_featured'] as bool? ?? false,
  );

  /// A deal without a parsable product is dropped rather than rendered as an
  /// empty card — the discount is not the point, the thing being sold is.
  FlashDeal? _deal(Map<String, dynamic> json) {
    final product = json['product'];
    if (product is! Map<String, dynamic>) return null;

    return FlashDeal(
      product: ProductModel.fromJson(product),
      // No timer where the server has no end date. A countdown that resets on
      // refresh is a lie the customer eventually notices.
      endsAt: DateTime.tryParse(json['ends_at'] as String? ?? ''),
      soldCount: (json['sold_count'] as num?)?.toInt() ?? 0,
      totalQuantity: (json['total_quantity'] as num?)?.toInt() ?? 0,
    );
  }

  FeaturedStore _store(Map<String, dynamic> json) => FeaturedStore(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    tagline: json['tagline'] as String? ?? '',
    logoUrl: json['logo_url'] as String? ?? '',
    coverUrl: json['cover_url'] as String? ?? '',
    isVerified: json['is_verified'] as bool? ?? false,
    rating: (json['rating'] as num?)?.toDouble(),
    productCount: (json['product_count'] as num?)?.toInt() ?? 0,
    followerCount: (json['follower_count'] as num?)?.toInt() ?? 0,
    isFollowing: json['is_following'] as bool? ?? false,
    previewImages: _strings(json['preview_images']),
  );

  /// Boutiques in her governorate. The field was on the wire and on the
  /// entity, and nothing read it here -- so the section could not have drawn
  /// anything even once the server started answering.
  NearbyStore _nearbyStore(Map<String, dynamic> json) => NearbyStore(
    id: json['id'] as String? ?? '',
    name: json['name'] as String? ?? '',
    logoUrl: json['logo_url'] as String? ?? '',
    area: json['area'] as String? ?? '',
    sameCity: json['same_city'] as bool? ?? false,
    rating: (json['rating'] as num?)?.toDouble(),
  );

  ContinueShoppingItem? _continueItem(Map<String, dynamic> json) {
    final product = json['product'];
    if (product is! Map<String, dynamic>) return null;
    return ContinueShoppingItem(
      product: ProductModel.fromJson(product),
      note: json['note'] as String? ?? '',
    );
  }

  SearchSuggestions _suggestions(dynamic json) {
    if (json is! Map<String, dynamic>) return const SearchSuggestions();
    return SearchSuggestions(
      trending: _strings(json['trending']),
      recent: _strings(json['recent']),
      suggested: _strings(json['suggested']),
    );
  }

  NotificationSummary _notifications(dynamic json) {
    if (json is! Map<String, dynamic>) return const NotificationSummary();
    return NotificationSummary(
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      previews: _list(json['previews'])
          .map(
            (preview) => HomeNotificationPreview(
              id: preview['id'] as String? ?? '',
              kind: _notificationKind(preview['kind'] as String?),
              title: preview['title'] as String? ?? '',
              timeAgo: _timeAgo(preview['created_at'] as String?),
              unread: preview['unread'] as bool? ?? false,
            ),
          )
          .toList(),
    );
  }

  HomeNotificationKind _notificationKind(String? wire) {
    final value = (wire ?? '').toUpperCase();
    if (value.contains('ORDER') ||
        value.contains('SHIP') ||
        value.contains('DELIVER')) {
      return HomeNotificationKind.order;
    }
    if (value.contains('PROMO') ||
        value.contains('COUPON') ||
        value.contains('CAMPAIGN')) {
      return HomeNotificationKind.promo;
    }
    if (value.contains('FOLLOW') ||
        value.contains('COMMENT') ||
        value.contains('LIKE')) {
      return HomeNotificationKind.social;
    }
    return HomeNotificationKind.system;
  }

  LoyaltySummary? _loyalty(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final points = (json['points'] as num?)?.toInt() ?? 0;
    final tier = LoyaltyTierX.fromWire(json['tier'] as String?);

    return LoyaltySummary(
      points: points,
      tier: tier,
      nextTier: tier.next,
      // The thresholds are the tier ladder's own, so this stays in step with
      // however the ladder is configured rather than repeating its numbers.
      pointsToNextTier: tier.next == null
          ? 0
          : (tier.next!.threshold - points).clamp(0, tier.next!.threshold),
      availableCoupons: 0,
      rewardHint: '',
      lifetimePoints: (json['lifetime_points'] as num?)?.toInt(),
    );
  }

  /// «قبل ساعتين» — computed here because the server sends a timestamp, which
  /// is the only form that survives a phone with the wrong clock.
  String _timeAgo(String? iso) {
    final at = DateTime.tryParse(iso ?? '');
    if (at == null) return '';

    final gap = DateTime.now().difference(at.toLocal());
    if (gap.inMinutes < 1) return 'الآن';
    if (gap.inMinutes < 60) return 'قبل ${gap.inMinutes} دقيقة';
    if (gap.inHours < 24) return 'قبل ${gap.inHours} ساعة';
    if (gap.inDays == 1) return 'أمس';
    if (gap.inDays < 30) return 'قبل ${gap.inDays} يوم';
    return 'قبل ${(gap.inDays / 30).floor()} شهر';
  }

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map<String, dynamic>>().toList()
      : const [];

  List<String> _strings(dynamic value) =>
      value is List ? value.whereType<String>().toList() : const [];
}
