import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  FlashSaleStatus,
  OfferStatus,
  PrismaClient,
  ProductStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { CART_INCLUDE } from '../cart/cart.repository';
import { unitPriceOf } from '../cart/cart.serializer';
import { claimFlashSaleUnits } from '../orders/workflow/stock-claim';
import { FlashSalesService } from './flash-sales.service';

/**
 * What a customer is actually charged during a sale.
 *
 * The rule these are guarding is that the price she sees and the price she
 * pays come from one function. Everything below reads the price the way the
 * basket does — through `unitPriceOf` on a real cart row — rather than asking
 * the sale service what it thinks, because the service being right about a
 * price the cart never applies is exactly the bug worth catching.
 */
const prisma = new PrismaClient();

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

function dbTest(name: string, body: () => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    await body();
  });
}

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;
const minutes = (n: number) => new Date(Date.now() + n * 60_000);

/** Everything a case made, torn down youngest-first. */
class Shop {
  saleIds: string[] = [];
  userIds: string[] = [];
  productIds: string[] = [];
  categoryIds: string[] = [];

  async destroy() {
    await prisma.cartItem.deleteMany({ where: { userId: { in: this.userIds } } });
    await prisma.flashSale.deleteMany({ where: { id: { in: this.saleIds } } });
    await prisma.product.deleteMany({ where: { id: { in: this.productIds } } });
    await prisma.category.deleteMany({ where: { id: { in: this.categoryIds } } });
    await prisma.user.deleteMany({ where: { id: { in: this.userIds } } });
  }
}

async function openShop(listPrice = '100000') {
  const shop = new Shop();
  const u = uniq();

  const seller = await prisma.user.create({
    data: {
      name: 'بوتيك',
      username: `fs_s_${u}`,
      phone: `+96395${u.slice(-7)}`,
      passwordHash: 'x',
      role: UserRole.SELLER,
    },
  });
  const buyer = await prisma.user.create({
    data: {
      name: 'ريم',
      username: `fs_b_${u}`,
      phone: `+96394${u.slice(-7)}`,
      passwordHash: 'x',
      role: UserRole.CUSTOMER,
    },
  });
  shop.userIds.push(seller.id, buyer.id);

  const category = await prisma.category.create({
    data: { slug: `fs-cat-${u}`, nameAr: 'فئة', nameEn: 'Cat' },
  });
  shop.categoryIds.push(category.id);

  const product = await prisma.product.create({
    data: {
      slug: `fs-prod-${u}`,
      title: 'فستان سهرة',
      description: 'وصف',
      categoryId: category.id,
      status: ProductStatus.ACTIVE,
      offers: {
        create: {
          sellerId: seller.id,
          currency: Currency.SYP,
          price: listPrice,
          stock: 50,
          status: OfferStatus.ACTIVE,
          isActive: true,
        },
      },
    },
    include: { offers: true },
  });
  shop.productIds.push(product.id);

  const service = new FlashSalesService(prisma as unknown as PrismaService);
  return { shop, seller, buyer, offer: product.offers[0], service };
}

/** A money amount as a number, so a test never depends on decimal places. */
const amount = (money: Money) => Number(money.toJSON().amount);

/** The price the basket would charge — the only figure that matters. */
async function basketPrice(buyerId: string, offerId: string): Promise<Money> {
  await prisma.cartItem.deleteMany({ where: { userId: buyerId } });
  await prisma.cartItem.create({
    data: { userId: buyerId, offerId, quantity: 1 },
  });
  const line = await prisma.cartItem.findFirstOrThrow({
    where: { userId: buyerId, offerId },
    include: CART_INCLUDE,
  });
  return unitPriceOf(line);
}

async function runSale(
  service: FlashSalesService,
  shop: Shop,
  seller: { id: string },
  offerId: string,
  over: {
    salePrice?: number;
    startsAt?: Date;
    endsAt?: Date;
    cap?: number | null;
    activate?: boolean;
  } = {},
) {
  const sale = await service.create({
    title: 'تخفيضات',
    startsAt: over.startsAt ?? minutes(-10),
    endsAt: over.endsAt ?? minutes(60),
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });
  shop.saleIds.push(sale.id);

  await service.addItem({
    saleId: sale.id,
    offerId,
    salePrice: over.salePrice ?? 60000,
    quantityCap: over.cap ?? null,
    actorId: seller.id,
    actorRole: UserRole.SELLER,
  });

  if (over.activate !== false) {
    await service.setStatus(
      sale.id,
      FlashSaleStatus.ACTIVE,
      seller.id,
      UserRole.SELLER,
    );
  }
  return sale;
}

