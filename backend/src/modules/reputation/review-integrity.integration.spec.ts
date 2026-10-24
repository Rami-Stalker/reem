import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  OrderStatus,
  PrismaClient,
  ProductStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { MediaService } from '../media/media.service';
import { FitProfileService } from './fit/fit-profile.service';
import { ReputationService } from './reputation.service';

/**
 * Who may rate a garment, and how often.
 *
 * `order_id` used to be optional on a review, and without it the row was
 * written anyway with `verifiedPurchase: false`. So any account could rate any
 * product it had never bought, and any boutique it had never bought from, with
 * moderation as the only thing between the catalogue and a competitor running
 * a script. The duplicate check made it worse rather than better: the unique
 * key was `(product_id, user_id, order_id)` and Postgres treats NULLs as
 * distinct, so an unverified review never collided with itself.
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
  reputation: ReputationService;
}

/**
 * These cases attach no photographs, so the media service is never asked
 * anything. A review with photographs is covered in
 * `fit-reviews.integration.spec.ts`.
 */
const noMedia = {
  resolveAssetId: async () => null,
  markAttached: async () => 0,
} as unknown as MediaService;

function build(tx: Tx): World {
  const db = asPrisma(tx);
  return {
    tx,
    reputation: new ReputationService(db, new FitProfileService(db), noMedia),
  };
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const phone = () =>
  `+9639${Math.floor(10_000_000 + Math.random() * 89_999_999)}`;

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `rv-${tag}`,
      username: `rv_${u}`,
      phone: phone(),
      passwordHash: 'x',
      role,
    },
  });
}

async function makeProduct(tx: Tx, sellerId: string) {
  const u = uniq('p');
  const category = await tx.category.create({
    data: { slug: `rv-cat-${u}`, nameAr: 'فئة', nameEn: 'Cat' },
  });
  return tx.product.create({
    data: {
      slug: `rv-prod-${u}`,
      title: 'فستان',
      description: 'اختبار',
      categoryId: category.id,
      status: ProductStatus.ACTIVE,
      createdBySellerId: sellerId,
    },
  });
}

