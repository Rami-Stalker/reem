import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  OrderStatus,
  PrismaClient,
  ProductStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { EconomicsService } from './economics.service';

/**
 * The marketplace figures, checked against parcels whose every number is known.
 *
 * These are the numbers a business is steered by, so "it returns a plausible
 * number" is not a passing test. Each case below builds merchandise and
 * journal entries whose arithmetic is stated in the assertion, so a change to
 * a definition — GMV including delivery, take rate over gross instead of net —
 * fails here rather than showing up as a quietly different figure on a
 * dashboard next quarter.
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

/** Everything runs inside one transaction that is always rolled back. */
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
  economics: EconomicsService;
  /** A window wide enough to hold anything the test just wrote. */
  window: { from: Date; to: Date; currency: Currency };
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  return {
    tx,
    ledger: new LedgerService(db),
    economics: new EconomicsService(db),
    window: {
      from: new Date(Date.now() - 60 * 60 * 1000),
      to: new Date(Date.now() + 60 * 60 * 1000),
      currency: Currency.SYP,
    },
  };
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const syp = (value: string | number) => Money.of(String(value), Currency.SYP);
const amountOf = (money: { amount: string }) => Number(money.amount);

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `ec-${tag}`,
      username: `ec_${u}`,
      phone: `+9639${u.slice(-8)}`,
      passwordHash: 'x',
      role,
    },
  });
}

interface ParcelShape {
  subtotal: string;
  discount?: string;
  commission: string;
  status?: SellerOrderStatus;
  sellerId?: string;
  categoryId?: string;
  /** Distinct parents make several orders; sharing one makes a split basket. */
  orderId?: string;
  customerId?: string;
}

