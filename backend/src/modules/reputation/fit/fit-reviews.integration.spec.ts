import assert from 'node:assert/strict';
import test from 'node:test';
import {
  Currency,
  MediaAssetStatus,
  OrderStatus,
  PrismaClient,
  ProductStatus,
  ReviewFit,
  ReviewStatus,
  SellerOrderStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../../prisma/prisma.service';
import { MediaService } from '../../media/media.service';
import { ReputationService } from '../reputation.service';
import { FitProfileService } from './fit-profile.service';

/**
 * «تقييمات من بمقاسي» against the real database.
 *
 * `fit-reviews.spec.ts` proves the matching and the summary in isolation.
 * This proves the three things only Postgres can show: that the size on a
 * review is the one that shipped, that the height a review publishes is the
 * band and only with her consent, and that a review cannot carry a photograph
 * that is not her own `review` upload.
 *
 * Every case runs inside a transaction that is rolled back.
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

interface World {
  tx: Tx;
  reputation: ReputationService;
  profiles: FitProfileService;
}

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

/**
 * The two media calls the review code makes, answered from the table. A URL
 * here is the asset's storage key — the real service parses a full URL down
 * to that key, which is its own tested concern.
 */
function mediaFor(tx: Tx): MediaService {
  return {
    resolveAssetId: async (url: string, ownerId: string) =>
      (await tx.mediaAsset.findFirst({ where: { storageKey: url, ownerId } }))?.id ?? null,
    markAttached: async (ownerId: string, urls: string[]) =>
      (
        await tx.mediaAsset.updateMany({
          where: { ownerId, storageKey: { in: urls } },
          data: { status: MediaAssetStatus.ATTACHED },
        })
      ).count,
  } as unknown as MediaService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const profiles = new FitProfileService(db);
  return { tx, profiles, reputation: new ReputationService(db, profiles, mediaFor(tx)) };
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;
const phone = () => `+9639${Math.floor(10_000_000 + Math.random() * 89_999_999)}`;

async function makeUser(tx: Tx, tag: string, role: UserRole = UserRole.CUSTOMER) {
  return tx.user.create({
    data: {
      name: `fit-${tag}`,
      username: `fit_${uniq(tag)}`,
      phone: phone(),
      passwordHash: 'x',
      role,
    },
  });
}

/** A dress in S, M and L. */
async function makeDress(tx: Tx, sellerId: string) {
  const u = uniq('p');
  const category = await tx.category.create({
    data: { slug: `fit-cat-${u}`, nameAr: 'فساتين', nameEn: 'Dresses' },
  });
  const product = await tx.product.create({
    data: {
      slug: `fit-prod-${u}`,
      title: 'فستان سهرة',
      description: 'اختبار',
      categoryId: category.id,
      status: ProductStatus.ACTIVE,
      createdBySellerId: sellerId,
    },
  });
  const variants: Record<string, string> = {};
  for (const size of ['S', 'M', 'L']) {
    const variant = await tx.productVariant.create({
      data: { productId: product.id, name: size, attributes: { size } },
    });
    variants[size] = variant.id;
  }
  return { product, variants };
}

/** A delivered order of the dress in the given sizes. */
async function deliver(
  tx: Tx,
  ids: { customerId: string; sellerId: string; productId: string },
  variantIds: string[],
) {
  return tx.order.create({
    data: {
      number: `ORD-${uniq('o').slice(-12)}`,
      userId: ids.customerId,
      status: OrderStatus.DELIVERED,
      currency: Currency.SYP,
      fxRate: '13000',
      itemsSubtotal: '100000',
      shippingTotal: '0',
      grandTotal: '100000',
      recipientName: 'ريم',
      recipientPhone: '+963900000000',
      governorate: 'دمشق',
      city: 'دمشق',
      addressLine: 'المزة',
      sellerOrders: {
        create: {
          number: `SO-${uniq('s').slice(-12)}`,
          sellerId: ids.sellerId,
          status: SellerOrderStatus.DELIVERED,
          currency: Currency.SYP,
          itemsSubtotal: '100000',
          shippingCost: '0',
          commissionBase: '100000',
          commissionAmount: '10000',
          sellerNet: '90000',
          items: {
            create: variantIds.map((variantId) => ({
              productId: ids.productId,
              variantId,
              titleSnapshot: 'فستان سهرة',
              sellerSnapshot: 'بائعة',
              currency: Currency.SYP,
              unitPrice: '100000',
              quantity: 1,
              lineTotal: '100000',
            })),
          },
        },
      },
    },
  });
}

async function upload(tx: Tx, ownerId: string, purpose: string) {
  const key = `test/${uniq(purpose)}.jpg`;
  await tx.mediaAsset.create({
    data: {
      ownerId,
      driver: 'local',
      storageKey: key,
      mimeType: 'image/jpeg',
      byteSize: 1000,
      checksum: uniq('c'),
      variants: [],
      purpose,
    },
  });
  return key;
}

/** A buyer of the dress in `size`, with a profile, who reviews it. */
async function buyerReviews(
  world: World,
  ctx: { sellerId: string; productId: string; variants: Record<string, string> },
  opts: { size: string; heightCm: number; usualSize: string; fit: ReviewFit; approve?: boolean },
) {
  const buyer = await makeUser(world.tx, 'buyer');
  await deliver(
    world.tx,
    { customerId: buyer.id, sellerId: ctx.sellerId, productId: ctx.productId },
    [ctx.variants[opts.size]],
  );
  await world.profiles.set(buyer.id, { heightCm: opts.heightCm, usualSize: opts.usualSize });
  const review = await world.reputation.createProductReview(buyer.id, ctx.productId, {
    rating: 5,
    fit: opts.fit,
  });
  if (opts.approve !== false) {
    await world.tx.productReview.update({
      where: { id: review.id },
      data: { status: ReviewStatus.APPROVED },
    });
  }
  return { buyer, review };
}

// ── Cases ───────────────────────────────────────────────────────────────────

dbTest('the size on a review is the one that shipped, and the height is a band', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const { product, variants } = await makeDress(world.tx, seller.id);
  const ctx = { sellerId: seller.id, productId: product.id, variants };

  const { review } = await buyerReviews(world, ctx, {
    size: 'M',
    heightCm: 163,
    usualSize: 'm',
    fit: ReviewFit.TRUE_TO_SIZE,
  });

  assert.equal(review.size_bought, 'M');
  assert.equal(review.fit, ReviewFit.TRUE_TO_SIZE);
  assert.equal(review.height_band, '160–164', 'never 163');
  assert.equal(review.usual_size, 'M');
  assert.equal(JSON.stringify(review).includes('163'), false);
});

dbTest('she can keep her height and size off a review, or off all of them', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const { product, variants } = await makeDress(world.tx, seller.id);

  // Off this one review.
  const first = await makeUser(world.tx, 'a');
  await deliver(world.tx, { customerId: first.id, sellerId: seller.id, productId: product.id }, [variants.S]);
  await world.profiles.set(first.id, { heightCm: 158, usualSize: 'S' });
  const kept = await world.reputation.createProductReview(first.id, product.id, {
    rating: 4,
    share_fit: false,
  });
  assert.equal(kept.height_band, null);
  assert.equal(kept.usual_size, null);
  assert.equal(kept.size_bought, 'S', 'the size that shipped is about the dress, not her');

  // Off by default, from her profile.
  const second = await makeUser(world.tx, 'b');
  await deliver(world.tx, { customerId: second.id, sellerId: seller.id, productId: product.id }, [variants.L]);
  await world.profiles.set(second.id, { heightCm: 170, usualSize: 'L', shareOnReviews: false });
  const quiet = await world.reputation.createProductReview(second.id, product.id, { rating: 5 });
  assert.equal(quiet.height_band, null);
});

