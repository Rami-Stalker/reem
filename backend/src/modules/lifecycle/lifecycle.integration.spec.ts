import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  OfferStatus,
  OrderStatus,
  PrismaClient,
  ProductStatus,
  ReengagementKind,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { NotificationsService } from '../notifications/notifications.service';
import { CustomerSegmentsService } from './customer-segments.service';
import { ReengagementService } from './reengagement.service';
import { SEGMENT_RULES } from './customer-segments';

/**
 * The lifecycle, against real customers.
 *
 * Two things are being proved. That the stages are what they claim — a woman
 * lands in exactly one, and buying moves her — and that the reminders are sent
 * once. The second matters more: a segmentation bug shows a wrong number on an
 * admin screen, and a de-duplication bug pushes the same notification to the
 * same woman every hour until she uninstalls the app.
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

/** Records what would have been pushed, instead of pushing it. */
class Postbox {
  readonly sent: { userId: string; title: string; body: string }[] = [];

  asService(): NotificationsService {
    return {
      dispatch: async (
        _actor: string,
        dto: { user_ids?: string[]; title: string; body: string },
      ) => {
        for (const userId of dto.user_ids ?? []) {
          this.sent.push({ userId, title: dto.title, body: dto.body });
        }
        return { queued: dto.user_ids?.length ?? 0 };
      },
    } as unknown as NotificationsService;
  }
}

interface World {
  tx: Tx;
  segments: CustomerSegmentsService;
  postbox: Postbox;
  reengagement: ReengagementService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const segments = new CustomerSegmentsService(db);
  const postbox = new Postbox();
  return {
    tx,
    segments,
    postbox,
    reengagement: new ReengagementService(db, segments, postbox.asService()),
  };
}

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;
const daysAgo = (n: number) => new Date(Date.now() - n * 86_400_000);
const hoursAgo = (n: number) => new Date(Date.now() - n * 3_600_000);

