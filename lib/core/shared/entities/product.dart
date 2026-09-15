// shared/entities/product.dart

import 'package:equatable/equatable.dart';
import 'package:reem/core/shared/entities/brand.dart';
import 'package:reem/core/shared/entities/category.dart';
import 'package:reem/core/shared/entities/media.dart';
import 'package:reem/core/shared/entities/product_cue.dart';
import 'package:reem/core/shared/entities/product_variant.dart';
import 'package:reem/core/shared/entities/seller_offer.dart';
import 'package:reem/core/shared/entities/user.dart';
import 'package:reem/core/shared/value_objects/money.dart';

/// A canonical catalogue entry.
///
/// It has no seller and no price. Several sellers may list the same item, each
/// with their own [SellerOffer] — that is what price comparison is (Q23). A
/// card shows [bestOffer]; the product page shows all of [offers].
class Product extends Equatable {
  final String id;
  final String slug;
  final String title;
  final String description;

  final Category category;
  final Brand? brand;

  /// Category-specific fields — الخامة، طول الكم، درجة اللون (Q27).
  final Map<String, dynamic> attributes;
  final String? gtin;

  final List<MediaItem> media;
  final List<ProductVariant> variants;

  /// Live offers. A card carries only the cheapest; the detail screen carries
  /// every one so the customer can choose a seller.
  final List<SellerOffer> offers;
  final int offersCount;

  /// Cheapest and dearest live offer, normalised to SYP so a seller pricing in
  /// USD still sorts and filters alongside one pricing in SYP.
  final Money? priceFrom;
  final Money? priceTo;

  final int stock;
  final bool isLiked;

  final double rating;
  final int reviewsCount;
  final int viewsCount;
  final int ordersCount;
  final int favoritesCount;

  /// The post gestures on a product, as of the read that produced this card.
  /// The live figures — and whether *she* liked or picked it — come from
  /// `productEngagementProvider`, which starts from these.
  final int likesCount;
  final int commentsCount;
  final int sharesCount;

  /// How many women added it to their page.
  final int picksCount;

  /// What the marketplace can honestly say about this listing — real scarcity,
  /// real social proof, a real anchor. Empty when there is nothing true to
  /// say, and an empty list is a card that shows no badge at all.
  final List<ProductCue> cues;

  final DateTime createdAt;

  const Product({
    required this.id,
    required this.slug,
    required this.title,
    required this.description,
    required this.category,
    required this.createdAt,
    this.brand,
    this.attributes = const {},
    this.gtin,
    this.media = const [],
    this.variants = const [],
    this.offers = const [],
    this.offersCount = 0,
    this.priceFrom,
    this.priceTo,
    this.stock = 0,
    this.isLiked = false,
    this.rating = 0,
    this.reviewsCount = 0,
    this.viewsCount = 0,
    this.ordersCount = 0,
    this.favoritesCount = 0,
    this.likesCount = 0,
    this.commentsCount = 0,
    this.sharesCount = 0,
    this.picksCount = 0,
    this.cues = const [],
  });

  MediaItem? get cover => media.isNotEmpty ? media.first : null;
  String? get coverUrl => cover?.displayUrl;

  /// The cover's blurred stand-in, for cards to draw while it loads.
  String? get coverBlurHash => cover?.blurHash;

  /// The offer a card quotes and "add to cart" defaults to. The server already
  /// sorts offers cheapest-first, so this is the best price.
  SellerOffer? get bestOffer => offers.isNotEmpty ? offers.first : null;

  /// Present so screens that still want "the seller" have an honest answer:
  /// the one whose offer is being shown, not an owner of the catalogue entry.
  User? get displaySeller => bestOffer?.seller;

  /// The figure a **card** quotes, normalised to SYP.
  ///
  /// `priceFrom` first, not the raw offer price: the server keeps that roll-up
  /// precisely "so cards from sellers pricing in USD stay comparable", and
  /// quoting the offer's own currency threw that away — a boutique pricing in
  /// dollars put `38.50 $` in a rail where every neighbour read `ل.س`, and
  /// nothing on the card said the two were the same money. The product page
  /// still shows the offer's own currency, because that is what she will
  /// actually be charged.
  Money? get price => priceFrom ?? bestOffer?.price;

  /// The struck-through "was" price — only when it is in the same currency as
  /// [price]. A SYP figure crossed out by a USD one is not a comparison.
  Money? get compareAtPrice {
    final was = bestOffer?.compareAtPrice;
    if (was == null) return null;
    final now = price;
    if (now != null && was.currency != now.currency) return null;
    return was;
  }

  bool get inStock => stock > 0 || offers.any((offer) => offer.inStock);
  bool get isAvailable => offers.any((offer) => offer.isBuyable);
  bool get hasVariants => variants.isNotEmpty;

  /// True when more than one seller lists this product, i.e. the compare-prices
  /// affordance is worth showing.
  bool get hasMultipleOffers => offersCount > 1;

  bool get hasDiscount => bestOffer?.hasDiscount ?? false;
  int get discountPercent => bestOffer?.discountPercent ?? 0;

  /// The spread between the cheapest and dearest seller, for a
  /// "from X to Y" label. Null when only one seller lists it.
  bool get hasPriceRange =>
      priceFrom != null &&
      priceTo != null &&
      priceFrom!.currency == priceTo!.currency &&
      priceTo!.approximateValue > priceFrom!.approximateValue;

  SellerOffer? offerById(String? id) {
    if (id == null) return null;
    for (final offer in offers) {
      if (offer.id == id) return offer;
    }
    return null;
  }

  @override
  List<Object?> get props => [
        id,
        slug,
        title,
        description,
        category,
        brand,
        attributes,
        gtin,
        media,
        variants,
        offers,
        offersCount,
        priceFrom,
        priceTo,
        stock,
        isLiked,
        rating,
        reviewsCount,
        viewsCount,
        ordersCount,
        favoritesCount,
        likesCount,
        commentsCount,
        sharesCount,
        picksCount,
        cues,
        createdAt,
      ];
}
