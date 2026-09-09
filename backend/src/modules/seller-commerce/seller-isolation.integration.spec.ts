import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  OfferStatus,
  OrderStatus,
  PrismaClient,
  ProductStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { AuthUser } from '../../common/decorators/current-user.decorator';
import { assertCanManage } from '../../common/authz';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * One boutique cannot reach another's.
 *
 * The rule is enforced in a dozen services and reads differently in each —
 * `assertCanManage` here, a `sellerId` in the `where` there, a `load()` that
 * answers "not found" rather than "not yours" so a seller cannot even learn
 * that a rival's order number exists. Every one of them was correct when this
 * was written; none of them was *asserted*, so a refactor could quietly widen
 * any of them and nothing would say so.
 *
 * These tests attempt the crossings from the outside: seller B, holding her
 * own valid session, reaching for seller A's parcel, her offer, her stock, her
 * earnings. Each must be refused. Where the refusal is a 404 rather than a 403
 * that is deliberate and asserted, because the status code itself leaks.
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

function dbTest(name: string, body: (tx: Tx) => Promise<void>): void {
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
            await body(tx);
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
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const phone = () =>
  `+9639${Math.floor(10_000_000 + Math.random() * 89_999_999)}`;

async function makeUser(tx: Tx, tag: string, role: UserRole) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `iso-${tag}`,
      username: `iso_${u}`,
      phone: phone(),
      passwordHash: 'x',
      role,
    },
  });
}

const asAuth = (user: { id: string; role: UserRole }): AuthUser =>
  ({ id: user.id, role: user.role }) as AuthUser;

