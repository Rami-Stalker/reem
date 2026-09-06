import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  PrismaClient,
  ReviewStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { ReputationService } from './reputation.service';

/**
 * The reviews a shopper has written.
 *
 * Her profile computed a count and an average and displayed both, while the
 * row that offered to open them was a "coming soon" sheet — nothing could list
 * them. What these pin is the part that is easy to get wrong once it can:
 * that she sees her own reviews and nobody else's, that a review still in
 * moderation is still shown to its author, and that a review of a shop and a
 * review of a piece arrive in one list each naming what it is about.
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

function build(tx: Tx): World {
  return { tx, reputation: new ReputationService(asPrisma(tx)) };
}

let counter = 0;
const uniq = (prefix: string) =>
  `${prefix}${Date.now().toString(36)}${(counter += 1).toString(36)}`;

async function makeUser(tx: Tx, role: UserRole = UserRole.CUSTOMER) {
  return tx.user.create({
    data: {
      name: role === UserRole.SELLER ? 'أتيليه لجين' : 'زبونة',
      phone: `+9639${String(Date.now() + (counter += 1)).slice(-8)}`,
      username: uniq('mine_spec_'),
      role,
      ...(role === UserRole.SELLER ? { sellerVerifiedAt: new Date() } : {}),
    },
  });
}

async function makeProduct(tx: Tx, sellerId: string, title = 'فستان سهرة') {
  const category = await tx.category.create({
    data: { slug: uniq('cat-'), nameAr: 'فساتين', nameEn: 'Dresses' },
  });
  const product = await tx.product.create({
    data: {
      slug: uniq('prod-'),
      title,
      description: 'للاختبار',
      categoryId: category.id,
    },
  });
  await tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId,
      currency: Currency.SYP,
      price: '500000',
      stock: 5,
    },
  });
  return product;
}

// ── Hers, and only hers ─────────────────────────────────────────────────────

dbTest('a product review and a shop review arrive in one list', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const product = await makeProduct(world.tx, seller.id, 'فستان مطرّز');

  await world.tx.productReview.create({
    data: {
      productId: product.id,
      userId: customer.id,
      rating: 5,
      body: 'أجمل مما توقّعت.',
      status: ReviewStatus.APPROVED,
    },
  });
  await world.tx.sellerReview.create({
    data: {
      sellerId: seller.id,
      userId: customer.id,
      rating: 3,
      body: 'التوصيل تأخّر يومين.',
      status: ReviewStatus.APPROVED,
    },
  });

  const mine = await world.reputation.reviewsByAuthor(customer.id);

  assert.equal(mine.count, 2);
  // A weighted mean over both tables: 5 and 3.
  assert.equal(mine.average, 4);

  // She does not think in terms of two tables, so each row has to say what it
  // is about — a list of bare star ratings names nothing.
  const subjects = mine.data.map((review) => review.subject.title).sort();
  assert.deepEqual(subjects, ['أتيليه لجين', 'فستان مطرّز']);

  const kinds = mine.data.map((review) => review.target_type).sort();
  assert.deepEqual(kinds, ['PRODUCT', 'SELLER']);
});

dbTest('another shopper’s reviews are not in her list', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const mineUser = await makeUser(world.tx);
  const otherUser = await makeUser(world.tx);
  const product = await makeProduct(world.tx, seller.id);

  await world.tx.productReview.create({
    data: {
      productId: product.id,
      userId: otherUser.id,
      rating: 1,
      body: 'ليست لي.',
      status: ReviewStatus.APPROVED,
    },
  });

  const mine = await world.reputation.reviewsByAuthor(mineUser.id);
  assert.equal(mine.count, 0);
  assert.deepEqual(mine.data, []);
});

dbTest('her review still in moderation is shown to her', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const product = await makeProduct(world.tx, seller.id);

  await world.tx.productReview.create({
    data: {
      productId: product.id,
      userId: customer.id,
      rating: 4,
      body: 'قيد المراجعة.',
      status: ReviewStatus.PENDING,
    },
  });

  // Every other read here filters to APPROVED. Hiding her own pending review
  // would look like the app had lost it, and she would write it again.
  const mine = await world.reputation.reviewsByAuthor(customer.id);
  assert.equal(mine.count, 1);
  assert.equal(mine.data[0].status, 'pending');

  // It is hers to see, and still not public.
  const publicReviews = await world.reputation.productReviews(product.id);
  assert.equal(publicReviews.length, 0);
});

dbTest('a boutique’s answer travels with her review', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const product = await makeProduct(world.tx, seller.id);

  await world.tx.productReview.create({
    data: {
      productId: product.id,
      userId: customer.id,
      rating: 2,
      body: 'القياس أصغر من المتوقع.',
      status: ReviewStatus.APPROVED,
      sellerReply: 'صحيح، خذي مقاساً أكبر.',
      sellerRepliedAt: new Date(),
    },
  });

  // The reply is the half she actually came back for.
  const mine = await world.reputation.reviewsByAuthor(customer.id);
  assert.equal(mine.data[0].seller_reply, 'صحيح، خذي مقاساً أكبر.');
});

dbTest('a shopper who has written nothing gets an empty list, not an error', async (world) => {
  const customer = await makeUser(world.tx);

  const mine = await world.reputation.reviewsByAuthor(customer.id);
  assert.deepEqual(mine, { data: [], count: 0, average: 0 });
});
