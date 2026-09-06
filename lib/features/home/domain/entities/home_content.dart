import 'package:equatable/equatable.dart';

import 'package:reem/core/shared/entities/loyalty.dart';
import 'package:reem/core/shared/entities/product.dart';
import 'package:reem/features/home/domain/entities/continue_shopping_item.dart';
import 'package:reem/features/home/domain/entities/dynamic_block.dart';
import 'package:reem/features/home/domain/entities/featured_store.dart';
import 'package:reem/features/home/domain/entities/flash_deal.dart';
import 'package:reem/features/home/domain/entities/hero_banner.dart';
import 'package:reem/features/home/domain/entities/home_category.dart';
import 'package:reem/features/home/domain/entities/home_notification.dart';
import 'package:reem/features/home/domain/entities/nearby_store.dart';
import 'package:reem/features/home/domain/entities/search_suggestions.dart';

/// The aggregate of all personalized, home-specific content fetched in one
/// pass. Product *rails* (recommended / new arrivals / best sellers …) and the
/// social feed/stories stay in their own providers — this carries the bespoke
/// merchandising surfaces that the home page composes around them.
class HomeContent extends Equatable {
  const HomeContent({
    this.heroBanners = const [],
    this.featuredCategories = const [],
    this.flashDeals = const [],
    this.featuredStores = const [],
    this.recentlyViewed = const [],
    this.continueShopping = const [],
    this.nearbyStores = const [],
    this.dynamicBlocks = const [],
    this.searchSuggestions = const SearchSuggestions(),
    this.notifications = const NotificationSummary(),
    this.loyalty,
  });

  final List<HeroBanner> heroBanners;
  final List<HomeCategory> featuredCategories;
  final List<FlashDeal> flashDeals;
  final List<FeaturedStore> featuredStores;
  final List<Product> recentlyViewed;
  final List<ContinueShoppingItem> continueShopping;
  final List<NearbyStore> nearbyStores;
  final List<DynamicContentBlock> dynamicBlocks;
  final SearchSuggestions searchSuggestions;
  final NotificationSummary notifications;
  final LoyaltySummary? loyalty;

  @override
  List<Object?> get props => [
    heroBanners,
    featuredCategories,
    flashDeals,
    featuredStores,
    recentlyViewed,
    continueShopping,
    nearbyStores,
    dynamicBlocks,
    searchSuggestions,
    notifications,
    loyalty,
  ];
}
