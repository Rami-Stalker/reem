import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CommissionStatus,
  Currency,
  OrderStatus,
  PayoutStatus,
  PrismaClient,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { FinancialAuditService } from './financial-audit.service';
import { SellerPayoutsService } from './seller-payouts.service';

/**
 * Q69 P1's second half — «طلب سحب الأرباح».
 *
 * The statement was built and the asking was not, so a seller watched a
 * balance marked «متاح للسحب» grow with no way to ask for any of it. What
 * these pin is not that a request can be made, but the four things that must
 * stay true once it can: she is paid only for sales whose escrow has actually
 * released, no sale is ever claimed by two payouts, a security freeze stops
 * her, and cancelling a request gives the money back to the next one rather
 * than stranding it.
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
        return async (fn: (inner: Tx) => unknown) => fn(tx);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

interface World {
  tx: Tx;
  payouts: SellerPayoutsService;
}

const audit = {
  record: async () => {},
  recordBalanceChange: async () => {},
} as unknown as FinancialAuditService;

function build(tx: Tx): World {
  return { tx, payouts: new SellerPayoutsService(asPrisma(tx), audit) };
}

const syp = (amount: string) => Money.of(amount, Currency.SYP);

let counter = 0;
const uniq = (prefix: string) =>
  `${prefix}${Date.now().toString(36)}${(counter += 1).toString(36)}`;

async function makeSeller(tx: Tx) {
  return tx.user.create({
    data: {
      name: 'بائعة اختبار',
      phone: `+9639${String(Date.now() + (counter += 1)).slice(-8)}`,
      username: uniq('payout_spec_'),
      role: UserRole.SELLER,
      sellerVerifiedAt: new Date(),
    },
  });
}

/**
 * One delivered sale with its commission settled.
 *
 * `escrowReleased` is the switch under test: it is what the return window
 * closing sets, and money before it is the customer's to take back.
 */
