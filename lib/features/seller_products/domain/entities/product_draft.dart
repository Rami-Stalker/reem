import 'package:reem/core/shared/value_objects/money.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';

/// One media item being authored.
class MediaDraft {
  final String url;
  final bool isVideo;
  const MediaDraft(this.url, {this.isVideo = false});
}

/// One option combination being authored — «مقاس M / لون وردي».
///
/// A variant has two halves, exactly as the catalogue does. Its identity —
/// the name and the option axes it stands for — belongs to the shared
/// product; its price and stock belong to the seller's offer. Both are
/// captured here and split apart on the way out.
class VariantDraft {
  final String name;
  final Map<String, String> attributes;
  final String? sku;

  /// A decimal string, never a double: a variant may cost 1,450,000 ل.س and a
  /// JSON number is free to round it. `null` means "same as the listing".
  final String? price;
  final int stock;

  const VariantDraft({
    required this.name,
    this.attributes = const {},
    this.sku,
    this.price,
    this.stock = 0,
  });
}

/// Everything the product form composes, across both halves of the catalogue.
///
/// A seller does not own a product; she owns an *offer* on one. So a draft
/// carries the canonical fields (title, description, category, gallery,
/// option axes) and the offer fields (currency, price, stock, fulfilment
/// terms) side by side, and the serialiser posts each to the endpoint that
/// actually owns it. The previous flat shape — `category` as a typed slug and
/// `price` as a double, all posted to one route — matched no endpoint on the
/// server and failed validation on every submission.
class ProductDraft {
  // ── The canonical catalogue entry ──────────────────────────────────────
  final String title;
  final String description;

  /// A LEAF category's UUID. The server rejects anything above level 2.
  final String categoryId;
  final String? brandId;

  /// Extra fields the category's schema asks for (Q27 P2).
  final Map<String, dynamic> attributes;

  /// Barcode — unique across the catalogue when present.
  final String? gtin;
  final List<MediaDraft> media;
  final List<VariantDraft> variants;

  // ── The seller's offer on it ───────────────────────────────────────────
  final Currency currency;

  /// A decimal string, sent verbatim. See [Money].
  final String price;
  final String? compareAtPrice;
  final int stock;
  final String? sku;
  final int handlingDays;
  final int minOrderQty;
  final int? maxOrderQty;
  final bool isMadeToOrder;
  final bool acceptsReturns;

  /// Where the seller wants the listing to end up. A new offer is always born
  /// a draft server-side; asking for [ProductStatus.active] publishes it in a
  /// follow-up call.
  final ProductStatus status;

  const ProductDraft({
    required this.title,
    required this.description,
    required this.categoryId,
    required this.price,
    this.currency = Currency.syp,
    this.brandId,
    this.attributes = const {},
    this.gtin,
    this.media = const [],
    this.variants = const [],
    this.compareAtPrice,
    this.stock = 0,
    this.sku,
    this.handlingDays = 1,
    this.minOrderQty = 1,
    this.maxOrderQty,
    this.isMadeToOrder = false,
    this.acceptsReturns = true,
    this.status = ProductStatus.draft,
  });
}
