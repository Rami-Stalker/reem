import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  OfferStatus,
  PrismaClient,
  ProductStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { TrendSignalService } from '../trends/collection/trend-signal.service';
import { CartRepository } from './cart.repository';
import { CartService } from './cart.service';

/**
 * The basket, which is the one screen a woman fills before she spends money.
 *
 * It had no spec of its own. Checkout, oversell, expiry and idempotency all
 * have theirs and all of them start from a basket that was assembled correctly
 * — so the rules that decide what may go into it, and whose it is, were the
 * least-asserted part of the purchase path.
 *
 * Four things are pinned here, each because getting it wrong is visible to a
 * customer rather than to a log:
 *
 *   - **The stock ceiling holds across adds.** Adding three and then three more
 *     is six against a shelf of five, and checking each add on its own would
 *     let it through. The oversell guarantee at checkout would still catch it,
 *     but only after she had filled a basket she could never buy.
 *   - **A seller's minimum and maximum are about the line, not the tap.** Same
 *     shape, opposite direction, and the one a refactor is likeliest to reduce
 *     to a per-request check.
 *   - **A listing that has been withdrawn cannot be added.** She should be told
 *     at the moment she taps, not at the till.
 *   - **One basket is one person's.** A cart item id is a uuid in a URL, and
 *     `updateItem`/`removeItem` take it straight from the client.
 *
 * Every case runs inside a transaction that is rolled back, so the shop is
 * unchanged afterwards.
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
        return async (fn: unknown) => {
          if (Array.isArray(fn)) return Promise.all(fn);
          return (fn as (inner: Tx) => unknown)(tx);
        };
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

interface World {
  tx: Tx;
  db: PrismaService;
  cart: CartService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  // The real signal service: `recordCartAdd` is fire-and-forget, and stubbing it
  // would hide a throw inside it that would reach the customer as a failed add.
  const signals = new TrendSignalService(db);
  return { tx, db, cart: new CartService(new CartRepository(db), db, signals) };
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const phone = () => `+9639${Math.floor(10000000 + Math.random() * 89999999)}`;

async function makeCustomer(tx: Tx, tag: string) {
  return tx.user.create({
    data: {
      name: `عميلة ${tag}`,
      username: uniq(tag),
      phone: phone(),
      role: UserRole.CUSTOMER,
      isVerified: true,
    },
  });
}

/** A live listing with whatever shelf and limits the case needs. */
async function makeOffer(
  tx: Tx,
  options: {
    stock?: number;
    minOrderQty?: number;
    maxOrderQty?: number | null;
    status?: OfferStatus;
    isActive?: boolean;
  } = {},
) {
  const seller = await tx.user.create({
    data: {
      name: 'بوتيك',
      username: uniq('sel'),
      phone: phone(),
      role: UserRole.SELLER,
    },
  });
  const category = await tx.category.create({
    data: { slug: `cat-${uniq('c')}`, nameAr: 'فساتين', nameEn: 'Dresses' },
  });
  const product = await tx.product.create({
    data: {
      slug: `prod-${uniq('p')}`,
      title: 'فستان سهرة',
      description: 'للاختبار',
      categoryId: category.id,
      status: ProductStatus.ACTIVE,
    },
  });
  return tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId: seller.id,
      currency: Currency.SYP,
      price: '50000',
      stock: options.stock ?? 5,
      minOrderQty: options.minOrderQty ?? 1,
      maxOrderQty: options.maxOrderQty ?? null,
      status: options.status ?? OfferStatus.ACTIVE,
      isActive: options.isActive ?? true,
    },
  });
}

// ── The shelf ───────────────────────────────────────────────────────────────

dbTest('the stock ceiling holds across separate adds, not just within one', async (world) => {
  // Three, then three more, against a shelf of five. Checking each add on its
  // own lets this through and hands her a basket she can never buy.
  const buyer = await makeCustomer(world.tx, 'a');
  const offer = await makeOffer(world.tx, { stock: 5 });

  await world.cart.addItem(buyer.id, { offer_id: offer.id, quantity: 3 });

  await assert.rejects(
    world.cart.addItem(buyer.id, { offer_id: offer.id, quantity: 3 }),
    /Only 5 in stock/,
  );

  const cart = await world.cart.getCart(buyer.id);
  assert.equal(cart.items.length, 1);
  assert.equal(cart.items[0].quantity, 3, 'the refused add changed nothing');
});

