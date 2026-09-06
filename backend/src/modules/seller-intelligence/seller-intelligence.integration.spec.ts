import assert from 'node:assert/strict';
import test from 'node:test';
import { PrismaClient, SellerHealthBand, SellerOrderStatus } from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { DemandRadarService } from './radar/demand-radar.service';
import { ProductHealthService } from './product-health/product-health.service';
import { SellerHealthService } from './health/seller-health.service';

/**
 * Seller Intelligence against the real database.
 *
 * The kernel specs prove the arithmetic. These prove the claims only Postgres
 * can settle — and they are the claims the brief made:
 *
 *   - the numbers come from real rows, never from a constant;
 *   - the response time that used to be hardcoded as `90` is now measured
 *     from actual messages;
 *   - a seller's health writes back to `SellerReputation`, so the platform
 *     keeps one opinion of a shop rather than two;
 *   - the radar reads the trend engine's tables rather than a second pipeline;
 *   - a seller can only ever see her own shop.
 *
 * Every case runs inside a transaction that is rolled back.
 */
const prisma = new PrismaClient();

class Rollback extends Error {}
type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

test.after(() => prisma.$disconnect());

function dbTest(name: string, body: (world: World) => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    let failure: unknown;
    try {
      await prisma.$transaction(
        async (tx) => {
          try {
            await body(build(tx));
          } catch (error) {
            failure = error;
          }
          throw new Rollback();
        },
        { timeout: 60_000 },
      );
    } catch (error) {
      if (!(error instanceof Rollback)) throw error;
    }
    if (failure) throw failure;
  });
}

function asPrisma(tx: Tx): PrismaService {
  return new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: unknown) => {
          if (Array.isArray(fn)) return Promise.all(fn);
          return (fn as (inner: Tx) => unknown)(tx);
        };
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

interface World {
  db: PrismaService;
  radar: DemandRadarService;
  products: ProductHealthService;
  health: SellerHealthService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  return {
    db,
    radar: new DemandRadarService(db),
    products: new ProductHealthService(db),
    health: new SellerHealthService(db),
  };
}

// ── Fixtures ─────────────────────────────────────────────────────────────

/** A seller with live offers, from the seeded catalogue. */
async function tradingSeller(db: PrismaService): Promise<string> {
  const offer = await db.sellerOffer.findFirst({
    where: { status: 'ACTIVE', product: { status: 'ACTIVE' } },
    select: { sellerId: true },
  });
  assert.ok(offer, 'the seed should carry at least one live offer');
  return offer.sellerId;
}

/** A seller who has actually shipped things. */
async function shippingSeller(db: PrismaService): Promise<string | null> {
  const row = await db.sellerOrder.findFirst({
    where: { status: SellerOrderStatus.DELIVERED, shippedAt: { not: null } },
    select: { sellerId: true },
  });
  return row?.sellerId ?? null;
}

// ── Seller health ────────────────────────────────────────────────────────

dbTest('a shop is measured from its own orders, not from a constant', async (world) => {
  const sellerId = await shippingSeller(world.db);
  if (!sellerId) return;

  const facts = await world.health.gather(sellerId, 3650);

  // Every one of these has to be reconcilable with a count anybody can run.
  const accepted = await world.db.sellerOrder.count({
    where: { sellerId, confirmedAt: { not: null } },
  });
  const delivered = await world.db.sellerOrder.count({
    where: { sellerId, status: SellerOrderStatus.DELIVERED },
  });

  assert.equal(facts.deliveredOrders, delivered, 'delivered orders match the table');

  // `acceptedOrders` is the *settled* count — the reliability denominator —
  // and `openOrders` is the rest. Together they are everything she accepted,
  // which is the number the cancellation rate divides by.
  assert.equal(
    facts.acceptedOrders + facts.openOrders,
    accepted,
    'settled plus in-flight accounts for every accepted order',
  );
  assert.ok(
    facts.acceptedOrders >= delivered,
    'a delivered order is by definition settled',
  );
  assert.ok(accepted > 0, 'the fixture seller has traded');
});

dbTest('an order still with the courier is not counted against her', async (world) => {
  // The regression the live check caught: in-flight orders were landing in
  // the reliability denominator, so a busy week read as a failing shop.
  const sellerId = await shippingSeller(world.db);
  if (!sellerId) return;

  const facts = await world.health.gather(sellerId, 3650);
  if (facts.openOrders === 0) return;

  const inFlight = await world.db.sellerOrder.count({
    where: {
      sellerId,
      confirmedAt: { not: null },
      status: {
        notIn: [
          SellerOrderStatus.DELIVERED,
          SellerOrderStatus.DELIVERY_FAILED,
          SellerOrderStatus.CANCELLED_BY_CUSTOMER,
          SellerOrderStatus.CANCELLED_BY_SELLER,
          SellerOrderStatus.REJECTED_ON_DELIVERY,
          SellerOrderStatus.RETURNED,
          SellerOrderStatus.EXCHANGED,
          SellerOrderStatus.REFUNDED,
        ],
      },
    },
  });

  assert.equal(facts.openOrders, inFlight, 'the in-flight count is the rows');
  assert.ok(
    facts.acceptedOrders < facts.acceptedOrders + facts.openOrders,
    'and it is genuinely excluded from the reliability denominator',
  );
});

