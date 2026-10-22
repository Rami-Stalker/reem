import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  PrismaClient,
  ReferralStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { CouponsService } from './coupons.service';
import { ReferralsService } from './referrals.service';

/**
 * «كود الدعوة» — the discount, and the promise that it is paid once.
 *
 * The referral engine recorded who invited whom and paid points at some later
 * date. What it never did was the thing the gesture means from her side: give
 * her money off the purchase she is making now, and give her friend money off
 * hers once that purchase completes. These pin both halves, and — more
 * importantly — pin that neither half can be collected twice, whatever order
 * the requests arrive in.
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

interface World {
  tx: Tx;
  referrals: ReferralsService;
  coupons: CouponsService;
}

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
          const db = asPrisma(tx);
          try {
            await body({
              tx,
              referrals: new ReferralsService(db),
              coupons: new CouponsService(db),
            });
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
        return async (arg: unknown) =>
          typeof arg === 'function'
            ? (arg as (inner: Tx) => unknown)(tx)
            : Promise.all(arg as Promise<unknown>[]);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;

async function makeUser(tx: Tx, tag: string) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `ref-${tag}`,
      username: `ref_${u}`,
      phone: `+9638${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role: UserRole.CUSTOMER,
      phoneVerifiedAt: new Date(),
    },
  });
}

/** An order, only as much of one as `qualifyReferralForOrder` needs. */
async function makeOrder(tx: Tx, userId: string) {
  return tx.order.create({
    data: {
      userId,
      number: `ORD-${uniq('o')}`.slice(0, 24),
      currency: Currency.SYP,
      fxRate: 1,
      itemsSubtotal: 100_000,
      grandTotal: 100_000,
      recipientName: 'ريم',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'شارع',
    },
  });
}

// ── The invitee's side ─────────────────────────────────────────────────────

dbTest('applying an invite mints a discount she can spend now', async (world) => {
  const host = await makeUser(world.tx, 'a');
  const guest = await makeUser(world.tx, 'b');
  const code = await world.referrals.getOrCreateCode(host.id);

  const applied = await world.referrals.applyCode(guest.id, {
    code: code.code,
  });

  assert.equal(applied.accepted, true);
  const welcome = applied.welcome_coupon;
  assert.ok(welcome, 'she gets a code she can spend');
  assert.equal(welcome!.discount_percent, 15);

  // And it works through the ordinary coupon rail — bound to her, and worth
  // the percentage it promised.
  const evaluated = await world.coupons.evaluate(
    welcome!.code,
    guest.id,
    Money.of(100_000, Currency.SYP),
  );
  assert.equal(evaluated.discount.toString(), Money.of(15_000, Currency.SYP).toString());

  // Bound to her: her friend cannot spend it.
  await assert.rejects(
    world.coupons.evaluate(welcome!.code, host.id, Money.of(100_000, Currency.SYP)),
    /not available for your account/i,
  );
});

dbTest('the welcome discount cannot be spent twice', async (world) => {
  const host = await makeUser(world.tx, 'c');
  const guest = await makeUser(world.tx, 'd');
  const code = await world.referrals.getOrCreateCode(host.id);
  const applied = await world.referrals.applyCode(guest.id, {
    code: code.code,
  });
  const welcome = applied.welcome_coupon!;

  const coupon = await world.tx.coupon.findUniqueOrThrow({
    where: { code: welcome.code },
  });
  const order = await makeOrder(world.tx, guest.id);

  await world.coupons.redeemInTransaction(
    world.tx,
    coupon.id,
    guest.id,
    order.id,
    Money.of(15_000, Currency.SYP),
  );

  // `maxUses: 1` and `perUserLimit: 1`, enforced under the row lock the
  // redemption rail takes — the same one every other coupon queues behind.
  await assert.rejects(
    world.coupons.redeemInTransaction(
      world.tx,
      coupon.id,
      guest.id,
      order.id,
      Money.of(15_000, Currency.SYP),
    ),
    /usage limit|already used/i,
  );
});

