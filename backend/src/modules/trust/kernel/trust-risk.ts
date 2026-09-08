import {
  IdentityFacts,
  RefundFacts,
  ReviewFacts,
  SellerConductFacts,
} from './trust-facts';

/**
 * From facts to a score, and from a score to a band.
 *
 * Three rules this file holds itself to, all of them learned from the COD
 * scorer next door.
 *
 * **Every point is attributable.** A score is not a number, it is a list of
 * reasons that happen to add up. A moderator who cannot see *why* a review was
 * flagged will either approve everything or delete everything, and both are
 * worse than no queue at all.
 *
 * **Nothing here decides anything.** These functions return a reading. What to
 * do about it — hide a review, hold a refund, freeze an account — is policy,
 * and policy for accusations of dishonesty belongs to a person. There is no
 * automatic takedown in this module, deliberately: the cost of wrongly
 * deleting a real customer's honest review is much higher than the cost of a
 * fake one sitting up for another day.
 *
 * **Absence of evidence scores nothing.** A missing fact contributes zero
 * rather than a default. A new marketplace has no history for anybody, and a
 * scorer that reads thin data as guilt would flag its first hundred customers.
 */

/** One thing the evidence said, and what it was worth. */
export interface RiskReason {
  /** Stable identifier — screens and tests key on this, never on the wording. */
  code: string;
  /** Points added. Always positive; the code says which direction it argues. */
  weight: number;
  /** Arabic, because the moderation console is Arabic. */
  ar: string;
}

export interface RiskReading {
  /** 0–100, clamped. */
  score: number;
  band: RiskBand;
  reasons: RiskReason[];
}

export type RiskBand = 'CLEAR' | 'WATCH' | 'SUSPECT';

/**
 * Where the bands sit.
 *
 * `WATCH` is not an accusation — it is "show this to somebody eventually".
 * `SUSPECT` means a person should look before the review keeps earning the
 * boutique money. Nothing above 100 exists, and nothing below 25 is worth a
 * moderator's afternoon.
 */
export const WATCH_AT = 25;
export const SUSPECT_AT = 55;

export function bandFor(score: number): RiskBand {
  if (score >= SUSPECT_AT) return 'SUSPECT';
  if (score >= WATCH_AT) return 'WATCH';
  return 'CLEAR';
}

function reading(reasons: RiskReason[]): RiskReading {
  const score = Math.min(
    100,
    Math.round(reasons.reduce((total, reason) => total + reason.weight, 0)),
  );
  return { score, band: bandFor(score), reasons };
}

// ── Reviews ──────────────────────────────────────────────────────────────────

/**
 * How much a review looks bought rather than lived.
 *
 * Only one signal here is heavy enough to reach the queue alone — identical
 * text, which somebody had to paste. Everything else, the missing purchase
 * included, is worth less than the WATCH band by itself. That is deliberate:
 * Reem lets a customer review without the order being matched (a gift, an
 * order placed on a friend's account), and treating every unverified review
 * as fake would empty the honest half of the review section.
 */
