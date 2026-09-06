import assert from 'node:assert/strict';
import test from 'node:test';
import {
  AffinityKind,
  ClosetItemSource,
  ClosetItemStatus,
  DropAudience,
  DropStatus,
  MarketSubject,
  OfferStatus,
  OutfitSlot,
  Prisma,
  PrismaClient,
  ProductStatus,
  ResaleCondition,
  ResaleStatus,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { GraphQueryService } from '../graph/graph-query.service';
import { BundlesService } from './bundles/bundles.service';
import { DropsService } from './drops/drops.service';
import { MarketEconomicsService } from './economics/market-economics.service';
import { MarketIntelligenceService } from './intelligence/market-intelligence.service';
import { MissionsService } from './missions/missions.service';
import { LifecycleService } from './resale/lifecycle.service';

/**
 * Reem Market Evolution against the real database.
 *
 * The kernels prove the arithmetic — 46 cases across economics, drop
 * targeting, life cycle and missions. These prove the claims only Postgres can
 * settle, and each is a claim this phase makes out loud:
 *
 *   - a market reading is derived from rows that already existed, and a second
 *     sweep on the same day updates rather than duplicating;
 *   - a bundle crosses sellers, fills one slot per piece, and every piece
 *     carries a reason;
 *   - a drop reaches only women the graph has a reason to invite, and an
 *     invite-only drop is invisible to everybody else;
 *   - a resale listing archives the piece and never enters product search;
 *   - a mission is withheld when she cannot finish it, and its progress cannot
 *     be moved by anything but the underlying rows.
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
        { timeout: 180_000 },
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
  economics: MarketEconomicsService;
  intelligence: MarketIntelligenceService;
  drops: DropsService;
  bundles: BundlesService;
  lifecycle: LifecycleService;
  missions: MissionsService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const economics = new MarketEconomicsService(db);
  const graph = new GraphQueryService(db);
  return {
    db,
    economics,
    intelligence: new MarketIntelligenceService(db, economics),
    drops: new DropsService(db, economics),
    bundles: new BundlesService(db),
    lifecycle: new LifecycleService(db, graph),
    missions: new MissionsService(db),
  };
}

/** A shopper who has actually done things. */
async function activeShopper(db: PrismaService): Promise<string | null> {
  const row = await db.order.findFirst({
    orderBy: { createdAt: 'desc' },
    select: { userId: true },
  });
  return row?.userId ?? null;
}

/** A live, buyable product with a seller behind it. */
async function buyable(db: PrismaService) {
  return db.product.findFirst({
    where: {
      status: ProductStatus.ACTIVE,
      offers: { some: { status: OfferStatus.ACTIVE, stock: { gt: 0 } } },
    },
    include: {
      offers: {
        where: { status: OfferStatus.ACTIVE, stock: { gt: 0 } },
        take: 1,
        select: { id: true, sellerId: true },
      },
    },
  });
}

// ── Economics ────────────────────────────────────────────────────────────

dbTest('a market reading is derived, and re-running it does not duplicate', async (world) => {
  const first = await world.economics.sweep();
  assert.ok(first.categories > 0, 'the platform has categories to read');

  const day = new Date();
  day.setUTCHours(0, 0, 0, 0);
  const after = await world.db.marketSignal.count({ where: { day } });

  await world.economics.sweep();
  const again = await world.db.marketSignal.count({ where: { day } });

  assert.equal(again, after, 'a second sweep on the same day must update in place');
});

dbTest('every reading is anchored to a subject that exists', async (world) => {
  await world.economics.sweep();

  const signals = await world.db.marketSignal.findMany({
    where: { subjectType: MarketSubject.CATEGORY },
    take: 50,
  });
  assert.ok(signals.length > 0);

  for (const signal of signals) {
    const category = await world.db.category.count({
      where: { id: signal.subjectId },
    });
    assert.equal(category, 1, `signal for a category that does not exist`);
    assert.ok(signal.confidence >= 0 && signal.confidence <= 1);
    assert.ok(signal.demandScore >= 0 && signal.demandScore <= 100);
  }
});

dbTest('a listing with no stock is not counted as supply', async (world) => {
  // The rule the kernel encodes, proved end to end: a category whose only
  // products are out of stock must not read as supplied.
  const product = await buyable(world.db);
  if (!product) return;

  await world.economics.sweep();
  const before = await world.economics.signalFor(
    MarketSubject.CATEGORY,
    product.categoryId,
  );
  if (!before) return;

  await world.db.sellerOffer.updateMany({
    where: { product: { categoryId: product.categoryId } },
    data: { stock: 0 },
  });
  await world.economics.sweep();

  const after = await world.economics.signalFor(
    MarketSubject.CATEGORY,
    product.categoryId,
  );
  assert.ok(after);
  assert.equal(after.supplyScore, 0, 'nothing buyable is not supply');
});

dbTest('an opportunity never speaks above its confidence', async (world) => {
  await world.economics.sweep();
  const opportunities = await world.intelligence.platform(20);

  for (const opportunity of opportunities) {
    assert.ok(
      opportunity.confidence >= 0.25,
      `"${opportunity.headline}" published at confidence ${opportunity.confidence}`,
    );
    assert.ok(opportunity.headline.length > 0, 'an opportunity with no sentence');
    assert.ok(
      opportunity.subjectName !== '—',
      'an opportunity about a subject with no name',
    );
  }
});

dbTest('one subject produces at most one opportunity', async (world) => {
  await world.economics.sweep();
  const opportunities = await world.intelligence.platform(30);
  const keys = opportunities.map((o) => `${o.subjectType}:${o.subjectId}`);
  assert.equal(
    new Set(keys).size,
    keys.length,
    'three findings about one category is one opportunity, not three',
  );
});

dbTest("a seller's opportunities are only about her own market", async (world) => {
  await world.economics.sweep();

  const seller = await world.db.sellerOffer.findFirst({
    where: { status: OfferStatus.ACTIVE },
    select: { sellerId: true },
  });
  if (!seller) return;

  const opportunities = await world.intelligence.forSeller(seller.sellerId, 20);

  for (const opportunity of opportunities) {
    if (opportunity.subjectType === MarketSubject.CATEGORY) {
      const hers = await world.db.product.count({
        where: {
          categoryId: opportunity.subjectId,
          offers: { some: { sellerId: seller.sellerId, status: OfferStatus.ACTIVE } },
        },
      });
      assert.ok(hers > 0, 'an opportunity in a market she has never entered');
    } else {
      const hers = await world.db.product.count({
        where: {
          id: opportunity.subjectId,
          offers: { some: { sellerId: seller.sellerId, status: OfferStatus.ACTIVE } },
        },
      });
      assert.ok(hers > 0, "an opportunity about somebody else's product");
    }
  }
});

// ── Drops ────────────────────────────────────────────────────────────────

dbTest('a drop invites only women the graph can explain', async (world) => {
  const product = await buyable(world.db);
  if (!product) return;

  const drop = await world.drops.create({
    sellerId: product.offers[0].sellerId,
    title: 'اختبار',
    audience: DropAudience.EARLY_ACCESS,
    startsAt: new Date(Date.now() + 86_400_000),
    productIds: [product.id],
  });

  const built = await world.drops.buildAudience(drop.id, { limit: 50 });
  const invites = await world.db.dropInvite.findMany({ where: { dropId: drop.id } });

  assert.equal(invites.length, built.invited);
  for (const invite of invites) {
    const reasons = (invite.reason ?? []) as Array<{ code: string; weight: number }>;
    assert.ok(reasons.length > 0, 'an unexplained invitation is a blast');
    assert.ok(invite.affinity >= 30, 'below the floor and invited anyway');
  }
});

dbTest('rebuilding an audience replaces it rather than accumulating', async (world) => {
  const product = await buyable(world.db);
  if (!product) return;

  const drop = await world.drops.create({
    sellerId: product.offers[0].sellerId,
    title: 'اختبار',
    audience: DropAudience.INVITE_ONLY,
    startsAt: new Date(Date.now() + 86_400_000),
    productIds: [product.id],
  });

  const first = await world.drops.buildAudience(drop.id, { limit: 50 });
  const second = await world.drops.buildAudience(drop.id, { limit: 50 });
  const count = await world.db.dropInvite.count({ where: { dropId: drop.id } });

  assert.equal(first.invited, second.invited);
  assert.equal(count, second.invited, 'targeting twice must not double the list');
});

dbTest('an invite-only drop is invisible to everybody else', async (world) => {
  const product = await buyable(world.db);
  const shopper = await activeShopper(world.db);
  if (!product || !shopper) return;

  const drop = await world.drops.create({
    sellerId: product.offers[0].sellerId,
    title: 'خاص',
    audience: DropAudience.INVITE_ONLY,
    startsAt: new Date(Date.now() - 3600_000),
    productIds: [product.id],
  });
  await world.drops.setStatus(drop.id, DropStatus.SCHEDULED);
  await world.drops.setStatus(drop.id, DropStatus.LIVE);

  const anonymous = await world.drops.visibleTo(null);
  assert.equal(
    anonymous.filter((row) => row.drop.id === drop.id).length,
    0,
    'an invite-only drop leaked to a signed-out visitor',
  );

  const uninvited = await world.drops.visibleTo(shopper);
  assert.equal(
    uninvited.filter((row) => row.drop.id === drop.id).length,
    0,
    'an invite-only drop leaked to somebody it did not invite',
  );

  // And it *is* visible to somebody on the list.
  await world.db.dropInvite.create({
    data: { dropId: drop.id, userId: shopper, affinity: 80, reason: [] },
  });
  const invited = await world.drops.visibleTo(shopper);
  assert.equal(
    invited.filter((row) => row.drop.id === drop.id).length,
    1,
    'the woman it was built for could not see it',
  );
});

dbTest('a drop cannot skip its own state machine', async (world) => {
  const product = await buyable(world.db);
  if (!product) return;

  const drop = await world.drops.create({
    sellerId: product.offers[0].sellerId,
    title: 'اختبار',
    audience: DropAudience.EVERYONE,
    startsAt: new Date(Date.now() + 86_400_000),
    productIds: [product.id],
  });

  await assert.rejects(
    () => world.drops.setStatus(drop.id, DropStatus.ENDED),
    'a draft must not be endable',
  );
  await assert.rejects(
    () => world.drops.setStatus(drop.id, DropStatus.LIVE),
    'a draft must be scheduled before it can open',
  );

  await world.drops.setStatus(drop.id, DropStatus.SCHEDULED);
  await world.drops.setStatus(drop.id, DropStatus.CANCELLED);
  await assert.rejects(
    () => world.drops.setStatus(drop.id, DropStatus.LIVE),
    'a cancelled drop must stay cancelled',
  );
});

dbTest("a seller cannot touch another seller's drop", async (world) => {
  const product = await buyable(world.db);
  if (!product) return;

  const other = await world.db.sellerOffer.findFirst({
    where: {
      status: OfferStatus.ACTIVE,
      sellerId: { not: product.offers[0].sellerId },
    },
    select: { sellerId: true },
  });
  if (!other) return;

  const drop = await world.drops.create({
    sellerId: product.offers[0].sellerId,
    title: 'اختبار',
    audience: DropAudience.EVERYONE,
    startsAt: new Date(Date.now() + 86_400_000),
    productIds: [product.id],
  });

  // 404, not 403: another seller's drop is not hers to know exists.
  await assert.rejects(
    () => world.drops.performance(drop.id, other.sellerId),
    /not found/i,
  );
  await assert.rejects(
    () => world.drops.buildAudience(drop.id, { sellerId: other.sellerId }),
    /not found/i,
  );
});

dbTest('a conversion is only counted for somebody the drop invited', async (world) => {
  const product = await buyable(world.db);
  const shopper = await activeShopper(world.db);
  if (!product || !shopper) return;

  const drop = await world.drops.create({
    sellerId: product.offers[0].sellerId,
    title: 'اختبار',
    audience: DropAudience.EVERYONE,
    startsAt: new Date(Date.now() - 3600_000),
    productIds: [product.id],
  });
  await world.drops.setStatus(drop.id, DropStatus.SCHEDULED);
  await world.drops.setStatus(drop.id, DropStatus.LIVE);

  // Nobody invited: a purchase converts nothing.
  assert.equal(await world.drops.markConverted(shopper, [product.id]), 0);

  await world.db.dropInvite.create({
    data: { dropId: drop.id, userId: shopper, affinity: 70, reason: [] },
  });
  assert.equal(await world.drops.markConverted(shopper, [product.id]), 1);
  // Idempotent — a second order does not convert her twice.
  assert.equal(await world.drops.markConverted(shopper, [product.id]), 0);
});

// ── Bundles ──────────────────────────────────────────────────────────────

dbTest('a bundle fills one slot per piece and explains every one', async (world) => {
  await world.bundles.build({ limit: 8 });

  const bundles = await world.bundles.list({ limit: 10 });
  if (!bundles.length) return; // no complement relations in this dataset yet

  for (const bundle of bundles) {
    assert.ok(bundle.items.length >= 3, 'a two-piece bundle is not a solution');
    assert.ok(bundle.items.length <= 5, 'a bundle is a suggestion, not a catalogue');

    const slots = bundle.items.map((item) => item.slot).filter(Boolean);
    assert.equal(
      new Set(slots).size,
      slots.length,
      'two pieces claiming the same slot is a shopping list',
    );

    for (const item of bundle.items) {
      assert.ok(item.reason, 'a piece that cannot explain itself is a gift basket');
      assert.ok(item.offerId, 'a bundle item that cannot be bought');
    }
  }
});

dbTest('a bundle only ever contains things somebody can buy today', async (world) => {
  await world.bundles.build({ limit: 8 });
  const bundles = await world.bundles.list({ limit: 6 });
  if (!bundles.length) return;

  for (const bundle of bundles) {
    for (const item of bundle.items) {
      const live = await world.db.sellerOffer.count({
        where: {
          id: item.offerId as string,
          status: OfferStatus.ACTIVE,
          stock: { gt: 0 },
        },
      });
      assert.equal(live, 1, 'a bundle offering something out of stock');
    }
  }
});

dbTest('rebuilding retires the bundles it no longer produces', async (world) => {
  await world.bundles.build({ limit: 6 });
  const before = await world.db.bundle.findMany({
    where: { status: 'GENERATED' },
    select: { id: true, fingerprint: true },
  });
  if (!before.length) return;

  await world.bundles.build({ limit: 6 });
  const after = await world.db.bundle.findMany({
    where: { status: 'GENERATED' },
    select: { id: true, fingerprint: true },
  });

  // Stable across rebuilds: the same pieces keep the same row.
  assert.deepEqual(
    after.map((b) => b.fingerprint).sort(),
    before.map((b) => b.fingerprint).sort(),
    'a rebuild over unchanged data must not churn identities',
  );
});

dbTest('an alternative in a bundle is genuinely cheaper', async (world) => {
  await world.bundles.build({ limit: 8 });
  const bundles = await world.bundles.list({ limit: 5 });
  if (!bundles.length) return;

  for (const bundle of bundles) {
    const alternatives = await world.bundles.alternativesFor(bundle.id);
    for (const alternative of alternatives) {
      assert.ok(
        alternative.alternative.priceSyp < alternative.current.priceSyp,
        'an "alternative" that costs more',
      );
      assert.ok(alternative.savingSyp > 0);

      // And it must be a substitute the graph actually believes in.
      const edge = await world.db.productAffinity.count({
        where: {
          productId: alternative.current.productId,
          relatedId: alternative.alternative.productId,
          kind: AffinityKind.SUBSTITUTE,
        },
      });
      assert.equal(edge, 1, 'an alternative invented outside the graph');
    }
  }
});

// ── Life cycle and resale ────────────────────────────────────────────────

dbTest('a wardrobe reading never advises selling a favourite', async (world) => {
  const shopper = await activeShopper(world.db);
  if (!shopper) return;

  const closet = await world.db.closet.findFirst({ where: { userId: shopper } });
  if (!closet) return;

  const item = await world.db.closetItem.create({
    data: {
      closetId: closet.id,
      userId: shopper,
      source: ClosetItemSource.PERSONAL,
      status: ClosetItemStatus.ACTIVE,
      title: 'فستان قديم',
      slot: OutfitSlot.DRESS,
      colours: [],
      materials: [],
      occasions: [],
      seasons: [],
      isFavourite: true,
      wearCount: 1,
      lastWornAt: new Date(Date.now() - 400 * 86_400_000),
      acquiredAt: new Date(Date.now() - 800 * 86_400_000),
      purchasePriceSyp: new Prisma.Decimal(9000),
    },
  });

  const row = await world.lifecycle.readItem(shopper, item.id);
  assert.equal(row.reading.rotation, 'DORMANT');
  assert.notEqual(row.reading.disposition, 'RESELL');
  assert.notEqual(row.reading.disposition, 'DONATE');
});

dbTest('listing a piece archives it, and selling it releases it', async (world) => {
  const shopper = await activeShopper(world.db);
  if (!shopper) return;
  const closet = await world.db.closet.findFirst({ where: { userId: shopper } });
  if (!closet) return;

  const item = await world.db.closetItem.create({
    data: {
      closetId: closet.id,
      userId: shopper,
      source: ClosetItemSource.PERSONAL,
      status: ClosetItemStatus.ACTIVE,
      title: 'عباية',
      slot: OutfitSlot.ABAYA,
      colours: [],
      materials: [],
      occasions: [],
      seasons: [],
      purchasePriceSyp: new Prisma.Decimal(6000),
    },
  });

  const listing = await world.lifecycle.list(shopper, item.id, {
    condition: ResaleCondition.EXCELLENT,
  });
  assert.equal(listing.status, ResaleStatus.DRAFT, 'a listing must not publish itself');
  assert.equal(Number(listing.priceSyp), 3300, '55% of 6000, rounded to the fifty');

  await world.lifecycle.setStatus(shopper, listing.id, ResaleStatus.LISTED);
  let refreshed = await world.db.closetItem.findUniqueOrThrow({ where: { id: item.id } });
  assert.equal(refreshed.status, ClosetItemStatus.ARCHIVED);

  await world.lifecycle.setStatus(shopper, listing.id, ResaleStatus.SOLD);
  refreshed = await world.db.closetItem.findUniqueOrThrow({ where: { id: item.id } });
  assert.equal(
    refreshed.status,
    ClosetItemStatus.RELEASED,
    'the row survives the sale so cost-per-wear does',
  );

  await assert.rejects(
    () => world.lifecycle.setStatus(shopper, listing.id, ResaleStatus.LISTED),
    'a sold piece cannot be relisted',
  );
});

dbTest('a resale listing never enters the product catalogue', async (world) => {
  const shopper = await activeShopper(world.db);
  if (!shopper) return;
  const closet = await world.db.closet.findFirst({ where: { userId: shopper } });
  if (!closet) return;

  const productsBefore = await world.db.product.count();

  const item = await world.db.closetItem.create({
    data: {
      closetId: closet.id,
      userId: shopper,
      source: ClosetItemSource.PERSONAL,
      status: ClosetItemStatus.ACTIVE,
      title: 'شنطة',
      slot: OutfitSlot.BAG,
      colours: [],
      materials: [],
      occasions: [],
      seasons: [],
      purchasePriceSyp: new Prisma.Decimal(5000),
    },
  });
  const listing = await world.lifecycle.list(shopper, item.id, {
    condition: ResaleCondition.GOOD,
  });
  await world.lifecycle.setStatus(shopper, listing.id, ResaleStatus.LISTED);

  assert.equal(
    await world.db.product.count(),
    productsBefore,
    'resale must not write into the catalogue',
  );

  // And her own listing is not shown back to her in the market.
  const market = await world.lifecycle.market({ viewerId: shopper });
  assert.equal(market.filter((row) => row.listing.id === listing.id).length, 0);
});

dbTest('a piece with no known price cannot be listed at an invented one', async (world) => {
  const shopper = await activeShopper(world.db);
  if (!shopper) return;
  const closet = await world.db.closet.findFirst({ where: { userId: shopper } });
  if (!closet) return;

  const item = await world.db.closetItem.create({
    data: {
      closetId: closet.id,
      userId: shopper,
      source: ClosetItemSource.PERSONAL,
      status: ClosetItemStatus.ACTIVE,
      title: 'قطعة بلا سعر',
      slot: OutfitSlot.TOP,
      colours: [],
      materials: [],
      occasions: [],
      seasons: [],
    },
  });

  await assert.rejects(
    () => world.lifecycle.list(shopper, item.id, { condition: ResaleCondition.GOOD }),
    /price is required/i,
  );

  // Naming one herself works.
  const listing = await world.lifecycle.list(shopper, item.id, {
    condition: ResaleCondition.GOOD,
    priceSyp: 2500,
  });
  assert.equal(Number(listing.priceSyp), 2500);
});

// ── Missions ─────────────────────────────────────────────────────────────

dbTest('the mission catalogue installs idempotently', async (world) => {
  await world.missions.seed();
  const first = await world.db.mission.count({ where: { isActive: true } });
  await world.missions.seed();
  const second = await world.db.mission.count({ where: { isActive: true } });
  assert.equal(first, second);
  assert.ok(first >= 6);
});

dbTest('no mission is ever offered that she cannot finish', async (world) => {
  const shopper = await activeShopper(world.db);
  if (!shopper) return;
  await world.missions.seed();

  const rows = await world.missions.mine(shopper);
  for (const row of rows) {
    if (row.progress.status === 'COMPLETED') continue;
    assert.ok(
      row.evidence.possible >= row.reading.remaining,
      `"${row.mission.titleAr}" asks for ${row.reading.remaining} with ${row.evidence.possible} available`,
    );
  }
});

dbTest('at most three missions are live at once', async (world) => {
  const shopper = await activeShopper(world.db);
  if (!shopper) return;
  await world.missions.seed();

  await world.missions.mine(shopper);
  await world.missions.mine(shopper);

  const live = await world.db.missionProgress.count({
    where: { userId: shopper, status: { in: ['OFFERED', 'ACTIVE'] } },
  });
  assert.ok(live <= 3, `${live} missions live at once is a chore list`);
});

dbTest('mission progress moves only when the underlying rows do', async (world) => {
  const shopper = await activeShopper(world.db);
  if (!shopper) return;
  const closet = await world.db.closet.findFirst({ where: { userId: shopper } });
  if (!closet) return;

  await world.missions.seed();

  const before = await world.missions.evidence(shopper, 'DESCRIBE_CLOSET');

  await world.db.closetItem.create({
    data: {
      closetId: closet.id,
      userId: shopper,
      source: ClosetItemSource.PERSONAL,
      status: ClosetItemStatus.ACTIVE,
      title: 'قطعة موصوفة',
      slot: OutfitSlot.TOP,
      colours: ['black'],
      materials: ['قطن'],
      occasions: [],
      seasons: [],
    },
  });

  const after = await world.missions.evidence(shopper, 'DESCRIBE_CLOSET');
  assert.equal(after.done, before.done + 1, 'a described piece must count');
  assert.equal(after.possible, before.possible, 'and must not change what is left');
});

dbTest('declining a mission is believed', async (world) => {
  const shopper = await activeShopper(world.db);
  if (!shopper) return;
  await world.missions.seed();

  const offered = await world.missions.mine(shopper);
  const live = offered.find((row) => row.progress.status !== 'COMPLETED');
  if (!live) return;

  await world.missions.decline(shopper, live.mission.key);
  const again = await world.missions.mine(shopper);

  assert.equal(
    again.filter(
      (row) =>
        row.mission.key === live.mission.key &&
        row.progress.status !== 'COMPLETED',
    ).length,
    0,
    'a declined mission came straight back',
  );
});
