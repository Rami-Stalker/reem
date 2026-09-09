import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  FlashSaleStatus,
  InventoryReservationState,
  OfferStatus,
  OrderStatus,
  PrismaClient,
  ProductStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { CartService } from '../cart/cart.service';
import { CodTrustService } from '../cod-trust/cod-trust.service';
import { CustomerRefundsService } from '../finance/customer-refunds.service';
import { OrdersRepository } from './orders.repository';
import { OrdersService } from './orders.service';
import { InventoryReservationService } from './workflow/inventory-reservation.service';
import { SellerOrderWorkflowService } from './workflow/seller-order-workflow.service';
import { expiryMinutesFor } from './order-expiry';
import { PaymentMethodType } from '@prisma/client';

/**
 * What happens to an order nobody pays for.
 *
 * Stock leaves the shelf inside the checkout transaction — that is what makes
 * the oversell guarantee work — so an unpaid order is a garment withdrawn from
 * sale. The platform had one release valve, the cash-hold sweep, and it
 * covered only orders the trust engine had held for a confirmation code.
 * Everything else held its stock for ever: a transfer never sent, a gateway
 * page closed, a guest checkout, or a crash between creating the order and
 * confirming it.
 *
 * These also pin down the *other* half of that unwinding, which no test and no
 * code had: the demand counters. `Product.ordersCount` and a flash sale's
 * `quantitySold` were incremented at checkout and decremented by nothing, so
 * a listing could climb the catalogue on sales that never happened and a
 * promotion could sell out on orders that were cancelled.
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
  orders: OrdersService;
}

/** Nothing under test reaches these; they exist so the service can be built. */
const noCart = {} as unknown as CartService;
const noRefunds = {} as unknown as CustomerRefundsService;
const quietTrust = { observe: async () => {} } as unknown as CodTrustService;

