import { Brand, Category, ProductMedia, ProductVariant } from '@prisma/client';
import {
  OfferRecord,
  ProductRecord,
  defaultOffer,
  totalStock,
} from '../catalog/product-include';
import { Money } from '../money';
import { cuesFor } from '../../modules/ranking/kernel/behavioural';
import { serializePublicUser } from './user.serializer';

/**
 * The canonical product JSON.
 *
 * Two contract changes over the previous shape, both forced by the catalog
 * redesign: a product no longer *has* a seller or a price — it has offers, and
 * a price belongs to an offer. And every amount now travels as
 * `{ amount, currency }` rather than a bare JSON number, so no client can
 * render a figure without knowing what currency it is in.
 */

export type { ProductRecord, OfferRecord };

export function serializeCategory(category: Category) {
  return {
    id: category.id,
    slug: category.slug,
    name_ar: category.nameAr,
    name_en: category.nameEn,
    level: category.level,
    parent_id: category.parentId,
    icon_url: category.iconUrl,
    image_url: category.imageUrl,
    is_sensitive: category.isSensitive,
    returns_allowed: category.returnsAllowed,
  };
}

export function serializeBrand(brand: Brand) {
  return {
    id: brand.id,
    slug: brand.slug,
    name_ar: brand.nameAr,
    name_en: brand.nameEn,
    logo_url: brand.logoUrl,
    is_verified: brand.isVerified,
  };
}

export function serializeMedia(media: ProductMedia) {
  return {
    url: media.url,
    type: media.type,
    /// Drawn while the photograph is still arriving. Null for an external
    /// link, and for anything uploaded before derivatives existed.
    blur_hash: media.blurHash,
  };
}

/** The canonical option combination — no price, no stock (those are per offer). */
export function serializeVariant(variant: ProductVariant) {
  return {
    id: variant.id,
    name: variant.name,
    attributes: variant.attributes ?? null,
    image_url: variant.imageUrl,
    sort_order: variant.sortOrder,
  };
}

export function serializeOffer(offer: OfferRecord) {
  const price = Money.of(offer.price, offer.currency);
  const compareAt = offer.compareAtPrice
    ? Money.of(offer.compareAtPrice, offer.currency)
    : null;

  return {
    id: offer.id,
    seller: serializePublicUser(offer.seller),
    currency: offer.currency,
    price: price.toJSON(),
    compare_at_price: compareAt?.toJSON() ?? null,
    wholesale_price: offer.wholesalePrice
      ? Money.of(offer.wholesalePrice, offer.currency).toJSON()
      : null,
    wholesale_min_qty: offer.wholesaleMinQty,
    stock: offer.stock,
    min_order_qty: offer.minOrderQty,
    max_order_qty: offer.maxOrderQty,
    sku: offer.sku,
    handling_days: offer.handlingDays,
    is_made_to_order: offer.isMadeToOrder,
    requires_deposit: offer.requiresDeposit,
    accepts_returns: offer.acceptsReturns,
    status: offer.status.toLowerCase(),
    variants: offer.variants.map((offerVariant) => ({
      id: offerVariant.id,
      variant_id: offerVariant.variantId,
      name: offerVariant.variant.name,
      attributes: offerVariant.variant.attributes ?? null,
      image_url: offerVariant.variant.imageUrl,
      price: Money.of(
        offerVariant.price ?? offer.price,
        offer.currency,
      ).toJSON(),
      stock: offerVariant.stock,
      sku: offerVariant.sku,
    })),
  };
}

export function serializeProduct(
  product: ProductRecord,
  options?: { isLiked?: boolean; includeOffers?: boolean },
) {
  const best = defaultOffer(product);

  // What can honestly be said about this card. Empty when nothing can — see
  // `ranking/kernel/behavioural.ts` for why silence is the correct output
  // rather than a softened claim.
  const cues = cuesFor({
    recentOrders: product.recentOrders30 ?? 0,
    windowDays: 30,
    favourites: product.favoritesCount ?? 0,
    stock: product.liveStock ?? 0,
    liveOffers: product.liveOffersCount ?? 0,
    rating: product.rating ?? 0,
    reviews: product.reviewsCount ?? 0,
    compareAtPrice: best?.compareAtPrice ? Number(best.compareAtPrice) : null,
    price: best ? Number(best.price) : 0,
  });

  return {
    id: product.id,
    slug: product.slug,
    title: product.title,
    // Honest badges only; an empty list means there is nothing true to say.
    cues,
    description: product.description,
    category: serializeCategory(product.category),
    brand: product.brand ? serializeBrand(product.brand) : null,
    attributes: product.attributes ?? null,
    gtin: product.gtin,
    status: product.status.toLowerCase(),
    media: product.media.map(serializeMedia),
    variants: product.variants.map(serializeVariant),

    // Offers — the price-comparison surface (Q23/Q27).
    offers_count: product.offersCount,
    best_offer: best ? serializeOffer(best) : null,
    ...(options?.includeOffers
      ? { offers: product.offers.map(serializeOffer) }
      : {}),

    /// Normalised to SYP so cards from sellers pricing in USD stay comparable.
    price_from: product.minPriceSyp
      ? Money.of(product.minPriceSyp, 'SYP').toJSON()
      : null,
    price_to: product.maxPriceSyp
      ? Money.of(product.maxPriceSyp, 'SYP').toJSON()
      : null,

    stock: totalStock(product),
    is_available: product.offers.length > 0,

    rating: product.rating,
    reviews_count: product.reviewsCount,
    views_count: product.viewsCount,
    orders_count: product.ordersCount,
    favorites_count: product.favoritesCount,
    created_at: product.createdAt.toISOString(),
    ...(options?.isLiked !== undefined ? { is_liked: options.isLiked } : {}),
  };
}
