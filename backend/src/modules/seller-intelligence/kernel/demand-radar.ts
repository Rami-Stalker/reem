/**
 * Demand Radar.
 *
 * The arithmetic behind "what is rising, what is nobody serving, and where
 * should you put your money next".
 *
 * ── What this kernel is not ──────────────────────────────────────────────
 *
 * It is not a second trend engine. `CategoryTrendScore`, `ProductTrendScore`
 * and `UnmetDemandSignal` already say what the market is doing, and building
 * a parallel pipeline would mean two sets of numbers disagreeing in front of
 * a seller. What this file adds is the step the trend engine deliberately
 * does not take: turning a platform-wide fact into *her* opportunity, which
 * needs to know what she already sells, what she has in stock, and what she
 * would have to do to act on it.
 *
 * So a rising category is only interesting here if she is in it or next to
 * it; unmet demand is only interesting if it is demand she could plausibly
 * serve; and a stock warning is only worth an alert if the thing running out
 * is also the thing being asked for.
 */

import {
  RISING_GROWTH,
  STOCK_COVER_DAYS,
  UNMET_MIN_MISS_RATE,
  UNMET_MIN_SEARCHES,
} from '../intelligence.constants';

const round = (n: number, dp = 2): number => {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
};
const clamp01 = (n: number): number => Math.min(1, Math.max(0, n));

// ── Rising categories ────────────────────────────────────────────────────

export interface CategoryDemand {
  categoryId: string;
  name: string;
  /** Demand in the recent half of the window, and in the half before it. */
  recent: number;
  previous: number;
  /** The market's own trend score for the category, when it has one. */
  trendScore: number | null;
  /** Does she already sell here? */
  sellerListings: number;
  sellerUnits: number;
}

export interface RisingCategory {
  categoryId: string;
  name: string;
  /** As a ratio: 0.25 is +25%. */
  growth: number;
  recent: number;
  trendScore: number | null;
  /** Whether this is growth in her own aisle or in one next door. */
  presence: 'selling' | 'absent';
  /** 0-100. What it is worth to *her*, which is not the same as how fast it grows. */
  relevance: number;
}

/**
 * Growth, with a floor under the denominator.
 *
 * A category that went from one search to four did not grow 300% in any sense
 * a seller should act on, so small bases are damped rather than excluded —
 * excluded would hide genuinely new demand, which is the most valuable kind.
 */
export function growthOf(recent: number, previous: number): number {
  const base = Math.max(previous, 3);
  return round((recent - previous) / base, 3);
}

export function risingCategories(
  rows: readonly CategoryDemand[],
  limit = 6,
): RisingCategory[] {
  return rows
    .map((row) => {
      const growth = growthOf(row.recent, row.previous);
      // Relevance blends how fast it is moving with how much of it she can
      // actually catch. Somewhere she already sells is worth more than a
      // faster category she would have to enter from nothing.
      const momentum = clamp01(growth / (RISING_GROWTH * 4)) * 60;
      const market = ((row.trendScore ?? 0) / 100) * 20;
      const foothold = row.sellerListings > 0 ? 20 : 8;
      return {
        categoryId: row.categoryId,
        name: row.name,
        growth,
        recent: row.recent,
        trendScore: row.trendScore,
        presence: (row.sellerListings > 0 ? 'selling' : 'absent') as
          | 'selling'
          | 'absent',
        relevance: round(momentum + market + foothold),
      };
    })
    .filter((row) => row.growth >= RISING_GROWTH && row.recent > 0)
    .sort((a, b) => b.relevance - a.relevance)
    .slice(0, limit);
}

// ── Unmet demand ─────────────────────────────────────────────────────────

export interface UnmetTerm {
  termKey: string;
  display: string;
  searches: number;
  zeroResults: number;
  missRate: number;
  growth: number;
  demandScore: number;
  suggestedCategoryId: string | null;
  suggestionAr: string | null;
}

export interface SellerUnmet extends UnmetTerm {
  /** Whether the suggested category is one she already works in. */
  inHerCategories: boolean;
  /** 0-100, ordered for her rather than for the platform. */
  opportunity: number;
}

/**
 * The searches that came back empty, filtered to the ones she could serve.
 *
 * Two gates before anything is shown. The volume gate stops a single curious
 * search becoming a business recommendation. The miss-rate gate is the one
 * that matters: a term with plenty of searches that mostly *do* find
 * something is not unmet demand, it is just a popular search, and telling a
 * seller to stock for it would be advice built on a misreading.
 */
