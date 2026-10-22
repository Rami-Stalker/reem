import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CommissionStatus,
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  OrderStatus,
  PayoutStatus,
  PrismaClient,
  RoundingPolicy,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { CommissionsService } from '../commissions/commissions.service';
import { LedgerService } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import { CheckoutService } from '../orders/checkout.service';
import { MembershipService } from '../rewards/membership.service';
import { PurchaseRewardsService } from '../rewards/purchase-rewards.service';
import { ReferralsService } from '../rewards/referrals.service';
import { FinancialAuditService } from './financial-audit.service';
import { LoyaltyService } from './loyalty.service';
import { SellerPayoutsService } from './seller-payouts.service';

/**
 * The guards that keep the money honest when a caller is not.
 *
 * Every case runs in a transaction that is rolled back. The database-level
 * balance check is deferred to commit, so the cases that exercise it ask for
 * it early with `SET CONSTRAINTS ALL IMMEDIATE`.
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

const audit = {
  record: async () => {},
  recordBalanceChange: async () => {},
} as unknown as FinancialAuditService;

interface World {
  tx: Tx;
  ledger: LedgerService;
  commissions: CommissionsService;
  payouts: SellerPayoutsService;
  loyalty: LoyaltyService;
  rewards: PurchaseRewardsService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const ledger = new LedgerService(db);
  const wallets = new WalletService(db, ledger);
  const loyalty = new LoyaltyService(db, ledger, wallets);
  const rewards = new PurchaseRewardsService(
    db,
    new MembershipService(db),
    new ReferralsService(db),
  );
  return {
    tx,
    ledger,
    loyalty,
    rewards,
    commissions: new CommissionsService(db, ledger, loyalty, audit, rewards),
    payouts: new SellerPayoutsService(db, audit),
  };
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

let seq = 0;
const uniq = (tag: string) =>
  `${Date.now().toString(36)}${(seq += 1).toString(36)}${tag}`;
const syp = (value: string) => Money.of(value, Currency.SYP);

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  return tx.user.create({
    data: {
      name: `fi-${tag}`,
      username: `fi_${uniq(tag)}`,
      phone: `+9639${Math.floor(10_000_000 + Math.random() * 89_999_999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

/** A simple balanced posting between two platform accounts. */
async function postSimple(world: World, amount = '1000') {
  return world.ledger.post(
    {
      type: JournalEntryType.MANUAL_ADJUSTMENT,
      reference: `fi-simple:${uniq('e')}`,
      description: 'Integrity fixture',
      lines: [
        {
          account: { code: LedgerAccountCode.PLATFORM_CASH },
          direction: LedgerDirection.DEBIT,
          amount: syp(amount),
        },
        {
          account: { code: LedgerAccountCode.SUSPENSE },
          direction: LedgerDirection.CREDIT,
          amount: syp(amount),
        },
      ],
    },
    world.tx,
  );
}

/**
 * One order with released, unpaid sales for a seller: the commission rows and
 * the payable the escrow release books for them.
 */
