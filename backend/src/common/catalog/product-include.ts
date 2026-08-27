import { OfferStatus, Prisma, ProductStatus } from '@prisma/client';

/**
 * The single definition of "how a product is loaded".
 *
 * This used to be nine near-identical `{ seller: true, media: …, variants: … }`
 * literals scattered across products, discovery, search, favorites, posts,
 * ai-assistant, commerce-content and admin — each of which had to be edited in
 * lockstep and, predictably, had already drifted (two of them silently dropped
 * `variants`). Everything now imports from here.
 */

// ── Where-clauses ───────────────────────────────────────────────────────

/** An offer a customer can actually buy from right now. */
export const LIVE_OFFER_WHERE = {
  status: OfferStatus.ACTIVE,
  isActive: true,
  stock: { gt: 0 },
} satisfies Prisma.SellerOfferWhereInput;

/**
 * A product is purchasable when at least one seller lists it live. Stock and
 * availability moved to the offer, so this is a relation filter now — the old
 * `{ status: ACTIVE, isAvailable: true, stock: { gt: 0 } }` predicate (which
 * existed four times under three different names) can no longer be expressed
 * on the product row at all.
 */
export const PURCHASABLE_PRODUCT_WHERE = {
  status: ProductStatus.ACTIVE,
  offers: { some: LIVE_OFFER_WHERE },
} satisfies Prisma.ProductWhereInput;

/** Everything publicly visible, including products momentarily out of stock. */
export const PUBLIC_PRODUCT_WHERE = {
  status: ProductStatus.ACTIVE,
} satisfies Prisma.ProductWhereInput;

export function sellerOwnsProductWhere(sellerId: string) {
  return { offers: { some: { sellerId } } } satisfies Prisma.ProductWhereInput;
}

// ── Includes ────────────────────────────────────────────────────────────

const MEDIA_INCLUDE = { orderBy: { sortOrder: 'asc' as const } };
const VARIANTS_INCLUDE = { orderBy: { sortOrder: 'asc' as const } };

export const OFFER_INCLUDE = {
  seller: true,
  variants: { include: { variant: true } },
} satisfies Prisma.SellerOfferInclude;

/** Full detail — the product page. Every live offer, for price comparison. */
export const PRODUCT_INCLUDE = {
  category: true,
  brand: true,
  media: MEDIA_INCLUDE,
  variants: VARIANTS_INCLUDE,
  offers: {
    where: LIVE_OFFER_WHERE,
    orderBy: { price: 'asc' as const },
    include: OFFER_INCLUDE,
  },
} satisfies Prisma.ProductInclude;

/**
 * List/card detail — feeds, search results, rails. Carries only the cheapest
 * live offer so a 20-item page does not drag every seller's whole variant
 * matrix across the wire.
 */
export const PRODUCT_CARD_INCLUDE = {
  category: true,
  brand: true,
  media: MEDIA_INCLUDE,
  variants: VARIANTS_INCLUDE,
  offers: {
    where: LIVE_OFFER_WHERE,
    orderBy: { price: 'asc' as const },
    take: 1,
    include: OFFER_INCLUDE,
  },
} satisfies Prisma.ProductInclude;

/** A seller's own offers, including drafts and paused ones. */
export function sellerOfferInclude(sellerId: string) {
  return {
    category: true,
    brand: true,
    media: MEDIA_INCLUDE,
    variants: VARIANTS_INCLUDE,
    offers: {
      where: { sellerId },
      orderBy: { createdAt: 'desc' as const },
      include: OFFER_INCLUDE,
    },
  } satisfies Prisma.ProductInclude;
}

export type ProductRecord = Prisma.ProductGetPayload<{
  include: typeof PRODUCT_INCLUDE;
}>;

export type OfferRecord = Prisma.SellerOfferGetPayload<{
  include: typeof OFFER_INCLUDE;
}>;

// ── Offer selection ─────────────────────────────────────────────────────

/**
 * The offer shown by default on a card. `PRODUCT_INCLUDE` already sorts by
 * price ascending, so this is the cheapest live one — but the choice is
 * centralised here so a future ranking (seller rating, package tier, delivery
 * speed) changes in one place rather than at every call site.
 */
export function defaultOffer(product: {
  offers: OfferRecord[];
}): OfferRecord | null {
  return product.offers[0] ?? null;
}

export function findOffer(
  product: { offers: OfferRecord[] },
  offerId: string,
): OfferRecord | null {
  return product.offers.find((offer) => offer.id === offerId) ?? null;
}

/** Total sellable units for a product across every live offer. */
export function totalStock(product: { offers: OfferRecord[] }): number {
  return product.offers.reduce((sum, offer) => sum + offer.stock, 0);
}
