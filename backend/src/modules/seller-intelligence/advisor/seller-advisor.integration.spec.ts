import assert from 'node:assert/strict';
import test from 'node:test';
import {
  AnalyticsEventType,
  Currency,
  OfferStatus,
  OrderStatus,
  PrismaClient,
  ProductStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';
import { SellerAdvisorService } from './seller-advisor.service';

/**
 * The advisor against real rows.
 *
 * The kernel tests prove which cause is named. These prove the harder half:
 * that the two windows are read from the tables correctly, that a competitor's
 * price is found on the shared product page rather than on her own listing,
 * and that one boutique can never diagnose another's.
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
  advisor: SellerAdvisorService;
}

function build(tx: Tx): World {
  return { tx, advisor: new SellerAdvisorService(asPrisma(tx)) };
}

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;
const daysAgo = (n: number) => new Date(Date.now() - n * 86_400_000);

async function makeUser(tx: Tx, role: UserRole) {
  const u = uniq();
  return tx.user.create({
    data: {
      name: role === UserRole.SELLER ? 'بوتيك' : 'أوهارا',
      username: `ad_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

/** One product with the given boutique's offer on it. */
async function listProduct(
  tx: Tx,
  sellerId: string,
  over: { price?: string; stock?: number } = {},
) {
  const u = uniq();
  const category = await tx.category.create({
    data: { slug: `ad-cat-${u}`, nameAr: 'فئة', nameEn: 'Cat' },
  });
  const product = await tx.product.create({
    data: {
      slug: `ad-prod-${u}`,
      title: 'فستان سهرة',
      description: 'وصف',
      categoryId: category.id,
      status: ProductStatus.ACTIVE,
      offers: {
        create: {
          sellerId,
          currency: Currency.SYP,
          price: over.price ?? '100000',
          priceSyp: over.price ?? '100000',
          stock: over.stock ?? 10,
          status: OfferStatus.ACTIVE,
          isActive: true,
        },
      },
    },
  });
  return { product, categoryId: category.id };
}

/** A second boutique listing the same product, cheaper. */
async function addRivalOffer(
  tx: Tx,
  productId: string,
  sellerId: string,
  price: string,
) {
  return tx.sellerOffer.create({
    data: {
      productId,
      sellerId,
      currency: Currency.SYP,
      price,
      priceSyp: price,
      stock: 20,
      status: OfferStatus.ACTIVE,
      isActive: true,
    },
  });
}

async function sell(
  tx: Tx,
  sellerId: string,
  customerId: string,
  productId: string,
  when: Date,
) {
  const u = uniq();
  const order = await tx.order.create({
    data: {
      number: `AD-${u.slice(-10)}`,
      userId: customerId,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: '100000',
      discountTotal: '0',
      shippingTotal: '0',
      grandTotal: '100000',
      recipientName: 'ريم',
      recipientPhone: `+96386${u.slice(-7)}`,
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      createdAt: when,
    },
  });
  await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `AD-SO-${u.slice(-10)}`,
      sellerId,
      status: SellerOrderStatus.DELIVERED,
      currency: Currency.SYP,
      itemsSubtotal: '100000',
      discountTotal: '0',
      shippingCost: '0',
      commissionBase: '100000',
      commissionAmount: '0',
      sellerNet: '100000',
      createdAt: when,
      deliveredAt: when,
      items: {
        create: {
          productId,
          titleSnapshot: 'فستان',
          sellerSnapshot: 'بوتيك',
          currency: Currency.SYP,
          unitPrice: '100000',
          quantity: 1,
          lineTotal: '100000',
        },
      },
    },
  });
}

async function views(tx: Tx, productId: string, when: Date, count: number) {
  for (let i = 0; i < count; i += 1) {
    await tx.analyticsEvent.create({
      data: {
        type: AnalyticsEventType.PRODUCT_VIEW,
        productId,
        occurredAt: when,
      },
    });
  }
}

// ── The path ─────────────────────────────────────────────────────────────────

dbTest('a listing nobody looked at gets an honest refusal', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const { product } = await listProduct(world.tx, seller.id);

  const result = await world.advisor.diagnoseListing(seller.id, product.id);
  assert.ok(result);
  assert.equal(result.diagnosis.code, 'insufficient_evidence');
});

