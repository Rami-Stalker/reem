import { Prisma } from '@prisma/client';
import { LIVE_OFFER_WHERE } from '../../common/catalog/product-include';
import { ProductOrderBy } from './discovery.repository';

/**
 * Declarative specification for a discovery collection. Adding a collection is
 * a single entry here — the query path, caching, and pagination are shared.
 */
export interface CollectionSpec {
  extraWhere?: Prisma.ProductWhereInput;
  orderBy: ProductOrderBy;
  /** Cache TTL in ms. Hotter / more volatile collections use shorter TTLs. */
  ttlMs: number;
  /** Section size used on the aggregated home payload. */
  homeSize: number;
}

export type StaticCollectionKey =
  | 'trending'
  | 'best_selling'
  | 'new_arrivals'
  | 'featured'
  | 'most_loved'
  | 'top_rated'
  | 'deals';

export const STATIC_COLLECTIONS: Record<StaticCollectionKey, CollectionSpec> = {
  trending: {
    orderBy: [{ ordersCount: 'desc' }, { viewsCount: 'desc' }],
    ttlMs: 60_000,
    homeSize: 12,
  },
  best_selling: {
    orderBy: [{ ordersCount: 'desc' }],
    ttlMs: 120_000,
    homeSize: 12,
  },
  new_arrivals: {
    orderBy: [{ createdAt: 'desc' }],
    ttlMs: 30_000,
    homeSize: 12,
  },
  featured: {
    extraWhere: { isFeatured: true },
    orderBy: [{ createdAt: 'desc' }],
    ttlMs: 120_000,
    homeSize: 12,
  },
  most_loved: {
    orderBy: [{ favoritesCount: 'desc' }, { rating: 'desc' }],
    ttlMs: 60_000,
    homeSize: 12,
  },
  top_rated: {
    orderBy: [{ rating: 'desc' }, { reviewsCount: 'desc' }],
    ttlMs: 120_000,
    homeSize: 12,
  },
  /**
   * Everything currently marked down — where «عرض الكل» under the flash-deals
   * rail leads. It used to lead to `best_selling`, so a shopper following a
   * discount arrived at full-price merchandise.
   *
   * "Marked down" is read as *the seller entered a compare-at price on a live
   * offer*. Comparing the two columns (compare-at strictly above price) needs
   * a field reference the collection specs cannot express; a compare-at at or
   * below the asking price is a data error rather than a deal, and the card
   * itself shows no discount badge for one.
   */
  deals: {
    extraWhere: {
      offers: { some: { ...LIVE_OFFER_WHERE, compareAtPrice: { not: null } } },
    },
    orderBy: [{ updatedAt: 'desc' }],
    ttlMs: 60_000,
    homeSize: 12,
  },
};

export const STATIC_COLLECTION_KEYS = Object.keys(
  STATIC_COLLECTIONS,
) as StaticCollectionKey[];

/**
 * The shelves the aggregated home payload carries.
 *
 * `deals` is addressable as a collection — it is where "see all" under the
 * flash-deals rail goes — but it is not a home section: the home page already
 * builds that rail from live offers, and adding it here would only cost a
 * query and steal products from the shelves below it through the de-duping.
 */
export const HOME_COLLECTION_KEYS = STATIC_COLLECTION_KEYS.filter(
  (key) => key !== 'deals',
);

export function isStaticCollection(key: string): key is StaticCollectionKey {
  return Object.prototype.hasOwnProperty.call(STATIC_COLLECTIONS, key);
}
