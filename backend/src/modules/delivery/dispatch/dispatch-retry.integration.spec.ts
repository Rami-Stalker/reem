import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  DeliveryProviderKind,
  FulfilmentMode,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  PrismaClient,
  SellerOrderStatus,
  ShipmentStatus,
  UserRole,
  WebhookAuthScheme,
} from '@prisma/client';

import { Money } from '../../../common/money';
import { utcTimestamp } from '../../../common/sql/utc-timestamp';
import { PrismaService } from '../../../prisma/prisma.service';
import { DeliveryDispatchScheduler } from './delivery-dispatch.scheduler';
import { DeliveryDispatchService } from './delivery-dispatch.service';

/**
 * Which parcels the platform will ask a carrier about again, and which it will
 * not.
 *
 * `DeliveryDispatchService` was written correctly: a carrier's failure is never
 * the seller's problem, so the dispatch row records the error and "ops (or a
 * retry) tries again". The retry existed as an admin endpoint and **nothing ever
 * called it**, so a parcel refused because a carrier's API blipped for thirty
 * seconds was never collected at all — the customer watched a tracking page
 * that never moved, and the seller's escrow clock never started, because it runs
 * from delivery. On a cash platform that is a sale that silently did not happen.
 *
 * The scheduler that closes it is small; the risk is entirely in its judgement,
 * so that is what these cases pin. Retrying a parcel the carrier already
 * accepted would ask for a second parcel at the warehouse, and retrying for ever
 * would hammer an endpoint that has answered the same way six times instead of
 * putting the problem in front of a person.
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
  scheduler: DeliveryDispatchScheduler;
  /** Every dispatch id the scheduler asked to retry, in order. */
  asked: string[];
  /**
   * The ids this case created.
   *
   * The sweep reads the whole table and the seeded shop has dispatches of its
   * own, so an assertion of the form "it asked for nothing" has to mean "it
   * asked for nothing of *mine*". A rolled-back transaction still sees every
   * committed row.
   */
  mine: Set<string>;
  /** Ids the stubbed carrier should accept; anything else keeps failing. */
  accept: Set<string>;
}

/** What the sweep asked for, of the rows this case owns. */
const askedMine = (world: World) =>
  world.asked.filter((id) => world.mine.has(id));

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const asked: string[] = [];
  const accept = new Set<string>();

  // No adapter and no carrier: these cases are about *which* dispatches the
  // sweep selects, and a real provider call would only add a second reason for
  // a case to fail.
  const dispatches = {
    retry: async (id: string) => {
      asked.push(id);
      const accepted = accept.has(id);
      return tx.deliveryDispatch.update({
        where: { id },
        data: accepted
          ? {
              externalDeliveryId: `ACME-${id.slice(0, 8)}`,
              lastError: null,
              attemptCount: { increment: 1 },
            }
          : { attemptCount: { increment: 1 }, lastError: 'carrier unreachable' },
      });
    },
  } as unknown as DeliveryDispatchService;

  return {
    tx,
    db,
    scheduler: new DeliveryDispatchScheduler(db, dispatches),
    asked,
    mine: new Set<string>(),
    accept,
  };
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const syp = (value: string | number) => Money.of(value, Currency.SYP);

/**
 * A packed parcel with a dispatch row in whatever state the case needs.
 *
 * `updatedAt` is `@updatedAt`, so Prisma overwrites it on every write and the
 * backoff cannot be tested through the client. It is set with raw SQL after the
 * row exists — through `utcTimestamp`, because `updated_at` is `timestamp
 * without time zone` and both SQL `now()` and a bound JS `Date` arrive as
 * `timestamptz` and get converted to the session's wall clock on the way in.
 * Writing this test is how that bug was found in the idempotency interceptor.
 */
