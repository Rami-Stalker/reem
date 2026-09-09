import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  LedgerAccountCode,
  LedgerDirection,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  PrismaClient,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { FinancialAuditService } from '../finance/financial-audit.service';
import { LoyaltyService } from '../finance/loyalty.service';
import { LedgerService } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import { CommissionsService } from './commissions.service';

/**
 * What the settlement entry claims happened.
 *
 * This is the entry every other financial figure is derived from, and for a
 * long time it described a sale nobody had made: it debited the collection
 * account for the *list* price while the customer had paid a discounted one,
 * and it never mentioned the delivery fee at all. Both errors balanced, which
 * is exactly why neither was ever noticed — a wrong book still adds up.
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
  ledger: LedgerService;
  commissions: CommissionsService;
}

const audit = {
  record: async () => {},
  recordBalanceChange: async () => {},
} as unknown as FinancialAuditService;

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const ledger = new LedgerService(db);
  const wallets = new WalletService(db, ledger);
  const loyalty = new LoyaltyService(db, ledger, wallets);
  return { tx, ledger, commissions: new CommissionsService(db, ledger, loyalty, audit) };
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const syp = (value: string) => Money.of(value, Currency.SYP);

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `st-${tag}`,
      username: `st_${u}`,
      // Eight genuinely random digits, not a slice of the timestamp.
      // `uniq` is unique *within* a process; `node --test` runs spec files in
      // parallel, so two of them entering `makeUser` in the same millisecond
      // with the same counter produced the same eight digits and one of them
      // died on the unique index — a failure that looked like the assertion
      // under test rather than like the fixture it was.
      phone: `+9639${Math.floor(10_000_000 + Math.random() * 89_999_999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

interface ParcelShape {
  subtotal: string;
  discount?: string;
  shipping?: string;
  /**
   * The base commission was charged on. Left at the subtotal for a
   * platform-funded coupon, reduced for a seller-funded one.
   */
  commissionBase: string;
  sellerNet: string;
}

