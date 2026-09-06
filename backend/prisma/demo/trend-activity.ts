import { AnalyticsEventType, Prisma, PrismaClient } from '@prisma/client';
import { DemoContext } from './context';
import { SEARCH_QUERIES } from './data';

/**
 * The browsing the Trend Engine reads.
 *
 * Every other demo pass seeds an *outcome* — an order, a review, a payout. The
 * engine's whole point is to see demand **before** it becomes an outcome, and
 * none of the existing passes produce a single page view, search or add to
 * cart. Without this the two trend dashboards are correct and empty, which
 * looks identical to broken.
 *
 * Three shapes are planted deliberately, because a demo of a trend engine that
 * shows only flat lines demonstrates nothing:
 *
 *  - **Climbers.** A handful of products whose views, searches and cart adds
 *    ramp steeply through the final fortnight while their sales stay small.
 *    These are what `EMERGING` exists to catch, and they are the screenshot the
 *    feature is for.
 *  - **Fallers.** Products that were busy a month ago and are not now.
 *  - **A leaky funnel.** Products with heavy traffic and almost no cart adds,
 *    so the low-conversion rules have something to fire on.
 *
 * And a set of searches the catalogue cannot answer — long green evening
 * dresses, wide-fit shoes — so Unmet Demand is populated with the exact case
 * the client described.
 *
 * Deterministic, like every other pass: the same `db:seed` produces the same
 * curves, so a screenshot taken today matches one taken next month.
 */

/** How far back the browsing history runs. Two scoring windows plus a margin. */
const HISTORY_DAYS = 70;

/** Rows per insert. Large enough to be fast, small enough not to hold a lock. */
const BATCH = 4_000;

/** Searches with no answer in the catalogue — the Unmet Demand fixture. */
const UNMET_QUERIES = [
  'فستان سهرة أخضر طويل',
  'حذاء عريض مقاس 41',
  'عباية صيفية قطن',
  'حقيبة ظهر جلد طبيعي',
];

type EventRow = Prisma.AnalyticsEventCreateManyInput;