async function makeDispatch(
  world: World,
  state: {
    lastError?: string | null;
    attemptCount?: number;
    externalDeliveryId?: string | null;
    cancelledAt?: Date | null;
    ageMinutes?: number;
  },
) {
  const tx = world.tx;
  const subtotal = syp('100000');
  const shipping = syp('10000');

  const phone = () => `+9639${Math.floor(10000000 + Math.random() * 89999999)}`;
  const customer = await tx.user.create({
    data: {
      name: 'عميلة',
      username: uniq('cus'),
      phone: phone(),
      role: UserRole.CUSTOMER,
    },
  });
  const seller = await tx.user.create({
    data: {
      name: 'بوتيك',
      username: uniq('sel'),
      phone: phone(),
      role: UserRole.SELLER,
    },
  });
  const category = await tx.category.create({
    data: { slug: `cat-${uniq('c')}`, nameAr: 'تجربة', nameEn: 'Test' },
  });
  const product = await tx.product.create({
    data: {
      slug: `prod-${uniq('p')}`,
      title: 'فستان',
      description: 'للاختبار',
      categoryId: category.id,
    },
  });
  const offer = await tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId: seller.id,
      currency: Currency.SYP,
      price: '50000',
      stock: 5,
    },
  });
  const order = await tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-12)}`,
      userId: customer.id,
      status: OrderStatus.CONFIRMED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: subtotal.toPrisma(),
      shippingTotal: shipping.toPrisma(),
      grandTotal: subtotal.plus(shipping).toPrisma(),
      recipientName: 'ريم',
      recipientPhone: '+963900111222',
      governorate: 'دمشق',
      district: 'المزة',
      city: 'دمشق',
      addressLine: 'شارع الجلاء',
      placedAt: new Date(),
      payment: {
        create: {
          method: PaymentMethodType.COD,
          status: PaymentStatus.PENDING,
          currency: Currency.SYP,
          amount: subtotal.plus(shipping).toPrisma(),
        },
      },
    },
  });
  const sellerOrder = await tx.sellerOrder.create({
    data: {
      orderId: order.id,
      number: `${order.number}-1`,
      sellerId: seller.id,
      status: SellerOrderStatus.READY_TO_SHIP,
      fulfilmentMode: FulfilmentMode.PLATFORM_COURIER,
      currency: Currency.SYP,
      itemsSubtotal: subtotal.toPrisma(),
      shippingCost: shipping.toPrisma(),
      commissionBase: subtotal.toPrisma(),
      commissionAmount: syp('15000').toPrisma(),
      sellerNet: syp('85000').toPrisma(),
      confirmedAt: new Date(),
      items: {
        create: {
          offerId: offer.id,
          productId: product.id,
          titleSnapshot: product.title,
          sellerSnapshot: 'بوتيك',
          currency: Currency.SYP,
          unitPrice: '50000',
          quantity: 2,
          lineTotal: subtotal.toPrisma(),
        },
      },
    },
  });
  const shipment = await tx.shipment.create({
    data: {
      trackingCode: `REM-${uniq('t').slice(-8).toUpperCase()}`,
      sellerOrderId: sellerOrder.id,
      currency: Currency.SYP,
      codAmount: subtotal.plus(shipping).toPrisma(),
      status: ShipmentStatus.CREATED,
    },
  });
  const account = await tx.deliveryProviderAccount.create({
    data: {
      code: `acme_${uniq('a').slice(-6)}`,
      displayName: 'أكمي للتوصيل',
      kind: DeliveryProviderKind.EXTERNAL_API,
      isEnabled: true,
      supportsWebhook: true,
      webhookAuth: WebhookAuthScheme.HMAC_SHA256,
      governorates: ['دمشق'],
    },
  });

  const dispatch = await tx.deliveryDispatch.create({
    data: {
      shipmentId: shipment.id,
      providerId: account.id,
      providerCode: account.code,
      status: ShipmentStatus.CREATED,
      idempotencyKey: `reem-dispatch-${shipment.id}`,
      lastError: state.lastError === undefined ? 'carrier 502' : state.lastError,
      attemptCount: state.attemptCount ?? 1,
      externalDeliveryId: state.externalDeliveryId ?? null,
      cancelledAt: state.cancelledAt ?? null,
      requestedAt: new Date(),
    },
  });

  if (state.ageMinutes) {
    await tx.$executeRaw`
      UPDATE delivery_dispatches
         SET updated_at = ${utcTimestamp(new Date())} - (${state.ageMinutes}::int * interval '1 minute')
       WHERE id = ${dispatch.id}::uuid
    `;
  }

  world.mine.add(dispatch.id);
  return dispatch;
}

// ── What it retries ────────────────────────────────────────────────────────

dbTest('a parcel the carrier refused is asked again once its backoff has passed', async (world) => {
  const dispatch = await makeDispatch(world, {
    attemptCount: 1,
    ageMinutes: 30,
  });
  world.accept.add(dispatch.id);

  await world.scheduler.retryFailedDispatches();

  assert.deepEqual(askedMine(world), [dispatch.id]);
  const after = await world.tx.deliveryDispatch.findUniqueOrThrow({
    where: { id: dispatch.id },
  });
  assert.ok(after.externalDeliveryId, 'the parcel is now with the carrier');
  assert.equal(after.lastError, null);
});

dbTest('a carrier that refuses again leaves the parcel for the next sweep', async (world) => {
  const dispatch = await makeDispatch(world, {
    attemptCount: 1,
    ageMinutes: 30,
  });
  // Not in `accept`: the carrier is still down.

  await world.scheduler.retryFailedDispatches();

  const after = await world.tx.deliveryDispatch.findUniqueOrThrow({
    where: { id: dispatch.id },
  });
  assert.equal(after.externalDeliveryId, null);
  assert.equal(after.attemptCount, 2, 'the attempt is counted, so backoff widens');
  assert.ok(after.lastError, 'and the reason is still on the ops screen');
});

// ── What it must never retry ───────────────────────────────────────────────

dbTest('a parcel the carrier accepted is never dispatched twice', async (world) => {
  // The guarantee the whole integration rests on. Asking again for a parcel
  // that has an external id is asking for a second parcel at the warehouse.
  await makeDispatch(world, {
    externalDeliveryId: 'ACME-ALREADY',
    lastError: 'a stale error from the attempt that eventually succeeded',
    attemptCount: 2,
    ageMinutes: 120,
  });

  await world.scheduler.retryFailedDispatches();

  assert.deepEqual(askedMine(world), []);
});

dbTest('a dispatch that has not been attempted yet is left to the order path', async (world) => {
  // No error means nothing has gone wrong; the parcel is waiting for `ready()`.
  // Retrying here would call the carrier for a parcel nobody has packed.
  await makeDispatch(world, {
    lastError: null,
    attemptCount: 0,
    ageMinutes: 120,
  });

  await world.scheduler.retryFailedDispatches();

  assert.deepEqual(askedMine(world), []);
});

dbTest('a cancelled dispatch stays cancelled', async (world) => {
  await makeDispatch(world, {
    attemptCount: 1,
    cancelledAt: new Date(),
    ageMinutes: 120,
  });

  await world.scheduler.retryFailedDispatches();

  assert.deepEqual(askedMine(world), []);
});

dbTest('a parcel that just failed is not asked again immediately', async (world) => {
  // Backoff. A carrier that refused a second ago will refuse again, and every
  // pending parcel retrying at once is how a recovering carrier is finished off.
  await makeDispatch(world, { attemptCount: 1, ageMinutes: 0 });

  await world.scheduler.retryFailedDispatches();

  assert.deepEqual(askedMine(world), []);
});

dbTest('after six attempts it stops asking and leaves it for a person', async (world) => {
  // Past this it is not a transient failure — a rejected address, a closed
  // account, a changed API — and the honest thing is the delivery desk.
  await makeDispatch(world, { attemptCount: 6, ageMinutes: 600 });

  await world.scheduler.retryFailedDispatches();

  assert.deepEqual(askedMine(world), []);
});

dbTest('the backoff widens with each attempt', async (world) => {
  // Attempt 3 waits 18 minutes; ten is not enough and twenty is.
  const tooSoon = await makeDispatch(world, {
    attemptCount: 3,
    ageMinutes: 10,
  });
  const due = await makeDispatch(world, {
    attemptCount: 3,
    ageMinutes: 20,
  });

  await world.scheduler.retryFailedDispatches();

  assert.ok(!askedMine(world).includes(tooSoon.id), 'ten minutes into an 18-minute wait');
  assert.ok(askedMine(world).includes(due.id), 'twenty minutes is past it');
});
