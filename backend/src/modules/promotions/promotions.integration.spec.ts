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
  StoreAdTier,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { PromotionsService, MAX_SLOTS } from './promotions.service';
import { AdTiersService } from './ad-tiers.service';
import { AdAudienceService } from './ad-audience.service';
import { StoreAdsService } from './store-ads.service';

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
  tiers: AdTiersService;
  ads: StoreAdsService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const ledger = new LedgerService(db);
  const tiers = new AdTiersService(db, ledger);
  const audiences = new AdAudienceService(db);
  const promotions = new PromotionsService(db, ledger, tiers, audiences);
  return {
    tx,
    ledger,
    promotions,
    tiers,
    ads: new StoreAdsService(db, promotions, tiers, audiences),
  };
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
  // Six at once needs a plan that runs six at once.
  await world.tiers.subscribe(seller.id, StoreAdTier.DIAMOND);

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

// ── «باقات الإعلان»: what a plan buys ───────────────────────────────────────

async function makeShopper(tx: Tx, governorate?: string) {
  const u = uniq();
  const shopper = await tx.user.create({
    data: {
      name: 'زبونة',
      username: `prc_${u}`,
      phone: `+96393${Math.floor(1000000 + Math.random() * 8999999)}`,
      passwordHash: 'x',
      role: UserRole.CUSTOMER,
    },
  });
  if (governorate) {
    await tx.address.create({
      data: {
        userId: shopper.id,
        recipientName: 'زبونة',
        recipientPhone: '+963930000000',
        governorate,
        city: governorate,
        addressLine: 'شارع',
      },
    });
  }
  return shopper;
}

const days = (n: number) => minutes(n * 24 * 60);

dbTest('a free boutique cannot buy the feed or the home spotlight', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);

  for (const placement of [PromotionPlacement.FEED_TOP, PromotionPlacement.HOME_SPOTLIGHT]) {
    await assert.rejects(
      world.promotions.create({
        offerId: offer.id,
        placement,
        startsAt: minutes(-1),
        endsAt: days(3),
        actorId: seller.id,
        actorRole: UserRole.SELLER,
      }),
      /plan/,
    );
  }
});

dbTest('silver may target by place but not by interest', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '100000');
  await world.tiers.subscribe(seller.id, StoreAdTier.SILVER);

  const base = {
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    startsAt: minutes(-1),
    endsAt: days(2),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  };
  const located = await world.promotions.create({
    ...base,
    audience: { ...noAudience, targeted: true, governorates: ['حلب'] },
  });
  assert.equal(located.audience.type, 'targeted');

  await assert.rejects(
    world.promotions.create({
      ...base,
      audience: { ...noAudience, targeted: true, followers: true },
    }),
    /GOLD plan/,
  );
});

const noAudience = {
  targeted: false,
  governorates: [] as string[],
  followers: false,
  pastBuyers: false,
  interested: false,
  newShoppers: false,
};

dbTest('a free boutique runs one campaign at a time', async (world) => {
  const seller = await makeSeller(world.tx);
  await fundPayable(world, seller.id, '100000');
  const launch = async () => {
    const { offer } = await makeOffer(world.tx, seller.id);
    const p = await world.promotions.create({
      offerId: offer.id,
      placement: PromotionPlacement.SEARCH,
      startsAt: minutes(-1),
      endsAt: days(1),
      actorId: seller.id,
      actorRole: UserRole.SELLER,
    });
    return world.promotions.activate(p.id, seller.id, UserRole.SELLER);
  };
  await launch();
  await assert.rejects(launch(), /1 campaign/);
});

dbTest('without a fee she pays the quote, and a plan discounts it', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);

  const free = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    startsAt: minutes(-1),
    endsAt: days(4),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  assert.equal(Number(free.fee.amount), 1500 * 4, 'four days of search at the free rate');

  await fundPayable(world, seller.id, '100000');
  await world.tiers.subscribe(seller.id, StoreAdTier.GOLD);
  const gold = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    startsAt: minutes(-1),
    endsAt: days(4),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  assert.equal(Number(gold.fee.amount), 1500 * 4 * 0.8, 'gold takes twenty per cent off');

  await assert.rejects(
    world.promotions.create({
      offerId: offer.id,
      placement: PromotionPlacement.SEARCH,
      fee: syp('100'),
      startsAt: minutes(-1),
      endsAt: days(4),
      actorId: seller.id,
      actorRole: UserRole.SELLER,
    }),
    /costs at least/,
    'naming a fee below the quote is not a discount she can give herself',
  );
});