/** An order that reached her door, or one that did not. */
async function makeOrder(
  tx: Tx,
  ids: { customerId: string; sellerId: string; productId: string },
  status: SellerOrderStatus,
) {
  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-12)}`,
      userId: ids.customerId,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: '100000',
      shippingTotal: '0',
      grandTotal: '100000',
      recipientName: 'ريم',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      sellerOrders: {
        create: {
          number: `SO-${uniq('s').slice(-12)}`,
          sellerId: ids.sellerId,
          status,
          currency: Currency.SYP,
          itemsSubtotal: '100000',
          shippingCost: '0',
          commissionBase: '100000',
          commissionAmount: '10000',
          sellerNet: '90000',
          items: {
            create: {
              productId: ids.productId,
              titleSnapshot: 'فستان',
              sellerSnapshot: 'بائعة',
              currency: Currency.SYP,
              unitPrice: '100000',
              quantity: 1,
              lineTotal: '100000',
            },
          },
        },
      },
    },
  });
  return order;
}

const review = { rating: 5, title: 'جميل', body: 'أعجبني' };

// ── Only a buyer may speak ──────────────────────────────────────────────

dbTest('a woman who received the dress may review it', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const customer = await makeUser(world.tx, 'cus');
  const product = await makeProduct(world.tx, seller.id);
  await makeOrder(
    world.tx,
    { customerId: customer.id, sellerId: seller.id, productId: product.id },
    SellerOrderStatus.DELIVERED,
  );

  const written = await world.reputation.createProductReview(
    customer.id,
    product.id,
    review,
  );
  assert.ok(written);

  const row = await world.tx.productReview.findFirstOrThrow({
    where: { productId: product.id, userId: customer.id },
  });
  assert.equal(row.verifiedPurchase, true);
  assert.ok(row.orderId, 'and the order is recorded, resolved by the server');
});

dbTest('a stranger who bought nothing is refused', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const stranger = await makeUser(world.tx, 'cus');
  const product = await makeProduct(world.tx, seller.id);

  await assert.rejects(
    world.reputation.createProductReview(stranger.id, product.id, review),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'REVIEW_REQUIRES_PURCHASE',
    'this is the scripted-competitor case, and it used to succeed',
  );
});

dbTest('a parcel still in transit earns no review yet', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const customer = await makeUser(world.tx, 'cus');
  const product = await makeProduct(world.tx, seller.id);
  await makeOrder(
    world.tx,
    { customerId: customer.id, sellerId: seller.id, productId: product.id },
    SellerOrderStatus.IN_TRANSIT,
  );

  await assert.rejects(
    world.reputation.createProductReview(customer.id, product.id, review),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'REVIEW_REQUIRES_PURCHASE',
    'she has not seen the garment, so she has nothing to say about it yet',
  );
});

dbTest("naming somebody else's order buys nothing", async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const buyer = await makeUser(world.tx, 'buyer');
  const stranger = await makeUser(world.tx, 'stranger');
  const product = await makeProduct(world.tx, seller.id);
  const hers = await makeOrder(
    world.tx,
    { customerId: buyer.id, sellerId: seller.id, productId: product.id },
    SellerOrderStatus.DELIVERED,
  );

  // The hint is a real delivered order — just not this caller's. The server
  // resolves the order itself rather than trusting the body, so it finds
  // nothing of the stranger's and refuses.
  await assert.rejects(
    world.reputation.createProductReview(stranger.id, product.id, {
      ...review,
      order_id: hers.id,
    }),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'REVIEW_REQUIRES_PURCHASE',
  );
});

// ── One voice ───────────────────────────────────────────────────────────

dbTest('she cannot review the same dress twice', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const customer = await makeUser(world.tx, 'cus');
  const product = await makeProduct(world.tx, seller.id);
  await makeOrder(
    world.tx,
    { customerId: customer.id, sellerId: seller.id, productId: product.id },
    SellerOrderStatus.DELIVERED,
  );

  await world.reputation.createProductReview(customer.id, product.id, review);
  await assert.rejects(
    world.reputation.createProductReview(customer.id, product.id, review),
    /already reviewed/i,
  );
});

dbTest('the database refuses a duplicate even without the check', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const customer = await makeUser(world.tx, 'cus');
  const product = await makeProduct(world.tx, seller.id);
  const order = await makeOrder(
    world.tx,
    { customerId: customer.id, sellerId: seller.id, productId: product.id },
    SellerOrderStatus.DELIVERED,
  );

  await world.tx.productReview.create({
    data: { productId: product.id, userId: customer.id, orderId: order.id, rating: 5 },
  });

  // Written straight past the service, the way a second concurrent request
  // would arrive. The old key included `order_id`, and a NULL there is
  // distinct from itself in Postgres — so this used to succeed.
  await assert.rejects(
    world.tx.productReview.create({
      data: { productId: product.id, userId: customer.id, orderId: null, rating: 1 },
    }),
    /Unique constraint/i,
  );
});

// ── Boutiques ───────────────────────────────────────────────────────────

dbTest('a boutique may be rated only by somebody it delivered to', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const customer = await makeUser(world.tx, 'cus');
  const stranger = await makeUser(world.tx, 'other');
  const product = await makeProduct(world.tx, seller.id);
  await makeOrder(
    world.tx,
    { customerId: customer.id, sellerId: seller.id, productId: product.id },
    SellerOrderStatus.DELIVERED,
  );

  await world.reputation.createSellerReview(customer.id, seller.id, review);

  await assert.rejects(
    world.reputation.createSellerReview(stranger.id, seller.id, review),
    (error: { response?: { code?: string } }) =>
      error.response?.code === 'REVIEW_REQUIRES_PURCHASE',
  );
});

dbTest('a seller still cannot review herself', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  await assert.rejects(
    world.reputation.createSellerReview(seller.id, seller.id, review),
    /cannot review themselves/i,
  );
});

// ── Moderation is unchanged ─────────────────────────────────────────────

dbTest('a new review is still not published until it is approved', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const customer = await makeUser(world.tx, 'cus');
  const product = await makeProduct(world.tx, seller.id);
  await makeOrder(
    world.tx,
    { customerId: customer.id, sellerId: seller.id, productId: product.id },
    SellerOrderStatus.DELIVERED,
  );

  await world.reputation.createProductReview(customer.id, product.id, review);
  const row = await world.tx.productReview.findFirstOrThrow({
    where: { productId: product.id, userId: customer.id },
  });
  assert.equal(
    row.status,
    'PENDING',
    'a verified purchase earns her a voice, not an unmoderated one',
  );
});