export function scoreReview(facts: ReviewFacts): RiskReading {
  const reasons: RiskReason[] = [];

  if (!facts.verifiedPurchase) {
    reasons.push({
      code: 'no_verified_purchase',
      weight: 20,
      ar: 'لا يوجد طلب مسلَّم يطابق هذا المنتج',
    });
  }

  if (facts.ordersPlaced === 0) {
    reasons.push({
      code: 'never_bought_anything',
      weight: 18,
      ar: 'الحساب لم يشترِ شيئاً قط',
    });
  }

  // An account minutes old that arrives already knowing what it thinks.
  if (facts.accountAgeDays !== null && facts.accountAgeDays < 1) {
    reasons.push({
      code: 'account_hours_old',
      weight: 15,
      ar: 'حساب عمره أقل من يوم',
    });
  } else if (facts.accountAgeDays !== null && facts.accountAgeDays < 7) {
    reasons.push({
      code: 'account_days_old',
      weight: 8,
      ar: 'حساب عمره أقل من أسبوع',
    });
  }

  if (!facts.phoneVerified) {
    reasons.push({
      code: 'phone_unverified',
      weight: 6,
      ar: 'رقم غير مُوثَّق',
    });
  }

  // Volume: a person writes a few reviews a week, not thirty.
  if (facts.reviewsInWindow >= 15) {
    reasons.push({
      code: 'review_volume_extreme',
      weight: 18,
      ar: `${facts.reviewsInWindow} تقييماً خلال النافذة`,
    });
  } else if (facts.reviewsInWindow >= 7) {
    reasons.push({
      code: 'review_volume_high',
      weight: 9,
      ar: `${facts.reviewsInWindow} تقييمات خلال النافذة`,
    });
  }

  // Uniformity: every mark the same is a machine's habit, not a shopper's.
  if (
    facts.reviewsInWindow >= 5 &&
    facts.fiveStarInWindow === facts.reviewsInWindow
  ) {
    reasons.push({
      code: 'all_five_star',
      weight: 12,
      ar: 'كل تقييماتها الأخيرة خمس نجوم',
    });
  }

  // Concentration on one boutique.
  if (
    facts.reviewsInWindow >= 4 &&
    facts.reviewsForSameSeller >= Math.ceil(facts.reviewsInWindow * 0.8)
  ) {
    reasons.push({
      code: 'single_seller_focus',
      weight: 14,
      ar: 'كل تقييماتها تقريباً على متجر واحد',
    });
  }

  // A burst on the listing itself, judged against what the listing usually
  // gets rather than a flat number — a bestseller collecting ten reviews a
  // day is doing well, not being gamed.
  if (
    facts.productReviewsSameDay >= 5 &&
    facts.productReviewsSameDay > facts.productReviewsTotal * 0.5
  ) {
    reasons.push({
      code: 'review_burst',
      weight: 16,
      ar: `${facts.productReviewsSameDay} تقييمات على المنتج في يوم واحد`,
    });
  }

  // Rating manipulation: a mark far from what everyone else said. Only
  // counted once the product has enough reviews for "everyone else" to mean
  // something, and only alongside whatever else is here — a genuinely
  // disappointed customer produces exactly this gap and nothing more.
  if (
    facts.productMeanWithout !== null &&
    facts.productReviewsTotal >= 5 &&
    Math.abs(facts.rating - facts.productMeanWithout) >= 2.5
  ) {
    reasons.push({
      code: 'rating_outlier',
      weight: 10,
      ar: `تقييم شاذّ عن متوسط المنتج (${facts.productMeanWithout.toFixed(1)})`,
    });
  }

  // The one signal heavy enough to reach the queue by itself. Two reviews
  // carrying identical words are not a coincidence in the way an unverified
  // purchase or a harsh mark can be — somebody pasted something. It still
  // falls far short of SUSPECT, so it asks for a look rather than convicting.
  if (facts.duplicateBodies > 0) {
    reasons.push({
      code: 'duplicate_text',
      weight: 28,
      ar: `النص نفسه في ${facts.duplicateBodies} تقييم آخر`,
    });
  }

  // Worth almost nothing alone — plenty of honest reviews are a bare star —
  // but it is what a bought review looks like when it is cheap.
  if (facts.bodyEmpty && facts.rating === 5) {
    reasons.push({
      code: 'bare_five_star',
      weight: 4,
      ar: 'خمس نجوم بلا نص',
    });
  }

  return reading(reasons);
}

// ── Refund abuse ─────────────────────────────────────────────────────────────

/**
 * How far a customer's returns sit from what the platform itself does.
 *
 * The comparison is against `platformRefundRate` rather than a fixed
 * threshold, because the right number is a property of the catalogue: a shop
 * selling clothing without a fitting room *should* see a high return rate,
 * and a scorer with 20% hardcoded would spend its first month accusing the
 * entire customer base.
 *
 * Nothing scores until she has enough parcels for a rate to mean anything.
 * Two returns out of two is not a pattern, it is a Tuesday.
 */