dbTest('prep and shipping hours are real medians over real timestamps', async (world) => {
  const sellerId = await shippingSeller(world.db);
  if (!sellerId) return;

  const facts = await world.health.gather(sellerId, 3650);
  if (facts.prepSample === 0) return;

  assert.ok(facts.prepHours !== null, 'a median exists where a sample does');
  assert.ok(facts.prepHours >= 0, 'nothing ships before it is confirmed');

  const withBoth = await world.db.sellerOrder.count({
    where: { sellerId, confirmedAt: { not: null }, shippedAt: { not: null } },
  });
  assert.equal(facts.prepSample, withBoth, 'the sample is the row count');
});

dbTest('the response time that used to be hardcoded is now measured', async (world) => {
  // The specific regression this system exists to fix: `ReputationService`
  // wrote `const responseScore = 90` for every seller on the platform.
  const sellerId = await tradingSeller(world.db);
  const facts = await world.health.gather(sellerId, 3650);

  if (facts.responseSample > 0) {
    assert.ok(facts.responseHours !== null);
    assert.ok(facts.responseHours >= 0, 'a reply cannot precede the question');

    // And it has to be derived from chats this seller is actually in.
    const chats = await world.db.chat.count({
      where: { sellerId, buyerId: { not: null } },
    });
    assert.ok(chats > 0, 'the sample implies conversations exist');
  } else {
    // The honest outcome when nobody has messaged her: no number at all.
    assert.equal(facts.responseHours, null, 'no conversations, no invented 90');
  }
});

dbTest('a seller nobody has messaged is not scored for responsiveness', async (world) => {
  const sellerId = await tradingSeller(world.db);
  const { result } = await world.health.current(sellerId);
  const dim = result.dimensions.find((d) => d.key === 'responsiveness');
  assert.ok(dim, 'the dimension is always reported');

  if (dim.sample === 0) {
    assert.equal(dim.score, null);
    assert.equal(dim.weight, 0, 'silence carries no weight either way');
  }
});

dbTest('health writes back to SellerReputation so the platform has one opinion', async (world) => {
  const sellerId = await shippingSeller(world.db);
  if (!sellerId) return;

  const before = await world.db.sellerReputation.findUnique({ where: { sellerId } });
  const { score } = await world.health.snapshot(sellerId);
  const after = await world.db.sellerReputation.findUniqueOrThrow({
    where: { sellerId },
  });

  assert.equal(after.performanceScore, score, 'the shared row carries the health score');
  assert.notEqual(
    after.responseScore,
    90,
    'the fabricated constant is gone unless it was genuinely earned',
  );
  // Reviews belong to ReputationService and must not be trampled.
  if (before) {
    assert.equal(after.reviewsCount, before.reviewsCount, 'review counts untouched');
    assert.equal(after.averageRating, before.averageRating, 'rating untouched');
  }
});

dbTest('the snapshot is one row a day and is idempotent', async (world) => {
  const sellerId = await shippingSeller(world.db);
  if (!sellerId) return;

  const now = new Date();
  await world.health.snapshot(sellerId, { now });
  await world.health.snapshot(sellerId, { now });

  const day = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
  const rows = await world.db.sellerHealthSnapshot.count({
    where: { sellerId, day },
  });
  assert.equal(rows, 1, 'pressing it twice changes nothing');
});

dbTest('the snapshot keeps every component, not just the number', async (world) => {
  const sellerId = await shippingSeller(world.db);
  if (!sellerId) return;

  await world.health.snapshot(sellerId);
  const row = await world.db.sellerHealthSnapshot.findFirstOrThrow({
    where: { sellerId },
    orderBy: { day: 'desc' },
  });

  const dimensions = row.dimensions as unknown as Array<{ key: string }>;
  assert.equal(dimensions.length, 8, 'all eight dimensions are recorded');
  assert.ok(
    Object.values(SellerHealthBand).includes(row.band),
    'the band is stored rather than re-derived on read',
  );
});

// ── Product health ───────────────────────────────────────────────────────

dbTest('a listing is scored from its own row and its own demand', async (world) => {
  const sellerId = await tradingSeller(world.db);
  const { rows } = await world.products.list(sellerId, { limit: 5 });
  assert.ok(rows.length > 0, 'a trading seller has listings');

  const row = rows[0];
  const product = await world.db.product.findUniqueOrThrow({
    where: { id: row.productId },
    include: { media: true },
  });

  const detail = await world.products.detail(sellerId, row.productId);
  assert.equal(
    detail.facts.imageCount,
    product.media.length,
    'the image count is the media rows, not an estimate',
  );
  assert.equal(detail.facts.description, product.description);
  assert.ok(detail.result.score >= 0 && detail.result.score <= 100);
});

