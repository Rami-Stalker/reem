import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  LedgerAccountCode,
  OfferStatus,
  PrismaClient,
  ProductStatus,
  PromotionPlacement,
  PromotionStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { PromotionsService, MAX_SLOTS } from './promotions.service';

/**
 * Sponsored placements, and the money behind them.
 *
 * Two things are being guarded. That a slot cannot be shown without being paid
 * for — an ad product that serves on credit is a receivable nobody is
 * tracking — and that the fee lands in its own revenue account rather than
 * being folded into commission, which would quietly corrupt the take rate.
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
  ledger: LedgerService;
  promotions: PromotionsService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const ledger = new LedgerService(db);
  return { tx, ledger, promotions: new PromotionsService(db, ledger) };
}

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;
const minutes = (n: number) => new Date(Date.now() + n * 60_000);
const syp = (value: string | number) => Money.of(String(value), Currency.SYP);

async function makeSeller(tx: Tx) {
  const u = uniq();
  return tx.user.create({
    data: {
      name: 'بوتيك',
      username: `pr_${u}`,
      phone: `+96392${Math.floor(1000000 + Math.random() * 8999999)}`,
      passwordHash: 'x',
      role: UserRole.SELLER,
    },
  });
}

async function makeOffer(tx: Tx, sellerId: string, stock = 5) {
  const u = uniq();
  const category = await tx.category.create({
    data: { slug: `pr-cat-${u}`, nameAr: 'فئة', nameEn: 'Cat' },
  });
  const product = await tx.product.create({
    data: {
      slug: `pr-prod-${u}`,
      title: 'فستان',
      description: 'وصف',
      categoryId: category.id,
      status: ProductStatus.ACTIVE,
      offers: {
        create: {
          sellerId,
          currency: Currency.SYP,
          price: '100000',
          stock,
          status: OfferStatus.ACTIVE,
          isActive: true,
        },
      },
    },
    include: { offers: true },
  });
  return { offer: product.offers[0], categoryId: category.id, product };
}

/** Gives the boutique earnings to pay a placement fee out of. */
async function fundPayable(world: World, sellerId: string, amount: string) {
  await world.ledger.post(
    {
      type: 'PAYOUT_ACCRUED',
      reference: `pr-fund:${uniq()}`,
      description: 'اختبار',
      lines: [
        {
          account: { code: LedgerAccountCode.PLATFORM_CASH },
          direction: 'DEBIT',
          amount: syp(amount),
        },
        {
          account: { code: LedgerAccountCode.SELLER_PAYABLE, ownerId: sellerId },
          direction: 'CREDIT',
          amount: syp(amount),
        },
      ],
    },
    world.tx,
  );
}

const payable = (world: World, sellerId: string) =>
  world.ledger.balanceOf(
    { code: LedgerAccountCode.SELLER_PAYABLE, ownerId: sellerId },
    Currency.SYP,
    world.tx,
  );

const promotionRevenue = (world: World) =>
  world.ledger.balanceOf(
    { code: LedgerAccountCode.PROMOTION_REVENUE },
    Currency.SYP,
    world.tx,
  );

// ── Buying and billing ───────────────────────────────────────────────────────

dbTest('a placement is dark until it is paid for', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);

  const promotion = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    fee: syp('20000'),
    startsAt: minutes(-10),
    endsAt: minutes(60),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });

  assert.equal(promotion.status, 'pending');
  assert.equal(promotion.charged_at, null);

  const slots = await world.promotions.slotsFor(PromotionPlacement.SEARCH);
  assert.ok(
    !slots.includes(offer.id),
    'an ad product that serves on credit is a receivable nobody is tracking',
  );
});

dbTest('going live takes the fee from her earnings', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '100000');

  const before = await payable(world, seller.id);
  const revenueBefore = await promotionRevenue(world);

  const promotion = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    fee: syp('20000'),
    startsAt: minutes(-10),
    endsAt: minutes(60),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  const live = await world.promotions.activate(
    promotion.id,
    seller.id,
    UserRole.SELLER,
  );

  assert.equal(live.status, 'active');
  assert.ok(live.charged_at);

  assert.equal(
    Number((await payable(world, seller.id)).toJSON().amount),
    Number(before.toJSON().amount) - 20000,
    'the platform owes her twenty thousand less',
  );
  assert.equal(
    Number((await promotionRevenue(world)).toJSON().amount),
    Number(revenueBefore.toJSON().amount) + 20000,
    'and books it as promotion revenue, not commission',
  );
});

dbTest('the fee is taken once, however often activate is called', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '100000');

  const promotion = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    fee: syp('20000'),
    startsAt: minutes(-10),
    endsAt: minutes(60),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });

  await world.promotions.activate(promotion.id, seller.id, UserRole.SELLER);
  const after = await payable(world, seller.id);

  await world.promotions.activate(promotion.id, seller.id, UserRole.SELLER);
  await world.promotions.setStatus(
    promotion.id,
    PromotionStatus.PAUSED,
    seller.id,
    UserRole.SELLER,
  );
  await world.promotions.activate(promotion.id, seller.id, UserRole.SELLER);

  assert.equal(
    Number((await payable(world, seller.id)).toJSON().amount),
    Number(after.toJSON().amount),
    'a pause and a restart is not a second sale',
  );
});

