import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  OfferStatus,
  PrismaClient,
  ProductStatus,
  ReviewStatus,
  TrustSignalStatus,
  TrustSubject,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { TrustFactsService } from './trust-facts.service';
import { TrustService } from './trust.service';

/**
 * The trust engine against real rows.
 *
 * The kernel tests prove the scoring rules. These prove the other half — that
 * the facts handed to those rules are the facts the database actually holds,
 * which is where a scorer usually goes wrong: a rule that is right about a
 * number nobody is measuring correctly.
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
  trust: TrustService;
  facts: TrustFactsService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const facts = new TrustFactsService(db);
  return { tx, facts, trust: new TrustService(db, facts) };
}

let seq = 0;
const uniq = () => `${Date.now()}${(seq += 1)}`;

async function makeUser(
  tx: Tx,
  over: { role?: UserRole; ageDays?: number; phoneVerified?: boolean } = {},
) {
  const u = uniq();
  const created = over.ageDays
    ? new Date(Date.now() - over.ageDays * 86_400_000)
    : undefined;
  return tx.user.create({
    data: {
      name: 'ريم',
      username: `tr_${u}`,
      phone: `+9639${u.slice(-8)}`,
      passwordHash: 'x',
      role: over.role ?? UserRole.CUSTOMER,
      ...(created ? { createdAt: created } : {}),
      ...(over.phoneVerified ? { phoneVerifiedAt: new Date() } : {}),
    },
  });
}

/** A listing with a seller behind it, so seller-affinity can be measured. */
async function makeProduct(tx: Tx, sellerId: string, categoryId?: string) {
  const u = uniq();
  let cat = categoryId;
  if (!cat) {
    const category = await tx.category.create({
      data: { slug: `tr-cat-${u}`, nameAr: 'فئة', nameEn: 'Cat' },
    });
    cat = category.id;
  }
  const product = await tx.product.create({
    data: {
      slug: `tr-prod-${u}`,
      title: 'فستان',
      description: 'وصف',
      categoryId: cat,
      status: ProductStatus.ACTIVE,
      offers: {
        create: {
          sellerId,
          currency: Currency.SYP,
          price: '100000',
          stock: 5,
          status: OfferStatus.ACTIVE,
          isActive: true,
        },
      },
    },
  });
  return { product, categoryId: cat };
}

async function makeReview(
  tx: Tx,
  input: {
    productId: string;
    userId: string;
    rating: number;
    body?: string | null;
    verified?: boolean;
    createdAt?: Date;
  },
) {
  return tx.productReview.create({
    data: {
      productId: input.productId,
      userId: input.userId,
      rating: input.rating,
      body: input.body ?? 'تقييم',
      verifiedPurchase: input.verified ?? false,
      status: ReviewStatus.APPROVED,
      ...(input.createdAt ? { createdAt: input.createdAt } : {}),
    },
  });
}

/** A bare order, so a reviewer counts as somebody who actually buys. */
async function makeOrder(tx: Tx, userId: string) {
  const u = uniq();
  return tx.order.create({
    data: {
      number: `TR-${u.slice(-10)}`,
      userId,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: '10000',
      discountTotal: '0',
      shippingTotal: '0',
      grandTotal: '10000',
      recipientName: 'ريم',
      recipientPhone: `+96398${u.slice(-7)}`,
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
    },
  });
}

// ── Facts ────────────────────────────────────────────────────────────────────

dbTest('a real customer’s review reads as an ordinary one', async (world) => {
  const seller = await makeUser(world.tx, { role: UserRole.SELLER });
  const buyer = await makeUser(world.tx, { ageDays: 300, phoneVerified: true });
  const { product } = await makeProduct(world.tx, seller.id);

  const review = await makeReview(world.tx, {
    productId: product.id,
    userId: buyer.id,
    rating: 5,
    verified: true,
    body: 'وصل بسرعة والقماش ممتاز، شكراً لكم',
  });

  const facts = await world.facts.forReview(review.id);
  assert.ok(facts);
  assert.equal(facts.verifiedPurchase, true);
  assert.equal(facts.phoneVerified, true);
  assert.equal(facts.reviewsInWindow, 1);
  assert.equal(facts.duplicateBodies, 0);
  assert.ok((facts.accountAgeDays ?? 0) > 200);

  // And nothing is written, because there is nothing to look at.
  const signal = await world.trust.scoreOneReview(review.id);
  assert.equal(signal, null);
});