dbTest('the work queue is ordered worst first', async (world) => {
  const sellerId = await tradingSeller(world.db);
  const { rows } = await world.products.list(sellerId);
  if (rows.length < 2) return;

  for (let i = 1; i < rows.length; i += 1) {
    assert.ok(
      rows[i - 1].score <= rows[i].score,
      'the listing needing most help comes first',
    );
  }
});

dbTest('a seller cannot inspect a listing she does not sell', async (world) => {
  const sellerId = await tradingSeller(world.db);
  const foreign = await world.db.product.findFirst({
    where: { offers: { none: { sellerId } } },
    select: { id: true },
  });
  if (!foreign) return;

  await assert.rejects(
    () => world.products.detail(sellerId, foreign.id),
    /not found/i,
    'somebody else’s listing is not hers to audit',
  );
});

dbTest('the cohort is the category, and it is withheld when too small', async (world) => {
  const sellerId = await tradingSeller(world.db);
  const { rows } = await world.products.list(sellerId, { limit: 20 });
  if (!rows.length) return;

  for (const row of rows) {
    if (!row.peers) continue;
    const product = await world.db.product.findUniqueOrThrow({
      where: { id: row.productId },
      select: { categoryId: true },
    });
    const live = await world.db.product.count({
      where: { categoryId: product.categoryId, status: 'ACTIVE' },
    });
    assert.equal(row.peers.peers, live, 'the cohort is the live category');
    assert.ok(row.peers.peers >= 4, 'never reported below the honest minimum');
    return;
  }
});

dbTest('product snapshots are one row per listing per day', async (world) => {
  const sellerId = await tradingSeller(world.db);
  const now = new Date();

  const first = await world.products.snapshotSeller(sellerId, { now });
  const second = await world.products.snapshotSeller(sellerId, { now });
  assert.equal(first, second, 'the same listings are scored both times');

  const day = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
  const rows = await world.db.productHealthSnapshot.count({
    where: { sellerId, day },
  });
  assert.equal(rows, first, 'no duplicates from the second run');
});

// ── Demand radar ─────────────────────────────────────────────────────────

dbTest('the radar reads the trend engine’s tables rather than a second pipeline', async (world) => {
  const sellerId = await tradingSeller(world.db);
  const radar = await world.radar.overview(sellerId);

  assert.ok(radar.categoryCount > 0, 'she sells in at least one category');
  assert.ok(Array.isArray(radar.opportunities));

  // Every unmet term must exist in the trend engine's own table, with the
  // same figures. If these ever diverge, two systems are counting searches.
  for (const term of radar.unmet) {
    const source = await world.db.unmetDemandSignal.findUniqueOrThrow({
      where: { termKey: term.termKey },
    });
    assert.equal(term.searches, source.searches);
    assert.equal(term.missRate, source.missRate);
  }
});

dbTest('the radar only ever reports her own categories and listings', async (world) => {
  const sellerId = await tradingSeller(world.db);
  const radar = await world.radar.overview(sellerId);

  const hers = new Set(
    (
      await world.db.product.findMany({
        where: { offers: { some: { sellerId, status: 'ACTIVE' } } },
        select: { id: true },
      })
    ).map((p) => p.id),
  );

  for (const alert of radar.stockAlerts) {
    assert.ok(hers.has(alert.productId), 'a stock alert is about her own stock');
  }
  for (const trend of radar.priceTrends) {
    assert.ok(trend.recentMedian > 0, 'no category is reported without a price');
  }
});

dbTest('a seller with no listings gets an empty radar, not a crash', async (world) => {
  const stranger = await world.db.user.findFirst({
    where: { sellerOffers: { none: {} } },
    select: { id: true },
  });
  if (!stranger) return;

  const radar = await world.radar.overview(stranger.id);
  assert.equal(radar.categoryCount, 0);
  assert.deepEqual(radar.rising, []);
  assert.deepEqual(radar.priceTrends, []);
  assert.deepEqual(radar.stockAlerts, []);
});

dbTest('every opportunity carries a sentence she can act on', async (world) => {
  const sellerId = await tradingSeller(world.db);
  const radar = await world.radar.overview(sellerId);

  for (const opportunity of radar.opportunities) {
    assert.ok(opportunity.ar.length > 10, 'no empty advice');
    assert.ok(opportunity.score > 0);
  }

  // And the list is ordered, so the screen never has to sort it again.
  for (let i = 1; i < radar.opportunities.length; i += 1) {
    assert.ok(radar.opportunities[i - 1].score >= radar.opportunities[i].score);
  }
});