dbTest('a paused placement stops being served', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '100000');

  const promotion = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    fee: syp('20000'),
    startsAt: minutes(-10),
    endsAt: minutes(60),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  await world.promotions.activate(promotion.id, seller.id, UserRole.SELLER);

  assert.ok(
    (await world.promotions.slotsFor(PromotionPlacement.SEARCH)).includes(
      offer.id,
    ),
  );

  await world.promotions.setStatus(
    promotion.id,
    PromotionStatus.PAUSED,
    seller.id,
    UserRole.SELLER,
  );

  assert.ok(
    !(await world.promotions.slotsFor(PromotionPlacement.SEARCH)).includes(
      offer.id,
    ),
  );
});

// ── What a slot does not buy ─────────────────────────────────────────────────

dbTest('a paid slot is not served once the listing is out of stock', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '100000');

  const promotion = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    fee: syp('20000'),
    startsAt: minutes(-10),
    endsAt: minutes(60),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  await world.promotions.activate(promotion.id, seller.id, UserRole.SELLER);

  await world.tx.sellerOffer.update({
    where: { id: offer.id },
    data: { stock: 0 },
  });

  assert.ok(
    !(await world.promotions.slotsFor(PromotionPlacement.SEARCH)).includes(
      offer.id,
    ),
    'paying for a slot does not buy the right to fill it with nothing',
  );
});

dbTest('a placement outside its window is not served', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '100000');

  const promotion = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    fee: syp('20000'),
    startsAt: minutes(30),
    endsAt: minutes(90),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  await world.promotions.activate(promotion.id, seller.id, UserRole.SELLER);

  assert.ok(
    !(await world.promotions.slotsFor(PromotionPlacement.SEARCH)).includes(
      offer.id,
    ),
  );
});

dbTest('the page can never carry more than its ceiling of paid slots', async (world) => {
  const seller = await makeSeller(world.tx);
  await fundPayable(world, seller.id, '1000000');

  for (let i = 0; i < MAX_SLOTS + 3; i += 1) {
    const { offer } = await makeOffer(world.tx, seller.id);
    const promotion = await world.promotions.create({
      offerId: offer.id,
      placement: PromotionPlacement.SEARCH,
      fee: syp('10000'),
      startsAt: minutes(-10),
      endsAt: minutes(60),
      actorId: seller.id,
      actorRole: UserRole.SELLER,
    });
    await world.promotions.activate(promotion.id, seller.id, UserRole.SELLER);
  }

  const slots = await world.promotions.slotsFor(PromotionPlacement.SEARCH, {
    limit: 50,
  });
  assert.ok(
    slots.length <= MAX_SLOTS,
    'a page whose top half is bought stops answering the question it exists for',
  );
});

dbTest('one boutique cannot promote another’s listing', async (world) => {
  const mine = await makeSeller(world.tx);
  const hers = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, hers.id);

  await assert.rejects(
    world.promotions.create({
      offerId: offer.id,
      placement: PromotionPlacement.SEARCH,
      fee: syp('20000'),
      startsAt: minutes(-10),
      endsAt: minutes(60),
      actorId: mine.id,
      actorRole: UserRole.SELLER,
    }),
    /not yours/,
  );
});

// ── Reporting ────────────────────────────────────────────────────────────────

dbTest('impressions and clicks are counted, and buy nothing', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '100000');

  const promotion = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    fee: syp('20000'),
    startsAt: minutes(-10),
    endsAt: minutes(60),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  await world.promotions.activate(promotion.id, seller.id, UserRole.SELLER);

  const payableAfterCharge = await payable(world, seller.id);

  await world.promotions.recordImpressions([offer.id]);
  await world.promotions.recordImpressions([offer.id]);
  await world.promotions.recordClick(offer.id);

  const [mine] = await world.promotions.listForSeller(seller.id);
  assert.equal(mine.impressions, 2);
  assert.equal(mine.clicks, 1);
  assert.equal(mine.click_through_rate, 0.5);

  assert.equal(
    Number((await payable(world, seller.id)).toJSON().amount),
    Number(payableAfterCharge.toJSON().amount),
    'nothing about the money reads a counter a phone can inflate',
  );
});

dbTest('a placement nobody has seen has no click-through rate', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);

  await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    fee: syp('20000'),
    startsAt: minutes(-10),
    endsAt: minutes(60),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });

  const [mine] = await world.promotions.listForSeller(seller.id);
  assert.equal(
    mine.click_through_rate,
    null,
    'a rate over no impressions is unknown, not zero',
  );
});