async function makeReleasedSales(world: World, nets: string[]) {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const customer = await makeUser(world.tx, 'cus');
  const ledgers = [];
  for (const net of nets) {
    const gross = syp(net).plus(syp('1000'));
    const order = await world.tx.order.create({
      data: {
        number: `FI-${uniq('o').slice(-12)}`,
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
    const sellerOrder = await world.tx.sellerOrder.create({
      data: {
        orderId: order.id,
        number: `${order.number}-1`,
        sellerId: seller.id,
        status: SellerOrderStatus.DELIVERED,
        currency: Currency.SYP,
        itemsSubtotal: gross.toPrisma(),
        commissionBase: gross.toPrisma(),
        commissionAmount: syp('1000').toPrisma(),
        sellerNet: net,
        deliveredAt: new Date(),
        escrowReleased: true,
      },
    });
    ledgers.push(
      await world.tx.commissionLedger.create({
        data: {
          sellerOrderId: sellerOrder.id,
          sellerId: seller.id,
          currency: Currency.SYP,
          gross: gross.toPrisma(),
          commission: syp('1000').toPrisma(),
          net: syp(net).toPrisma(),
          status: CommissionStatus.EARNED,
        },
      }),
    );
    await world.ledger.post(
      {
        type: JournalEntryType.ESCROW_RELEASED,
        reference: `escrow-release:${sellerOrder.id}`,
        description: 'Fixture release',
        sellerOrderId: sellerOrder.id,
        lines: [
          {
            account: { code: LedgerAccountCode.SELLER_ESCROW, ownerId: seller.id },
            direction: LedgerDirection.DEBIT,
            amount: syp(net),
          },
          {
            account: { code: LedgerAccountCode.SELLER_PAYABLE, ownerId: seller.id },
            direction: LedgerDirection.CREDIT,
            amount: syp(net),
          },
        ],
      },
      world.tx,
    );
  }
  return { seller, customer, ledgers };
}

/** A refund taken out of the seller's payable after her sales were released. */
async function chargeSeller(world: World, sellerId: string, amount: string) {
  await world.ledger.post(
    {
      type: JournalEntryType.MANUAL_ADJUSTMENT,
      reference: `fi-charge:${uniq('c')}`,
      description: 'Refund recovered from the seller',
      lines: [
        {
          account: { code: LedgerAccountCode.SELLER_PAYABLE, ownerId: sellerId },
          direction: LedgerDirection.DEBIT,
          amount: syp(amount),
        },
        {
          account: { code: LedgerAccountCode.PLATFORM_CASH },
          direction: LedgerDirection.CREDIT,
          amount: syp(amount),
        },
      ],
    },
    world.tx,
  );
}

const rejectsWith = (code: string) => (error: unknown) => {
  const response = (error as { getResponse?: () => unknown }).getResponse?.();
  const text = JSON.stringify(response ?? (error as Error).message);
  assert.ok(text.includes(code), `expected ${code}, got ${text}`);
  return true;
};

// ── The ledger, in the database itself ──────────────────────────────────

dbTest('the database refuses a journal entry that does not balance', async (world) => {
  const entry = await postSimple(world);
  // A line written around `LedgerService`, the way a hand-run fix would.
  await world.tx.journalLine.create({
    data: {
      entryId: entry.id,
      accountId: entry.lines[0].accountId,
      direction: LedgerDirection.DEBIT,
      amount: '1',
      currency: Currency.SYP,
    },
  });
  await assert.rejects(
    () => world.tx.$executeRaw`SET CONSTRAINTS ALL IMMEDIATE`,
    /does not balance/,
  );
});

dbTest('a journal line cannot be edited after it is written', async (world) => {
  const entry = await postSimple(world);
  await assert.rejects(
    () =>
      world.tx.journalLine.update({
        where: { id: entry.lines[0].id },
        data: { amount: '2000' },
      }),
    /append-only/,
  );
});

dbTest('a journal entry cannot be deleted', async (world) => {
  const entry = await postSimple(world);
  await assert.rejects(
    () => world.tx.journalEntry.delete({ where: { id: entry.id } }),
    /append-only/,
  );
});

dbTest('declared maintenance may still empty the ledger', async (world) => {
  const entry = await postSimple(world);
  await world.tx.$executeRaw`SELECT set_config('reem.ledger_maintenance', 'on', true)`;
  await world.tx.journalEntry.delete({ where: { id: entry.id } });
  const left = await world.tx.journalEntry.count({ where: { id: entry.id } });
  assert.equal(left, 0);
});

dbTest('a ledger line finer than the stored precision is refused', async (world) => {
  await assert.rejects(
    () => postSimple(world, '10.00005'),
    /finer than the ledger stores/,
  );
});

dbTest('a reference cannot be reused for a different kind of entry', async (world) => {
  const entry = await postSimple(world);
  await assert.rejects(
    () =>
      world.ledger.post(
        {
          type: JournalEntryType.REFUND_ISSUED,
          reference: entry.reference,
          description: 'A different event under the same reference',
          lines: [
            {
              account: { code: LedgerAccountCode.PLATFORM_CASH },
              direction: LedgerDirection.DEBIT,
              amount: syp('1000'),
            },
            {
              account: { code: LedgerAccountCode.SUSPENSE },
              direction: LedgerDirection.CREDIT,
              amount: syp('1000'),
            },
          ],
        },
        world.tx,
      ),
    /already belongs to a MANUAL_ADJUSTMENT entry/,
  );
});

// ── Payouts ─────────────────────────────────────────────────────────────

dbTest('a payout never carries more than the books say is owed', async (world) => {
  const { seller } = await makeReleasedSales(world, ['400000', '250000']);
  // Part of one parcel came back after release; its share left payable.
  await chargeSeller(world, seller.id, '150000');

  const payout = await world.payouts.request(seller.id, Currency.SYP);
  assert.equal(payout.net.amount, '500000.0000');
  const row = await world.tx.sellerPayout.findUniqueOrThrow({
    where: { id: payout.id },
  });
  assert.equal(row.adjustments.toString(), '-150000');

  const availability = await world.payouts.availability(seller.id, Currency.SYP);
  assert.equal(availability.blocked_by, 'request_open');
});

dbTest('a seller whose refunds exceed her releases has nothing to withdraw', async (world) => {
  const { seller } = await makeReleasedSales(world, ['100000']);
  await chargeSeller(world, seller.id, '120000');

  const availability = await world.payouts.availability(seller.id, Currency.SYP);
  assert.equal(availability.can_request, false);
  assert.equal(availability.blocked_by, 'offset_by_refunds');
  await assert.rejects(
    () => world.payouts.request(seller.id, Currency.SYP),
    rejectsWith('NOTHING_PAYABLE'),
  );
});

dbTest('a cancelled payout can never be marked paid', async (world) => {
  const { seller } = await makeReleasedSales(world, ['400000']);
  const payout = await world.payouts.request(seller.id, Currency.SYP);
  await world.payouts.cancel(seller.id, payout.id);

  await assert.rejects(
    () =>
      world.commissions.updatePayoutStatus(
        payout.id,
        { status: PayoutStatus.PAID },
        seller.id,
        UserRole.SUPER_ADMIN,
      ),
    rejectsWith('PAYOUT_TRANSITION_REFUSED'),
  );
  const cash = await world.tx.journalEntry.count({
    where: { reference: `payout-paid:${payout.id}` },
  });
  assert.equal(cash, 0, 'no cash left for it');
});

dbTest('paying is refused when what she is owed fell after the request', async (world) => {
  const { seller } = await makeReleasedSales(world, ['400000']);
  const payout = await world.payouts.request(seller.id, Currency.SYP);
  await chargeSeller(world, seller.id, '50000');

  await assert.rejects(
    () =>
      world.commissions.updatePayoutStatus(
        payout.id,
        { status: PayoutStatus.PAID },
        seller.id,
        UserRole.SUPER_ADMIN,
      ),
    rejectsWith('PAYOUT_EXCEEDS_PAYABLE'),
  );
});

dbTest('a payout that is paid drains exactly its own net', async (world) => {
  const { seller, ledgers } = await makeReleasedSales(world, ['400000']);
  const payout = await world.payouts.request(seller.id, Currency.SYP);
  await world.commissions.updatePayoutStatus(
    payout.id,
    { status: PayoutStatus.PAID },
    seller.id,
    UserRole.SUPER_ADMIN,
  );
  // Asking again is answered, not refused, and moves nothing twice.
  await world.commissions.updatePayoutStatus(
    payout.id,
    { status: PayoutStatus.PAID },
    seller.id,
    UserRole.SUPER_ADMIN,
  );

  const payable = await world.ledger.balanceOf(
    { code: LedgerAccountCode.SELLER_PAYABLE, ownerId: seller.id },
    Currency.SYP,
    world.tx,
  );
  assert.equal(payable.isZero(), true);
  const ledger = await world.tx.commissionLedger.findUniqueOrThrow({
    where: { id: ledgers[0].id },
  });
  assert.equal(ledger.status, CommissionStatus.PAID);
});

dbTest('a sale belongs to at most one payout', async (world) => {
  const { seller, ledgers } = await makeReleasedSales(world, ['400000']);
  const base = {
    sellerId: seller.id,
    periodStart: new Date(),
    periodEnd: new Date(),
    currency: Currency.SYP,
    gross: '0',
    commission: '0',
    platformFees: '0',
    adjustments: '0',
    net: '1',
  };
  await world.tx.sellerPayout.create({
    data: { ...base, ledgers: { create: [{ ledgerId: ledgers[0].id }] } },
  });
  await assert.rejects(
    () =>
      world.tx.sellerPayout.create({
        data: { ...base, ledgers: { create: [{ ledgerId: ledgers[0].id }] } },
      }),
    // Raised as a unique violation, which Prisma reports as P2002.
    /Unique constraint failed/,
  );
});

dbTest('a paid commission row cannot be made claimable again', async (world) => {
  const { ledgers } = await makeReleasedSales(world, ['400000']);
  await world.tx.commissionLedger.update({
    where: { id: ledgers[0].id },
    data: { status: CommissionStatus.PAID },
  });
  await assert.rejects(
    () =>
      world.commissions.updateLedgerStatus(ledgers[0].id, {
        status: CommissionStatus.EARNED,
      }),
    rejectsWith('COMMISSION_STATUS_FINAL'),
  );
});

// ── Rewards ─────────────────────────────────────────────────────────────

dbTest('purchase rewards wait for every parcel, then are granted once', async (world) => {
  const customer = await makeUser(world.tx, 'rw');
  const seller = await makeUser(world.tx, 'rws', UserRole.SELLER);
  const order = await world.tx.order.create({
    data: {
      number: `FI-${uniq('r').slice(-12)}`,
      userId: customer.id,
      status: OrderStatus.CONFIRMED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: '300000',
      grandTotal: '300000',
      recipientName: 'ريم',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      placedAt: new Date(),
    },
  });
  const parcel = (n: number, extra: object) =>
    world.tx.sellerOrder.create({
      data: {
        orderId: order.id,
        number: `${order.number}-${n}`,
        sellerId: seller.id,
        currency: Currency.SYP,
        itemsSubtotal: '150000',
        commissionBase: '150000',
        sellerNet: '135000',
        ...extra,
      },
    });
  await parcel(1, { status: SellerOrderStatus.DELIVERED, escrowReleased: true });
  const open = await parcel(2, { status: SellerOrderStatus.PREPARING });

  assert.equal(await world.rewards.grantIfFinal(order.id), false, 'a parcel is still on its way');

  await world.tx.sellerOrder.update({
    where: { id: open.id },
    data: { status: SellerOrderStatus.CANCELLED_BY_CUSTOMER },
  });
  assert.equal(await world.rewards.grantIfFinal(order.id), true);
  assert.equal(await world.rewards.grantIfFinal(order.id), false, 'and only once');

  const account = await world.tx.membershipAccount.findUniqueOrThrow({
    where: { userId: customer.id },
  });
  // Only the parcel she kept counts as spend.
  assert.equal(account.currentPeriodSpend.toString(), '150000');
});

dbTest('loyalty points are earned on what she paid, not the list price', async (world) => {
  const customer = await makeUser(world.tx, 'lp');
  const seller = await makeUser(world.tx, 'lps', UserRole.SELLER);
  const order = await world.tx.order.create({
    data: {
      number: `FI-${uniq('l').slice(-12)}`,
      userId: customer.id,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: '10000',
      discountTotal: '4000',
      grandTotal: '6000',
      recipientName: 'ريم',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
    },
  });
  const sellerOrder = await world.tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `${order.number}-1`,
      sellerId: seller.id,
      status: SellerOrderStatus.DELIVERED,
      currency: Currency.SYP,
      itemsSubtotal: '10000',
      discountTotal: '4000',
      commissionBase: '6000',
      sellerNet: '5400',
    },
  });

  // 6,000 paid at 100 a point is 60 points; the list price would have been 100.
  const points = await world.loyalty.accrueForSellerOrder(sellerOrder.id, world.tx);
  assert.equal(points, 60);
});

