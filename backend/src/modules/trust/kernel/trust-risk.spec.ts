import assert from 'node:assert/strict';
import test from 'node:test';

import {
  IdentityFacts,
  RefundFacts,
  ReviewFacts,
  SellerConductFacts,
} from './trust-facts';
import {
  bandFor,
  SUSPECT_AT,
  WATCH_AT,
  scoreMultiAccount,
  scoreRefundAbuse,
  scoreReview,
  scoreSellerConduct,
} from './trust-risk';

/**
 * The scoring rules, pinned.
 *
 * These run without a database because the kernel has no idea one exists.
 * What they are really guarding is the shape of the judgement: that no single
 * signal convicts, that thin data scores nothing, and that an ordinary
 * customer doing ordinary things is never flagged. A trust engine that fails
 * those three is worse than none — it teaches whoever reads the queue to stop
 * reading it.
 */

/** A perfectly ordinary review from a perfectly ordinary customer. */
const honestReview = (): ReviewFacts => ({
  rating: 5,
  verifiedPurchase: true,
  accountAgeDays: 400,
  phoneVerified: true,
  reviewsInWindow: 2,
  fiveStarInWindow: 1,
  reviewsForSameSeller: 1,
  ordersPlaced: 6,
  productReviewsSameDay: 1,
  productReviewsTotal: 30,
  productMeanWithout: 4.5,
  duplicateBodies: 0,
  bodyEmpty: false,
});

const codes = (facts: ReviewFacts) =>
  scoreReview(facts).reasons.map((reason) => reason.code);

// ── The honest case ──────────────────────────────────────────────────────────

test('an ordinary review is not flagged', () => {
  const reading = scoreReview(honestReview());
  assert.deepEqual(reading.reasons, []);
  assert.equal(reading.score, 0);
  assert.equal(reading.band, 'CLEAR');
});

test('a disappointed customer is not an attacker', () => {
  // One star against a well-liked product, from a real buyer with a history.
  // This is the case a naive "rating outlier" rule punishes, and it must not.
  const reading = scoreReview({
    ...honestReview(),
    rating: 1,
    productMeanWithout: 4.6,
  });
  assert.deepEqual(codes({ ...honestReview(), rating: 1, productMeanWithout: 4.6 }), [
    'rating_outlier',
  ]);
  assert.equal(
    reading.band,
    'CLEAR',
    'an outlying mark alone must never reach a moderator',
  );
});

test('an unverified review alone stays below the queue', () => {
  const reading = scoreReview({ ...honestReview(), verifiedPurchase: false });
  assert.deepEqual(reading.reasons.map((r) => r.code), ['no_verified_purchase']);
  assert.ok(
    reading.score < WATCH_AT,
    'Ohara allows reviews without a matched order — a gift, an order on a ' +
      'friend’s account — so this cannot be enough on its own',
  );
});

// ── The shapes worth catching ────────────────────────────────────────────────

test('a bought review is caught by its several tells at once', () => {
  const reading = scoreReview({
    ...honestReview(),
    verifiedPurchase: false,
    ordersPlaced: 0,
    accountAgeDays: 0,
    phoneVerified: false,
    reviewsInWindow: 9,
    fiveStarInWindow: 9,
    reviewsForSameSeller: 9,
    bodyEmpty: true,
  });

  assert.equal(reading.band, 'SUSPECT');
  assert.ok(reading.reasons.length >= 5, 'and it says why, in five ways');
  assert.ok(
    reading.reasons.every((reason) => reason.ar.length > 0),
    'every reason is worded for the Arabic console',
  );
});

test('a burst is judged against the listing’s own history', () => {
  const quiet = {
    ...honestReview(),
    productReviewsSameDay: 6,
    productReviewsTotal: 8,
  };
  const bestseller = {
    ...honestReview(),
    productReviewsSameDay: 6,
    productReviewsTotal: 400,
  };

  assert.ok(codes(quiet).includes('review_burst'));
  assert.ok(
    !codes(bestseller).includes('review_burst'),
    'a popular listing collecting six reviews in a day is doing well',
  );
});

test('copied text is the strongest single tell', () => {
  const reading = scoreReview({ ...honestReview(), duplicateBodies: 4 });
  assert.ok(codes({ ...honestReview(), duplicateBodies: 4 }).includes('duplicate_text'));
  assert.ok(reading.score >= WATCH_AT, 'the same words twice is worth a look');
});

