import assert from 'node:assert/strict';
import test from 'node:test';
import {
  AnalyticsEventType,
  Currency,
  OrderStatus,
  PrismaClient,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { CustomerFactsService } from './customer-facts.service';
import { CustomerIntelligenceService } from './customer-intelligence.service';
import { cadenceOf } from './kernel/propensity';

/**
 * The readings against real rows.
 *
 * The kernel tests prove the arithmetic. These prove the harder half — that
 * the facts fed into it are the facts the database actually holds. A scorer
 * that is right about a number nobody is measuring correctly is the failure
 * mode worth guarding, and it is invisible from the kernel side.
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

test.after(async () => {
  await prisma.$disconnect();
});

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
        return async (fn: (inner: Tx) => unknown) => fn(tx);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

interface World {
  tx: Tx;
  facts: CustomerFactsService;
  intelligence: CustomerIntelligenceService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const facts = new CustomerFactsService(db);
  return { tx, facts, intelligence: new CustomerIntelligenceService(db, facts) };
}

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;
const daysAgo = (n: number) => new Date(Date.now() - n * 86_400_000);

async function makeCustomer(tx: Tx) {
  const u = uniq();
  return tx.user.create({
    data: {
      name: 'ريم',
      username: `ci_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role: UserRole.CUSTOMER,
    },
  });
}

async function makeSeller(tx: Tx) {
  const u = uniq();
  return tx.user.create({
    data: {
      name: 'بوتيك',
      username: `cis_${u}`,
      phone: `+96388${Math.floor(1000000 + Math.random() * 8999999)}`,
      passwordHash: 'x',
      role: UserRole.SELLER,
    },
  });
}

/** A delivered order worth `subtotal`, placed `when`. */
async function buy(
  tx: Tx,
  customerId: string,
  sellerId: string,
  when: Date,
  subtotal = '100000',
) {
  const u = uniq();
  const order = await tx.order.create({
    data: {
      number: `CI-${u.slice(-10)}`,
      userId: customerId,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: subtotal,
      discountTotal: '0',
      shippingTotal: '0',
      grandTotal: subtotal,
      recipientName: 'ريم',
      recipientPhone: `+96387${u.slice(-7)}`,
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      createdAt: when,
    },
  });
  await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `CI-SO-${u.slice(-10)}`,
      sellerId,
      status: SellerOrderStatus.DELIVERED,
      currency: Currency.SYP,
      itemsSubtotal: subtotal,
      discountTotal: '0',
      shippingCost: '0',
      commissionBase: subtotal,
      commissionAmount: '0',
      sellerNet: subtotal,
      createdAt: when,
      deliveredAt: when,
    },
  });
  return order;
}

async function event(
  tx: Tx,
  userId: string,
  type: AnalyticsEventType,
  when: Date,
) {
  return tx.analyticsEvent.create({
    data: { userId, type, occurredAt: when },
  });
}

// ── Facts ────────────────────────────────────────────────────────────────────

dbTest('her trading history is read from the parcels that earned', async (world) => {
  const seller = await makeSeller(world.tx);
  const buyer = await makeCustomer(world.tx);

  await buy(world.tx, buyer.id, seller.id, daysAgo(90), '100000');
  await buy(world.tx, buyer.id, seller.id, daysAgo(60), '150000');
  await buy(world.tx, buyer.id, seller.id, daysAgo(30), '50000');

  const facts = await world.facts.forCustomer(buyer.id);

  assert.equal(facts.purchases.orders, 3);
  assert.equal(facts.purchases.lifetimeSpend, 300000);
  assert.equal(facts.purchases.daysSinceFirstOrder, 90);
  assert.equal(facts.purchases.daysSinceLastOrder, 30);
  assert.equal(
    cadenceOf(facts.purchases),
    30,
    'three orders over sixty days is one every thirty',
  );
});

dbTest('her engagement is read from intent, not from impressions', async (world) => {
  const buyer = await makeCustomer(world.tx);

  await event(world.tx, buyer.id, AnalyticsEventType.APP_OPEN, daysAgo(2));
  await event(world.tx, buyer.id, AnalyticsEventType.PRODUCT_VIEW, daysAgo(2));
  await event(world.tx, buyer.id, AnalyticsEventType.CART_ADD, daysAgo(1));
  // A hundred cards scrolling past her says nothing about what she wants.
  for (let i = 0; i < 100; i += 1) {
    await event(
      world.tx,
      buyer.id,
      AnalyticsEventType.PRODUCT_IMPRESSION,
      daysAgo(1),
    );
  }

  const facts = await world.facts.forCustomer(buyer.id);

  assert.equal(facts.engagement.appOpens, 1);
  assert.equal(facts.engagement.productViews, 1);
  assert.equal(facts.engagement.cartAdds, 1);
  assert.ok(
    facts.engagement.daysSinceLastSeen !== null &&
      facts.engagement.daysSinceLastSeen <= 1,
  );
});

dbTest('an open basket is seen', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const before = await world.facts.forCustomer(buyer.id);
  assert.equal(before.engagement.hasOpenCart, false);
});

