import { Prisma, PrismaClient } from '@prisma/client';
import { Rng } from './rng';

export interface DemoSeller {
  id: string;
  name: string;
  store: string;
  /** Leaf category slugs this boutique actually stocks. */
  categories: string[];
  governorate: string;
  city: string;
  level: 'BASIC' | 'VERIFIED' | 'PREMIUM';
}

export interface DemoCustomer {
  id: string;
  name: string;
  phone: string;
  governorate: string;
  city: string;
  district: string;
  address: string;
  tier: string;
}

export interface DemoProduct {
  id: string;
  slug: string;
  title: string;
  leaf: string;
  imageUrl: string;
  /** Every live offer on this product, cheapest first. */
  offers: DemoOffer[];
}

export interface DemoOffer {
  id: string;
  sellerId: string;
  sellerName: string;
  price: number;
  currency: 'SYP' | 'USD';
  /** Price normalised to SYP — what the order lines are charged in. */
  priceSyp: number;
  stock: number;
  /** True when the offer satisfies `LIVE_OFFER_WHERE` — buyable right now. */
  live: boolean;
  /** Buyable variants only — a sold-out size is not listed here. */
  variants: { id: string; name: string; stock: number }[];
}

/** Everything the demo modules share; assembled by `bootstrap()` in index.ts. */
export interface DemoContext {
  prisma: PrismaClient;
  rng: Rng;
  adminId: string;
  sellers: DemoSeller[];
  customers: DemoCustomer[];
  /** Leaf category slug → id, level 2 of the three-level tree. */
  leafBySlug: Map<string, string>;
  brandIds: string[];
  /** SYP per USD, frozen for the whole demo dataset. */
  fxRate: Prisma.Decimal;
  fxRateId: string | null;
  products: DemoProduct[];
}

/// New Syrian pounds per US dollar. 13,000 old lira is 130 new.
export const SYP_PER_USD = 130;