dbTest('two sizes of the same dress in one order record no size at all', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const { product, variants } = await makeDress(world.tx, seller.id);
  const buyer = await makeUser(world.tx, 'both');
  await deliver(world.tx, { customerId: buyer.id, sellerId: seller.id, productId: product.id }, [
    variants.M,
    variants.L,
  ]);
  const review = await world.reputation.createProductReview(buyer.id, product.id, { rating: 4 });
  assert.equal(review.size_bought, null, 'she kept one of them, and the review cannot say which');
});

dbTest('a review carries only her own review photographs', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const { product, variants } = await makeDress(world.tx, seller.id);
  const buyer = await makeUser(world.tx, 'pics');
  const other = await makeUser(world.tx, 'other');
  await deliver(world.tx, { customerId: buyer.id, sellerId: seller.id, productId: product.id }, [variants.M]);

  const closetPhoto = await upload(world.tx, buyer.id, 'closet');
  const someoneElses = await upload(world.tx, other.id, 'review');
  await assert.rejects(
    world.reputation.createProductReview(buyer.id, product.id, { rating: 5, photo_urls: [closetPhoto] }),
    /not one of your uploads/,
    'her private closet photo cannot be published through a review',
  );
  await assert.rejects(
    world.reputation.createProductReview(buyer.id, product.id, { rating: 5, photo_urls: [someoneElses] }),
    /not one of your uploads/,
  );
  // Nothing was written by the refused attempts.
  assert.equal(await world.tx.productReview.count({ where: { productId: product.id } }), 0);

  const mine = await upload(world.tx, buyer.id, 'review');
  const review = await world.reputation.createProductReview(buyer.id, product.id, {
    rating: 5,
    photo_urls: [mine],
  });
  assert.deepEqual(review.photos, [mine]);
  const asset = await world.tx.mediaAsset.findFirstOrThrow({ where: { storageKey: mine } });
  assert.equal(asset.status, MediaAssetStatus.ATTACHED, 'claimed, so the sweeper keeps it');
});