dbTest('a refund comes off her realised value', async (world) => {
  const seller = await makeSeller(world.tx);
  const buyer = await makeCustomer(world.tx);
  await buy(world.tx, buyer.id, seller.id, daysAgo(40), '200000');

  const clean = await world.facts.forCustomer(buyer.id);
  assert.equal(clean.purchases.refundedSpend, 0);

  const parcel = await world.tx.sellerOrder.findFirstOrThrow({
    where: { sellerId: seller.id },
  });
  await world.tx.returnRequest.create({
    data: {
      number: `RET-${uniq().slice(-10)}`,
      sellerOrderId: parcel.id,
      requestedById: buyer.id,
      status: 'REFUNDED',
      reason: 'SIZE_ISSUE',
      currency: Currency.SYP,
      windowClosesAt: new Date(),
    },
  });

  const after = await world.facts.forCustomer(buyer.id);
  assert.equal(
    after.purchases.refundedSpend,
    200000,
    'an amount, not a count — the count cannot say what it was worth',
  );
  assert.equal(after.purchases.refundedOrders, 1);
});

// ── Readings ─────────────────────────────────────────────────────────────────

dbTest('a customer on her rhythm reads safe; the same silence reads differently', async (world) => {
  const seller = await makeSeller(world.tx);

  // Buys monthly, bought three weeks ago.
  const regular = await makeCustomer(world.tx);
  for (const ago of [120, 90, 60, 21]) {
    await buy(world.tx, regular.id, seller.id, daysAgo(ago));
  }
  await event(world.tx, regular.id, AnalyticsEventType.APP_OPEN, daysAgo(1));

  // Buys twice a year, bought three weeks ago.
  const occasional = await makeCustomer(world.tx);
  for (const ago of [400, 200, 21]) {
    await buy(world.tx, occasional.id, seller.id, daysAgo(ago));
  }
  await event(world.tx, occasional.id, AnalyticsEventType.APP_OPEN, daysAgo(1));

  const a = await world.intelligence.read(regular.id);
  const b = await world.intelligence.read(occasional.id);

  assert.equal(a.churn.band, 'safe');
  assert.equal(b.churn.band, 'safe');
  assert.ok(a.churn.cadenceDays !== null && a.churn.cadenceDays < 40);
  assert.ok(b.churn.cadenceDays !== null && b.churn.cadenceDays > 150);
});

dbTest('a monthly customer silent for four months is leaving', async (world) => {
  const seller = await makeSeller(world.tx);
  const buyer = await makeCustomer(world.tx);
  for (const ago of [270, 240, 210, 180, 120]) {
    await buy(world.tx, buyer.id, seller.id, daysAgo(ago));
  }

  const reading = await world.intelligence.read(buyer.id);
  assert.ok(
    ['leaving', 'gone'].includes(reading.churn.band),
    `four cycles of silence should read as leaving, got ${reading.churn.band}`,
  );
  assert.ok(reading.churn.cyclesOverdue !== null && reading.churn.cyclesOverdue > 2);
});

dbTest('the profile is stored with its reasons, in Arabic', async (world) => {
  const seller = await makeSeller(world.tx);
  const buyer = await makeCustomer(world.tx);
  for (const ago of [90, 60, 30]) {
    await buy(world.tx, buyer.id, seller.id, daysAgo(ago));
  }

  const stored = await world.intelligence.refresh(buyer.id);

  assert.ok(stored.churn.cadence_days !== null);
  assert.ok(Number(stored.value.realised.amount) > 0);
  assert.equal(stored.stale, false, 'a profile computed now is not stale');

  const signals = stored.signals as {
    churn: { code: string; ar: string }[];
  };
  assert.ok(signals.churn.length > 0);
  assert.ok(
    signals.churn.every((signal) => signal.ar.length > 0),
    'a score nobody can explain is a score nobody acts on',
  );

  const row = await world.tx.customerProfile.findUniqueOrThrow({
    where: { userId: buyer.id },
  });
  assert.equal(row.churnBand, stored.churn.band);
});

dbTest('refreshing twice updates rather than duplicating', async (world) => {
  const seller = await makeSeller(world.tx);
  const buyer = await makeCustomer(world.tx);
  await buy(world.tx, buyer.id, seller.id, daysAgo(20));

  await world.intelligence.refresh(buyer.id);
  await world.intelligence.refresh(buyer.id);

  const count = await world.tx.customerProfile.count({
    where: { userId: buyer.id },
  });
  assert.equal(count, 1);
});

dbTest('the distribution reports what leaving would cost, not just who', async (world) => {
  const seller = await makeSeller(world.tx);
  const buyer = await makeCustomer(world.tx);
  for (const ago of [200, 170, 140]) {
    await buy(world.tx, buyer.id, seller.id, daysAgo(ago), '400000');
  }
  await world.intelligence.refresh(buyer.id);

  const dist = await world.intelligence.distribution();
  assert.ok(dist.customers >= 1);
  assert.ok(
    dist.churn.every((row) => 'value_at_risk' in row),
    'a count of at-risk customers does not get a retention budget approved',
  );
});

dbTest('the band query can be narrowed to customers worth keeping', async (world) => {
  const seller = await makeSeller(world.tx);

  const valuable = await makeCustomer(world.tx);
  for (const ago of [150, 120, 90]) {
    await buy(world.tx, valuable.id, seller.id, daysAgo(ago), '500000');
  }
  await world.intelligence.refresh(valuable.id);

  const cheap = await makeCustomer(world.tx);
  for (const ago of [150, 120, 90]) {
    await buy(world.tx, cheap.id, seller.id, daysAgo(ago), '100');
  }
  await world.intelligence.refresh(cheap.id);

  const rich = await world.intelligence.inBand({
    dimension: 'churn',
    band: (await world.intelligence.profile(valuable.id))!.churn.band,
    limit: 50,
    skip: 0,
    minValue: 1000,
  });

  const ids = rich.data.map((row) => row.user_id);
  assert.ok(ids.includes(valuable.id));
  assert.ok(
    !ids.includes(cheap.id),
    'a retention budget spread evenly is spent mostly on customers worth nothing',
  );
});
