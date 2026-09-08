import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  OfferStatus,
  PrismaClient,
  ProductStatus,
  UserRole,
} from '@prisma/client';

import { Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { LedgerService } from '../ledger/ledger.service';
import { WalletService } from '../ledger/wallet.service';
import {
  LoyaltyService,
  POINTS_PER_REDEMPTION,
} from '../finance/loyalty.service';
import { CouponsService } from '../rewards/coupons.service';
import { claimStock } from './workflow/stock-claim';

/**
 * What two women reaching for the same thing at the same moment get.
 *
 * Every check in here was already written somewhere in the code — the stock
 * check in `assertPurchasable`, the usage check in `evaluate`, the balance
 * check in `convertToWallet`. All three read a number, decided against it,
 * and then wrote as though nothing could have happened in between. Under READ
 * COMMITTED something can, and did: the losing request read the world as it
 * was before the winner touched it and passed a check it should have failed.
 *
 * These tests cannot run inside the rolled-back transaction the other
 * integration specs use, because that harness gives every assertion the same
 * connection and a race needs two. So they commit real rows, race them on
 * genuinely parallel connections, and clean up after themselves.
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
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;

/** Everything a test made, torn down youngest-first. */
class Fixtures {
  readonly userIds: string[] = [];
  readonly productIds: string[] = [];
  readonly categoryIds: string[] = [];
  readonly couponIds: string[] = [];

  async destroy(): Promise<void> {
    await prisma.coupon.deleteMany({ where: { id: { in: this.couponIds } } });
    await prisma.product.deleteMany({ where: { id: { in: this.productIds } } });
    await prisma.category.deleteMany({
      where: { id: { in: this.categoryIds } },
    });
    await prisma.user.deleteMany({ where: { id: { in: this.userIds } } });
  }
}

async function makeUser(
  f: Fixtures,
  tag: string,
  role: UserRole = UserRole.CUSTOMER,
  points = 0,
) {
  const u = uniq(tag);
  const user = await prisma.user.create({
    data: {
      name: `race-${tag}`,
      username: `race_${u}`,
      phone: `+9639${u.slice(-8)}`,
      passwordHash: 'x',
      role,
      points,
    },
  });
  f.userIds.push(user.id);
  return user;
}

/** One offer, with exactly `stock` on the shelf. */
async function makeOffer(f: Fixtures, stock: number) {
  const seller = await makeUser(f, 'sel', UserRole.SELLER);
  const u = uniq('cat');
  const category = await prisma.category.create({
    data: { slug: `race-cat-${u}`, nameAr: 'سباق', nameEn: 'Race' },
  });
  f.categoryIds.push(category.id);

  const product = await prisma.product.create({
    data: {
      slug: `race-prod-${u}`,
      title: 'فستان السباق',
      description: 'The last one on the shelf.',
      categoryId: category.id,
      status: ProductStatus.ACTIVE,
      offers: {
        create: {
          sellerId: seller.id,
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
  f.productIds.push(product.id);
  return { offer: product.offers[0], product };
}

/**
 * Runs `attempt` `n` times on genuinely parallel connections and reports how
 * many got through. Each attempt gets its own transaction, so they contend
 * the way two checkouts contend.
 */
async function race(
  n: number,
  attempt: (index: number) => Promise<unknown>,
): Promise<{ won: number; lost: number; errors: string[] }> {
  const results = await Promise.allSettled(
    Array.from({ length: n }, (_, i) => attempt(i)),
  );
  const errors = results
    .filter((r): r is PromiseRejectedResult => r.status === 'rejected')
    .map((r) => String((r.reason as Error)?.message ?? r.reason));
  return {
    won: results.filter((r) => r.status === 'fulfilled').length,
    lost: errors.length,
    errors,
  };
}

// ── Stock ────────────────────────────────────────────────────────────────────

dbTest(
  'the last dress is sold once, not to everyone who reached for it',
  async () => {
    const f = new Fixtures();
    try {
      const { offer, product } = await makeOffer(f, 1);

      const outcome = await race(8, () =>
        prisma.$transaction((tx) =>
          claimStock(tx, {
            offerId: offer.id,
            offerVariantId: null,
            quantity: 1,
            title: product.title,
          }),
        ),
      );

      assert.equal(
        outcome.won,
        1,
        'exactly one checkout may claim the last unit',
      );
      assert.equal(outcome.lost, 7);
      assert.ok(
        outcome.errors.every((message) => message.includes('sold out')),
        `the seven who lost are told it sold out, not shown a crash: ${outcome.errors[0]}`,
      );

      const after = await prisma.sellerOffer.findUniqueOrThrow({
        where: { id: offer.id },
      });
      assert.equal(after.stock, 0, 'stock lands on zero and never below it');
    } finally {
      await f.destroy();
    }
  },
);

dbTest('a shelf of five serves five baskets of one, and no sixth', async () => {
  const f = new Fixtures();
  try {
    const { offer, product } = await makeOffer(f, 5);

    const outcome = await race(12, () =>
      prisma.$transaction((tx) =>
        claimStock(tx, {
          offerId: offer.id,
          offerVariantId: null,
          quantity: 1,
          title: product.title,
        }),
      ),
    );

    assert.equal(outcome.won, 5);
    const after = await prisma.sellerOffer.findUniqueOrThrow({
      where: { id: offer.id },
    });
    assert.equal(after.stock, 0);
  } finally {
    await f.destroy();
  }
});

dbTest('a basket larger than the shelf is refused, not part-filled', async () => {
  const f = new Fixtures();
  try {
    const { offer, product } = await makeOffer(f, 3);

    await assert.rejects(
      prisma.$transaction((tx) =>
        claimStock(tx, {
          offerId: offer.id,
          offerVariantId: null,
          quantity: 4,
          title: product.title,
        }),
      ),
      /sold out/,
    );

    const after = await prisma.sellerOffer.findUniqueOrThrow({
      where: { id: offer.id },
    });
    assert.equal(after.stock, 3, 'a refused claim takes nothing');
  } finally {
    await f.destroy();
  }
});

// ── Coupons ──────────────────────────────────────────────────────────────────

dbTest(
  'a single-use code funds one basket, however many arrive together',
  async () => {
    const f = new Fixtures();
    try {
      const customer = await makeUser(f, 'cus');
      const coupon = await prisma.coupon.create({
        data: {
          code: `RACE${uniq('C').toUpperCase()}`,
          title: 'One use only',
          discountPercent: '10',
          maxUses: 1,
          expiresAt: new Date(Date.now() + 86_400_000),
        },
      });
      f.couponIds.push(coupon.id);

      const coupons = new CouponsService(prisma as unknown as PrismaService);
      const outcome = await race(6, (i) =>
        prisma.$transaction((tx) =>
          coupons.redeemInTransaction(
            tx,
            coupon.id,
            customer.id,
            // A distinct order per attempt: these are six baskets, not a retry.
            `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
            Money.of('1000', Currency.SYP),
          ),
        ),
      );

      assert.equal(outcome.won, 1, 'max_uses: 1 means one');
      const after = await prisma.coupon.findUniqueOrThrow({
        where: { id: coupon.id },
      });
      assert.equal(after.usedCount, 1);
      assert.equal(
        await prisma.couponRedemption.count({ where: { couponId: coupon.id } }),
        1,
        'the redemption ledger agrees with the counter',
      );
    } finally {
      await prisma.couponRedemption.deleteMany({
        where: { couponId: { in: f.couponIds } },
      });
      await f.destroy();
    }
  },
);

dbTest(
  'a per-customer limit holds against the same customer in parallel',
  async () => {
    const f = new Fixtures();
    try {
      const customer = await makeUser(f, 'cus');
      const coupon = await prisma.coupon.create({
        data: {
          code: `RACE${uniq('P').toUpperCase()}`,
          title: 'Twice per customer',
          discountPercent: '10',
          perUserLimit: 2,
          expiresAt: new Date(Date.now() + 86_400_000),
        },
      });
      f.couponIds.push(coupon.id);

      const coupons = new CouponsService(prisma as unknown as PrismaService);
      const outcome = await race(7, (i) =>
        prisma.$transaction((tx) =>
          coupons.redeemInTransaction(
            tx,
            coupon.id,
            customer.id,
            `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`,
            Money.of('1000', Currency.SYP),
          ),
        ),
      );

      assert.equal(outcome.won, 2, 'two per customer, not seven');
      assert.equal(
        await prisma.couponRedemption.count({
          where: { couponId: coupon.id, userId: customer.id },
        }),
        2,
      );
    } finally {
      await prisma.couponRedemption.deleteMany({
        where: { couponId: { in: f.couponIds } },
      });
      await f.destroy();
    }
  },
);

// ── Points ───────────────────────────────────────────────────────────────────

dbTest('points convert to credit once, so the liability is paid once', async () => {
  // This test does not tear itself down, and that is deliberate.
  //
  // A conversion posts a balanced journal entry — loyalty liability down,
  // customer wallet up — and the ledger is append-only: `LedgerService` moves
  // cached balances only through `post`, and nothing in the codebase deletes
  // an entry, because a book you can delete from is not a book. An earlier
  // version of this test cleaned up after itself by deleting the entry it had
  // created, which removed the customer's half and left the platform's
  // LOYALTY_LIABILITY balance still carrying the decrement. The `finance`
  // suite noticed immediately: "a healthy book reports sound" started
  // failing, because the book was no longer sound.
  //
  // The entry this leaves behind is a correct one. What it costs is a handful
  // of rows in the development database, which is the right price.
  const f = new Fixtures();
  const step = POINTS_PER_REDEMPTION;
  try {
    // Exactly enough for one conversion, and no more.
    const customer = await makeUser(f, 'cus', UserRole.CUSTOMER, step);
    // Kept out of the teardown along with everything the conversion writes.
    f.userIds.pop();

    const db = prisma as unknown as PrismaService;
    const ledger = new LedgerService(db);
    const wallets = new WalletService(db, ledger);
    const loyalty = new LoyaltyService(db, ledger, wallets);

    const outcome = await race(5, () =>
      loyalty.convertToWallet(customer.id, step),
    );

    assert.equal(outcome.won, 1, 'one balance buys one conversion');
    assert.ok(
      outcome.errors.every((message) => message.includes('Not enough points')),
      `the losers are told why: ${outcome.errors[0]}`,
    );

    const after = await prisma.user.findUniqueOrThrow({
      where: { id: customer.id },
      select: { points: true },
    });
    assert.equal(after.points, 0, 'points land on zero and never below it');

    const wallet = await prisma.wallet.findFirst({
      where: { userId: customer.id },
    });
    const credited = await prisma.walletTransaction.count({
      where: { walletId: wallet?.id ?? '' },
    });
    assert.equal(credited, 1, 'and the wallet was credited exactly once');
  } finally {
    // `f` is empty by design — see the note at the top of this test.
    await f.destroy();
  }
});