// ── Checkout totals ─────────────────────────────────────────────────────

test('the rounded total and its parts add up to the last unit', () => {
  const checkout: unknown = Object.create(CheckoutService.prototype);
  const roundTotal = (
    CheckoutService.prototype as unknown as {
      roundTotal: (
        items: Money,
        discount: Money,
        shipping: Money,
        policy: RoundingPolicy,
      ) => { grandTotal: Money; shippingTotal: Money };
    }
  ).roundTotal.bind(checkout);

  // 3,378.7 of goods with 337.87 off and 500 delivery: 3,540.83 raw.
  const rounded = roundTotal(
    syp('3378.7'),
    syp('337.87'),
    syp('500'),
    RoundingPolicy.NEAREST_10,
  );
  assert.equal(rounded.grandTotal.toJSON().amount, '3540.0000');
  assert.equal(
    syp('3378.7').minus(syp('337.87')).plus(rounded.shippingTotal).toString(),
    rounded.grandTotal.toString(),
  );

  // Free delivery cannot absorb a rounding down, so the total rounds up.
  const free = roundTotal(syp('1234'), syp('0'), syp('0'), RoundingPolicy.NEAREST_10);
  assert.equal(free.grandTotal.toJSON().amount, '1240.0000');
  assert.equal(free.shippingTotal.toJSON().amount, '6.0000');
  assert.equal(free.shippingTotal.isNegative(), false);
});