export function scoreRefundAbuse(facts: RefundFacts): RiskReading {
  const reasons: RiskReason[] = [];
  const MIN_PARCELS = 4;

  if (facts.deliveredParcels < MIN_PARCELS) {
    return reading(reasons);
  }

  const hers = facts.refundsReceived / facts.deliveredParcels;
  const norm = Math.max(facts.platformRefundRate, 0.02);

  if (hers >= norm * 4 && facts.refundsReceived >= 3) {
    reasons.push({
      code: 'refund_rate_extreme',
      weight: 30,
      ar: `نسبة استرداد ${(hers * 100).toFixed(0)}% مقابل ${(norm * 100).toFixed(0)}% للمنصة`,
    });
  } else if (hers >= norm * 2.5 && facts.refundsReceived >= 2) {
    reasons.push({
      code: 'refund_rate_high',
      weight: 15,
      ar: `نسبة استرداد ${(hers * 100).toFixed(0)}% مقابل ${(norm * 100).toFixed(0)}% للمنصة`,
    });
  }

  if (facts.refusedParcels >= 3) {
    reasons.push({
      code: 'repeated_refusal',
      weight: 18,
      ar: `${facts.refusedParcels} طرود رُفضت عند الباب`,
    });
  }

  // Disputes she opened and lost: the platform looked, and disagreed.
  if (facts.disputesLost >= 2) {
    reasons.push({
      code: 'disputes_lost',
      weight: 20,
      ar: `${facts.disputesLost} نزاعات حُسمت ضدّها`,
    });
  }

  // Asking to return almost everything, whether or not it was granted.
  if (
    facts.returnsRequested >= 4 &&
    facts.returnsRequested >= facts.deliveredParcels * 0.75
  ) {
    reasons.push({
      code: 'returns_most_parcels',
      weight: 16,
      ar: 'طلبت إرجاع معظم ما استلمته',
    });
  }

  return reading(reasons);
}

// ── Multiple accounts ────────────────────────────────────────────────────────

/**
 * How much one account looks like several.
 *
 * Every signal here has an innocent explanation that is *more* common than the
 * guilty one — a family shares a phone, sisters share an address, a mother's
 * handset signs both accounts — so the weights are low and the band a person
 * has to act on is far away. What makes a cluster interesting is not sharing;
 * it is sharing plus a coupon being spent across every account in it.
 */
export function scoreMultiAccount(facts: IdentityFacts): RiskReading {
  const reasons: RiskReason[] = [];

  if (facts.accountsSharingPhone >= 3) {
    reasons.push({
      code: 'phone_shared_many',
      weight: 16,
      ar: `${facts.accountsSharingPhone} حسابات أخرى تشحن إلى رقمها`,
    });
  } else if (facts.accountsSharingPhone > 0) {
    reasons.push({
      code: 'phone_shared',
      weight: 6,
      ar: `${facts.accountsSharingPhone} حساب آخر يشحن إلى رقمها`,
    });
  }

  if (facts.accountsSharingDevice >= 3) {
    reasons.push({
      code: 'device_shared_many',
      weight: 18,
      ar: `${facts.accountsSharingDevice} حسابات أخرى على الجهاز نفسه`,
    });
  } else if (facts.accountsSharingDevice > 0) {
    reasons.push({
      code: 'device_shared',
      weight: 7,
      ar: `${facts.accountsSharingDevice} حساب آخر على الجهاز نفسه`,
    });
  }

  if (facts.accountsSharingAddress >= 3) {
    reasons.push({
      code: 'address_shared_many',
      weight: 10,
      ar: `${facts.accountsSharingAddress} حسابات أخرى على العنوان نفسه`,
    });
  }

  // The signal that turns a family into a scheme: the linked accounts have
  // been spending coupons. Only counted when there is a cluster to spend
  // them across.
  const linked =
    facts.accountsSharingPhone +
    facts.accountsSharingDevice +
    facts.accountsSharingAddress;
  if (linked >= 2 && facts.linkedCouponRedemptions >= 3) {
    reasons.push({
      code: 'coupons_across_cluster',
      weight: 24,
      ar: `${facts.linkedCouponRedemptions} قسائم استُهلكت عبر الحسابات المرتبطة`,
    });
  }

  if (linked >= 2 && facts.accountAgeDays !== null && facts.accountAgeDays < 7) {
    reasons.push({
      code: 'fresh_account_in_cluster',
      weight: 10,
      ar: 'حساب جديد ضمن مجموعة مرتبطة',
    });
  }

  return reading(reasons);
}

// ── Seller conduct ───────────────────────────────────────────────────────────

/**
 * Whether the platform is carrying a risk by listing this boutique.
 *
 * Every rate is measured against her own category rather than a flat number,
 * for the same reason the refund scorer is: occasionwear comes back more than
 * perfume does, and a scorer that does not know it would spend its life
 * accusing whoever sells the hardest thing to fit.
 *
 * A new shop is not a suspicious shop. Nothing rate-based scores until she has
 * enough parcels behind her for a rate to be a fact rather than an accident,
 * and the two signals that *are* evidence on their own — a confirmed review
 * campaign, disputes decided against her — do not depend on volume at all.
 */