dbTest('a steady listing is told it has not declined', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const buyer = await makeUser(world.tx, UserRole.CUSTOMER);
  const { product } = await listProduct(world.tx, seller.id);

  await views(world.tx, product.id, daysAgo(10), 20);
  await views(world.tx, product.id, daysAgo(45), 20);
  for (const ago of [5, 10, 15]) {
    await sell(world.tx, seller.id, buyer.id, product.id, daysAgo(ago));
  }
  for (const ago of [35, 40, 45]) {
    await sell(world.tx, seller.id, buyer.id, product.id, daysAgo(ago));
  }

  const result = await world.advisor.diagnoseListing(seller.id, product.id);
  assert.equal(result?.diagnosis.code, 'not_declining');
});

dbTest('being undercut is found on the shared page, not her own offer', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const rival = await makeUser(world.tx, UserRole.SELLER);
  const buyer = await makeUser(world.tx, UserRole.CUSTOMER);

  const { product } = await listProduct(world.tx, seller.id, {
    price: '150000',
  });
  await addRivalOffer(world.tx, product.id, rival.id, '80000');

  await views(world.tx, product.id, daysAgo(10), 25);
  await views(world.tx, product.id, daysAgo(45), 25);
  // Was selling, now is not.
  for (const ago of [35, 40, 45, 50] as const) {
    await sell(world.tx, seller.id, buyer.id, product.id, daysAgo(ago));
  }

  const result = await world.advisor.diagnoseListing(seller.id, product.id);
  assert.equal(result?.diagnosis.code, 'undercut');
  assert.ok(
    result.diagnosis.ar.includes('80,000'),
    'the rival price comes from the product page she shares, not her own listing',
  );
});

dbTest('an empty shelf outranks every other explanation', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const rival = await makeUser(world.tx, UserRole.SELLER);
  const buyer = await makeUser(world.tx, UserRole.CUSTOMER);

  const { product } = await listProduct(world.tx, seller.id, {
    price: '150000',
    stock: 0,
  });
  await addRivalOffer(world.tx, product.id, rival.id, '80000');

  await views(world.tx, product.id, daysAgo(10), 25);
  await views(world.tx, product.id, daysAgo(45), 25);
  for (const ago of [35, 40, 45, 50]) {
    await sell(world.tx, seller.id, buyer.id, product.id, daysAgo(ago));
  }

  const result = await world.advisor.diagnoseListing(seller.id, product.id);
  assert.equal(
    result?.diagnosis.code,
    'out_of_stock',
    'no price analysis matters for the days there was nothing to sell',
  );
});

dbTest('fewer viewers with the same conversion reads as visibility', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const buyer = await makeUser(world.tx, UserRole.CUSTOMER);
  const { product } = await listProduct(world.tx, seller.id);

  // Views halved; the proportion buying held.
  await views(world.tx, product.id, daysAgo(45), 80);
  await views(world.tx, product.id, daysAgo(10), 20);
  for (const ago of [32, 36, 40, 44]) {
    await sell(world.tx, seller.id, buyer.id, product.id, daysAgo(ago));
  }
  await sell(world.tx, seller.id, buyer.id, product.id, daysAgo(8));

  const result = await world.advisor.diagnoseListing(seller.id, product.id);
  assert.equal(result?.diagnosis.code, 'lost_visibility');
});

// ── Scope ────────────────────────────────────────────────────────────────────

dbTest('one boutique cannot diagnose another’s listing', async (world) => {
  const mine = await makeUser(world.tx, UserRole.SELLER);
  const hers = await makeUser(world.tx, UserRole.SELLER);
  const { product } = await listProduct(world.tx, hers.id);

  assert.equal(
    await world.advisor.diagnoseListing(mine.id, product.id),
    null,
    'a diagnosis names competitors and prices — it is not hers to read',
  );
});

dbTest('the declining list only holds listings that were selling', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const buyer = await makeUser(world.tx, UserRole.CUSTOMER);

  // Sold four times last window, once this window: a real decline.
  const fell = await listProduct(world.tx, seller.id);
  await views(world.tx, fell.product.id, daysAgo(45), 40);
  await views(world.tx, fell.product.id, daysAgo(10), 40);
  for (const ago of [33, 38, 43, 48]) {
    await sell(world.tx, seller.id, buyer.id, fell.product.id, daysAgo(ago));
  }

  // Never sold at all: nothing to diagnose, only something to fix.
  await listProduct(world.tx, seller.id);

  const rows = await world.advisor.decliningListings(seller.id, 10);
  const ids = rows.map((row) => row.product_id);

  assert.ok(ids.includes(fell.product.id));
  assert.equal(
    ids.length,
    1,
    'a listing that never sold belongs to product health, not to the advisor',
  );
  assert.ok(rows[0].diagnosis.action.length > 0);
});
