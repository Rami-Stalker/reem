import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  PrismaClient,
  ReviewStatus,
  ReviewTargetType,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { ReputationService } from './reputation.service';

/**
 * A seller answering a review.
 *
 * She could read every review of her goods and answer none of them, so the
 * only remedy for an unfair one was asking a moderator to take it down. What
 * these pin is who may answer what: the catalogue entry is SHARED, so "her"
 * product review is one on a product she actually lists, and a review still
 * in moderation has no audience to be answered in front of.
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
      name: role === UserRole.SELLER ? 'بائعة' : 'زبونة',
      phone: `+9639${String(Date.now() + (counter += 1)).slice(-8)}`,
      username: uniq('review_spec_'),
      role,
      ...(role === UserRole.SELLER ? { sellerVerifiedAt: new Date() } : {}),
    },
  });
}

/** A product listed by [sellerId], with a review on it. */
async function makeReviewedProduct(
  tx: Tx,
  sellerId: string,
  customerId: string,
  status: ReviewStatus = ReviewStatus.APPROVED,
) {
  const category = await tx.category.create({
    data: { slug: uniq('cat-'), nameAr: 'تجربة', nameEn: 'Test' },
  });
  const product = await tx.product.create({
    data: {
      slug: uniq('prod-'),
      title: 'فستان تجريبي',
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
  const review = await tx.productReview.create({
    data: {
      productId: product.id,
      userId: customerId,
      rating: 2,
      body: 'القياس أصغر من المتوقع.',
      status,
    },
  });
  return { product, review };
}

// ── Answering ───────────────────────────────────────────────────────────────

dbTest('she answers a review of something she lists', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const { review } = await makeReviewedProduct(
    world.tx,
    seller.id,
    customer.id,
  );

  const answered = (await world.reputation.replyToReview(
    seller.id,
    review.id,
    ReviewTargetType.PRODUCT,
    'صحيح، الموديل ضيّق — خذي مقاساً أكبر.',
  )) as { seller_reply: string | null; seller_replied_at: string | null };

  assert.equal(answered.seller_reply, 'صحيح، الموديل ضيّق — خذي مقاساً أكبر.');
  assert.ok(answered.seller_replied_at);
});

dbTest('the reply is published under the review for everyone', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const { product, review } = await makeReviewedProduct(
    world.tx,
    seller.id,
    customer.id,
  );
  await world.reputation.replyToReview(
    seller.id,
    review.id,
    ReviewTargetType.PRODUCT,
    'اعتذر عن ذلك، وسأصحّح جدول المقاسات.',
  );

  // The buyer's own view of the product page — a reply nobody else can read
  // would be a letter to herself.
  const [published] = (await world.reputation.productReviews(product.id)) as {
    seller_reply: string | null;
  }[];
  assert.equal(published.seller_reply, 'اعتذر عن ذلك، وسأصحّح جدول المقاسات.');
});

dbTest('an empty reply takes it back down', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const { review } = await makeReviewedProduct(
    world.tx,
    seller.id,
    customer.id,
  );
  await world.reputation.replyToReview(
    seller.id,
    review.id,
    ReviewTargetType.PRODUCT,
    'ردّ كُتب في لحظة غضب',
  );

  const removed = (await world.reputation.replyToReview(
    seller.id,
    review.id,
    ReviewTargetType.PRODUCT,
    '   ',
  )) as { seller_reply: string | null; seller_replied_at: string | null };

  assert.equal(removed.seller_reply, null);
  assert.equal(removed.seller_replied_at, null);
});

// ── Who may answer what ─────────────────────────────────────────────────────

dbTest('a seller cannot answer a review of goods she does not list', async (
  world,
) => {
  const mine = await makeUser(world.tx, UserRole.SELLER);
  const hers = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const { review } = await makeReviewedProduct(world.tx, hers.id, customer.id);

  // The catalogue entry is shared, so ownership has to run through the offer.
  // Checking the product alone would let any seller answer for any other.
  await assert.rejects(() =>
    world.reputation.replyToReview(
      mine.id,
      review.id,
      ReviewTargetType.PRODUCT,
      'ليست بضاعتي',
    ),
  );
});