test('loyalty to one boutique needs volume before it counts', () => {
  // Three reviews, all of one shop: a woman with a favourite.
  assert.ok(
    !codes({
      ...honestReview(),
      reviewsInWindow: 3,
      reviewsForSameSeller: 3,
    }).includes('single_seller_focus'),
  );
  // Eight, all of one shop, is a different shape.
  assert.ok(
    codes({
      ...honestReview(),
      reviewsInWindow: 8,
      reviewsForSameSeller: 8,
    }).includes('single_seller_focus'),
  );
});

test('an outlying mark is not counted on a listing with barely any reviews', () => {
  assert.ok(
    !codes({
      ...honestReview(),
      rating: 1,
      productReviewsTotal: 3,
      productMeanWithout: 5,
    }).includes('rating_outlier'),
    '"everyone else" needs to be somebody',
  );
});

// ── Refunds ──────────────────────────────────────────────────────────────────

const refunds = (over: Partial<RefundFacts> = {}): RefundFacts => ({
  deliveredParcels: 20,
  returnsRequested: 1,
  refundsReceived: 1,
  refusedParcels: 0,
  disputesOpened: 0,
  disputesLost: 0,
  platformRefundRate: 0.1,
  ...over,
});

test('a customer who returns at the platform’s own rate is not flagged', () => {
  const reading = scoreRefundAbuse(refunds({ refundsReceived: 2 }));
  assert.equal(reading.band, 'CLEAR');
});

test('a thin history scores nothing at all', () => {
  // Two parcels, both returned. A rate of 100%, and no evidence whatsoever.
  const reading = scoreRefundAbuse(
    refunds({ deliveredParcels: 2, returnsRequested: 2, refundsReceived: 2 }),
  );
  assert.deepEqual(reading.reasons, []);
});

test('the bar moves with the catalogue, not with a hardcoded number', () => {
  const hers = { deliveredParcels: 10, returnsRequested: 5, refundsReceived: 5 };

  // A marketplace where half of everything comes back: she is unremarkable.
  assert.equal(
    scoreRefundAbuse(refunds({ ...hers, platformRefundRate: 0.45 })).band,
    'CLEAR',
  );
  // A marketplace where almost nothing does: the same customer stands out —
  // but only as far as WATCH. A high rate on its own has innocent readings
  // (one bad boutique she kept going back to), and the doctrine of this
  // kernel is that no single signal convicts.
  assert.equal(
    scoreRefundAbuse(refunds({ ...hers, platformRefundRate: 0.03 })).band,
    'WATCH',
  );
});

test('what reaches SUSPECT is a rate plus the behaviour around it', () => {
  const reading = scoreRefundAbuse(
    refunds({
      deliveredParcels: 10,
      returnsRequested: 8,
      refundsReceived: 5,
      refusedParcels: 4,
      disputesOpened: 3,
      disputesLost: 2,
      platformRefundRate: 0.03,
    }),
  );
  assert.equal(reading.band, 'SUSPECT');
  assert.ok(
    reading.reasons.length >= 3,
    'and a moderator is handed three separate things to check',
  );
});

test('disputes decided against her carry real weight', () => {
  const reading = scoreRefundAbuse(
    refunds({ disputesOpened: 4, disputesLost: 3 }),
  );
  assert.ok(reading.reasons.some((r) => r.code === 'disputes_lost'));
});

// ── Multiple accounts ────────────────────────────────────────────────────────

const identity = (over: Partial<IdentityFacts> = {}): IdentityFacts => ({
  accountAgeDays: 200,
  phoneVerified: true,
  accountsSharingPhone: 0,
  accountsSharingDevice: 0,
  accountsSharingAddress: 0,
  linkedCouponRedemptions: 0,
  ...over,
});

test('a family sharing a handset is not a scheme', () => {
  const reading = scoreMultiAccount(
    identity({ accountsSharingPhone: 2, accountsSharingDevice: 1 }),
  );
  assert.ok(
    reading.band === 'CLEAR' || reading.band === 'WATCH',
    'sharing alone must never reach the band a person acts on',
  );
  assert.ok(reading.score < SUSPECT_AT);
});

test('what turns a cluster into a case is the coupons', () => {
  const sharing = identity({
    accountsSharingPhone: 2,
    accountsSharingDevice: 2,
  });
  const before = scoreMultiAccount(sharing);
  const after = scoreMultiAccount({
    ...sharing,
    linkedCouponRedemptions: 5,
  });

  assert.ok(after.score > before.score);
  assert.ok(
    after.reasons.some((r) => r.code === 'coupons_across_cluster'),
    'the accounts are linked AND the discounts are being harvested',
  );
});

test('coupons on an unlinked account prove nothing', () => {
  const reading = scoreMultiAccount(identity({ linkedCouponRedemptions: 9 }));
  assert.deepEqual(reading.reasons, [], 'there is no cluster to spend them across');
});

