import { Prisma } from '@prisma/client';
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
  | 'top_rated';

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
};

export const STATIC_COLLECTION_KEYS = Object.keys(
  STATIC_COLLECTIONS,
) as StaticCollectionKey[];

export function isStaticCollection(key: string): key is StaticCollectionKey {
  return Object.prototype.hasOwnProperty.call(STATIC_COLLECTIONS, key);
}