async function makeCustomer(tx: Tx) {
  const u = uniq();
  return tx.user.create({
    data: {
      name: 'ريم',
      username: `lc_${u}`,
      phone: `+9639${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role: UserRole.CUSTOMER,
    },
  });
}

async function makeOrder(tx: Tx, userId: string, when: Date) {
  const u = uniq();
  return tx.order.create({
    data: {
      number: `LC-${u.slice(-10)}`,
      userId,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: '50000',
      discountTotal: '0',
      shippingTotal: '0',
      grandTotal: '50000',
      recipientName: 'ريم',
      recipientPhone: `+96397${u.slice(-7)}`,
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      createdAt: when,
    },
  });
}

/** A live offer somebody can put in a basket. */
async function makeOffer(tx: Tx, title = 'فستان سهرة') {
  const u = uniq();
  const seller = await tx.user.create({
    data: {
      name: 'بوتيك',
      username: `lcs_${u}`,
      phone: `+96396${Math.floor(1000000 + Math.random() * 8999999)}`,
      passwordHash: 'x',
      role: UserRole.SELLER,
    },
  });
  const category = await tx.category.create({
    data: { slug: `lc-cat-${u}`, nameAr: 'فئة', nameEn: 'Cat' },
  });
  const product = await tx.product.create({
    data: {
      slug: `lc-prod-${u}`,
      title,
      description: 'وصف',
      categoryId: category.id,
      status: ProductStatus.ACTIVE,
      offers: {
        create: {
          sellerId: seller.id,
          currency: Currency.SYP,
          price: '100000',
          stock: 4,
          status: OfferStatus.ACTIVE,
          isActive: true,
        },
      },
    },
    include: { offers: true },
  });
  return product.offers[0];
}

async function addToCart(tx: Tx, userId: string, offerId: string, when: Date) {
  return tx.cartItem.create({
    data: { userId, offerId, quantity: 1, updatedAt: when },
  });
}

// ── Stages ───────────────────────────────────────────────────────────────────

dbTest('a customer sits in exactly one stage', async (world) => {
  const buyer = await makeCustomer(world.tx);
  await makeOrder(world.tx, buyer.id, daysAgo(5));

  const stage = await world.segments.stageOf(buyer.id);
  assert.equal(stage, 'first_time');

  // And no other stage claims her.
  const others = ['prospect', 'repeat', 'loyal', 'at_risk', 'lapsed'] as const;
  for (const other of others) {
    const rows = await world.segments.stage(other, 100_000);
    assert.ok(
      !rows.some((row) => row.userId === buyer.id),
      `she must not also be ${other}`,
    );
  }
});

dbTest('buying again moves her out of first_time', async (world) => {
  const buyer = await makeCustomer(world.tx);
  await makeOrder(world.tx, buyer.id, daysAgo(20));
  assert.equal(await world.segments.stageOf(buyer.id), 'first_time');

  await makeOrder(world.tx, buyer.id, daysAgo(2));
  assert.equal(await world.segments.stageOf(buyer.id), 'repeat');
});

dbTest('four orders in the window make her loyal', async (world) => {
  const buyer = await makeCustomer(world.tx);
  for (const ago of [50, 40, 20, 3]) {
    await makeOrder(world.tx, buyer.id, daysAgo(ago));
  }
  assert.equal(await world.segments.stageOf(buyer.id), 'loyal');
});

dbTest('silence moves her to at_risk, then to lapsed', async (world) => {
  const quiet = await makeCustomer(world.tx);
  await makeOrder(
    world.tx,
    quiet.id,
    daysAgo(SEGMENT_RULES.atRiskAfterDays + 10),
  );
  assert.equal(await world.segments.stageOf(quiet.id), 'at_risk');

  const gone = await makeCustomer(world.tx);
  await makeOrder(
    world.tx,
    gone.id,
    daysAgo(SEGMENT_RULES.lapsedAfterDays + 30),
  );
  assert.equal(await world.segments.stageOf(gone.id), 'lapsed');
});

dbTest('somebody who has only ever looked is a window shopper', async (world) => {
  const looker = await makeCustomer(world.tx);
  const offer = await makeOffer(world.tx);
  const product = await world.tx.sellerOffer.findUniqueOrThrow({
    where: { id: offer.id },
    select: { productId: true },
  });
  await world.tx.favorite.create({
    data: { userId: looker.id, productId: product.productId },
  });

  assert.equal(await world.segments.stageOf(looker.id), 'window_shopper');
});

dbTest('the distribution counts every customer once', async (world) => {
  const a = await makeCustomer(world.tx);
  await makeOrder(world.tx, a.id, daysAgo(3));
  const b = await makeCustomer(world.tx);
  await makeOrder(world.tx, b.id, daysAgo(200));

  const rows = await world.segments.distribution();
  const total = rows.reduce((sum, row) => sum + row.customers, 0);

  const customers = await world.tx.user.count({
    where: { role: UserRole.CUSTOMER, disabledAt: null },
  });
  assert.equal(
    total,
    customers,
    'the stages partition the customer base — no double counting, nobody lost',
  );
});

// ── Abandoned baskets ────────────────────────────────────────────────────────

dbTest('a basket left overnight is abandoned', async (world) => {
  const shopper = await makeCustomer(world.tx);
  const offer = await makeOffer(world.tx, 'عباية سوداء');
  await addToCart(world.tx, shopper.id, offer.id, hoursAgo(12));

  const baskets = await world.segments.abandonedBaskets(200);
  const hers = baskets.find((basket) => basket.userId === shopper.id);

  assert.ok(hers, 'twelve hours untouched is abandoned');
  assert.equal(hers.items, 1);
  assert.equal(
    hers.leadTitle,
    'عباية سوداء',
    'and the reminder can name the thing she left',
  );
});

dbTest('a basket she is still filling is not abandoned', async (world) => {
  const shopper = await makeCustomer(world.tx);
  const offer = await makeOffer(world.tx);
  await addToCart(world.tx, shopper.id, offer.id, hoursAgo(1));

  const baskets = await world.segments.abandonedBaskets(200);
  assert.ok(
    !baskets.some((basket) => basket.userId === shopper.id),
    'an hour is her still deciding, and a nudge would be an interruption',
  );
});

dbTest('a customer who checked out is not chased for her old basket', async (world) => {
  const shopper = await makeCustomer(world.tx);
  const offer = await makeOffer(world.tx);
  await addToCart(world.tx, shopper.id, offer.id, hoursAgo(12));
  // She bought, through a room or a second basket, and the cart was not cleared.
  await makeOrder(world.tx, shopper.id, hoursAgo(2));

  const baskets = await world.segments.abandonedBaskets(200);
  assert.ok(
    !baskets.some((basket) => basket.userId === shopper.id),
    'without the order check, every successful customer is "abandoned"',
  );
});

dbTest('a basket holding only sold-out stock is left alone', async (world) => {
  const shopper = await makeCustomer(world.tx);
  const offer = await makeOffer(world.tx);
  await addToCart(world.tx, shopper.id, offer.id, hoursAgo(12));
  await world.tx.sellerOffer.update({
    where: { id: offer.id },
    data: { stock: 0 },
  });

  const baskets = await world.segments.abandonedBaskets(200);
  assert.ok(
    !baskets.some((basket) => basket.userId === shopper.id),
    'a reminder about something she cannot buy is worse than silence',
  );
});

// ── Sending, once ────────────────────────────────────────────────────────────

dbTest('a basket earns one reminder, however often the job runs', async (world) => {
  const shopper = await makeCustomer(world.tx);
  const offer = await makeOffer(world.tx, 'حقيبة يد');
  await addToCart(world.tx, shopper.id, offer.id, hoursAgo(12));

  // Counted for this shopper rather than for the run: the development
  // database carries seeded baskets belonging to other customers, and they
  // are legitimately abandoned too.
  const hers = () =>
    world.postbox.sent.filter((message) => message.userId === shopper.id).length;

  await world.reengagement.nudgeAbandonedBaskets(500);
  assert.equal(hers(), 1);

  // The job runs again an hour later, as it will.
  await world.reengagement.nudgeAbandonedBaskets(500);
  assert.equal(
    hers(),
    1,
    'she is reminded once, not once an hour until she uninstalls',
  );
});

dbTest('editing the basket earns a new reminder', async (world) => {
  const shopper = await makeCustomer(world.tx);
  const one = await makeOffer(world.tx);
  await addToCart(world.tx, shopper.id, one.id, hoursAgo(12));
  await world.reengagement.nudgeAbandonedBaskets(500);

  const hers = () =>
    world.postbox.sent.filter((message) => message.userId === shopper.id).length;
  assert.equal(hers(), 1);

  // She comes back, adds something, and leaves again.
  const two = await makeOffer(world.tx);
  await addToCart(world.tx, shopper.id, two.id, hoursAgo(10));

  await world.reengagement.nudgeAbandonedBaskets(500);
  assert.equal(
    hers(),
    2,
    'a different basket is a different thing to be reminded about',
  );
});

dbTest('win-back reaches a lapsed customer once a month', async (world) => {
  const gone = await makeCustomer(world.tx);
  await makeOrder(
    world.tx,
    gone.id,
    daysAgo(SEGMENT_RULES.lapsedAfterDays + 40),
  );

  const hers = () =>
    world.postbox.sent.filter((message) => message.userId === gone.id).length;

  await world.reengagement.winBack('lapsed', 1000);
  assert.equal(hers(), 1);

  await world.reengagement.winBack('lapsed', 1000);
  assert.equal(hers(), 1, 'twice in a month is not a win-back, it is nagging');
});

dbTest('what the reminders achieved is measured, not assumed', async (world) => {
  const shopper = await makeCustomer(world.tx);
  const offer = await makeOffer(world.tx);
  await addToCart(world.tx, shopper.id, offer.id, hoursAgo(12));
  await world.reengagement.nudgeAbandonedBaskets(100);

  const before = await world.reengagement.report(30);
  const cart = before.find((row) => row.kind === 'abandoned_cart');
  assert.ok(cart);
  assert.equal(cart.returned, 0, 'nothing has come back yet');

  // She buys.
  await makeOrder(world.tx, shopper.id, new Date());
  await world.reengagement.attribute(30);

  const after = await world.reengagement.report(30);
  const settled = after.find((row) => row.kind === 'abandoned_cart');
  assert.ok(settled && settled.returned >= 1);
  assert.ok(
    (settled.return_rate ?? 0) > 0,
    'and the rate is a measured fraction, not a claim about causation',
  );

  const touch = await world.tx.reengagementTouch.findFirstOrThrow({
    where: { userId: shopper.id, kind: ReengagementKind.ABANDONED_CART },
  });
  assert.ok(touch.convertedAt, 'the touch records when she came back');
});