export function scoreSellerConduct(facts: SellerConductFacts): RiskReading {
  const reasons: RiskReason[] = [];
  const MIN_PARCELS = 8;

  if (facts.deliveredParcels >= MIN_PARCELS) {
    const hers = facts.refundedParcels / facts.deliveredParcels;
    const norm = Math.max(facts.categoryRefundRate, 0.02);

    if (hers >= norm * 3 && facts.refundedParcels >= 4) {
      reasons.push({
        code: 'seller_refund_rate_extreme',
        weight: 26,
        ar: `${(hers * 100).toFixed(0)}% من طرودها تُرَدّ مقابل ${(norm * 100).toFixed(0)}% لفئتها`,
      });
    } else if (hers >= norm * 2 && facts.refundedParcels >= 3) {
      reasons.push({
        code: 'seller_refund_rate_high',
        weight: 13,
        ar: `${(hers * 100).toFixed(0)}% من طرودها تُرَدّ مقابل ${(norm * 100).toFixed(0)}% لفئتها`,
      });
    }

    // Cancelling after accepting is the one that costs a customer her plans:
    // she has paid, waited, and is told days later that it was never there.
    const cancelRate = facts.cancelledBySeller / facts.deliveredParcels;
    if (cancelRate >= 0.2 && facts.cancelledBySeller >= 3) {
      reasons.push({
        code: 'cancels_after_accepting',
        weight: 22,
        ar: `ألغت ${facts.cancelledBySeller} طلباً بعد قبولها`,
      });
    }
  }

  // Evidence rather than a heuristic, and weighted as such.
  //
  // The rule that no single signal convicts governs the *guesses* in this
  // file — a missing purchase, a harsh mark, a shared handset — because each
  // has an innocent reading more common than the guilty one. A confirmed fake
  // review has already been through a person, who looked at it and agreed.
  // Three of them on one boutique's listings is not a pattern to watch, it is
  // a finding, and it reaches SUSPECT on its own.
  if (facts.confirmedFakeReviews >= 3) {
    reasons.push({
      code: 'confirmed_review_campaign',
      weight: 55,
      ar: `${facts.confirmedFakeReviews} تقييمات مؤكَّدة كمزيّفة على منتجاتها`,
    });
  } else if (facts.confirmedFakeReviews > 0) {
    reasons.push({
      code: 'confirmed_fake_reviews',
      weight: 16,
      ar: `${facts.confirmedFakeReviews} تقييم مؤكَّد كمزيّف على منتجاتها`,
    });
  }

  if (facts.disputesLost >= 3) {
    reasons.push({
      code: 'seller_disputes_lost',
      weight: 24,
      ar: `${facts.disputesLost} نزاعات حُسمت ضدّها`,
    });
  } else if (facts.disputesLost === 2) {
    reasons.push({
      code: 'seller_disputes_lost_few',
      weight: 10,
      ar: 'نزاعان حُسما ضدّها',
    });
  }

  // Listings taken down, as a share of what she has up. Two removals from a
  // shop of four is a different shop from two removals out of three hundred.
  const listings = facts.liveListings + facts.removedListings;
  if (facts.removedListings >= 2 && listings > 0) {
    const share = facts.removedListings / listings;
    if (share >= 0.25) {
      reasons.push({
        code: 'listings_removed_share',
        weight: 20,
        ar: `${facts.removedListings} من ${listings} إعلاناً أُزيلت`,
      });
    } else {
      reasons.push({
        code: 'listings_removed',
        weight: 8,
        ar: `${facts.removedListings} إعلانات أُزيلت`,
      });
    }
  }

  // A shop days old moving real volume is worth a look — not because youth is
  // suspicious, but because there is no history to check anything against.
  if (
    facts.accountAgeDays !== null &&
    facts.accountAgeDays < 14 &&
    facts.deliveredParcels >= 20
  ) {
    reasons.push({
      code: 'new_shop_high_volume',
      weight: 12,
      ar: 'متجر جديد بحجم مبيعات مرتفع',
    });
  }

  return reading(reasons);
}