dbTest('an empty shelf says so, rather than quoting a number', async (world) => {
  const buyer = await makeCustomer(world.tx, 'b');
  const offer = await makeOffer(world.tx, { stock: 0 });

  await assert.rejects(
    world.cart.addItem(buyer.id, { offer_id: offer.id, quantity: 1 }),
    /out of stock/i,
  );
});

// ── The seller's limits ─────────────────────────────────────────────────────

dbTest("a seller's minimum is about the line, not the tap", async (world) => {
  // Two singles must satisfy a minimum of two. The rule is a property of the
  // line she ends up with, and reading it as "at least two per request" is the
  // shape a refactor falls into.
  const buyer = await makeCustomer(world.tx, 'c');
  const offer = await makeOffer(world.tx, { minOrderQty: 2, stock: 10 });

  await assert.rejects(
    world.cart.addItem(buyer.id, { offer_id: offer.id, quantity: 1 }),
    /at least 2/,
  );

  await world.cart.addItem(buyer.id, { offer_id: offer.id, quantity: 2 });
  const cart = await world.cart.getCart(buyer.id);
  assert.equal(cart.items[0].quantity, 2);
});

dbTest("a seller's maximum counts what is already in the basket", async (world) => {
  const buyer = await makeCustomer(world.tx, 'd');
  const offer = await makeOffer(world.tx, { maxOrderQty: 3, stock: 20 });

  await world.cart.addItem(buyer.id, { offer_id: offer.id, quantity: 2 });
  await assert.rejects(
    world.cart.addItem(buyer.id, { offer_id: offer.id, quantity: 2 }),
    /at most 3/,
  );

  // And exactly the maximum is allowed, which is the off-by-one this pins.
  await world.cart.addItem(buyer.id, { offer_id: offer.id, quantity: 1 });
  const cart = await world.cart.getCart(buyer.id);
  assert.equal(cart.items[0].quantity, 3);
});

// ── A listing that is no longer for sale ────────────────────────────────────

dbTest('a withdrawn listing is refused at the tap, not at the till', async (world) => {
  const buyer = await makeCustomer(world.tx, 'e');
  const paused = await makeOffer(world.tx, { isActive: false });
  const archived = await makeOffer(world.tx, { status: OfferStatus.ARCHIVED });

  await assert.rejects(
    world.cart.addItem(buyer.id, { offer_id: paused.id, quantity: 1 }),
    /not available/i,
  );
  await assert.rejects(
    world.cart.addItem(buyer.id, { offer_id: archived.id, quantity: 1 }),
    /not available/i,
  );
});

// ── Whose basket it is ──────────────────────────────────────────────────────

dbTest('one basket belongs to one woman', async (world) => {
  // A cart item id is a uuid the client holds, and `updateItem` and
  // `removeItem` take it straight from the URL.
  const layla = await makeCustomer(world.tx, 'f');
  const fatima = await makeCustomer(world.tx, 'g');
  const offer = await makeOffer(world.tx, { stock: 10 });

  const hers = await world.cart.addItem(layla.id, {
    offer_id: offer.id,
    quantity: 2,
  });
  const itemId = hers.items[0].id;

  await assert.rejects(
    world.cart.updateItem(fatima.id, itemId, 9),
    /not found/i,
    'and "not found" rather than "forbidden": the id itself is hers',
  );
  await assert.rejects(world.cart.removeItem(fatima.id, itemId), /not found/i);

  const stillHers = await world.cart.getCart(layla.id);
  assert.equal(stillHers.items.length, 1);
  assert.equal(stillHers.items[0].quantity, 2);

  const strangers = await world.cart.getCart(fatima.id);
  assert.equal(strangers.items.length, 0, 'and she sees an empty basket');
});

dbTest('a guest basket and an account basket never mix', async (world) => {
  // Guest checkout is a launch feature, so the two live side by side in
  // different tables and the owner is a tagged union rather than a nullable id.
  const buyer = await makeCustomer(world.tx, 'h');
  const offer = await makeOffer(world.tx, { stock: 10 });

  const guestSession = await world.tx.guestSession.create({
    data: {
      tokenHash: uniq('tok'),
      expiresAt: new Date(Date.now() + 86_400_000),
    },
  });

  await world.cart.addItem(
    { kind: 'guest', guestSessionId: guestSession.id },
    { offer_id: offer.id, quantity: 4 },
  );
  await world.cart.addItem(buyer.id, { offer_id: offer.id, quantity: 1 });

  const guestCart = await world.cart.getCart({
    kind: 'guest',
    guestSessionId: guestSession.id,
  });
  const userCart = await world.cart.getCart(buyer.id);

  assert.equal(guestCart.items[0].quantity, 4);
  assert.equal(userCart.items[0].quantity, 1);
});