async function makeSale(
  tx: Tx,
  sellerId: string,
  options: {
    net: string;
    escrowReleased?: boolean;
    status?: CommissionStatus;
  },
) {
  const customer = await tx.user.create({
    data: {
      name: 'زبونة',
      phone: `+9639${String(Date.now() + (counter += 1)).slice(-8)}`,
      username: uniq('payout_cus_'),
    },
  });

  const gross = syp(options.net).plus(syp('100000'));

  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-12)}`,
      userId: customer.id,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: gross.toPrisma(),
      grandTotal: gross.toPrisma(),
      recipientName: 'ريم',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
    },
  });

  const sellerOrder = await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `SUB-${uniq('s').slice(-12)}`,
      sellerId,
      status: SellerOrderStatus.DELIVERED,
      currency: Currency.SYP,
      itemsSubtotal: gross.toPrisma(),
      commissionBase: gross.toPrisma(),
      commissionAmount: syp('100000').toPrisma(),
      sellerNet: options.net,
      deliveredAt: new Date(),
      escrowReleased: options.escrowReleased ?? true,
    },
  });

  return tx.commissionLedger.create({
    data: {
      sellerOrderId: sellerOrder.id,
      sellerId,
      currency: Currency.SYP,
      gross: gross.toPrisma(),
      commission: syp('100000').toPrisma(),
      net: syp(options.net).toPrisma(),
      status: options.status ?? CommissionStatus.EARNED,
    },
  });
}

// ── What she may ask for ────────────────────────────────────────────────────

dbTest('a request gathers every released sale, and nothing else', async (
  world,
) => {
  const seller = await makeSeller(world.tx);
  await makeSale(world.tx, seller.id, { net: '400000' });
  await makeSale(world.tx, seller.id, { net: '250000' });
  // Delivered, but the return window has not closed: still the customer's.
  await makeSale(world.tx, seller.id, {
    net: '900000',
    escrowReleased: false,
  });
  // Already paid out by an earlier run.
  await makeSale(world.tx, seller.id, {
    net: '700000',
    status: CommissionStatus.PAID,
  });

  const before = await world.payouts.availability(seller.id);
  assert.equal(before.can_request, true);
  assert.equal(before.orders_included, 2);
  assert.equal(before.claimable.amount, syp('650000').toJSON().amount);

  const payout = await world.payouts.request(seller.id);
  assert.equal(payout.status, PayoutStatus.PENDING);
  assert.equal(payout.net.amount, syp('650000').toJSON().amount);

  // Nothing moved. Creating a request must not pay anything: releasing it is
  // the general manager's act (Q62) and the cash posting happens on PAID.
  const links = await world.tx.sellerPayoutLedger.count({
    where: { payoutId: payout.id },
  });
  assert.equal(links, 2);
  const stillEarned = await world.tx.commissionLedger.count({
    where: { sellerId: seller.id, status: CommissionStatus.EARNED },
  });
  assert.equal(stillEarned, 3, 'the unreleased sale is untouched too');
});

dbTest('nothing released means nothing to ask for', async (world) => {
  const seller = await makeSeller(world.tx);
  await makeSale(world.tx, seller.id, {
    net: '500000',
    escrowReleased: false,
  });

  const availability = await world.payouts.availability(seller.id);
  assert.equal(availability.can_request, false);
  assert.equal(availability.blocked_by, 'nothing_released');

  await assert.rejects(() => world.payouts.request(seller.id));
});

dbTest('the same sale cannot be claimed by two requests', async (world) => {
  const seller = await makeSeller(world.tx);
  await makeSale(world.tx, seller.id, { net: '400000' });

  await world.payouts.request(seller.id);

  // The second attempt is refused outright — but even if it were not, the
  // ledger is already claimed and could not be gathered again.
  await assert.rejects(() => world.payouts.request(seller.id));

  const availability = await world.payouts.availability(seller.id);
  assert.equal(availability.blocked_by, 'request_open');
  assert.ok(availability.open_request, 'she is shown the request she has');
});

dbTest('a sale that arrives after a request waits for the next one', async (
  world,
) => {
  const seller = await makeSeller(world.tx);
  await makeSale(world.tx, seller.id, { net: '400000' });
  const first = await world.payouts.request(seller.id);

  await makeSale(world.tx, seller.id, { net: '300000' });

  // Settle the first the way the console does, so the queue is clear again.
  await world.tx.sellerPayout.update({
    where: { id: first.id },
    data: { status: PayoutStatus.PAID, paidAt: new Date() },
  });

  const second = await world.payouts.request(seller.id);
  assert.equal(second.net.amount, syp('300000').toJSON().amount);
});

// ── The freeze ──────────────────────────────────────────────────────────────

dbTest('a frozen account cannot ask to be paid', async (world) => {
  const seller = await makeSeller(world.tx);
  await makeSale(world.tx, seller.id, { net: '400000' });
  await world.tx.user.update({
    where: { id: seller.id },
    data: {
      payoutFrozenUntil: new Date(Date.now() + 7 * 86_400_000),
      payoutFreezeReason: 'phone_change',
    },
  });

  const availability = await world.payouts.availability(seller.id);
  assert.equal(availability.can_request, false);
  assert.equal(availability.blocked_by, 'payout_frozen');
  assert.ok(availability.frozen_until);
  // Her earnings keep accruing and her statement keeps working; it is only
  // the money leaving that stops.
  assert.equal(availability.claimable.amount, syp('400000').toJSON().amount);

  await assert.rejects(() => world.payouts.request(seller.id));
});

dbTest('a freeze that has expired stops nothing', async (world) => {
  const seller = await makeSeller(world.tx);
  await makeSale(world.tx, seller.id, { net: '400000' });
  await world.tx.user.update({
    where: { id: seller.id },
    data: { payoutFrozenUntil: new Date(Date.now() - 86_400_000) },
  });

  const payout = await world.payouts.request(seller.id);
  assert.equal(payout.status, PayoutStatus.PENDING);
});

// ── Withdrawing the request ─────────────────────────────────────────────────

dbTest('cancelling gives the money back to the next request', async (world) => {
  const seller = await makeSeller(world.tx);
  await makeSale(world.tx, seller.id, { net: '400000' });

  const payout = await world.payouts.request(seller.id);
  const cancelled = await world.payouts.cancel(seller.id, payout.id);
  assert.equal(cancelled.status, PayoutStatus.CANCELLED);

  // The whole point: the claim is released. Left in place, `payoutItems:
  // { none: {} }` would hold that sale outside every future payout for good.
  const links = await world.tx.sellerPayoutLedger.count({
    where: { payoutId: payout.id },
  });
  assert.equal(links, 0);

  const again = await world.payouts.request(seller.id);
  assert.equal(again.net.amount, syp('400000').toJSON().amount);
});

dbTest('an approved request is no longer hers to withdraw', async (world) => {
  const seller = await makeSeller(world.tx);
  await makeSale(world.tx, seller.id, { net: '400000' });
  const payout = await world.payouts.request(seller.id);

  await world.tx.sellerPayout.update({
    where: { id: payout.id },
    data: { status: PayoutStatus.APPROVED, approvedAt: new Date() },
  });

  await assert.rejects(() => world.payouts.cancel(seller.id, payout.id));
});

dbTest("a seller cannot touch another seller's request", async (world) => {
  const mine = await makeSeller(world.tx);
  const hers = await makeSeller(world.tx);
  await makeSale(world.tx, hers.id, { net: '400000' });
  const payout = await world.payouts.request(hers.id);

  await assert.rejects(() => world.payouts.cancel(mine.id, payout.id));

  const untouched = await world.tx.sellerPayout.findUnique({
    where: { id: payout.id },
  });
  assert.equal(untouched?.status, PayoutStatus.PENDING);
});

dbTest('her history shows what happened to each request', async (world) => {
  const seller = await makeSeller(world.tx);
  await makeSale(world.tx, seller.id, { net: '400000' });
  const first = await world.payouts.request(seller.id);
  await world.payouts.cancel(seller.id, first.id);
  await makeSale(world.tx, seller.id, { net: '150000' });
  await world.payouts.request(seller.id);

  const history = await world.payouts.history(seller.id);
  assert.equal(history.length, 2);
  assert.equal(history[0].status, PayoutStatus.PENDING);
  assert.equal(history[1].status, PayoutStatus.CANCELLED);
  // The second gathered both sales, the cancelled one having let its go.
  assert.equal(history[0].net.amount, syp('550000').toJSON().amount);
});