dbTest('listing the same product earns the right to answer', async (world) => {
  const first = await makeUser(world.tx, UserRole.SELLER);
  const second = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const { product, review } = await makeReviewedProduct(
    world.tx,
    first.id,
    customer.id,
  );

  await world.tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId: second.id,
      currency: Currency.SYP,
      price: '480000',
      stock: 3,
    },
  });

  // Both list it, so both may answer — the review is of the product, and a
  // competitor's page is a page she also sells from.
  const answered = (await world.reputation.replyToReview(
    second.id,
    review.id,
    ReviewTargetType.PRODUCT,
    'عندي منه بمقاسات أوسع.',
  )) as { seller_reply: string | null };
  assert.equal(answered.seller_reply, 'عندي منه بمقاسات أوسع.');
});

dbTest("a seller cannot answer another shop's review", async (world) => {
  const mine = await makeUser(world.tx, UserRole.SELLER);
  const hers = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const review = await world.tx.sellerReview.create({
    data: {
      sellerId: hers.id,
      userId: customer.id,
      rating: 1,
      body: 'تأخّر الطلب كثيراً.',
      status: ReviewStatus.APPROVED,
    },
  });

  await assert.rejects(() =>
    world.reputation.replyToReview(
      mine.id,
      review.id,
      ReviewTargetType.SELLER,
      'لست أنا',
    ),
  );
});

dbTest('a review still in moderation has nobody to answer', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const { review } = await makeReviewedProduct(
    world.tx,
    seller.id,
    customer.id,
    ReviewStatus.PENDING,
  );

  await assert.rejects(() =>
    world.reputation.replyToReview(
      seller.id,
      review.id,
      ReviewTargetType.PRODUCT,
      'ردّ على شيء لم يُنشر بعد',
    ),
  );
});

// ── Her desk ────────────────────────────────────────────────────────────────

dbTest('her desk merges both kinds and counts the unanswered', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  const { review } = await makeReviewedProduct(
    world.tx,
    seller.id,
    customer.id,
  );
  await world.tx.sellerReview.create({
    data: {
      sellerId: seller.id,
      userId: customer.id,
      rating: 5,
      body: 'تعامل راقٍ.',
      status: ReviewStatus.APPROVED,
    },
  });

  const desk = await world.reputation.reviewsForSeller(seller.id);
  assert.equal(desk.data.length, 2);
  assert.equal(desk.unanswered, 2);
  assert.deepEqual(
    desk.data.map((row) => row.target_type).sort(),
    [ReviewTargetType.PRODUCT, ReviewTargetType.SELLER],
  );
  // A product review carries the product it is about; a shop review does not.
  const product = desk.data.find(
    (row) => row.target_type === ReviewTargetType.PRODUCT,
  );
  assert.equal(product?.product?.title, 'فستان تجريبي');

  await world.reputation.replyToReview(
    seller.id,
    review.id,
    ReviewTargetType.PRODUCT,
    'شكراً لملاحظتكِ.',
  );

  const after = await world.reputation.reviewsForSeller(seller.id);
  assert.equal(after.unanswered, 1);

  const waiting = await world.reputation.reviewsForSeller(
    seller.id,
    'unanswered',
  );
  assert.equal(waiting.data.length, 1);
  assert.equal(waiting.data[0].target_type, ReviewTargetType.SELLER);
});

dbTest('an unpublished review never reaches her desk', async (world) => {
  const seller = await makeUser(world.tx, UserRole.SELLER);
  const customer = await makeUser(world.tx);
  await makeReviewedProduct(
    world.tx,
    seller.id,
    customer.id,
    ReviewStatus.PENDING,
  );

  const desk = await world.reputation.reviewsForSeller(seller.id);
  assert.equal(desk.data.length, 0);
});