// ── Bands ────────────────────────────────────────────────────────────────────

test('the bands are ordered and inclusive at their edges', () => {
  assert.equal(bandFor(0), 'CLEAR');
  assert.equal(bandFor(WATCH_AT - 1), 'CLEAR');
  assert.equal(bandFor(WATCH_AT), 'WATCH');
  assert.equal(bandFor(SUSPECT_AT - 1), 'WATCH');
  assert.equal(bandFor(SUSPECT_AT), 'SUSPECT');
  assert.equal(bandFor(1000), 'SUSPECT');
});

test('a score cannot run past 100 however many tells pile up', () => {
  const reading = scoreReview({
    rating: 5,
    verifiedPurchase: false,
    accountAgeDays: 0,
    phoneVerified: false,
    reviewsInWindow: 40,
    fiveStarInWindow: 40,
    reviewsForSameSeller: 40,
    ordersPlaced: 0,
    productReviewsSameDay: 30,
    productReviewsTotal: 31,
    productMeanWithout: 1,
    duplicateBodies: 12,
    bodyEmpty: true,
  });
  assert.equal(reading.score, 100);
});

// ── Seller conduct ───────────────────────────────────────────────────────────

const conduct = (over: Partial<SellerConductFacts> = {}): SellerConductFacts => ({
  accountAgeDays: 300,
  deliveredParcels: 40,
  refundedParcels: 3,
  categoryRefundRate: 0.08,
  cancelledBySeller: 0,
  disputesAgainst: 0,
  disputesLost: 0,
  confirmedFakeReviews: 0,
  removedListings: 0,
  liveListings: 60,
  ...over,
});

test('a boutique doing ordinary business is not flagged', () => {
  const reading = scoreSellerConduct(conduct());
  assert.deepEqual(reading.reasons, []);
  assert.equal(reading.band, 'CLEAR');
});

test('a new shop with no history scores nothing on rates', () => {
  const reading = scoreSellerConduct(
    conduct({
      accountAgeDays: 3,
      deliveredParcels: 4,
      refundedParcels: 3,
      cancelledBySeller: 3,
    }),
  );
  assert.deepEqual(
    reading.reasons,
    [],
    'four parcels is not a rate, and a young shop is not a suspicious one',
  );
});

test('a shop is judged against its own category, not the catalogue', () => {
  const hers = { deliveredParcels: 40, refundedParcels: 12 };

  // Occasionwear: nearly a third of everything comes back, and so does hers.
  assert.equal(
    scoreSellerConduct(conduct({ ...hers, categoryRefundRate: 0.3 })).band,
    'CLEAR',
  );
  // Perfume: almost nothing comes back, and a third of hers does.
  assert.ok(
    scoreSellerConduct(conduct({ ...hers, categoryRefundRate: 0.03 }))
      .reasons.some((r) => r.code.startsWith('seller_refund_rate')),
  );
});

test('cancelling after accepting is weighed heavily', () => {
  const reading = scoreSellerConduct(
    conduct({ deliveredParcels: 20, cancelledBySeller: 6 }),
  );
  assert.ok(
    reading.reasons.some((r) => r.code === 'cancels_after_accepting'),
    'a customer who paid and waited is told days later it was never there',
  );
});

test('a confirmed review campaign is evidence, not a rate', () => {
  // No volume at all, and it still counts: a moderator looked and agreed.
  const reading = scoreSellerConduct(
    conduct({ deliveredParcels: 0, confirmedFakeReviews: 4 }),
  );
  assert.equal(reading.band, 'SUSPECT');
  assert.ok(
    reading.reasons.some((r) => r.code === 'confirmed_review_campaign'),
  );
});

test('removals are read as a share of what she has up', () => {
  // Two removals out of three hundred listings.
  assert.ok(
    !scoreSellerConduct(
      conduct({ removedListings: 2, liveListings: 300 }),
    ).reasons.some((r) => r.code === 'listings_removed_share'),
  );
  // Two out of four is a different shop.
  assert.ok(
    scoreSellerConduct(
      conduct({ removedListings: 2, liveListings: 2 }),
    ).reasons.some((r) => r.code === 'listings_removed_share'),
  );
});

test('performance problems are not conduct problems', () => {
  // Slow, unloved, selling little — every one of those is SellerHealth's
  // business, and none of them belongs in a moderation queue.
  const reading = scoreSellerConduct(
    conduct({ deliveredParcels: 9, refundedParcels: 0, liveListings: 3 }),
  );
  assert.equal(reading.band, 'CLEAR');
});