function build(tx: Tx): World {
  const db = asPrisma(tx);
  return {
    tx,
    orders: new OrdersService(
      db,
      new OrdersRepository(db),
      noCart,
      new SellerOrderWorkflowService(db, new InventoryReservationService(db)),
      noRefunds,
      quietTrust,
    ),
  };
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `ex-${tag}`,
      username: `ex_${u}`,
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

interface BasketShape {
  /** Stock left on the offer *after* checkout took its units. */
  stockAfter: number;
  quantity: number;
  /** `ordersCount` as checkout left it, units included. */
  ordersCount: number;
  /** Set to attach a live flash sale that counted these units. */
  flashSaleSold?: number;
  status?: SellerOrderStatus;
  /** Null places the order as a guest. */
  customerId?: string | null;
  guestSessionId?: string;
  /**
   * Skips the reservation row, modelling an order placed before the table
   * existed. Checkout always writes one now.
   */
  withoutReservation?: boolean;
}

/**
 * An order as checkout leaves it: stock already claimed, counters already
 * incremented, nothing paid.
 */
async function makeUnpaidOrder(tx: Tx, shape: BasketShape) {
  const seller = await makeUser(tx, 'sel', UserRole.SELLER);
  const u = uniq('b');

  const category = await tx.category.create({
    data: { slug: `ex-cat-${u}`, nameAr: 'فئة', nameEn: 'Cat' },
  });
  const product = await tx.product.create({
    data: {
      slug: `ex-prod-${u}`,
      title: 'فستان',
      description: 'اختبار',
      categoryId: category.id,
      status: ProductStatus.ACTIVE,
      ordersCount: shape.ordersCount,
    },
  });
  const offer = await tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId: seller.id,
      currency: Currency.SYP,
      price: '100000',
      stock: shape.stockAfter,
      status: OfferStatus.ACTIVE,
    },
  });

  let flashSaleItemId: string | null = null;
  if (shape.flashSaleSold != null) {
    const sale = await tx.flashSale.create({
      data: {
        title: `تخفيض ${u}`,
        status: FlashSaleStatus.ACTIVE,
        startsAt: new Date(Date.now() - 60 * 60 * 1000),
        endsAt: new Date(Date.now() + 60 * 60 * 1000),
      },
    });
    const item = await tx.flashSaleItem.create({
      data: {
        saleId: sale.id,
        offerId: offer.id,
        salePrice: '80000',
        compareAtPrice: '100000',
        currency: Currency.SYP,
        quantityCap: 50,
        quantitySold: shape.flashSaleSold,
      },
    });
    flashSaleItemId = item.id;
  }

  const customerId =
    shape.customerId === null
      ? null
      : (shape.customerId ?? (await makeUser(tx, 'cus')).id);

  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-12)}`,
      userId: customerId,
      guestSessionId: shape.guestSessionId ?? null,
      status: OrderStatus.PENDING_PAYMENT,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: '100000',
      shippingTotal: '0',
      grandTotal: '100000',
      placedAt: new Date(),
      expiresAt: new Date(Date.now() - 60 * 60 * 1000),
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
      number: `${order.number}-1`,
      sellerId: seller.id,
      status: shape.status ?? SellerOrderStatus.NEW,
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
          quantity: shape.quantity,
          lineTotal: '100000',
        },
      },
    },
  });

  // Checkout writes one of these per line, so the fixture does too — without
  // it these tests would be asserting on an order shape the platform no longer
  // produces, and the release path would have nothing to release.
  if (!shape.withoutReservation) {
    await tx.inventoryReservation.create({
      data: {
        orderId: order.id,
        sellerOrderId: sellerOrder.id,
        offerId: offer.id,
        quantity: shape.quantity,
        state: InventoryReservationState.HELD,
        expiresAt: new Date(Date.now() - 60 * 60 * 1000),
      },
    });
  }

  return { seller, product, offer, order, sellerOrder, flashSaleItemId };
}

// ── The deadline ────────────────────────────────────────────────────────

dbTest('an unpaid order lets go of its stock', async (world) => {
  const { order, offer } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 2,
    ordersCount: 10,
  });

  const expired = await world.orders.expireUnpaid(order.id, 'انتهت المهلة');
  assert.equal(expired, true);

  const after = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: offer.id },
    select: { stock: true },
  });
  assert.equal(after.stock, 5, 'the two units are back on the shelf');

  const parent = await world.tx.order.findUniqueOrThrow({
    where: { id: order.id },
    select: { status: true },
  });
  assert.equal(parent.status, OrderStatus.CANCELLED);
});

dbTest('the timeline records why it was cancelled', async (world) => {
  const { order, sellerOrder } = await makeUnpaidOrder(world.tx, {
    stockAfter: 1,
    quantity: 1,
    ordersCount: 1,
  });

  await world.orders.expireUnpaid(order.id, 'انتهت مهلة الدفع');

  const events = await world.tx.orderEvent.findMany({
    where: { sellerOrderId: sellerOrder.id },
    orderBy: { createdAt: 'desc' },
  });
  const cancellation = events.find(
    (event) => event.toStatus === SellerOrderStatus.CANCELLED_BY_CUSTOMER,
  );
  assert.ok(cancellation, 'a customer-visible entry exists');
  assert.equal(cancellation?.actorRole, 'SYSTEM');
  assert.equal(cancellation?.description, 'انتهت مهلة الدفع');
});

dbTest('a parcel a seller has begun is never expired', async (world) => {
  const { order, offer } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 2,
    ordersCount: 10,
    status: SellerOrderStatus.PREPARING,
  });

  const expired = await world.orders.expireUnpaid(order.id, 'انتهت المهلة');
  assert.equal(
    expired,
    false,
    'a timer may not cancel work a seller is already doing',
  );

  const after = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: offer.id },
    select: { stock: true },
  });
  assert.equal(after.stock, 3, 'and the stock stays with the parcel');
});

dbTest('an order that moved on is left alone', async (world) => {
  const { order } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 2,
    ordersCount: 10,
  });
  await world.tx.order.update({
    where: { id: order.id },
    data: { status: OrderStatus.CONFIRMED },
  });

  assert.equal(await world.orders.expireUnpaid(order.id, 'x'), false);
});

// ── The counters checkout inflated ──────────────────────────────────────

dbTest('a cancelled sale stops counting as a sale', async (world) => {
  const { order, product } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 2,
    ordersCount: 10,
  });

  await world.orders.expireUnpaid(order.id, 'انتهت المهلة');

  const after = await world.tx.product.findUniqueOrThrow({
    where: { id: product.id },
    select: { ordersCount: true },
  });
  assert.equal(
    after.ordersCount,
    8,
    'the catalogue no longer ranks this listing on an order nobody placed',
  );
});

dbTest('the counter never goes negative', async (world) => {
  // A history that does not add up — a counter reset, an old order — must not
  // be able to produce "bought by -1 women" on a product card.
  const { order, product } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 5,
    ordersCount: 2,
  });

  await world.orders.expireUnpaid(order.id, 'انتهت المهلة');

  const after = await world.tx.product.findUniqueOrThrow({
    where: { id: product.id },
    select: { ordersCount: true },
  });
  assert.ok(after.ordersCount >= 0);
});

dbTest('a flash sale gets its units back', async (world) => {
  const { order, flashSaleItemId } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 2,
    ordersCount: 10,
    flashSaleSold: 12,
  });

  await world.orders.expireUnpaid(order.id, 'انتهت المهلة');

  const item = await world.tx.flashSaleItem.findUniqueOrThrow({
    where: { id: flashSaleItemId! },
    select: { quantitySold: true },
  });
  assert.equal(
    item.quantitySold,
    10,
    'the promotion no longer counts a cancelled order against its cap',
  );
});

// ── A guest's order is hers, and only hers ──────────────────────────────

dbTest('a guest can read the order she placed', async (world) => {
  const session = await world.tx.guestSession.create({
    data: {
      tokenHash: `hash-${uniq('g')}`,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });
  const { order } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 1,
    ordersCount: 1,
    customerId: null,
    guestSessionId: session.id,
  });

  const detail = await world.orders.detail(
    { kind: 'guest', guestSessionId: session.id },
    order.id,
  );
  assert.equal((detail as { id: string }).id, order.id);
});

dbTest('and another guest cannot', async (world) => {
  const mine = await world.tx.guestSession.create({
    data: {
      tokenHash: `hash-${uniq('g')}`,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });
  const stranger = await world.tx.guestSession.create({
    data: {
      tokenHash: `hash-${uniq('g')}`,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });
  const { order } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 1,
    ordersCount: 1,
    customerId: null,
    guestSessionId: mine.id,
  });

  await assert.rejects(
    world.orders.detail(
      { kind: 'guest', guestSessionId: stranger.id },
      order.id,
    ),
    /not found/i,
  );
});

dbTest('a signed-in customer cannot read a guest order either', async (world) => {
  const session = await world.tx.guestSession.create({
    data: {
      tokenHash: `hash-${uniq('g')}`,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });
  const someone = await makeUser(world.tx, 'other');
  const { order } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 1,
    ordersCount: 1,
    customerId: null,
    guestSessionId: session.id,
  });

  await assert.rejects(
    world.orders.detail({ kind: 'user', userId: someone.id }, order.id),
    /not found/i,
  );
});

// ── The deadline itself ─────────────────────────────────────────────────

test('a rail she must go and pay gets longer than one she already paid', () => {
  const cash = expiryMinutesFor(PaymentMethodType.COD);
  const transfer = expiryMinutesFor(PaymentMethodType.BANK_TRANSFER);
  assert.ok(
    transfer > cash,
    'a woman at an exchange office must not lose her order while she is there',
  );
  assert.ok(cash > 0);
});

// ── Signing up after buying as a guest ──────────────────────────────────

dbTest('her guest orders follow her into her new account', async (world) => {
  const session = await world.tx.guestSession.create({
    data: {
      tokenHash: `hash-${uniq('g')}`,
      expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
    },
  });
  const { order } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 1,
    ordersCount: 1,
    customerId: null,
    guestSessionId: session.id,
  });
  const account = await makeUser(world.tx, 'new');

  // What `GuestService.migrateToUser` does to the orders. Asserted on the
  // effect rather than through the service, which needs a token and a hashing
  // pepper this harness has no business holding.
  await world.tx.order.updateMany({
    where: { guestSessionId: session.id, userId: null },
    data: { userId: account.id },
  });

  const detail = await world.orders.detail(
    { kind: 'user', userId: account.id },
    order.id,
  );
  assert.equal((detail as { id: string }).id, order.id);

  // And the retired session no longer reaches it — the order is hers now, not
  // the browser's.
  const claimed = await world.tx.order.findUniqueOrThrow({
    where: { id: order.id },
    select: { userId: true },
  });
  assert.equal(claimed.userId, account.id);
});

// ── Reservations ────────────────────────────────────────────────────────
//
// Stock used to go back on the shelf with a bare `increment`, so any path that
// ran twice — a retried cancellation, a refusal recorded by both the rider and
// the carrier's webhook — credited the seller units she never got back. The
// reservation's state is the guard: it can leave HELD/COMMITTED exactly once,
// and only the rows that actually moved return their units.

dbTest('releasing a parcel twice returns its stock once', async (world) => {
  const { order, sellerOrder, offer } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 2,
    ordersCount: 10,
  });
  const reservations = new InventoryReservationService(asPrisma(world.tx));

  const first = await reservations.releaseForSellerOrder(
    world.tx,
    sellerOrder.id,
    'ألغته العميلة',
  );
  const second = await reservations.releaseForSellerOrder(
    world.tx,
    sellerOrder.id,
    'ألغته العميلة مرة أخرى',
  );

  assert.equal(first, 1);
  assert.equal(second, 0, 'the second call finds nothing left to release');

  const after = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: offer.id },
    select: { stock: true },
  });
  assert.equal(
    after.stock,
    5,
    'the two units came back once, not twice — this is the drift that used to ' +
      'let the shop sell garments it did not have',
  );
});

dbTest('a released reservation records why', async (world) => {
  const { order, sellerOrder, offer } = await makeUnpaidOrder(world.tx, {
    stockAfter: 1,
    quantity: 1,
    ordersCount: 1,
  });
  const held = await world.tx.inventoryReservation.findFirstOrThrow({
    where: { sellerOrderId: sellerOrder.id },
  });

  const reservations = new InventoryReservationService(asPrisma(world.tx));
  await reservations.releaseForSellerOrder(world.tx, sellerOrder.id, 'رفض عند الباب');

  const after = await world.tx.inventoryReservation.findUniqueOrThrow({
    where: { id: held.id },
  });
  assert.equal(after.state, InventoryReservationState.RELEASED);
  assert.equal(after.releaseReason, 'رفض عند الباب');
  assert.ok(after.releasedAt);
  assert.equal(after.expiresAt, null, 'a released hold has no deadline left');
});

dbTest('committing a hold takes away its deadline', async (world) => {
  const { order, sellerOrder, offer } = await makeUnpaidOrder(world.tx, {
    stockAfter: 1,
    quantity: 1,
    ordersCount: 1,
  });
  const held = await world.tx.inventoryReservation.findFirstOrThrow({
    where: { sellerOrderId: sellerOrder.id },
  });

  const reservations = new InventoryReservationService(asPrisma(world.tx));
  const moved = await reservations.commit(world.tx, order.id);
  assert.equal(moved, 1);

  const after = await world.tx.inventoryReservation.findUniqueOrThrow({
    where: { id: held.id },
  });
  assert.equal(after.state, InventoryReservationState.COMMITTED);
  assert.equal(
    after.expiresAt,
    null,
    'no timer may release goods a seller has begun packing',
  );
  assert.ok(after.committedAt);
});

dbTest('a delivered parcel closes its reservation for good', async (world) => {
  const { order, sellerOrder, offer } = await makeUnpaidOrder(world.tx, {
    stockAfter: 1,
    quantity: 1,
    ordersCount: 1,
  });
  const held = await world.tx.inventoryReservation.findFirstOrThrow({
    where: { sellerOrderId: sellerOrder.id },
  });

  const reservations = new InventoryReservationService(asPrisma(world.tx));
  await reservations.consume(world.tx, sellerOrder.id);

  const after = await world.tx.inventoryReservation.findUniqueOrThrow({
    where: { id: held.id },
  });
  assert.equal(after.state, InventoryReservationState.CONSUMED);

  // And a later release finds nothing: goods that arrived are not goods that
  // came back. A return is new stock, and `ReturnsService` owns that.
  const released = await reservations.releaseForSellerOrder(
    world.tx,
    sellerOrder.id,
    'متأخر',
  );
  assert.equal(released, 0);

  const stock = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: offer.id },
    select: { stock: true },
  });
  assert.equal(stock.stock, 1, 'the shelf is untouched by a delivered parcel');
});

dbTest('expiring a parcel releases through its reservation', async (world) => {
  const { order, sellerOrder, offer } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 2,
    ordersCount: 10,
  });
  await world.orders.expireUnpaid(order.id, 'انتهت المهلة');

  const stock = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: offer.id },
    select: { stock: true },
  });
  assert.equal(stock.stock, 5);

  const reservation = await world.tx.inventoryReservation.findFirstOrThrow({
    where: { sellerOrderId: sellerOrder.id },
  });
  assert.equal(reservation.state, InventoryReservationState.RELEASED);
});

dbTest('a parcel with no reservation restocks nothing', async (world) => {
  // Orders placed before this table existed carry no reservation. They must
  // not be silently double-restocked by the old blind increment, and they must
  // not crash the cancellation either — they simply have nothing to give back.
  const { order, offer } = await makeUnpaidOrder(world.tx, {
    stockAfter: 3,
    quantity: 2,
    ordersCount: 10,
    withoutReservation: true,
  });

  const expired = await world.orders.expireUnpaid(order.id, 'انتهت المهلة');
  assert.equal(expired, true, 'the order is still cancelled');

  const stock = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: offer.id },
    select: { stock: true },
  });
  assert.equal(
    stock.stock,
    3,
    'nothing invented: with no record of a hold there is nothing to release',
  );
});
