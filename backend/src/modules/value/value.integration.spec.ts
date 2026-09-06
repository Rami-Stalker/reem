import assert from 'node:assert/strict';
import test from 'node:test';
import { randomUUID } from 'node:crypto';
import {
  PrismaClient,
  ValueEventStatus,
  ValueGrantStatus,
  ValuePillar,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { ValueBenefitService } from './value-benefit.service';
import { ValueCollectorService } from './value-collector.service';
import { ValuePolicyService } from './value-policy.service';
import { ValueScoringService } from './value-scoring.service';
import { ValueAdminService } from './value.admin.service';
import { ValueService } from './value.service';
import { ValueVisibilityService } from './value-visibility.service';

/**
 * Reem Value against the real database.
 *
 * The kernel tests prove the arithmetic. These prove the promises that only the
 * database can settle — and every one of them is a promise the brief made:
 *
 *   - standing is never spent by using a benefit;
 *   - the same evidence counted twice is counted once;
 *   - evidence that collapses takes its contribution with it;
 *   - a benefit's cost is bounded before it is offered;
 *   - a frozen profile stops moving without losing anything.
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
  policies: ValuePolicyService;
  scoring: ValueScoringService;
  collector: ValueCollectorService;
  benefits: ValueBenefitService;
  value: ValueService;
  admin: ValueAdminService;
  visibility: ValueVisibilityService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const policies = new ValuePolicyService(db);
  const scoring = new ValueScoringService(db, policies);
  const collector = new ValueCollectorService(db, policies, scoring);
  const benefits = new ValueBenefitService(db, policies, scoring);
  const value = new ValueService(db, policies, scoring, benefits);
  const admin = new ValueAdminService(db, policies, scoring);
  const visibility = new ValueVisibilityService(db, benefits);
  return { db, policies, scoring, collector, benefits, value, admin, visibility };
}

async function someCustomer(db: PrismaService): Promise<string> {
  const user = await db.user.findFirst({
    where: { role: 'CUSTOMER', disabledAt: null },
    select: { id: true },
  });
  assert.ok(user, 'the seeded shop has no customer');
  return user.id;
}

/** Push a woman up to a named rung by recording enough real contributions. */
async function liftTo(
  world: World,
  userId: string,
  tierKey: string,
): Promise<void> {
  await world.policies.seed();
  const target = await world.db.valueTier.findUniqueOrThrow({
    where: { key: tierKey },
  });

  // Spread across pillars and days, because the programme is designed so that
  // no single pillar and no single day can carry somebody to the top.
  const start = new Date();
  let day = 0;
  for (let i = 0; i < 60; i += 1) {
    const occurredAt = new Date(start.getTime() - (day += 1) * 86_400_000);
    for (const code of [
      'review_helpful',
      'referral_kept',
      'post_engaged',
      'early_product',
      'order_kept',
    ] as const) {
      // Real uuids: `value_events.subject_id` is a uuid column, and a fixture
      // that fed it a label would be testing the fixture rather than the code.
      await world.collector.record({
        userId,
        code,
        subjectType: 'test',
        subjectId: randomUUID(),
        occurredAt,
      });
    }
    const profile = await world.scoring.recompute(userId);
    if (profile.score >= target.minScore) return;
  }
  const final = await world.scoring.recompute(userId);
  assert.ok(
    final.score >= target.minScore,
    `could not reach ${tierKey}: got ${final.score} of ${target.minScore}`,
  );
}

// ── The promise ─────────────────────────────────────────────────────────

dbTest('using a benefit never costs standing', async (world) => {
  const userId = await someCustomer(world.db);
  await liftTo(world, userId, 'known');

  const before = await world.db.valueProfile.findUniqueOrThrow({ where: { userId } });
  await world.benefits.grant(userId, 'priority-support');
  const after = await world.db.valueProfile.findUniqueOrThrow({ where: { userId } });

  assert.equal(after.score, before.score, 'a standing is not a balance');
  assert.equal(after.tierKey, before.tierKey);

  // And the grant carries no amount, because there is nothing to charge.
  const grant = await world.db.valueBenefitGrant.findFirstOrThrow({
    where: { userId },
  });
  assert.ok(!('amount' in grant), 'a grant must never carry a price');
});

dbTest('there is no way to ask for standing', async (world) => {
  const userId = await someCustomer(world.db);
  await world.policies.seed();
  const profile = await world.scoring.recompute(userId);

  // Recomputing repeatedly cannot move a score on its own: standing is a pure
  // function of evidence, and asking is not evidence.
  await world.scoring.recompute(userId);
  const again = await world.scoring.recompute(userId);
  assert.equal(again.score, profile.score);
});

// ── Idempotency ─────────────────────────────────────────────────────────

dbTest('the same evidence counted twice is counted once', async (world) => {
  const userId = await someCustomer(world.db);
  await world.policies.seed();
  const occurredAt = new Date();

  for (let i = 0; i < 5; i += 1) {
    await world.collector.record({
      userId,
      code: 'review_helpful',
      subjectType: 'product_review_helpful',
      subjectId: '11111111-1111-1111-1111-111111111111',
      occurredAt,
    });
  }

  // Scoped to the dedupe key this case wrote, not to every `review_helpful`
  // the account has. The seeded shop's own reviews are real evidence and the
  // collector picks them up on any sweep — asserting over all of them made this
  // depend on whether a scheduler had run, which is not what it is testing.
  const events = await world.db.valueEvent.count({
    where: {
      userId,
      dedupeKey: 'review_helpful:11111111-1111-1111-1111-111111111111',
    },
  });
  assert.equal(events, 1, 'dedupeKey must collapse a replayed sweep');
});

dbTest('a sweep can be run twice with no effect the second time', async (world) => {
  const userId = await someCustomer(world.db);
  await world.policies.seed();

  await world.collector.sweep();
  const first = await world.db.valueEvent.count();
  await world.collector.sweep();
  const second = await world.db.valueEvent.count();

  assert.equal(second, first, 'the collector must be safe to re-run');
});

// ── Evidence and its collapse ───────────────────────────────────────────

dbTest('a contribution whose evidence collapses stops counting', async (world) => {
  const userId = await someCustomer(world.db);
  await world.policies.seed();

  for (let i = 0; i < 3; i += 1) {
    await world.collector.record({
      userId,
      code: 'review_helpful',
      subjectType: 'product_review_helpful',
      subjectId: randomUUID(),
      occurredAt: new Date(),
    });
  }
  const before = await world.scoring.recompute(userId);
  assert.ok(before.score > 0);

  const events = await world.db.valueEvent.findMany({
    where: { userId, code: 'review_helpful' },
    select: { subjectId: true },
  });
  for (const event of events) {
    await world.collector.reverse(
      'product_review_helpful',
      event.subjectId!,
      'review_removed',
    );
  }

  const after = await world.scoring.recompute(userId);
  assert.ok(after.score < before.score, 'a withdrawn review must cost its points');

  // Reversed, never deleted: "why did my standing drop" has to have an answer.
  const reversed = await world.db.valueEvent.count({
    where: { userId, status: ValueEventStatus.REVERSED },
  });
  assert.equal(reversed, events.length);
});

dbTest('a discovery is pending until the find is proven right', async (world) => {
  const userId = await someCustomer(world.db);
  await world.policies.seed();

  await world.collector.record({
    userId,
    code: 'early_product',
    subjectType: 'product_discovery',
    subjectId: '33333333-1111-1111-1111-111111111111',
    occurredAt: new Date(),
    status: ValueEventStatus.PENDING,
  });

  const pending = await world.scoring.recompute(userId);
  const discovery = (pending.pillars as unknown as Array<{ pillar: string; raw: number }>)
    .find((p) => p.pillar === ValuePillar.DISCOVERY);
  assert.equal(discovery?.raw, 0, 'a pending find contributes nothing');

  await world.collector.confirm(
    userId,
    'early_product:33333333-1111-1111-1111-111111111111',
    { orders_now: 90 },
  );

  // The one this case wrote, by key — `events[0]` was whichever row the query
  // happened to return first, which is the account's real discovery history
  // once a sweep has run.
  const event = await world.db.valueEvent.findFirstOrThrow({
    where: {
      userId,
      dedupeKey: 'early_product:33333333-1111-1111-1111-111111111111',
    },
    select: { status: true },
  });
  assert.equal(event.status, ValueEventStatus.CONFIRMED);
});

// ── The economics ───────────────────────────────────────────────────────

dbTest('a benefit stops being granted once its budget is spent', async (world) => {
  const userId = await someCustomer(world.db);
  await liftTo(world, userId, 'known');

  await world.db.valueBenefit.update({
    where: { key: 'priority-support' },
    data: { totalBudget: 1, grantedCount: 1 },
  });

  await assert.rejects(
    () => world.benefits.grant(userId, 'priority-support'),
    /run out/,
  );
});

dbTest('a quota stops one woman holding a benefit twice in its window', async (world) => {
  const userId = await someCustomer(world.db);
  await liftTo(world, userId, 'known');

  await world.db.valueBenefit.update({
    where: { key: 'priority-support' },
    data: { perUserQuota: 1, quotaPeriodDays: 30 },
  });

  await world.benefits.grant(userId, 'priority-support', { dedupeKey: 'one' });
  await assert.rejects(
    () => world.benefits.grant(userId, 'priority-support', { dedupeKey: 'two' }),
    /already hold/,
  );
});

dbTest('a benefit above her standing is refused', async (world) => {
  const userId = await someCustomer(world.db);
  await world.policies.seed();
  await world.scoring.recompute(userId);

  await assert.rejects(
    () => world.benefits.grant(userId, 'seasonal-gift'),
    /not open at your standing/,
  );
});

dbTest('the cost report names any benefit that spends without a budget', async (world) => {
  await world.policies.seed();
  await world.db.valueBenefit.update({
    where: { key: 'priority-support' },
    data: { unitCostSyp: 5000, totalBudget: null },
  });

  const cost = await world.admin.projectedCost();
  assert.ok(cost.unboundedCount >= 1, 'an unbudgeted cost must be visible');
  assert.ok(
    cost.benefits.some((row) => row.key === 'priority-support' && row.unbounded),
  );
});

dbTest('the spending guarantee is reported beside the ladder', async (world) => {
  await world.policies.seed();
  const distribution = await world.admin.distribution();

  assert.ok(distribution.guarantee.spendingCeiling > 0);
  assert.equal(
    distribution.guarantee.holds,
    true,
    'money must not reach the upper rungs on its own',
  );
});

// ── Freezing ────────────────────────────────────────────────────────────

dbTest('a frozen profile stops moving without losing anything', async (world) => {
  const userId = await someCustomer(world.db);
  await liftTo(world, userId, 'known');
  const before = await world.db.valueProfile.findUniqueOrThrow({ where: { userId } });

  await world.admin.freeze(userId, 'under review');

  // New evidence is refused while frozen.
  const written = await world.collector.record({
    userId,
    code: 'review_helpful',
    subjectType: 'product_review_helpful',
    subjectId: '44444444-1111-1111-1111-111111111111',
    occurredAt: new Date(),
  });
  assert.equal(written, null);

  const during = await world.scoring.recompute(userId);
  assert.equal(during.score, before.score, 'a freeze must not rescore');

  // And nothing was lost.
  await world.admin.unfreeze(userId);
  const after = await world.db.valueProfile.findUniqueOrThrow({ where: { userId } });
  assert.equal(after.frozenAt, null);
  assert.ok(after.score >= before.score);
});

dbTest('a frozen profile is closed to benefits', async (world) => {
  const userId = await someCustomer(world.db);
  await liftTo(world, userId, 'known');
  await world.admin.freeze(userId, 'under review');

  assert.equal(await world.benefits.isUnlocked(userId, 'priority-support'), false);
});

// ── Standing, read back ─────────────────────────────────────────────────

dbTest('a standing never travels without its reasons', async (world) => {
  const userId = await someCustomer(world.db);
  await liftTo(world, userId, 'known');

  const standing = await world.value.standing(userId);

  assert.ok(standing.pillars.length === 6, 'all six pillars are always reported');
  assert.ok(standing.recent.length > 0, 'the events behind the number travel too');
  assert.ok(standing.benefits.length > 0, 'locked benefits are shown, not hidden');
  assert.ok(
    standing.benefits.some((offer) => !offer.unlocked),
    'a programme that hides what she has not reached cannot motivate anyone',
  );
});

dbTest('a new customer is not scored as a bad one', async (world) => {
  const userId = await someCustomer(world.db);
  await world.policies.seed();
  const profile = await world.scoring.recompute(userId);

  const reliability = (
    profile.pillars as unknown as Array<{ pillar: string; score: number }>
  ).find((p) => p.pillar === ValuePillar.RELIABILITY);

  assert.ok(reliability!.score >= 70, 'no history is not a bad history');
});

dbTest('the ladder and the benefit catalogue are seeded together', async (world) => {
  await world.policies.seed();

  const tiers = await world.db.valueTier.count();
  const benefits = await world.db.valueBenefit.count();
  assert.ok(tiers >= 5);
  assert.ok(benefits >= 6);

  // Every benefit that costs money carries a budget, so the programme's
  // exposure is decided when it is written.
  const paid = await world.db.valueBenefit.findMany({
    where: { unitCostSyp: { gt: 0 } },
    select: { key: true, totalBudget: true, perUserQuota: true },
  });
  for (const benefit of paid) {
    assert.ok(
      benefit.totalBudget !== null || benefit.perUserQuota !== null,
      `${benefit.key} spends money with neither a budget nor a quota`,
    );
  }
});

// ── Visibility ──────────────────────────────────────────────────────────

dbTest('early access hides new arrivals from everybody else', async (world) => {
  await world.policies.seed();
  const userId = await someCustomer(world.db);

  const filter = await world.visibility.catalogFilter(userId);
  // A woman with no standing gets the embargo clause; the catalogue she sees
  // simply does not contain the last 48 hours of arrivals.
  assert.ok(Object.keys(filter).length > 0, 'an embargo must reach the query');

  const guestFilter = await world.visibility.catalogFilter(undefined);
  assert.ok(Object.keys(guestFilter).length > 0, 'and it applies to guests too');
});

dbTest('early access lets her standing through', async (world) => {
  const userId = await someCustomer(world.db);
  await liftTo(world, userId, 'trusted');

  assert.equal(await world.benefits.isUnlocked(userId, 'early-access-48'), true);
  const filter = await world.visibility.catalogFilter(userId);
  assert.deepEqual(filter, {}, 'nothing is hidden from her at this standing');
});