dbTest('a plan is paid from her earnings, and its credit pays for campaigns first', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '200000');
  const before = Number((await payable(world, seller.id)).toJSON().amount);

  await world.tiers.subscribe(seller.id, StoreAdTier.SILVER);
  const afterPlan = Number((await payable(world, seller.id)).toJSON().amount);
  assert.equal(afterPlan, before - 25_000);

  const p = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    startsAt: minutes(-1),
    endsAt: days(10),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  const live = await world.promotions.activate(p.id, seller.id, UserRole.SELLER);
  assert.equal(Number(live.credit_applied.amount), 13_500, 'ten days of search, less ten per cent');
  assert.equal(
    Number((await payable(world, seller.id)).toJSON().amount),
    afterPlan,
    'credit covered it, so her earnings were not touched',
  );
  const plan = await world.tiers.current(seller.id);
  assert.equal(plan.creditRemaining, 30_000 - 13_500);

  // Credit runs out mid-campaign: the rest comes from earnings.
  const { offer: second } = await makeOffer(world.tx, seller.id);
  const big = await world.promotions.create({
    offerId: second.id,
    placement: PromotionPlacement.CATEGORY,
    startsAt: minutes(-1),
    endsAt: days(29),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  const total = Number(big.fee.amount);
  const charged = await world.promotions.activate(big.id, seller.id, UserRole.SELLER);
  assert.equal(Number(charged.credit_applied.amount), 16_500);
  assert.equal(
    Number((await payable(world, seller.id)).toJSON().amount),
    afterPlan - (total - 16_500),
  );
});

dbTest('a plan her earnings cannot cover is refused, and nothing is left behind', async (world) => {
  const seller = await makeSeller(world.tx);
  await fundPayable(world, seller.id, '1000');
  await assert.rejects(world.tiers.subscribe(seller.id, StoreAdTier.GOLD), /does not cover/);
  assert.equal((await world.tiers.current(seller.id)).tier, StoreAdTier.FREE);
});

dbTest('upgrading starts now and carries the unused credit over', async (world) => {
  const seller = await makeSeller(world.tx);
  await fundPayable(world, seller.id, '500000');
  await world.tiers.subscribe(seller.id, StoreAdTier.SILVER);
  await world.tiers.subscribe(seller.id, StoreAdTier.GOLD);

  const plan = await world.tiers.current(seller.id);
  assert.equal(plan.tier, StoreAdTier.GOLD);
  assert.equal(plan.creditRemaining, 80_000 + 30_000, 'nothing she paid for is lost');

  // A renewal queues after the current plan instead of cutting it short.
  await world.tiers.subscribe(seller.id, StoreAdTier.GOLD).catch(() => undefined);
  const rows = await world.tx.storeAdSubscription.findMany({
    where: { sellerId: seller.id },
    orderBy: { startsAt: 'asc' },
  });
  const last = rows[rows.length - 1];
  assert.ok(last.startsAt.getTime() >= plan.endsAt!.getTime() - 1000);
});

// ── Who sees it ──────────────────────────────────────────────────────────────

dbTest('a targeted campaign reaches only the women it names', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '200000');
  await world.tiers.subscribe(seller.id, StoreAdTier.GOLD);

  const aleppo = await makeShopper(world.tx, 'حلب');
  const damascus = await makeShopper(world.tx, 'دمشق');
  const follower = await makeShopper(world.tx, 'حلب');
  await world.tx.follow.create({ data: { followerId: follower.id, followingId: seller.id } });

  const p = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.HOME_SPOTLIGHT,
    startsAt: minutes(-1),
    endsAt: days(2),
    audience: { ...noAudience, targeted: true, governorates: ['حلب'], followers: true },
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  await world.promotions.activate(p.id, seller.id, UserRole.SELLER);

  const shown = async (viewerId?: string) =>
    (await world.promotions.slotsFor(PromotionPlacement.HOME_SPOTLIGHT, { viewerId })).includes(
      offer.id,
    );
  assert.equal(await shown(follower.id), true, 'in Aleppo and a follower');
  assert.equal(await shown(aleppo.id), false, 'in Aleppo but not a follower');
  assert.equal(await shown(damascus.id), false, 'not in Aleppo');
  assert.equal(await shown(undefined), false, 'a guest has nothing to match');

  const product = await world.tx.product.findFirstOrThrow({
    where: { offers: { some: { id: offer.id } } },
  });
  const reach = await new AdAudienceService(asPrisma(world.tx)).estimateReach(
    seller.id,
    product.categoryId,
    { ...noAudience, targeted: true, governorates: ['حلب'], followers: true },
  );
  assert.ok(reach.shoppers >= 1 && reach.shoppers < reach.total_shoppers);
});

dbTest('she is shown the same home advert at most three times a day', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '200000');
  await world.tiers.subscribe(seller.id, StoreAdTier.GOLD);
  const shopper = await makeShopper(world.tx);

  const p = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.HOME_SPOTLIGHT,
    startsAt: minutes(-1),
    endsAt: days(2),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  await world.promotions.activate(p.id, seller.id, UserRole.SELLER);

  for (let i = 0; i < 3; i += 1) {
    const slots = await world.promotions.slotsFor(PromotionPlacement.HOME_SPOTLIGHT, {
      viewerId: shopper.id,
    });
    assert.ok(slots.includes(offer.id), `shown on visit ${i + 1}`);
    await world.promotions.recordImpressions([offer.id], PromotionPlacement.HOME_SPOTLIGHT, shopper.id);
  }
  const fourth = await world.promotions.slotsFor(PromotionPlacement.HOME_SPOTLIGHT, {
    viewerId: shopper.id,
  });
  assert.ok(!fourth.includes(offer.id), 'the fourth time is how a woman learns to resent a shop');

  const [mine] = await world.promotions.listForSeller(seller.id);
  assert.equal(mine.reach, 1, 'three impressions, one woman');
});