async function makeParcel(tx: Tx, shape: ParcelShape) {
  const seller = await makeUser(tx, 'sel', UserRole.SELLER);
  const customer = await makeUser(tx, 'cus');
  const discount = shape.discount ?? '0';
  const shipping = shape.shipping ?? '0';

  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-12)}`,
      userId: customer.id,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: shape.subtotal,
      discountTotal: discount,
      shippingTotal: shipping,
      grandTotal: syp(shape.subtotal)
        .minus(syp(discount))
        .plus(syp(shipping))
        .toPrisma(),
      recipientName: 'ريم',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      payment: {
        create: {
          // Cash on delivery with no courier assigned yet, so the collection
          // lands in platform cash — the simplest account to assert against.
          method: PaymentMethodType.COD,
          status: PaymentStatus.PAID,
          currency: Currency.SYP,
          amount: syp(shape.subtotal).minus(syp(discount)).plus(syp(shipping)).toPrisma(),
        },
      },
    },
  });

  const sellerOrder = await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `${order.number}-1`,
      sellerId: seller.id,
      status: SellerOrderStatus.DELIVERED,
      currency: Currency.SYP,
      itemsSubtotal: shape.subtotal,
      discountTotal: discount,
      shippingCost: shipping,
      commissionBase: shape.commissionBase,
      commissionAmount: syp(shape.commissionBase)
        .minus(syp(shape.sellerNet))
        .toPrisma(),
      sellerNet: shape.sellerNet,
      deliveredAt: new Date(),
      items: {
        create: {
          titleSnapshot: 'قطعة',
          sellerSnapshot: 'بائعة',
          currency: Currency.SYP,
          unitPrice: shape.subtotal,
          quantity: 1,
          lineTotal: shape.subtotal,
        },
      },
    },
  });

  return { seller, customer, order, sellerOrder };
}

const balance = (world: World, code: LedgerAccountCode, ownerId?: string) =>
  world.ledger.balanceOf({ code, ownerId }, Currency.SYP, world.tx);

// ── The delivery fee ────────────────────────────────────────────────────

dbTest('the delivery fee is booked as revenue, not lost', async (world) => {
  const before = await balance(world, LedgerAccountCode.SHIPPING_REVENUE);
  const cashBefore = await balance(world, LedgerAccountCode.PLATFORM_CASH);

  const { sellerOrder } = await makeParcel(world.tx, {
    subtotal: '400000',
    shipping: '25000',
    commissionBase: '400000',
    sellerNet: '340000',
  });
  await world.commissions.settleSellerOrder(sellerOrder.id);

  const after = await balance(world, LedgerAccountCode.SHIPPING_REVENUE);
  assert.equal(after.minus(before).toString(), syp('25000').toString());

  // And the collection account carries the whole of what she handed over —
  // goods plus the fee — rather than the goods alone.
  const cashAfter = await balance(world, LedgerAccountCode.PLATFORM_CASH);
  assert.equal(cashAfter.minus(cashBefore).toString(), syp('425000').toString());
});

// ── The coupon ──────────────────────────────────────────────────────────

dbTest(
  'a seller-funded coupon costs the seller and nobody else',
  async (world) => {
    const promoBefore = await balance(
      world,
      LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE,
    );
    const cashBefore = await balance(world, LedgerAccountCode.PLATFORM_CASH);

    // She discounted her own goods: the base commission is charged on is what
    // the customer paid.
    const { sellerOrder, seller } = await makeParcel(world.tx, {
      subtotal: '500000',
      discount: '50000',
      commissionBase: '450000',
      sellerNet: '382500',
    });
    await world.commissions.settleSellerOrder(sellerOrder.id);

    const cashAfter = await balance(world, LedgerAccountCode.PLATFORM_CASH);
    assert.equal(
      cashAfter.minus(cashBefore).toString(),
      syp('450000').toString(),
      'the books must claim only what she actually paid',
    );

    const promoAfter = await balance(
      world,
      LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE,
    );
    assert.equal(
      promoAfter.toString(),
      promoBefore.toString(),
      'the platform funded nothing here',
    );

    const escrow = await balance(
      world,
      LedgerAccountCode.SELLER_ESCROW,
      seller.id,
    );
    assert.equal(escrow.toString(), syp('382500').toString());
  },
);

dbTest(
  'a platform-funded coupon is marketing spend, not commission revenue',
  async (world) => {
    const promoBefore = await balance(
      world,
      LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE,
    );
    const commissionBefore = await balance(
      world,
      LedgerAccountCode.COMMISSION_REVENUE,
    );
    const cashBefore = await balance(world, LedgerAccountCode.PLATFORM_CASH);

    // Q49 P2 — the platform ran the promotion, so the seller sold at her full
    // price and checkout leaves her base there.
    const { sellerOrder, seller } = await makeParcel(world.tx, {
      subtotal: '500000',
      discount: '50000',
      commissionBase: '500000',
      sellerNet: '425000',
    });
    await world.commissions.settleSellerOrder(sellerOrder.id);

    // She is owed on the full price — the discount was never hers to give.
    const escrow = await balance(
      world,
      LedgerAccountCode.SELLER_ESCROW,
      seller.id,
    );
    assert.equal(escrow.toString(), syp('425000').toString());

    // The customer paid 450,000, and that is all the books claim to hold.
    const cashAfter = await balance(world, LedgerAccountCode.PLATFORM_CASH);
    assert.equal(
      cashAfter.minus(cashBefore).toString(),
      syp('450000').toString(),
    );

    // The 50,000 gap is the platform's own spend. It used to be swallowed by
    // commission revenue, which flattered every revenue report by the value of
    // every discount ever given.
    const promoAfter = await balance(
      world,
      LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE,
    );
    assert.equal(
      promoAfter.minus(promoBefore).toString(),
      syp('50000').toString(),
    );

    const commissionAfter = await balance(
      world,
      LedgerAccountCode.COMMISSION_REVENUE,
    );
    assert.equal(
      commissionAfter.minus(commissionBefore).toString(),
      syp('75000').toString(),
      'commission is 500,000 − 425,000 — the discount is not part of it',
    );
  },
);

// ── The invariant underneath both ───────────────────────────────────────

dbTest('the entry balances and names every party', async (world) => {
  const { sellerOrder } = await makeParcel(world.tx, {
    subtotal: '500000',
    discount: '50000',
    shipping: '20000',
    commissionBase: '500000',
    sellerNet: '425000',
  });
  await world.commissions.settleSellerOrder(sellerOrder.id);

  const entry = await world.tx.journalEntry.findUniqueOrThrow({
    where: { reference: `settle:${sellerOrder.id}` },
    include: { lines: { include: { account: true } } },
  });

  const sum = (direction: LedgerDirection) =>
    entry.lines
      .filter((line) => line.direction === direction)
      .reduce((total, line) => total.plus(syp(line.amount.toString())), syp('0'));

  assert.equal(
    sum(LedgerDirection.DEBIT).toString(),
    sum(LedgerDirection.CREDIT).toString(),
  );

  const codes = entry.lines.map((line) => line.account.code).sort();
  assert.deepEqual(codes, [
    LedgerAccountCode.COMMISSION_REVENUE,
    LedgerAccountCode.PLATFORM_CASH,
    LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE,
    LedgerAccountCode.SELLER_ESCROW,
    LedgerAccountCode.SHIPPING_REVENUE,
  ].sort());
});

// ── The escrow bridge ───────────────────────────────────────────────────
//
// `releaseDueEscrow` was written, correct, and called by nothing — no cron, no
// route, no test. `SellerPayoutsService.claimableLedgers` will only pay a
// ledger whose sub-order carries `escrowReleased`, so with nothing setting it
// every payout request from every seller returned zero: the platform could
// take money and never pay it out. These are the tests that would have caught
// it, and they exercise the method the scheduler now calls.

/** Backdates the return window so the parcel is due for release. */
async function makeDue(world: World, sellerOrderId: string, daysAgo: number) {
  const at = new Date(Date.now() - daysAgo * 24 * 60 * 60 * 1000);
  await world.tx.sellerOrder.update({
    where: { id: sellerOrderId },
    data: { deliveredAt: at, escrowReleaseAt: at },
  });
}

dbTest('escrow whose window has closed becomes payable', async (world) => {
  const { sellerOrder, seller } = await makeParcel(world.tx, {
    subtotal: '400000',
    commissionBase: '400000',
    sellerNet: '340000',
  });
  await makeDue(world, sellerOrder.id, 1);

  const escrowBefore = await balance(
    world,
    LedgerAccountCode.SELLER_ESCROW,
    seller.id,
  );
  const payableBefore = await balance(
    world,
    LedgerAccountCode.SELLER_PAYABLE,
    seller.id,
  );

  const result = await world.commissions.releaseDueEscrow();
  assert.ok(result.released >= 1, 'the due parcel was released');
  assert.equal(result.failed, 0);

  const released = await world.tx.sellerOrder.findUniqueOrThrow({
    where: { id: sellerOrder.id },
    select: { escrowReleased: true },
  });
  assert.equal(released.escrowReleased, true);

  // The money moved from "hers, but not yet" to "hers, and payable". Escrow is
  // credited on settlement and debited again here, so it comes back to where
  // it started; the payable is what a payout run drains.
  const escrowAfter = await balance(
    world,
    LedgerAccountCode.SELLER_ESCROW,
    seller.id,
  );
  const payableAfter = await balance(
    world,
    LedgerAccountCode.SELLER_PAYABLE,
    seller.id,
  );
  assert.equal(escrowAfter.toString(), escrowBefore.toString());
  assert.equal(
    payableAfter.minus(payableBefore).toString(),
    syp('340000').toString(),
  );
});

dbTest('escrow still inside its window is left alone', async (world) => {
  const { sellerOrder } = await makeParcel(world.tx, {
    subtotal: '100000',
    commissionBase: '100000',
    sellerNet: '85000',
  });
  // Delivered today, so the return window has days left to run.
  await world.tx.sellerOrder.update({
    where: { id: sellerOrder.id },
    data: {
      deliveredAt: new Date(),
      escrowReleaseAt: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000),
    },
  });

  await world.commissions.releaseDueEscrow();

  const still = await world.tx.sellerOrder.findUniqueOrThrow({
    where: { id: sellerOrder.id },
    select: { escrowReleased: true },
  });
  assert.equal(
    still.escrowReleased,
    false,
    'a customer can still send this back, so the seller is not paid for it yet',
  );
});

dbTest('releasing the same parcel twice books nothing twice', async (world) => {
  const { sellerOrder, seller } = await makeParcel(world.tx, {
    subtotal: '200000',
    commissionBase: '200000',
    sellerNet: '170000',
  });
  await makeDue(world, sellerOrder.id, 2);

  await world.commissions.releaseDueEscrow();
  const once = await balance(
    world,
    LedgerAccountCode.SELLER_PAYABLE,
    seller.id,
  );

  // The flag now excludes it, but the postings are idempotent on their
  // reference anyway — belt and braces, because a sweep that double-pays is
  // the failure nobody can undo by re-running it.
  await world.tx.sellerOrder.update({
    where: { id: sellerOrder.id },
    data: { escrowReleased: false },
  });
  await world.commissions.releaseDueEscrow();

  const twice = await balance(
    world,
    LedgerAccountCode.SELLER_PAYABLE,
    seller.id,
  );
  assert.equal(twice.toString(), once.toString());
});

// ── What the journey cost ───────────────────────────────────────────────
//
// `SHIPPING_EXPENSE` sat in the chart of accounts, was read by
// `EconomicsService` when it computed contribution margin, and was written by
// nothing. The platform booked the fee it charged the customer and never the
// fee it paid the carrier, so every margin figure on the admin dashboard was
// overstated by the entire cost of delivery.

/** Hands the parcel to a carrier that has quoted a fee for the journey. */
async function dispatchParcel(
  world: World,
  sellerOrderId: string,
  fee: string,
) {
  const u = uniq('d');
  const courier = await world.tx.courier.create({
    data: { displayName: `شركة ${u}`, phone: `+96311${Math.floor(100000 + Math.random() * 899999)}` },
  });
  const provider = await world.tx.deliveryProviderAccount.create({
    data: { code: `prov-${u}`, displayName: `شركة ${u}`, courierId: courier.id },
  });
  const shipment = await world.tx.shipment.create({
    data: {
      trackingCode: `TRK-${u.slice(-10)}`,
      sellerOrderId,
      courierId: courier.id,
      currency: Currency.SYP,
    },
  });
  await world.tx.deliveryDispatch.create({
    data: {
      shipmentId: shipment.id,
      providerId: provider.id,
      providerCode: provider.code,
      idempotencyKey: `idem-${u}`,
      feeAmount: fee,
      feeCurrency: Currency.SYP,
    },
  });
  return { courier, provider, shipment };
}

dbTest('the carrier fee is booked as an expense we owe', async (world) => {
  const { sellerOrder } = await makeParcel(world.tx, {
    subtotal: '400000',
    shipping: '25000',
    commissionBase: '400000',
    sellerNet: '340000',
  });
  const { courier } = await dispatchParcel(world, sellerOrder.id, '18000');

  const expenseBefore = await balance(
    world,
    LedgerAccountCode.SHIPPING_EXPENSE,
  );

  await world.commissions.settleSellerOrder(sellerOrder.id);

  const expenseAfter = await balance(world, LedgerAccountCode.SHIPPING_EXPENSE);
  assert.equal(
    expenseAfter.minus(expenseBefore).toString(),
    syp('18000').toString(),
    'what the carrier charged is now a cost, not an invisible one',
  );

  // And it is owed to a named carrier, not to nobody — a courier hands over
  // the gross cash it collected, so its own fee has to accrue somewhere.
  const payable = await balance(
    world,
    LedgerAccountCode.COURIER_PAYABLE,
    courier.id,
  );
  assert.equal(payable.toString(), syp('18000').toString());

  // The margin on this parcel is now readable: 25,000 charged, 18,000 paid.
  const revenue = await balance(world, LedgerAccountCode.SHIPPING_REVENUE);
  assert.ok(revenue.toPrisma().greaterThan(0));
});

dbTest('a parcel nobody dispatched accrues no delivery cost', async (world) => {
  const { sellerOrder } = await makeParcel(world.tx, {
    subtotal: '100000',
    shipping: '10000',
    commissionBase: '100000',
    sellerNet: '85000',
  });

  const before = await balance(world, LedgerAccountCode.SHIPPING_EXPENSE);
  await world.commissions.settleSellerOrder(sellerOrder.id);
  const after = await balance(world, LedgerAccountCode.SHIPPING_EXPENSE);

  assert.equal(
    after.toString(),
    before.toString(),
    'no carrier quoted a fee, so there is nothing honest to book',
  );
});

dbTest('re-settling does not bill the carrier twice', async (world) => {
  const { sellerOrder } = await makeParcel(world.tx, {
    subtotal: '400000',
    shipping: '25000',
    commissionBase: '400000',
    sellerNet: '340000',
  });
  const { courier } = await dispatchParcel(world, sellerOrder.id, '18000');

  await world.commissions.settleSellerOrder(sellerOrder.id);
  await world.commissions.settleSellerOrder(sellerOrder.id);

  const payable = await balance(
    world,
    LedgerAccountCode.COURIER_PAYABLE,
    courier.id,
  );
  assert.equal(payable.toString(), syp('18000').toString());
});
