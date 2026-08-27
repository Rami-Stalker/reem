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
      phone: `+9639${u.slice(-8)}`,
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