dbTest('a feed placement needs a post of hers that shows the product', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer, product } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '200000');
  await world.tiers.subscribe(seller.id, StoreAdTier.SILVER);

  const draft = {
    offerId: offer.id,
    placement: PromotionPlacement.FEED_TOP,
    startsAt: minutes(-1),
    endsAt: days(2),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  };
  await assert.rejects(world.promotions.create(draft), /post/);

  const post = await world.tx.commerceContent.create({
    data: {
      authorId: seller.id,
      authorKind: 'SELLER',
      payload: {},
      contentType: 'product_post',
      status: 'PUBLISHED',
      visibility: 'PUBLIC',
      authorIsPublic: true,
      publishedAt: new Date(),
      productTags: { create: { productId: product.id } },
    },
  });
  const created = await world.promotions.create(draft);
  assert.equal(created.content_id, post.id, 'her latest post of the piece is pinned');
  await world.promotions.activate(created.id, seller.id, UserRole.SELLER);

  const [slot] = await world.promotions.serve(PromotionPlacement.FEED_TOP);
  assert.equal(slot?.contentId, post.id);
});

dbTest('the more a boutique pays, the more often it is shown — but the others still are', async (world) => {
  const diamond = await makeSeller(world.tx);
  const free = await makeSeller(world.tx);
  await fundPayable(world, diamond.id, '500000');
  await fundPayable(world, free.id, '500000');
  await world.tiers.subscribe(diamond.id, StoreAdTier.DIAMOND);

  const launch = async (sellerId: string) => {
    const { offer } = await makeOffer(world.tx, sellerId);
    const p = await world.promotions.create({
      offerId: offer.id,
      placement: PromotionPlacement.SEARCH,
      startsAt: minutes(-1),
      endsAt: days(1),
      actorId: sellerId,
      actorRole: UserRole.SELLER,
    });
    await world.promotions.activate(p.id, sellerId, UserRole.SELLER);
    return offer.id;
  };
  const rich = await launch(diamond.id);
  const modest = await launch(free.id);

  let seed = 7;
  const random = () => ((seed = (seed * 16807) % 2147483647) / 2147483647);
  let richFirst = 0;
  let modestFirst = 0;
  for (let i = 0; i < 400; i += 1) {
    const [first] = await world.promotions.serve(PromotionPlacement.SEARCH, { limit: 1, random });
    if (first?.offerId === rich) richFirst += 1;
    if (first?.offerId === modest) modestFirst += 1;
  }
  assert.ok(richFirst > modestFirst * 2, `diamond first ${richFirst}×, free ${modestFirst}×`);
  assert.ok(modestFirst > 0, 'a boutique that paid and is never seen has been sold nothing');
});

dbTest('an order from a woman who tapped the advert is credited to it', async (world) => {
  const seller = await makeSeller(world.tx);
  const { offer, product } = await makeOffer(world.tx, seller.id);
  await fundPayable(world, seller.id, '200000');
  const shopper = await makeShopper(world.tx);

  const p = await world.promotions.create({
    offerId: offer.id,
    placement: PromotionPlacement.SEARCH,
    startsAt: minutes(-60),
    endsAt: days(2),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  await world.promotions.activate(p.id, seller.id, UserRole.SELLER);
  await world.promotions.recordImpressions([offer.id], PromotionPlacement.SEARCH, shopper.id);
  await world.promotions.recordClick(offer.id, PromotionPlacement.SEARCH, shopper.id);

  const u = uniq();
  const order = await world.tx.order.create({
    data: {
      number: `PR-${u}`,
      userId: shopper.id,
      fxRate: '1',
      itemsSubtotal: '100000',
      grandTotal: '100000',
      recipientName: 'زبونة',
      recipientPhone: '+963930000000',
      addressLine: 'شارع',
      governorate: 'دمشق',
      city: 'دمشق',
    } as never,
  });
  await world.tx.sellerOrder.create({
    data: {
      number: `PRS-${u}`,
      orderId: order.id,
      sellerId: seller.id,
      currency: Currency.SYP,
      itemsSubtotal: '100000',
      commissionBase: '100000',
      sellerNet: '90000',
      // A moment after the tap: the advert came first.
      createdAt: minutes(1),
      items: {
        create: {
          offerId: offer.id,
          productId: product.id,
          titleSnapshot: 'فستان',
          sellerSnapshot: 'بوتيك',
          currency: Currency.SYP,
          unitPrice: '100000',
          lineTotal: '100000',
        },
      },
    },
  });

  const [mine] = await world.promotions.listForSeller(seller.id);
  assert.equal(mine.attributed_orders, 1);
  assert.equal(Number(mine.attributed_revenue.amount), 100000);

  const overview = await world.ads.overview(seller.id);
  assert.equal(overview.attributed_orders, 1);
  assert.ok(overview.return_on_ad_spend !== null && overview.return_on_ad_spend > 0);
});
