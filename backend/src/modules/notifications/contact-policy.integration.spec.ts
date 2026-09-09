import assert from 'node:assert/strict';
import test from 'node:test';
import {
  NotificationCategory,
  NotificationChannel,
  NotificationDeliveryStatus,
  PrismaClient,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import {
  CONTACT_LIMITS,
  ContactPolicyService,
} from './contact-policy.service';

/**
 * How much the platform is allowed to say.
 *
 * The failure these guard against is cumulative and invisible from any single
 * campaign: an abandoned-basket reminder, a win-back, a price drop and a
 * flash-sale announcement are each defensible alone, and four of them on one
 * Tuesday is why a customer turns notifications off — a decision she makes
 * once, silently, and never revisits.
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
  policy: ContactPolicyService;
}

function build(tx: Tx): World {
  return { tx, policy: new ContactPolicyService(asPrisma(tx)) };
}

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;

/** A time known to be inside the platform's waking hours, whatever today is. */
const middayUtc = () => {
  const now = new Date();
  now.setUTCHours(11, 0, 0, 0);
  return now;
};

const nightUtc = () => {
  const now = new Date();
  now.setUTCHours(0, 30, 0, 0);
  return now;
};

async function makeCustomer(tx: Tx, over: { push?: boolean } = {}) {
  const u = uniq();
  const user = await tx.user.create({
    data: {
      name: 'ريم',
      username: `cp_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role: UserRole.CUSTOMER,
    },
  });
  if (over.push !== undefined) {
    await tx.notificationPreference.create({
      data: { userId: user.id, push: over.push },
    });
  }
  return user;
}

/** Records that a message already went out. */
async function sent(
  tx: Tx,
  userId: string,
  category: NotificationCategory,
  when: Date,
) {
  return tx.notificationDelivery.create({
    data: {
      userId,
      channel: NotificationChannel.PUSH,
      category,
      status: NotificationDeliveryStatus.SENT,
      title: 'x',
      body: 'y',
      sentAt: when,
      createdAt: when,
    },
  });
}

// ── The cap ──────────────────────────────────────────────────────────────────

dbTest('a customer who has had nothing may be reached', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const decision = await world.policy.mayContact(buyer.id, {
    category: NotificationCategory.MARKETING,
    now: middayUtc(),
  });
  assert.equal(decision.allowed, true);
});

dbTest('the daily cap holds', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const now = middayUtc();

  for (let i = 0; i < CONTACT_LIMITS.perDay; i += 1) {
    await sent(
      world.tx,
      buyer.id,
      NotificationCategory.MARKETING,
      new Date(now.getTime() - 3600_000),
    );
  }

  const decision = await world.policy.mayContact(buyer.id, {
    category: NotificationCategory.MARKETING,
    now,
  });
  assert.equal(decision.allowed, false);
  assert.equal(decision.allowed === false && decision.reason, 'daily_cap');
});

dbTest('the weekly cap holds even when today is clear', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const now = middayUtc();

  // Spread across earlier days, so the daily count is zero.
  for (let i = 0; i < CONTACT_LIMITS.perWeek; i += 1) {
    await sent(
      world.tx,
      buyer.id,
      NotificationCategory.MARKETING,
      new Date(now.getTime() - (i + 2) * 24 * 3600_000),
    );
  }

  const decision = await world.policy.mayContact(buyer.id, {
    category: NotificationCategory.MARKETING,
    now,
  });
  assert.equal(decision.allowed, false);
  assert.equal(decision.allowed === false && decision.reason, 'weekly_cap');
});

dbTest('an order update is never capped', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const now = middayUtc();

  for (let i = 0; i < 20; i += 1) {
    await sent(
      world.tx,
      buyer.id,
      NotificationCategory.MARKETING,
      new Date(now.getTime() - 3600_000),
    );
  }

  const decision = await world.policy.mayContact(buyer.id, {
    category: NotificationCategory.TRANSACTIONAL,
    now,
  });
  assert.equal(
    decision.allowed,
    true,
    'the day somebody caps an order update is the day she stops trusting the app',
  );
});

dbTest('transactional volume does not eat her marketing allowance', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const now = middayUtc();

  // A busy week of order updates.
  for (let i = 0; i < 15; i += 1) {
    await sent(
      world.tx,
      buyer.id,
      NotificationCategory.TRANSACTIONAL,
      new Date(now.getTime() - i * 3600_000),
    );
  }

  const decision = await world.policy.mayContact(buyer.id, {
    category: NotificationCategory.MARKETING,
    now,
  });
  assert.equal(
    decision.allowed,
    true,
    'a customer who ordered a lot has not been marketed at a lot',
  );
});

dbTest('a queued message counts, not only a sent one', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const now = middayUtc();

  await world.tx.notificationDelivery.create({
    data: {
      userId: buyer.id,
      channel: NotificationChannel.PUSH,
      category: NotificationCategory.MARKETING,
      status: NotificationDeliveryStatus.QUEUED,
      title: 'x',
      body: 'y',
      createdAt: new Date(now.getTime() - 600_000),
    },
  });

  const decision = await world.policy.mayContact(buyer.id, {
    category: NotificationCategory.MARKETING,
    now,
  });
  assert.equal(
    decision.allowed,
    false,
    'a burst of scheduling would otherwise slip past the cap entirely',
  );
});

// ── Quiet hours ──────────────────────────────────────────────────────────────

dbTest('nothing marketing goes out in the middle of the night', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const decision = await world.policy.mayContact(buyer.id, {
    category: NotificationCategory.MARKETING,
    now: nightUtc(),
  });
  assert.equal(decision.allowed, false);
  assert.equal(decision.allowed === false && decision.reason, 'quiet_hours');
});

dbTest('an order update still goes out at night', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const decision = await world.policy.mayContact(buyer.id, {
    category: NotificationCategory.TRANSACTIONAL,
    now: nightUtc(),
  });
  assert.equal(
    decision.allowed,
    true,
    'a parcel out for delivery is worth knowing about at seven in the morning',
  );
});

dbTest('a scheduled send is not re-judged against the clock', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const decision = await world.policy.mayContact(buyer.id, {
    category: NotificationCategory.MARKETING,
    now: nightUtc(),
    ignoreQuietHours: true,
  });
  assert.equal(
    decision.allowed,
    true,
    'a message queued last evening for nine in the morning has already chosen its hour',
  );
});

// ── Her own answer ───────────────────────────────────────────────────────────

dbTest('a customer who turned push off is not reached', async (world) => {
  const buyer = await makeCustomer(world.tx, { push: false });
  const decision = await world.policy.mayContact(buyer.id, {
    category: NotificationCategory.MARKETING,
    now: middayUtc(),
  });
  assert.equal(decision.allowed, false);
  assert.equal(
    decision.allowed === false && decision.reason,
    'push_disabled',
    'she has already answered this question',
  );
});

// ── Scheduling ───────────────────────────────────────────────────────────────

dbTest('the next window is her own hour when one is known', async (world) => {
  const buyer = await makeCustomer(world.tx);
  await world.tx.customerProfile.create({
    data: {
      userId: buyer.id,
      propensityScore: 50,
      propensityBand: 'warm',
      churnScore: 10,
      churnBand: 'safe',
      realisedValue: 0,
      projectedValue: 0,
      valueHorizonDays: 180,
      bestContactHour: 20,
      signals: {},
    },
  });

  const when = await world.policy.nextWindow(buyer.id, middayUtc());
  assert.ok(when.getTime() > middayUtc().getTime(), 'always in the future');
  assert.ok(
    when.getTime() - middayUtc().getTime() <= 24 * 3600_000,
    'and within a day',
  );
});

dbTest('without a known hour it falls back to the end of quiet time', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const when = await world.policy.nextWindow(buyer.id, nightUtc());
  assert.ok(when.getTime() > nightUtc().getTime());
});

dbTest('the load report says why a campaign reached fewer people', async (world) => {
  const buyer = await makeCustomer(world.tx);
  const now = middayUtc();
  await sent(
    world.tx,
    buyer.id,
    NotificationCategory.MARKETING,
    new Date(now.getTime() - 3600_000),
  );

  const load = await world.policy.recentLoad(buyer.id, now);
  assert.equal(load.last_day, 1);
  assert.equal(load.day_limit, CONTACT_LIMITS.perDay);
  assert.equal(load.week_limit, CONTACT_LIMITS.perWeek);
});