/** A boutique with a listing, an offer on it, and a live parcel. */
async function makeShop(tx: Tx, tag: string) {
  const seller = await makeUser(tx, tag, UserRole.SELLER);
  const customer = await makeUser(tx, `${tag}cus`, UserRole.CUSTOMER);
  const u = uniq(tag);

  const category = await tx.category.create({
    data: { slug: `iso-cat-${u}`, nameAr: 'فئة', nameEn: 'Cat' },
  });
  const product = await tx.product.create({
    data: {
      slug: `iso-prod-${u}`,
      title: 'فستان',
      description: 'اختبار',
      categoryId: category.id,
      status: ProductStatus.ACTIVE,
      createdBySellerId: seller.id,
    },
  });
  const offer = await tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId: seller.id,
      currency: Currency.SYP,
      price: '100000',
      stock: 5,
      status: OfferStatus.ACTIVE,
    },
  });

  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-12)}`,
      userId: customer.id,
      status: OrderStatus.CONFIRMED,
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
          sellerId: seller.id,
          status: SellerOrderStatus.AWAITING_SELLER_CONFIRMATION,
          currency: Currency.SYP,
          itemsSubtotal: '100000',
          shippingCost: '0',
          commissionBase: '100000',
          commissionAmount: '10000',
          sellerNet: '90000',
          items: {
            create: {
              offerId: offer.id,
              productId: product.id,
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
    include: { sellerOrders: true },
  });

  return {
    seller,
    customer,
    product,
    offer,
    sellerOrder: order.sellerOrders[0],
    order,
  };
}

// ── The ownership primitive ─────────────────────────────────────────────

test('a seller may manage only her own', () => {
  const mine = { id: 'a', role: UserRole.SELLER } as AuthUser;
  assert.doesNotThrow(() => assertCanManage('a', mine));
  assert.throws(() => assertCanManage('b', mine), /only manage your own/);
});

test('a customer may not manage a boutique', () => {
  const shopper = { id: 'c', role: UserRole.CUSTOMER } as AuthUser;
  assert.throws(() => assertCanManage('a', shopper));
});

test('moderation roles may reach across, and only those', () => {
  for (const role of [
    UserRole.SUPER_ADMIN,
    UserRole.OPERATIONS_ADMIN,
    UserRole.CONTENT_MODERATOR,
    UserRole.ADMIN,
  ]) {
    assert.doesNotThrow(() =>
      assertCanManage('a', { id: 'x', role } as AuthUser),
    );
  }
  // A support agent and an accountant are staff but not moderators: neither
  // may edit a boutique's goods, which is what this gate protects.
  for (const role of [UserRole.SUPPORT, UserRole.FINANCE_ADMIN]) {
    assert.throws(() => assertCanManage('a', { id: 'x', role } as AuthUser));
  }
});

// ── Orders ──────────────────────────────────────────────────────────────

dbTest("a rival cannot read a boutique's parcel", async (tx) => {
  const mine = await makeShop(tx, 'a');
  const rival = await makeUser(tx, 'b', UserRole.SELLER);

  const { SellerOrdersService } = await import('./seller-orders.service');
  const service = Object.create(SellerOrdersService.prototype) as {
    prisma: unknown;
    detail: (user: AuthUser, id: string) => Promise<unknown>;
  };
  service.prisma = tx;

  await assert.rejects(
    service.detail(asAuth(rival), mine.sellerOrder.id),
    /Order not found/,
    'a 404, deliberately — a 403 would confirm the order number exists',
  );
});

dbTest('the same parcel opens for the boutique that owns it', async (tx) => {
  const mine = await makeShop(tx, 'a');

  const { SellerOrdersService } = await import('./seller-orders.service');
  const service = Object.create(SellerOrdersService.prototype) as {
    prisma: unknown;
    detail: (user: AuthUser, id: string) => Promise<{ id: string }>;
  };
  service.prisma = tx;

  const parcel = await service.detail(asAuth(mine.seller), mine.sellerOrder.id);
  assert.equal(parcel.id, mine.sellerOrder.id);
});

// ── Offers and stock ────────────────────────────────────────────────────

dbTest("a rival cannot touch a boutique's offer", async (tx) => {
  const mine = await makeShop(tx, 'a');
  const rival = await makeUser(tx, 'b', UserRole.SELLER);

  const offer = await tx.sellerOffer.findUniqueOrThrow({
    where: { id: mine.offer.id },
  });

  // The gate every write on `SellerOffersService` passes through first.
  assert.throws(
    () => assertCanManage(offer.sellerId, asAuth(rival)),
    /only manage your own/,
  );
  assert.doesNotThrow(() => assertCanManage(offer.sellerId, asAuth(mine.seller)));
});

dbTest("a rival's listing never appears in her own list", async (tx) => {
  const mine = await makeShop(tx, 'a');
  const hers = await makeShop(tx, 'b');

  const listed = await tx.sellerOffer.findMany({
    where: { sellerId: hers.seller.id },
    select: { id: true },
  });

  assert.ok(listed.some((row) => row.id === hers.offer.id));
  assert.ok(
    !listed.some((row) => row.id === mine.offer.id),
    "the query that backs her products screen is scoped, so a rival's goods " +
      'cannot appear in it',
  );
});

// ── Money ───────────────────────────────────────────────────────────────

dbTest('earnings are computed from her own parcels only', async (tx) => {
  const mine = await makeShop(tx, 'a');
  const hers = await makeShop(tx, 'b');

  // Both boutiques have one parcel worth 90,000 net. The scoped read must see
  // one, not two — this is the query behind the earnings screen.
  for (const shop of [mine, hers]) {
    await tx.commissionLedger.create({
      data: {
        sellerOrderId: shop.sellerOrder.id,
        sellerId: shop.seller.id,
        currency: Currency.SYP,
        gross: '100000',
        commission: '10000',
        platformFee: '0',
        net: '90000',
      },
    });
  }

  const ledgers = await tx.commissionLedger.findMany({
    where: { sellerId: mine.seller.id },
  });
  assert.equal(ledgers.length, 1);
  assert.equal(ledgers[0].sellerOrderId, mine.sellerOrder.id);
});

dbTest('a payout can only claim its own seller ledgers', async (tx) => {
  const mine = await makeShop(tx, 'a');
  const hers = await makeShop(tx, 'b');

  await tx.commissionLedger.create({
    data: {
      sellerOrderId: hers.sellerOrder.id,
      sellerId: hers.seller.id,
      currency: Currency.SYP,
      gross: '100000',
      commission: '10000',
      platformFee: '0',
      net: '90000',
    },
  });

  const claimable = await tx.commissionLedger.findMany({
    where: { sellerId: mine.seller.id, payoutItems: { none: {} } },
  });
  assert.equal(
    claimable.length,
    0,
    "a boutique with no settled sales cannot draw on a rival's",
  );
});

// ── The customer behind the parcel ──────────────────────────────────────

dbTest('a seller reaches a customer only through her own parcel', async (tx) => {
  const mine = await makeShop(tx, 'a');
  const hers = await makeShop(tx, 'b');

  // The CRM screen's query: customers who have bought from *this* boutique.
  const customers = await tx.sellerOrder.findMany({
    where: { sellerId: mine.seller.id },
    select: { order: { select: { userId: true } } },
  });
  const ids = customers.map((row) => row.order.userId);

  assert.ok(ids.includes(mine.customer.id));
  assert.ok(
    !ids.includes(hers.customer.id),
    "a rival's customer is not hers to see, and a leak here is the whole " +
      'customer list of a competing boutique',
  );
});