export function sellerUnmetDemand(
  terms: readonly UnmetTerm[],
  herCategoryIds: ReadonlySet<string>,
  limit = 6,
): SellerUnmet[] {
  return terms
    .filter(
      (t) =>
        t.searches >= UNMET_MIN_SEARCHES && t.missRate >= UNMET_MIN_MISS_RATE,
    )
    .map((t) => {
      const inHers = !!t.suggestedCategoryId &&
        herCategoryIds.has(t.suggestedCategoryId);
      const volume = clamp01(t.searches / 60) * 45;
      const miss = t.missRate * 25;
      const growing = clamp01(t.growth / 0.5) * 15;
      // Weighted towards her own aisles, but never to zero: the whole point of
      // showing unmet demand to a seller is that some of it is a reason to
      // stock something new.
      const fit = inHers ? 15 : 5;
      return {
        ...t,
        inHerCategories: inHers,
        opportunity: round(volume + miss + growing + fit),
      };
    })
    .sort((a, b) => b.opportunity - a.opportunity)
    .slice(0, limit);
}

// ── Stock under demand ───────────────────────────────────────────────────

export interface StockWatchInput {
  productId: string;
  title: string;
  stockUnits: number;
  /** Units sold per day over the window. */
  dailyUnits: number;
  /** Demand still arriving: views in the recent half vs the previous half. */
  recentViews: number;
  previousViews: number;
  inStock: boolean;
}

export interface StockAlert {
  productId: string;
  title: string;
  stockUnits: number;
  /** Days of cover left at the current rate, or null when nothing is selling. */
  coverDays: number | null;
  demandGrowth: number;
  severity: 'critical' | 'warning';
  ar: string;
}

/**
 * Running out of the thing people are currently asking for.
 *
 * The pairing is the point. Low stock on a product nobody is looking at is
 * not urgent, and high demand on a product with plenty of stock is good news
 * rather than an alert. Only the intersection is worth interrupting her for,
 * which is why this returns so little: an alert list that is always long is
 * one she stops reading.
 */
export function stockAlerts(
  rows: readonly StockWatchInput[],
  limit = 6,
): StockAlert[] {
  const out: StockAlert[] = [];

  for (const row of rows) {
    const growth = growthOf(row.recentViews, row.previousViews);
    const coverDays =
      row.dailyUnits > 0 ? round(row.stockUnits / row.dailyUnits, 1) : null;

    // Sold out while people are still arriving: the most expensive state a
    // listing can be in, because it is spending demand it cannot serve.
    if (!row.inStock || row.stockUnits <= 0) {
      if (row.recentViews > 0) {
        out.push({
          productId: row.productId,
          title: row.title,
          stockUnits: 0,
          coverDays: 0,
          demandGrowth: growth,
          severity: 'critical',
          ar: `«${row.title}» نفدت وما زالت تصلها ${row.recentViews} مشاهدة. كل يوم بلا كمية بيع ضائع.`,
        });
      }
      continue;
    }

    if (coverDays !== null && coverDays <= STOCK_COVER_DAYS) {
      const rising = growth >= RISING_GROWTH;
      out.push({
        productId: row.productId,
        title: row.title,
        stockUnits: row.stockUnits,
        coverDays,
        demandGrowth: growth,
        severity: coverDays <= 3 && rising ? 'critical' : 'warning',
        ar: rising
          ? `«${row.title}» بقي منها ${row.stockUnits} قطعة (تكفي ${coverDays} يوم) والطلب عليها يرتفع. جهّزي كمية.`
          : `«${row.title}» بقي منها ${row.stockUnits} قطعة، تكفي نحو ${coverDays} يوم.`,
      });
    }
  }

  return out
    .sort(
      (a, b) =>
        (a.severity === 'critical' ? 0 : 1) - (b.severity === 'critical' ? 0 : 1) ||
        (a.coverDays ?? 99) - (b.coverDays ?? 99),
    )
    .slice(0, limit);
}

// ── Price movement ───────────────────────────────────────────────────────

export interface PriceTrendInput {
  categoryId: string;
  name: string;
  /** Median live price in SYP, recent half of the window and the half before. */
  recentMedian: number | null;
  previousMedian: number | null;
  /** Her own median price in the same category, when she sells there. */
  sellerMedian: number | null;
}

export interface PriceTrend {
  categoryId: string;
  name: string;
  recentMedian: number;
  changeBps: number;
  /** Her position against the market median, in basis points. */
  sellerPremiumBps: number | null;
  ar: string;
}