dbTest('the same words pasted twice are found however they are spaced', async (world) => {
  const seller = await makeUser(world.tx, { role: UserRole.SELLER });
  const { product, categoryId } = await makeProduct(world.tx, seller.id);
  const second = await makeProduct(world.tx, seller.id, categoryId);

  const original = 'المنتج رائع جداً والجودة ممتازة أنصح الجميع بالشراء';
  // The same sentence, with harakat added and the spacing mangled — different
  // raw strings, one folded key. This is what a pasted campaign looks like.
  const pasted = 'المنتَج  رائع   جداً والجودة ممتازة أنصح الجميع بالشراء';

  const a = await makeUser(world.tx);
  const b = await makeUser(world.tx);
  await makeReview(world.tx, {
    productId: product.id,
    userId: a.id,
    rating: 5,
    body: original,
  });
  const review = await makeReview(world.tx, {
    productId: second.product.id,
    userId: b.id,
    rating: 5,
    body: pasted,
  });

  const facts = await world.facts.forReview(review.id);
  assert.equal(
    facts?.duplicateBodies,
    1,
    'the folded key is what catches a copy the raw text hides',
  );

  const signal = await world.trust.scoreOneReview(review.id);
  assert.ok(signal, 'and it is worth a moderator’s look on its own');
  assert.ok(
    (signal.reasons as { code: string }[]).some(
      (r) => r.code === 'duplicate_text',
    ),
  );
});

dbTest('a campaign of five-star reviews on one boutique is flagged', async (world) => {
  const seller = await makeUser(world.tx, { role: UserRole.SELLER });
  const shill = await makeUser(world.tx, { ageDays: 0 });
  const { categoryId } = await makeProduct(world.tx, seller.id);

  let last = '';
  for (let i = 0; i < 8; i += 1) {
    const { product } = await makeProduct(world.tx, seller.id, categoryId);
    const review = await makeReview(world.tx, {
      productId: product.id,
      userId: shill.id,
      rating: 5,
      body: `تقييم رقم ${i} لمنتج مختلف تماماً عن غيره`,
    });
    last = review.id;
  }

  const facts = await world.facts.forReview(last);
  assert.equal(facts?.reviewsInWindow, 8);
  assert.equal(facts?.fiveStarInWindow, 8);
  assert.equal(
    facts?.reviewsForSameSeller,
    8,
    'every one of them on the same boutique’s listings',
  );

  const signal = await world.trust.scoreOneReview(last);
  assert.ok(signal);
  assert.equal(signal.band, 'SUSPECT');
});

// ── The queue ────────────────────────────────────────────────────────────────

dbTest('a flag carries the review’s own words to the moderator', async (world) => {
  const seller = await makeUser(world.tx, { role: UserRole.SELLER });
  const shill = await makeUser(world.tx, { ageDays: 0 });
  const { categoryId } = await makeProduct(world.tx, seller.id);

  for (let i = 0; i < 8; i += 1) {
    const { product } = await makeProduct(world.tx, seller.id, categoryId);
    await makeReview(world.tx, {
      productId: product.id,
      userId: shill.id,
      rating: 5,
      body: `نص التقييم رقم ${i} وهو نص مختلف عن البقية`,
    });
  }
  await world.trust.sweepReviews(30, 50);

  const queue = await world.trust.queue({ limit: 20, skip: 0 });
  const mine = queue.data.filter(
    (row) => row.subject === 'review' && row.context !== null,
  );

  assert.ok(mine.length > 0, 'the sweep put something in the queue');
  const first = mine[0].context as { body: string; author: { id: string } };
  assert.ok(
    first.body.length > 0,
    'a row that says only an id is a lookup exercise, not a queue',
  );
});

dbTest('confirming a review flag is what takes the review down', async (world) => {
  const seller = await makeUser(world.tx, { role: UserRole.SELLER });
  const moderator = await makeUser(world.tx, { role: UserRole.ADMIN });
  const shill = await makeUser(world.tx, { ageDays: 0 });
  const { categoryId } = await makeProduct(world.tx, seller.id);

  let last = '';
  for (let i = 0; i < 8; i += 1) {
    const { product } = await makeProduct(world.tx, seller.id, categoryId);
    const review = await makeReview(world.tx, {
      productId: product.id,
      userId: shill.id,
      rating: 5,
      body: `تقييم مدفوع رقم ${i} بنص مختلف`,
    });
    last = review.id;
  }

  const signal = await world.trust.scoreOneReview(last);
  assert.ok(signal);

  // Before: the score alone changed nothing the customer can see.
  const before = await world.tx.productReview.findUniqueOrThrow({
    where: { id: last },
  });
  assert.equal(before.status, ReviewStatus.APPROVED);

  await world.trust.resolve({
    signalId: signal.id,
    status: TrustSignalStatus.CONFIRMED,
    note: 'حملة تقييمات',
    actorId: moderator.id,
  });

  const after = await world.tx.productReview.findUniqueOrThrow({
    where: { id: last },
  });
  assert.equal(
    after.status,
    ReviewStatus.REJECTED,
    'a person decided, and only then did the review come down',
  );
});