/** One seller's parcel, with an order item behind it so categories can be read. */
async function makeParcel(tx: Tx, shape: ParcelShape) {
  const seller = shape.sellerId
    ? { id: shape.sellerId }
    : await makeUser(tx, 'sel', UserRole.SELLER);
  const customer = shape.customerId
    ? { id: shape.customerId }
    : await makeUser(tx, 'cus');
  const discount = shape.discount ?? '0';

  let categoryId = shape.categoryId;
  if (!categoryId) {
    const u = uniq('cat');
    const category = await tx.category.create({
      data: { slug: `ec-cat-${u}`, nameAr: 'فئة', nameEn: 'Cat' },
    });
    categoryId = category.id;
  }

  const u = uniq('p');
  const product = await tx.product.create({
    data: {
      slug: `ec-prod-${u}`,
      title: 'قطعة',
      description: 'اختبار',
      categoryId,
      status: ProductStatus.ACTIVE,
    },
  });

  let orderId = shape.orderId;
  if (!orderId) {
    const order = await tx.order.create({
      data: {
        number: `ORD-${uniq('o').slice(-12)}`,
        userId: customer.id,
        status: OrderStatus.DELIVERED,
        currency: Currency.SYP,
        fxRate: '13000',
        itemsSubtotal: shape.subtotal,
        discountTotal: discount,
        shippingTotal: '0',
        grandTotal: syp(shape.subtotal).minus(syp(discount)).toPrisma(),
        recipientName: 'ريم',
        recipientPhone: '+963900000000',
        governorate: 'دمشق',
        city: 'دمشق',
        addressLine: 'المزة',
      },
    });
    orderId = order.id;
  }

  const sellerOrder = await tx.sellerOrder.create({
    data: {
      orderId,
      number: `SO-${uniq('s').slice(-12)}`,
      sellerId: seller.id,
      status: shape.status ?? SellerOrderStatus.DELIVERED,
      currency: Currency.SYP,
      itemsSubtotal: shape.subtotal,
      discountTotal: discount,
      shippingCost: '0',
      commissionBase: shape.subtotal,
      commissionAmount: shape.commission,
      sellerNet: syp(shape.subtotal)
        .minus(syp(discount))
        .minus(syp(shape.commission))
        .toPrisma(),
      deliveredAt: new Date(),
      items: {
        create: {
          productId: product.id,
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

  return { seller, customer, orderId, sellerOrder, categoryId, product };
}

/** Books platform revenue or cost the way settlement does. */
async function post(
  world: World,
  type: JournalEntryType,
  debit: LedgerAccountCode,
  credit: LedgerAccountCode,
  amount: string,
) {
  await world.ledger.post(
    {
      type,
      reference: `ec:${uniq('r')}`,
      description: 'اختبار',
      lines: [
        { account: { code: debit }, direction: LedgerDirection.DEBIT, amount: syp(amount) },
        { account: { code: credit }, direction: LedgerDirection.CREDIT, amount: syp(amount) },
      ],
    },
    world.tx,
  );
}

// ── Volume ───────────────────────────────────────────────────────────────────

dbTest('GMV is merchandise net of discount, and excludes delivery', async (world) => {
  await makeParcel(world.tx, {
    subtotal: '100000',
    discount: '15000',
    commission: '8500',
  });

  const report = await world.economics.overview(world.window);

  // 100,000 sold, 15,000 given away. Delivery was never merchandise.
  assert.equal(amountOf(report.volume.gmv_gross), 85000);
  assert.equal(amountOf(report.volume.gmv_net), 85000);
  assert.equal(report.volume.orders, 1);
  assert.equal(report.volume.units, 1);
});

dbTest('a refunded parcel comes off GMV without erasing that it happened', async (world) => {
  await makeParcel(world.tx, { subtotal: '100000', commission: '10000' });
  await makeParcel(world.tx, {
    subtotal: '40000',
    commission: '4000',
    status: SellerOrderStatus.REFUNDED,
  });

  const report = await world.economics.overview(world.window);

  // The refunded parcel is not in a revenue-bearing state, so it never
  // entered gross; what it must do is show up as a refund and leave net alone.
  assert.equal(amountOf(report.volume.gmv_gross), 100000);
  assert.equal(amountOf(report.volume.refunds), 40000);
  assert.equal(amountOf(report.volume.gmv_net), 60000);
});

dbTest('AOV counts the basket, not the parcels it was split into', async (world) => {
  const first = await makeParcel(world.tx, {
    subtotal: '60000',
    commission: '6000',
  });
  // A second boutique in the same basket: two parcels, one order.
  await makeParcel(world.tx, {
    subtotal: '40000',
    commission: '4000',
    orderId: first.orderId,
  });

  const report = await world.economics.overview(world.window);

  assert.equal(report.volume.sub_orders, 2);
  assert.equal(report.volume.orders, 1, 'she placed one order');
  assert.equal(amountOf(report.volume.gmv_net), 100000);
  assert.equal(
    amountOf(report.volume.aov),
    100000,
    'AOV over sub-orders would have reported 50,000 for a 100,000 basket',
  );
});

// ── Take rate and contribution ───────────────────────────────────────────────

dbTest('take rate is what the platform kept of what moved', async (world) => {
  await makeParcel(world.tx, { subtotal: '200000', commission: '20000' });
  await post(
    world,
    JournalEntryType.COMMISSION_EARNED,
    LedgerAccountCode.PLATFORM_CASH,
    LedgerAccountCode.COMMISSION_REVENUE,
    '20000',
  );

  const report = await world.economics.overview(world.window);

  assert.equal(amountOf(report.platform.revenue), 20000);
  assert.equal(report.platform.take_rate, 0.1, '20,000 of 200,000');
});

dbTest('contribution margin is revenue less what carrying it cost', async (world) => {
  await makeParcel(world.tx, { subtotal: '200000', commission: '20000' });

  // Earned: commission and the delivery fee she paid.
  await post(
    world,
    JournalEntryType.COMMISSION_EARNED,
    LedgerAccountCode.PLATFORM_CASH,
    LedgerAccountCode.COMMISSION_REVENUE,
    '20000',
  );
  await post(
    world,
    JournalEntryType.COMMISSION_EARNED,
    LedgerAccountCode.PLATFORM_CASH,
    LedgerAccountCode.SHIPPING_REVENUE,
    '5000',
  );
  // Spent: the courier, and a coupon the platform funded itself.
  await post(
    world,
    JournalEntryType.COMMISSION_EARNED,
    LedgerAccountCode.SHIPPING_EXPENSE,
    LedgerAccountCode.PLATFORM_CASH,
    '7000',
  );
  await post(
    world,
    JournalEntryType.COMMISSION_EARNED,
    LedgerAccountCode.PLATFORM_PROMOTION_EXPENSE,
    LedgerAccountCode.PLATFORM_CASH,
    '3000',
  );

  const report = await world.economics.overview(world.window);

  assert.equal(amountOf(report.platform.revenue), 25000, '20,000 + 5,000');
  assert.equal(amountOf(report.platform.direct_costs), 10000, '7,000 + 3,000');
  assert.equal(amountOf(report.platform.contribution_margin), 15000);
  assert.equal(amountOf(report.platform.contribution_per_order), 15000);
});

dbTest('a delivery run that costs more than it charges shows negative', async (world) => {
  await makeParcel(world.tx, { subtotal: '50000', commission: '2000' });
  await post(
    world,
    JournalEntryType.COMMISSION_EARNED,
    LedgerAccountCode.PLATFORM_CASH,
    LedgerAccountCode.COMMISSION_REVENUE,
    '2000',
  );
  await post(
    world,
    JournalEntryType.COMMISSION_EARNED,
    LedgerAccountCode.SHIPPING_EXPENSE,
    LedgerAccountCode.PLATFORM_CASH,
    '9000',
  );

  const report = await world.economics.overview(world.window);

  // The whole point of the figure: this order lost money, and growth in
  // orders like it makes the hole deeper rather than shallower.
  assert.equal(amountOf(report.platform.contribution_margin), -7000);
  assert.ok(
    (report.platform.contribution_margin_rate ?? 0) < 0,
    'a negative margin must read as negative, not as a small positive',
  );
});

dbTest('a month with no sales has no take rate, rather than a rate of zero', async (world) => {
  const report = await world.economics.overview({
    ...world.window,
    from: new Date('2001-01-01'),
    to: new Date('2001-02-01'),
  });

  assert.equal(amountOf(report.volume.gmv_net), 0);
  assert.equal(report.platform.take_rate, null);
  assert.equal(report.platform.contribution_margin_rate, null);
});

// ── Breakdowns ───────────────────────────────────────────────────────────────

dbTest('per-seller economics attribute each parcel to its own boutique', async (world) => {
  const first = await makeParcel(world.tx, {
    subtotal: '150000',
    commission: '15000',
  });
  await makeParcel(world.tx, { subtotal: '50000', commission: '2500' });

  const rows = await world.economics.bySeller(world.window, 20);
  const hers = rows.find((row) => row.seller.id === first.seller.id);

  assert.ok(hers, 'her boutique is in the report');
  assert.equal(amountOf(hers.gmv), 150000);
  assert.equal(amountOf(hers.commission), 15000);
  assert.equal(hers.take_rate, 0.1);
  assert.equal(rows[0].seller.id, first.seller.id, 'ordered by volume');
});

dbTest('per-category economics split a parcel across what was in it', async (world) => {
  const shelf = await makeParcel(world.tx, {
    subtotal: '80000',
    commission: '8000',
  });

  const rows = await world.economics.byCategory(world.window, 20);
  const row = rows.find((r) => r.category.id === shelf.categoryId);

  assert.ok(row, 'the category the garment sits in is reported');
  assert.equal(amountOf(row.gmv), 80000);
  assert.equal(amountOf(row.commission), 8000);
  assert.equal(row.units, 1);
});

dbTest('a reversed entry stops counting as revenue', async (world) => {
  await makeParcel(world.tx, { subtotal: '100000', commission: '10000' });
  await world.ledger.post(
    {
      type: JournalEntryType.COMMISSION_EARNED,
      reference: `ec:reversible:${uniq('r')}`,
      description: 'اختبار',
      lines: [
        {
          account: { code: LedgerAccountCode.PLATFORM_CASH },
          direction: LedgerDirection.DEBIT,
          amount: syp('10000'),
        },
        {
          account: { code: LedgerAccountCode.COMMISSION_REVENUE },
          direction: LedgerDirection.CREDIT,
          amount: syp('10000'),
        },
      ],
    },
    world.tx,
  );

  const before = await world.economics.overview(world.window);
  assert.equal(amountOf(before.platform.revenue), 10000);

  // Refunding the order reverses the settlement. Commission the platform gave
  // back must stop reading as commission the platform kept.
  const entry = await world.tx.journalEntry.findFirstOrThrow({
    where: { description: 'اختبار', reversedBy: null, reversesId: null },
    orderBy: { createdAt: 'desc' },
  });
  await world.ledger.reverse(entry.id, 'اختبار الاسترداد', {}, world.tx);

  const after = await world.economics.overview(world.window);
  assert.equal(
    amountOf(after.platform.revenue),
    0,
    'a reversed settlement and its mirror net to nothing',
  );
});
