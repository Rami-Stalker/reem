import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  OrderStatus,
  PrismaClient,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { SellerCrmService } from './seller-crm.service';

/**
 * A boutique's own customer book.
 *
 * The dashboard could say what sold and how the shop was rated. It could not
 * say *who* — how many buyers came back, who spent the most, who has stopped.
 * These check the two figures a shopkeeper actually steers by, and that she is
 * only ever shown her own trade.
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
  crm: SellerCrmService;
}

function build(tx: Tx): World {
  return { tx, crm: new SellerCrmService(asPrisma(tx)) };
}

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;
const daysAgo = (n: number) => new Date(Date.now() - n * 86_400_000);

async function makeUser(tx: Tx, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq();
  return tx.user.create({
    data: {
      name: role === UserRole.SELLER ? 'بوتيك' : 'أوهارا',
      username: `crm_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

/** One delivered parcel from a boutique to a customer. */
async function sell(
  tx: Tx,
  sellerId: string,
  customerId: string,
  when: Date,
  subtotal = '50000',
) {
  const u = uniq();
  const order = await tx.order.create({
    data: {
      number: `CRM-${u.slice(-10)}`,
      userId: customerId,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: subtotal,
      discountTotal: '0',
      shippingTotal: '0',
      grandTotal: subtotal,
      recipientName: 'ريم',
      recipientPhone: `+96393${u.slice(-7)}`,
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      createdAt: when,
    },
  });

  return tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `CRM-SO-${u.slice(-10)}`,
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
      items: {
        create: {
          titleSnapshot: 'قطعة',
          sellerSnapshot: 'بوتيك',
          currency: Currency.SYP,
          unitPrice: subtotal,
          quantity: 1,
          lineTotal: subtotal,
        },
      },
    },
  });
}

dbTest('a boutique sees who bought from her, biggest first', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const big = await makeUser(world.tx);
  const small = await makeUser(world.tx);

  await sell(world.tx, seller.id, big.id, daysAgo(30), '200000');
  await sell(world.tx, seller.id, small.id, daysAgo(20), '30000');

  const { data, total } = await world.crm.customers(seller.id, {
    limit: 20,
    skip: 0,
  });

  assert.equal(total, 2);
  assert.equal(data[0].userId, big.id, 'ordered by what she spent');
  assert.equal(Number(data[0].spend.toJSON().amount), 200000);
  assert.equal(data[0].orders, 1);
});

dbTest('a customer who came back reads as repeat', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const loyal = await makeUser(world.tx);
  const once = await makeUser(world.tx);

  await sell(world.tx, seller.id, loyal.id, daysAgo(40));
  await sell(world.tx, seller.id, loyal.id, daysAgo(10));
  await sell(world.tx, seller.id, once.id, daysAgo(15));

  const { data } = await world.crm.customers(seller.id, { limit: 20, skip: 0 });
  const hers = data.find((row) => row.userId === loyal.id);
  const other = data.find((row) => row.userId === once.id);

  assert.equal(hers?.orders, 2);
  assert.equal(hers?.isRepeat, true);
  assert.equal(other?.isRepeat, false);
});

dbTest('a customer who stopped buying from her is marked lapsed', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const gone = await makeUser(world.tx);
  const current = await makeUser(world.tx);

  await sell(world.tx, seller.id, gone.id, daysAgo(200));
  await sell(world.tx, seller.id, current.id, daysAgo(5));

  const { data } = await world.crm.customers(seller.id, { limit: 20, skip: 0 });
  assert.equal(data.find((row) => row.userId === gone.id)?.isLapsed, true);
  assert.equal(data.find((row) => row.userId === current.id)?.isLapsed, false);
});

dbTest('one boutique never sees another’s customers', async (world) => {
  const mine = await makeUser(world.tx, UserRole.SELLER);
  const hers = await makeUser(world.tx, UserRole.SELLER);
  const myBuyer = await makeUser(world.tx);
  const herBuyer = await makeUser(world.tx);

  await sell(world.tx, mine.id, myBuyer.id, daysAgo(10));
  await sell(world.tx, hers.id, herBuyer.id, daysAgo(10));

  const { data } = await world.crm.customers(mine.id, { limit: 50, skip: 0 });
  assert.ok(data.some((row) => row.userId === myBuyer.id));
  assert.ok(
    !data.some((row) => row.userId === herBuyer.id),
    'a customer book is her own trade, and only that',
  );
});

dbTest('repeat rate is the figure a shopkeeper steers by', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const a = await makeUser(world.tx);
  const b = await makeUser(world.tx);
  const c = await makeUser(world.tx);
  const d = await makeUser(world.tx);

  // Four customers, one of whom came back.
  await sell(world.tx, seller.id, a.id, daysAgo(40));
  await sell(world.tx, seller.id, a.id, daysAgo(10));
  for (const buyer of [b, c, d]) {
    await sell(world.tx, seller.id, buyer.id, daysAgo(20));
  }

  const overview = await world.crm.overview(seller.id);
  assert.equal(overview.customers, 4);
  assert.equal(overview.repeat_customers, 1);
  assert.equal(overview.repeat_rate, 0.25);
  assert.equal(overview.orders, 5);
});

dbTest('a shop with no customers has no repeat rate, rather than zero', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const overview = await world.crm.overview(seller.id);

  assert.equal(overview.customers, 0);
  assert.equal(
    overview.repeat_rate,
    null,
    '"no rate" and "a rate of nothing" say different things about a new shop',
  );
});

dbTest('a boutique that has gone quiet is surfaced for a phone call', async (world) => {
  const quiet = await makeUser(world.tx, UserRole.SELLER);
  const busy = await makeUser(world.tx, UserRole.SELLER);
  const buyer = await makeUser(world.tx);

  await sell(world.tx, quiet.id, buyer.id, daysAgo(120));
  await sell(world.tx, busy.id, buyer.id, daysAgo(2));

  const rows = await world.crm.quietSellers({ quietDays: 45, limit: 200 });
  const ids = rows.map((row) => row.seller_id);

  assert.ok(ids.includes(quiet.id), 'four months of silence is a lost shop');
  assert.ok(!ids.includes(busy.id));
});

dbTest('a boutique that never sold is not a retention problem', async (world) => {
  const neverSold = await makeUser(world.tx, UserRole.SELLER);

  const rows = await world.crm.quietSellers({ quietDays: 45, limit: 200 });
  assert.ok(
    !rows.some((row) => row.seller_id === neverSold.id),
    'that is an onboarding problem, and belongs on a different screen',
  );
});