dbTest('a dismissed flag is not raised again on the same evidence', async (world) => {
  const seller = await makeUser(world.tx, { role: UserRole.SELLER });
  const moderator = await makeUser(world.tx, { role: UserRole.ADMIN });
  const buyer = await makeUser(world.tx, { ageDays: 0 });
  const { categoryId } = await makeProduct(world.tx, seller.id);

  let last = '';
  for (let i = 0; i < 8; i += 1) {
    const { product } = await makeProduct(world.tx, seller.id, categoryId);
    const review = await makeReview(world.tx, {
      productId: product.id,
      userId: buyer.id,
      rating: 5,
      body: `تقييم رقم ${i} بنص مختلف تماماً`,
    });
    last = review.id;
  }

  const signal = await world.trust.scoreOneReview(last);
  assert.ok(signal);
  await world.trust.resolve({
    signalId: signal.id,
    status: TrustSignalStatus.DISMISSED,
    note: 'عميلة حقيقية اشترت ثمانية أشياء',
    actorId: moderator.id,
  });

  // Re-running the sweep must not reopen it. A queue that re-serves what a
  // moderator settled yesterday is a queue she stops opening.
  const again = await world.trust.scoreOneReview(last);
  assert.equal(again, null);

  const open = await world.tx.trustSignal.findUniqueOrThrow({
    where: {
      subject_subjectId: {
        subject: TrustSubject.REVIEW,
        subjectId: last,
      },
    },
  });
  assert.equal(open.status, TrustSignalStatus.DISMISSED);
});

dbTest('a flag clears itself when the behaviour stops', async (world) => {
  const seller = await makeUser(world.tx, { role: UserRole.SELLER });
  // An ordinary customer, so the copied text is the ONLY thing against her.
  // An account with no age and no orders carries four other tells of its own,
  // and removing the duplicate would not have cleared it — which would have
  // made this test pass or fail for the wrong reason.
  const buyer = await makeUser(world.tx, { ageDays: 300, phoneVerified: true });
  const { product } = await makeProduct(world.tx, seller.id);

  const other = await makeUser(world.tx, { ageDays: 300, phoneVerified: true });
  // Both of them buy, and both reviews are matched to a purchase, so that
  // when the copy is removed the reading has genuinely nothing left in it.
  await makeOrder(world.tx, buyer.id);
  await makeOrder(world.tx, other.id);

  const shared = 'نص مكرر تماماً بين تقييمين مختلفين لاختبار التكرار';
  await makeReview(world.tx, {
    productId: product.id,
    userId: other.id,
    rating: 5,
    verified: true,
    body: shared,
  });
  const review = await makeReview(world.tx, {
    productId: product.id,
    userId: buyer.id,
    rating: 5,
    verified: true,
    body: shared,
  });

  const flagged = await world.trust.scoreOneReview(review.id);
  assert.ok(flagged, 'the copy is flagged');
  assert.ok(
    (flagged.reasons as { code: string }[]).some(
      (r) => r.code === 'duplicate_text',
    ),
  );

  // The review it was copied from comes down, so the text is no longer
  // duplicated and there is nothing left to answer for.
  await world.tx.productReview.deleteMany({
    where: { productId: product.id, userId: other.id },
  });

  const cleared = await world.trust.scoreOneReview(review.id);
  assert.equal(cleared, null, 'the reading falls back below the queue');

  const rows = await world.tx.trustSignal.findMany({
    where: { subject: TrustSubject.REVIEW, subjectId: review.id },
  });
  assert.equal(
    rows.length,
    0,
    'and the open flag is removed rather than left saying nothing is wrong',
  );
});

// ── Refunds and identity ─────────────────────────────────────────────────────

dbTest('the platform’s own refund rate is what a customer is judged against', async (world) => {
  const buyer = await makeUser(world.tx, { ageDays: 100 });
  const facts = await world.facts.forRefunds(buyer.id);

  assert.equal(facts.deliveredParcels, 0);
  assert.ok(
    facts.platformRefundRate >= 0 && facts.platformRefundRate <= 1,
    'the norm is a fraction read off the catalogue, not a constant',
  );

  // With no parcels there is nothing to say about her.
  const signal = await world.trust.scoreCustomerRefunds(buyer.id);
  assert.equal(signal, null);
});

dbTest('two accounts shipping to one phone are linked, not condemned', async (world) => {
  const u = uniq();
  const phone = `+96399${u.slice(-7)}`;
  const first = await makeUser(world.tx, { ageDays: 200 });
  const second = await makeUser(world.tx, { ageDays: 200 });

  for (const user of [first, second]) {
    await world.tx.address.create({
      data: {
        userId: user.id,
        label: 'المنزل',
        recipientName: 'ريم',
        recipientPhone: phone,
        governorate: 'دمشق',
        city: 'دمشق',
        addressLine: `شارع ${u}`,
      },
    });
  }

  const facts = await world.facts.forIdentity(first.id);
  assert.equal(facts.accountsSharingPhone, 1);
  assert.equal(facts.accountsSharingAddress, 1);

  // A sister, a mother, a shared handset. Linked is not guilty.
  const signal = await world.trust.scoreCustomerIdentity(first.id);
  assert.equal(
    signal,
    null,
    'sharing alone must not put a woman in a moderation queue',
  );
});
