import { ModestyLevel, StylePersona } from '@prisma/client';

/**
 * Everything the ranker is allowed to know about *her*, as opposed to about
 * this request.
 *
 * Kept as a plain value rather than a service handle so scoring stays a pure
 * function of (product, brief, profile) — which is what makes the ranker
 * testable without a database, and what makes a recommendation's reasons
 * reproducible after the fact.
 */
export interface StyleProfile {
  /** Null for a first-time visitor. Scoring must survive that. */
  userId: string | null;

  // ── Stated ────────────────────────────────────────────────────────────
  modesty: ModestyLevel;
  personas: StylePersona[];
  favouriteColours: string[];
  avoidedColours: string[];
  preferredCategorySlugs: string[];
  avoidedCategorySlugs: string[];
  sizes: { clothing?: string; shoes?: string };
  budgetMinSyp: number | null;
  budgetMaxSyp: number | null;

  // ── Derived ───────────────────────────────────────────────────────────
  /** slug → weight. Higher means she engages with it more. */
  categoryAffinity: Map<string, number>;
  /** seller id → weight. */
  sellerAffinity: Map<string, number>;
  /** colour key → weight, read out of what she viewed, saved and bought. */
  colourAffinity: Map<string, number>;
  /** brand id → weight. */
  brandAffinity: Map<string, number>;

  /** The band she actually buys in, from her own orders. */
  typicalMinSyp: number | null;
  typicalMaxSyp: number | null;

  purchasedProductIds: Set<string>;
  savedProductIds: Set<string>;
  viewedProductIds: Set<string>;
  /** Cards she pushed away. The one signal nothing else in the schema keeps. */
  dismissedProductIds: Set<string>;

  recentQueries: string[];

  /** How much history there is — scales how far personalization may move a
   *  ranking, so a brand-new account is not ranked by three page views. */
  maturity: 'new' | 'browsing' | 'engaged' | 'loyal';
}

export function emptyStyleProfile(userId: string | null = null): StyleProfile {
  return {
    userId,
    modesty: ModestyLevel.UNSPECIFIED,
    personas: [],
    favouriteColours: [],
    avoidedColours: [],
    preferredCategorySlugs: [],
    avoidedCategorySlugs: [],
    sizes: {},
    budgetMinSyp: null,
    budgetMaxSyp: null,
    categoryAffinity: new Map(),
    sellerAffinity: new Map(),
    colourAffinity: new Map(),
    brandAffinity: new Map(),
    typicalMinSyp: null,
    typicalMaxSyp: null,
    purchasedProductIds: new Set(),
    savedProductIds: new Set(),
    viewedProductIds: new Set(),
    dismissedProductIds: new Set(),
    recentQueries: [],
    maturity: 'new',
  };
}

/**
 * How strongly personalization is allowed to speak.
 *
 * A new account has three page views and no opinion worth acting on; ranking
 * it as if it did produces a feed that locks onto the first thing she happened
 * to tap. The multiplier grows with evidence.
 */
export function personalizationWeight(profile: StyleProfile): number {
  switch (profile.maturity) {
    case 'loyal':
      return 1;
    case 'engaged':
      return 0.75;
    case 'browsing':
      return 0.45;
    case 'new':
      return 0.15;
  }
}

export function affinityOf(map: Map<string, number>, key: string | null | undefined): number {
  if (!key) return 0;
  return map.get(key) ?? 0;
}

/** Normalises a weight map to 0–1 so scores stay comparable between users. */
export function normaliseAffinity(map: Map<string, number>): Map<string, number> {
  let max = 0;
  for (const value of map.values()) max = Math.max(max, value);
  if (max <= 0) return map;
  const scaled = new Map<string, number>();
  for (const [key, value] of map) scaled.set(key, value / max);
  return scaled;
}