/**
 * Where prices in her categories are going, and where she sits in that.
 *
 * Medians rather than means throughout: one luxury listing in a category of
 * everyday pieces would drag a mean somewhere no seller should follow.
 */
export function priceTrends(
  rows: readonly PriceTrendInput[],
  limit = 6,
): PriceTrend[] {
  return rows
    .filter(
      (r): r is PriceTrendInput & { recentMedian: number; previousMedian: number } =>
        r.recentMedian !== null && r.previousMedian !== null && r.previousMedian > 0,
    )
    .map((r) => {
      const changeBps = Math.round(
        ((r.recentMedian - r.previousMedian) / r.previousMedian) * 10_000,
      );
      const sellerPremiumBps =
        r.sellerMedian !== null && r.recentMedian > 0
          ? Math.round(
              ((r.sellerMedian - r.recentMedian) / r.recentMedian) * 10_000,
            )
          : null;

      const direction =
        changeBps > 300 ? 'ترتفع' : changeBps < -300 ? 'تنخفض' : 'ثابتة';
      const positioning =
        sellerPremiumBps === null
          ? ''
          : sellerPremiumBps > 1000
            ? ` وأسعارك أعلى بـ${Math.round(sellerPremiumBps / 100)}%.`
            : sellerPremiumBps < -1000
              ? ` وأسعارك أقل بـ${Math.abs(Math.round(sellerPremiumBps / 100))}%.`
              : ' وأسعارك قريبة من السوق.';

      return {
        categoryId: r.categoryId,
        name: r.name,
        recentMedian: r.recentMedian,
        changeBps,
        sellerPremiumBps,
        ar: `أسعار «${r.name}» ${direction}${positioning}`,
      };
    })
    .sort((a, b) => Math.abs(b.changeBps) - Math.abs(a.changeBps))
    .slice(0, limit);
}

// ── Opportunities ────────────────────────────────────────────────────────

export interface Opportunity {
  code: 'UNMET_IN_CATEGORY' | 'RISING_CATEGORY' | 'RESTOCK_DEMAND' | 'ENTER_CATEGORY';
  /** 0-100, comparable across the kinds so one list can be ordered. */
  score: number;
  ar: string;
  categoryId?: string;
  productId?: string;
  termKey?: string;
}

/**
 * The one list the radar screen leads with.
 *
 * Everything above produces its own kind of finding; this reduces them to a
 * single ordered list of things to *do*, because a seller with four separate
 * ranked lists still has to decide which list to read first, and that is the
 * decision the system should be making for her.
 */
export function opportunities(input: {
  rising: readonly RisingCategory[];
  unmet: readonly SellerUnmet[];
  stock: readonly StockAlert[];
}): Opportunity[] {
  const out: Opportunity[] = [];

  for (const alert of input.stock) {
    // Restocking is first among equals: it is the only opportunity where the
    // demand is already proven and already hers.
    out.push({
      code: 'RESTOCK_DEMAND',
      score: alert.severity === 'critical' ? 95 : 78,
      ar: alert.ar,
      productId: alert.productId,
    });
  }

  for (const term of input.unmet) {
    out.push({
      code: 'UNMET_IN_CATEGORY',
      score: round(term.opportunity * (term.inHerCategories ? 0.92 : 0.7)),
      ar: term.inHerCategories
        ? `${term.searches} امرأة بحثت عن «${term.display}» ولم تجد — وهي في فئة تبيعين فيها.`
        : `${term.searches} امرأة بحثت عن «${term.display}» ولم تجد ما يناسبها.`,
      termKey: term.termKey,
      categoryId: term.suggestedCategoryId ?? undefined,
    });
  }

  for (const cat of input.rising) {
    out.push({
      code: cat.presence === 'selling' ? 'RISING_CATEGORY' : 'ENTER_CATEGORY',
      score: round(cat.relevance * (cat.presence === 'selling' ? 0.85 : 0.6)),
      ar:
        cat.presence === 'selling'
          ? `الطلب على «${cat.name}» يرتفع ${Math.round(cat.growth * 100)}% وأنتِ تبيعين فيها — وقت مناسب لزيادة المعروض.`
          : `«${cat.name}» ترتفع ${Math.round(cat.growth * 100)}% ولا شيء لديكِ فيها.`,
      categoryId: cat.categoryId,
    });
  }

  return out.sort((a, b) => b.score - a.score);
}