// ── The price ────────────────────────────────────────────────────────────────

dbTest('a live sale is what the basket charges', async () => {
  const { shop, seller, buyer, offer, service } = await openShop('100000');
  try {
    assert.equal(
      amount(await basketPrice(buyer.id, offer.id)),
      100000,
      'full price before the sale',
    );

    await runSale(service, shop, seller, offer.id, { salePrice: 60000 });

    assert.equal(
      amount(await basketPrice(buyer.id, offer.id)),
      60000,
      'and the sale price during it — from the same function the cart uses',
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('a sale that has not started yet changes nothing', async () => {
  const { shop, seller, buyer, offer, service } = await openShop('100000');
  try {
    await runSale(service, shop, seller, offer.id, {
      salePrice: 60000,
      startsAt: minutes(30),
      endsAt: minutes(90),
    });
    assert.equal(
      amount(await basketPrice(buyer.id, offer.id)),
      100000,
      'tomorrow’s sale is not today’s price',
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('a sale that has ended stops discounting', async () => {
  const { shop, seller, buyer, offer, service } = await openShop('100000');
  try {
    await runSale(service, shop, seller, offer.id, {
      salePrice: 60000,
      startsAt: minutes(-120),
      endsAt: minutes(-5),
    });
    assert.equal(
      amount(await basketPrice(buyer.id, offer.id)),
      100000,
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('pausing a sale stops the price immediately', async () => {
  const { shop, seller, buyer, offer, service } = await openShop('100000');
  try {
    const sale = await runSale(service, shop, seller, offer.id, {
      salePrice: 60000,
    });
    assert.equal(
      amount(await basketPrice(buyer.id, offer.id)),
      60000,
    );

    await service.setStatus(
      sale.id,
      FlashSaleStatus.PAUSED,
      seller.id,
      UserRole.SELLER,
    );

    assert.equal(
      amount(await basketPrice(buyer.id, offer.id)),
      100000,
      'the stop button has to work inside the window, or it is not a stop button',
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('a draft sale prices nothing', async () => {
  const { shop, seller, buyer, offer, service } = await openShop('100000');
  try {
    await runSale(service, shop, seller, offer.id, {
      salePrice: 60000,
      activate: false,
    });
    assert.equal(
      amount(await basketPrice(buyer.id, offer.id)),
      100000,
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('the cheaper of two overlapping sales wins', async () => {
  const { shop, seller, buyer, offer, service } = await openShop('100000');
  try {
    await runSale(service, shop, seller, offer.id, { salePrice: 80000 });
    await runSale(service, shop, seller, offer.id, { salePrice: 55000 });

    assert.equal(
      amount(await basketPrice(buyer.id, offer.id)),
      55000,
      'a customer shown two prices gets the lower one',
    );
  } finally {
    await shop.destroy();
  }
});

// ── What the service refuses ─────────────────────────────────────────────────

dbTest('a "sale" above the listing price is refused', async () => {
  const { shop, seller, offer, service } = await openShop('100000');
  try {
    const sale = await service.create({
      title: 'تخفيضات',
      startsAt: minutes(-10),
      endsAt: minutes(60),
      actorId: seller.id,
      actorRole: UserRole.SELLER,
    });
    shop.saleIds.push(sale.id);

    await assert.rejects(
      service.addItem({
        saleId: sale.id,
        offerId: offer.id,
        salePrice: 120000,
        actorId: seller.id,
        actorRole: UserRole.SELLER,
      }),
      /must be below/,
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('an empty sale cannot go live', async () => {
  const { shop, seller, service } = await openShop();
  try {
    const sale = await service.create({
      title: 'فارغ',
      startsAt: minutes(-10),
      endsAt: minutes(60),
      actorId: seller.id,
      actorRole: UserRole.SELLER,
    });
    shop.saleIds.push(sale.id);

    await assert.rejects(
      service.setStatus(
        sale.id,
        FlashSaleStatus.ACTIVE,
        seller.id,
        UserRole.SELLER,
      ),
      /nothing in it/,
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('one boutique cannot put another’s listing in her sale', async () => {
  const first = await openShop();
  const second = await openShop();
  try {
    const sale = await first.service.create({
      title: 'تخفيضات',
      startsAt: minutes(-10),
      endsAt: minutes(60),
      actorId: first.seller.id,
      actorRole: UserRole.SELLER,
    });
    first.shop.saleIds.push(sale.id);

    await assert.rejects(
      first.service.addItem({
        saleId: sale.id,
        offerId: second.offer.id,
        salePrice: 50000,
        actorId: first.seller.id,
        actorRole: UserRole.SELLER,
      }),
      /another boutique|not yours/,
    );
  } finally {
    await first.shop.destroy();
    await second.shop.destroy();
  }
});

// ── The cap ──────────────────────────────────────────────────────────────────

dbTest('a filled cap ends the sale price for whoever comes next', async () => {
  const { shop, seller, buyer, offer, service } = await openShop('100000');
  try {
    await runSale(service, shop, seller, offer.id, {
      salePrice: 60000,
      cap: 2,
    });

    assert.equal(
      amount(await basketPrice(buyer.id, offer.id)),
      60000,
    );

    // Two units go.
    await prisma.$transaction((tx) =>
      claimFlashSaleUnits(tx, { offerId: offer.id, quantity: 2 }),
    );

    assert.equal(
      amount(await basketPrice(buyer.id, offer.id)),
      100000,
      'the doorbuster is over even though the window is still open',
    );
  } finally {
    await shop.destroy();
  }
});

dbTest('the counter tells the truth when buyers arrive together', async () => {
  const { shop, seller, offer, service } = await openShop('100000');
  try {
    await runSale(service, shop, seller, offer.id, {
      salePrice: 60000,
      cap: 3,
    });

    // Ten simultaneous single-unit checkouts. The cap is soft by design — see
    // `claimFlashSaleUnits` — so what is asserted is not that exactly three
    // got it, but that every unit sold is counted. A counter that loses
    // writes under concurrency is how a sale silently runs for ever.
    const results = await Promise.all(
      Array.from({ length: 10 }, () =>
        prisma.$transaction((tx) =>
          claimFlashSaleUnits(tx, { offerId: offer.id, quantity: 1 }),
        ),
      ),
    );
    const claimed = results.filter((r) => r.claimed).length;

    const item = await prisma.flashSaleItem.findFirstOrThrow({
      where: { offerId: offer.id },
    });
    assert.equal(
      item.quantitySold,
      claimed,
      'every unit the sale gave away is on the counter',
    );
    assert.equal(claimed, 10, 'and a live sale never refuses a paid order');
  } finally {
    await shop.destroy();
  }
});

dbTest('an ended sale takes no more units', async () => {
  const { shop, seller, offer, service } = await openShop('100000');
  try {
    const sale = await runSale(service, shop, seller, offer.id, {
      salePrice: 60000,
    });
    await service.setStatus(
      sale.id,
      FlashSaleStatus.PAUSED,
      seller.id,
      UserRole.SELLER,
    );

    const result = await prisma.$transaction((tx) =>
      claimFlashSaleUnits(tx, { offerId: offer.id, quantity: 1 }),
    );
    assert.equal(result.claimed, false);

    const item = await prisma.flashSaleItem.findFirstOrThrow({
      where: { offerId: offer.id },
    });
    assert.equal(item.quantitySold, 0);
  } finally {
    await shop.destroy();
  }
});

dbTest('what is live is what a shopper is shown', async () => {
  const { shop, seller, offer, service } = await openShop('100000');
  try {
    await runSale(service, shop, seller, offer.id, {
      salePrice: 60000,
      cap: 5,
    });

    const live = await service.live(50);
    const mine = live
      .flatMap((sale) => sale.items)
      .find((item) => item.offer_id === offer.id);

    assert.ok(mine, 'the sale is on the public list');
    assert.equal(Number(mine.sale_price.amount), 60000);
    assert.equal(Number(mine.compare_at.amount), 100000);
    assert.equal(mine.units_left, 5);
  } finally {
    await shop.destroy();
  }
});