dbTest('applying the same invite again hands back the same coupon', async (world) => {
  const host = await makeUser(world.tx, 'e');
  const guest = await makeUser(world.tx, 'f');
  const code = await world.referrals.getOrCreateCode(host.id);

  const first = await world.referrals.applyCode(guest.id, { code: code.code });
  const second = await world.referrals.applyCode(guest.id, { code: code.code });

  assert.equal(second.already_applied, true);
  // Not a second code: the same one, so typing it again at checkout is the
  // same discount rather than a way of minting another.
  assert.equal(second.welcome_coupon?.code, first.welcome_coupon?.code);

  const minted = await world.tx.coupon.count({
    where: { userId: guest.id },
  });
  assert.equal(minted, 1);
});

dbTest('her own code buys her nothing', async (world) => {
  const her = await makeUser(world.tx, 'g');
  const code = await world.referrals.getOrCreateCode(her.id);

  await assert.rejects(
    world.referrals.applyCode(her.id, { code: code.code }),
    /your own referral code/i,
  );
});

// ── The referrer's side ────────────────────────────────────────────────────

dbTest('her friend is paid when the first purchase completes', async (world) => {
  const host = await makeUser(world.tx, 'h');
  const guest = await makeUser(world.tx, 'i');
  const code = await world.referrals.getOrCreateCode(host.id);
  await world.referrals.applyCode(guest.id, { code: code.code });

  // Before the purchase, the host has nothing.
  assert.equal(await world.tx.coupon.count({ where: { userId: host.id } }), 0);

  const order = await makeOrder(world.tx, guest.id);
  await world.referrals.qualifyReferralForOrder(guest.id, order.id);

  const hostCoupons = await world.tx.coupon.findMany({
    where: { userId: host.id },
  });
  assert.equal(hostCoupons.length, 1);
  assert.equal(Number(hostCoupons[0].discountPercent), 10);
  assert.equal(hostCoupons[0].maxUses, 1);

  // And the points, which were already paid, still are.
  const paid = await world.tx.user.findUniqueOrThrow({
    where: { id: host.id },
  });
  assert.equal(paid.points, 500);

  const referral = await world.tx.referral.findUniqueOrThrow({
    where: { referredUserId: guest.id },
  });
  assert.equal(referral.status, ReferralStatus.REWARDED);
});

dbTest('a second purchase pays the invite nothing more', async (world) => {
  const host = await makeUser(world.tx, 'j');
  const guest = await makeUser(world.tx, 'k');
  const code = await world.referrals.getOrCreateCode(host.id);
  await world.referrals.applyCode(guest.id, { code: code.code });

  const first = await makeOrder(world.tx, guest.id);
  await world.referrals.qualifyReferralForOrder(guest.id, first.id);
  const second = await makeOrder(world.tx, guest.id);
  await world.referrals.qualifyReferralForOrder(guest.id, second.id);

  // One invite, one payment — on both sides. This is «منع التكرار في
  // الاستفادة», and it holds because the qualification only ever looks at a
  // PENDING referral and the coupon code is derived from the referral id.
  assert.equal(await world.tx.coupon.count({ where: { userId: host.id } }), 1);
  const host2 = await world.tx.user.findUniqueOrThrow({
    where: { id: host.id },
  });
  assert.equal(host2.points, 500);

  const rewards = await world.tx.referralReward.count({
    where: { userId: host.id },
  });
  // Points, cashback, coupon — one of each, not two.
  assert.equal(rewards, 3);
});

// ── The ceiling ────────────────────────────────────────────────────────────

dbTest('a percentage code cannot take off more than its ceiling', async (world) => {
  const host = await makeUser(world.tx, 'l');
  const guest = await makeUser(world.tx, 'm');
  const code = await world.referrals.getOrCreateCode(host.id);
  const applied = await world.referrals.applyCode(guest.id, {
    code: code.code,
  });

  // 15% of a gold set is not a welcome discount, it is an unbudgeted one.
  const huge = Money.of(10_000_000, Currency.SYP);
  const evaluated = await world.coupons.evaluate(
    applied.welcome_coupon!.code,
    guest.id,
    huge,
  );
  assert.equal(
    evaluated.discount.toString(),
    Money.of(150_000, Currency.SYP).toString(),
  );
});