dbTest('«من بمقاسي» finds the women like her, and the fit summary speaks only above the floor', async (world) => {
  const seller = await makeUser(world.tx, 'sel', UserRole.SELLER);
  const { product, variants } = await makeDress(world.tx, seller.id);
  const ctx = { sellerId: seller.id, productId: product.id, variants };

  // Two women near her who kept an L and called it right, one tall M, and one
  // still in moderation that must not count.
  await buyerReviews(world, ctx, { size: 'L', heightCm: 161, usualSize: 'M', fit: ReviewFit.TRUE_TO_SIZE });
  await buyerReviews(world, ctx, { size: 'L', heightCm: 164, usualSize: 'M', fit: ReviewFit.TRUE_TO_SIZE });
  await buyerReviews(world, ctx, { size: 'M', heightCm: 178, usualSize: 'M', fit: ReviewFit.RUNS_SMALL });
  await buyerReviews(world, ctx, {
    size: 'S',
    heightCm: 162,
    usualSize: 'M',
    fit: ReviewFit.RUNS_LARGE,
    approve: false,
  });

  const me = await makeUser(world.tx, 'me');

  // Before she has said her size.
  assert.deepEqual(await world.reputation.productReviews(product.id, me.id, 'near_me'), []);
  const before = await world.reputation.productFit(product.id, me.id);
  assert.equal(before.has_profile, false);
  assert.equal(before.near_me, null);
  assert.equal(before.overall.total, 3, 'approved only');
  assert.equal(before.overall.enough, true);
  assert.equal(before.overall.verdict, ReviewFit.TRUE_TO_SIZE);

  await world.profiles.set(me.id, { heightCm: 162, usualSize: 'M' });

  const near = await world.reputation.productReviews(product.id, me.id, 'near_me');
  assert.equal(near.length, 2, 'the tall M is not near her');

  const after = await world.reputation.productFit(product.id, me.id);
  assert.equal(after.has_profile, true);
  assert.equal(after.near_me?.total, 2);
  assert.equal(after.near_me?.enough, false, 'two women are not a verdict');
  assert.equal(after.suggested_size, 'L', 'but two of them kept an L');
});

dbTest('the profile refuses a typo, and clears with null', async (world) => {
  const me = await makeUser(world.tx, 'me');
  await assert.rejects(world.profiles.set(me.id, { heightCm: 16 }), /between/);
  await assert.rejects(world.profiles.set(me.id, { usualSize: 'free size' }), /Unknown size/);

  await world.profiles.set(me.id, { heightCm: 165, usualSize: '2xl' });
  let profile = await world.profiles.get(me.id);
  assert.equal(profile?.usualSize, 'XXL');

  await world.profiles.set(me.id, { heightCm: null });
  profile = await world.profiles.get(me.id);
  assert.equal(profile?.heightCm, null);
  assert.equal(profile?.usualSize, 'XXL', 'an absent field is left alone');
});