export async function seedTrendActivity(ctx: DemoContext): Promise<number> {
  const { prisma, rng } = ctx;
  if (!ctx.products.length || !ctx.customers.length) return 0;

  // Clear first: the pass is additive to a table other passes also write, and
  // re-seeding must not stack a second history on top of the first.
  await prisma.analyticsEvent.deleteMany({
    where: { source: { startsWith: 'demo:' } },
  });

  const today = startOfUtcDay(new Date());
  const rows: EventRow[] = [];
  let written = 0;

  const flush = async (force = false): Promise<void> => {
    if (rows.length < BATCH && !force) return;
    while (rows.length) {
      const chunk = rows.splice(0, BATCH);
      await prisma.analyticsEvent.createMany({ data: chunk });
      written += chunk.length;
    }
  };

  // ── Who does the browsing ──────────────────────────────────────────────
  // A pool rather than every account, so distinct-viewer counts land above the
  // k-anonymity floor instead of being suppressed to zero on every product.
  const shoppers = ctx.customers.map((customer) => customer.id);

  // ── Which products get which shape ─────────────────────────────────────
  // A real catalogue has a long tail; only a slice of it sees real traffic.
  const active = rng.sample(ctx.products, Math.min(70, ctx.products.length));
  const climbers = active.slice(0, 6);
  const fallers = active.slice(6, 12);
  const leaky = active.slice(12, 18);
  const steady = active.slice(18);

  const emit = (
    type: AnalyticsEventType,
    productId: string,
    day: Date,
    hour: number,
    userId?: string | null,
    metadata?: Prisma.InputJsonValue,
  ): void => {
    rows.push({
      type,
      productId,
      userId: userId ?? null,
      source: 'demo:trend',
      occurredAt: new Date(day.getTime() + hour * 3_600_000),
      metadata,
      // `occurredAt` is what the collector reads; `createdAt` is the row's own
      // clock and would otherwise all be "now", which reads oddly in the
      // analytics console beside a two-month-old event.
      createdAt: new Date(day.getTime() + hour * 3_600_000),
    });
  };

  /** Writes one product's day: views, some cart adds, a share or two. */
  const browse = (
    productId: string,
    day: Date,
    views: number,
    cartRate: number,
  ): void => {
    for (let i = 0; i < views; i += 1) {
      emit(
        AnalyticsEventType.PRODUCT_VIEW,
        productId,
        day,
        8 + rng.int(0, 13),
        rng.pick(shoppers),
      );
    }
    const carts = Math.round(views * cartRate);
    for (let i = 0; i < carts; i += 1) {
      emit(
        AnalyticsEventType.CART_ADD,
        productId,
        day,
        9 + rng.int(0, 12),
        rng.pick(shoppers),
      );
    }
    if (rng.next() < 0.08) {
      emit(
        AnalyticsEventType.PRODUCT_SHARE,
        productId,
        day,
        12 + rng.int(0, 8),
        rng.pick(shoppers),
      );
    }
  };

  for (let offset = HISTORY_DAYS - 1; offset >= 0; offset -= 1) {
    const day = addDays(today, -offset);
    // Fridays are busy; the forecaster's weekday index has something to find.
    const weekday = day.getUTCDay() === 5 ? 1.6 : 1;
    // How far through the history we are, 0 → 1.
    const progress = 1 - offset / HISTORY_DAYS;

    for (const product of climbers) {
      // Flat for most of the history, then a steep ramp over the last
      // fortnight. This is the shape `EMERGING` is defined by.
      const ramp = offset > 14 ? 1 : 1 + (14 - offset) * 0.55;
      const views = Math.round((3 + rng.int(0, 3)) * ramp * weekday);
      browse(product.id, day, views, 0.1);
    }

    for (const product of fallers) {
      const decay = Math.max(0.15, 1.4 - progress * 1.6);
      const views = Math.round((14 + rng.int(0, 6)) * decay * weekday);
      browse(product.id, day, views, 0.07);
    }

    for (const product of leaky) {
      // Plenty of looking, almost no touching — the low-conversion case.
      const views = Math.round((18 + rng.int(0, 10)) * weekday);
      browse(product.id, day, views, 0.012);
    }

    for (const product of steady) {
      if (rng.next() > 0.55) continue;
      const views = Math.round((2 + rng.int(0, 5)) * weekday);
      browse(product.id, day, views, 0.06);
    }

    // ── Searches ─────────────────────────────────────────────────────────
    // Answered ones name the products they surfaced, which is what gives a
    // product its search exposure.
    const searchesToday = 6 + rng.int(0, 8);
    for (let i = 0; i < searchesToday; i += 1) {
      const surfaced = rng.sample(active, rng.int(2, 6)).map((p) => p.id);
      rows.push({
        type: AnalyticsEventType.PRODUCT_SEARCH,
        userId: rng.next() < 0.7 ? rng.pick(shoppers) : null,
        source: 'demo:search',
        occurredAt: new Date(day.getTime() + (9 + rng.int(0, 11)) * 3_600_000),
        createdAt: new Date(day.getTime() + (9 + rng.int(0, 11)) * 3_600_000),
        metadata: {
          q: rng.pick(SEARCH_QUERIES),
          results: surfaced.length,
          product_ids: surfaced,
        } satisfies Prisma.InputJsonValue,
      });
    }

    // The ones the catalogue cannot answer, weighted toward recency so the
    // gap reads as a live problem rather than a historical one.
    const unmetToday = offset < 30 ? 2 + rng.int(0, 3) : rng.int(0, 1);
    for (let i = 0; i < unmetToday; i += 1) {
      rows.push({
        type: AnalyticsEventType.SEARCH_ZERO_RESULT,
        userId: rng.next() < 0.7 ? rng.pick(shoppers) : null,
        source: 'demo:search',
        occurredAt: new Date(day.getTime() + (10 + rng.int(0, 10)) * 3_600_000),
        createdAt: new Date(day.getTime() + (10 + rng.int(0, 10)) * 3_600_000),
        metadata: {
          q: rng.pick(UNMET_QUERIES),
          results: 0,
          product_ids: [],
        } satisfies Prisma.InputJsonValue,
      });
    }

    await flush();
  }

  await flush(true);
  return written;
}

// ── Date helpers. UTC, to match the collector's day boundaries. ──────────

function startOfUtcDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}

function addDays(date: Date, days: number): Date {
  const next = new Date(date.getTime());
  next.setUTCDate(next.getUTCDate() + days);
  return next;
}

/** Standalone entry point, so the browsing can be regenerated on its own. */
export async function runTrendActivity(prisma: PrismaClient): Promise<number> {
  const { Rng } = await import('./rng');
  const [products, customers] = await Promise.all([
    prisma.product.findMany({
      where: { status: 'ACTIVE' },
      select: { id: true, slug: true, title: true },
    }),
    prisma.user.findMany({
      where: { role: 'CUSTOMER', disabledAt: null },
      select: { id: true },
    }),
  ]);

  const ctx = {
    prisma,
    rng: new Rng('reem-demo-2026'),
    products: products.map((product) => ({
      ...product,
      leaf: '',
      imageUrl: '',
      offers: [],
    })),
    customers: customers.map((customer) => ({ id: customer.id })),
  } as unknown as DemoContext;

  return seedTrendActivity(ctx);
}
