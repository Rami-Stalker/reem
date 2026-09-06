import 'package:reem/core/shared/entities/product_variant.dart';
import 'package:reem/features/seller_products/domain/entities/product_draft.dart';
import 'package:reem/features/seller_products/domain/entities/product_status.dart';

/// Serialises a [ProductDraft] into the two payloads the backend accepts.
///
/// The catalogue split put a product's identity and a seller's terms behind
/// different routes with different contracts, and this class is where that
/// split is honoured:
///
/// * [toCreateJson] → `POST /seller/products` — a canonical entry with the
///   seller's first offer nested inside it, which is the only shape that
///   endpoint validates.
/// * [toProductJson] → `PATCH /seller/products/:productId` — the shared half.
/// * [toOfferJson] → `PATCH /seller/offers/:offerId` — the seller's half.
///
/// Money crosses the wire as a decimal string with an explicit currency, never
/// as a JSON number. There is no platform default price currency: the seller
/// chooses (Q45 P2).
class ProductDraftRequest {
  const ProductDraftRequest(this.draft);

  final ProductDraft draft;

  /// `POST /seller/products` — creating the entry and the first offer at once.
  Map<String, dynamic> toCreateJson() => {
        ...toProductJson(),
        'offer': _offerCreateJson(),
      };

  /// The canonical half: what every seller of this product sees.
  Map<String, dynamic> toProductJson() => {
        'title': draft.title,
        'description': draft.description,
        'category_id': draft.categoryId,
        if (draft.brandId != null && draft.brandId!.isNotEmpty)
          'brand_id': draft.brandId,
        if (draft.attributes.isNotEmpty) 'attributes': draft.attributes,
        if (draft.gtin != null && draft.gtin!.isNotEmpty) 'gtin': draft.gtin,
        'media': [
          for (var i = 0; i < draft.media.length; i++)
            {
              'url': draft.media[i].url,
              'type': draft.media[i].isVideo ? 'video' : 'image',
              'sort_order': i,
            },
        ],
        if (draft.variants.isNotEmpty)
          'variants': [
            for (var i = 0; i < draft.variants.length; i++)
              {
                'name': draft.variants[i].name,
                // The option axes. A variant with none still needs the object:
                // the server validates it as required, and an unnamed axis is
                // better recorded as its own label than dropped entirely.
                'attributes': draft.variants[i].attributes.isEmpty
                    ? {'name': draft.variants[i].name}
                    : draft.variants[i].attributes,
                'sort_order': i,
              },
          ],
      };

  /// The seller's half — price, stock and fulfilment terms.
  ///
  /// `status` is included so publishing and pausing ride the same route as
  /// every other listing edit. Stock is sent as an absolute figure here;
  /// `POST /seller/offers/:id/stock` exists separately for a *delta*, which is
  /// what the inventory stepper wants.
  Map<String, dynamic> toOfferJson({bool includeStatus = true}) => {
        'currency': draft.currency.wire,
        'price': draft.price,
        if (draft.compareAtPrice != null && draft.compareAtPrice!.isNotEmpty)
          'compare_at_price': draft.compareAtPrice,
        'stock': draft.stock,
        if (draft.sku != null && draft.sku!.isNotEmpty) 'sku': draft.sku,
        'handling_days': draft.handlingDays,
        'min_order_qty': draft.minOrderQty,
        if (draft.maxOrderQty != null) 'max_order_qty': draft.maxOrderQty,
        'is_made_to_order': draft.isMadeToOrder,
        'accepts_returns': draft.acceptsReturns,
        if (includeStatus) 'status': draft.status.wire,
      };

  /// The nested offer on creation. `CreateOfferDto` carries no `status` — a
  /// new listing is born a draft and is published by a second call — and no
  /// `product_id`, because the product does not exist yet.
  Map<String, dynamic> _offerCreateJson() => toOfferJson(includeStatus: false);

  /// The per-option price and stock rows, matched to the canonical variant ids
  /// the server has just minted.
  ///
  /// The offer's variant rows are keyed by `variant_id`, and those ids do not
  /// exist until the product row is written — so they cannot travel on the
  /// create call and are attached immediately afterwards. Matching is by name,
  /// which is what the draft and the created entry share; a row whose name the
  /// server did not echo back is dropped rather than guessed at.
  List<Map<String, dynamic>> offerVariantsFor(List<ProductVariant> canonical) {
    if (draft.variants.isEmpty || canonical.isEmpty) return const [];

    final byName = {
      for (final variant in canonical) variant.name.trim(): variant.id,
    };

    return [
      for (final variant in draft.variants)
        if (byName[variant.name.trim()] case final String variantId)
          {
            'variant_id': variantId,
            'stock': variant.stock,
            if (variant.price != null && variant.price!.isNotEmpty)
              'price': variant.price,
            if (variant.sku != null && variant.sku!.isNotEmpty)
              'sku': variant.sku,
          },
    ];
  }
}
