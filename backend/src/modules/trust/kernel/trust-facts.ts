/**
 * The facts the trust scorers are allowed to see.
 *
 * Same discipline as `cod-trust/kernel`: every field is a count, a ratio, a
 * flag or an age in days. The kernel does not know what a `ProductReview` is,
 * cannot reach a database, and holds nobody's name or phone number. That is
 * what lets the scoring be tested in a line and read in a screen — and it is
 * also what stops a "risk score" quietly becoming a place where personal
 * details accumulate.
 */

/** What one review looks like, stripped of who wrote it. */
export interface ReviewFacts {
  /** 1–5, as left. */
  rating: number;

  /** An order of hers, delivered, containing this product. */
  verifiedPurchase: boolean;

  /** Her account's age when she wrote it. Null for an account with no age. */
  accountAgeDays: number | null;

  /** She has confirmed her number. */
  phoneVerified: boolean;

  /** Reviews she has written in the recent window, this one included. */
  reviewsInWindow: number;

  /** Of those, how many were the top mark. */
  fiveStarInWindow: number;

  /**
   * How many of her recent reviews landed on products this same boutique
   * sells. One woman who loves one shop is ordinary; one account that only
   * ever reviews one shop is a different shape.
   */
  reviewsForSameSeller: number;

  /** Orders she has actually placed, ever. A reviewer who never buys. */
  ordersPlaced: number;

  /**
   * Reviews the product received in the day around this one. A listing that
   * collects a fortnight of reviews in an afternoon was not discovered by a
   * fortnight of shoppers.
   */
  productReviewsSameDay: number;

  /** Reviews the product has, all told. Context for the burst above. */
  productReviewsTotal: number;

  /**
   * The product's mean rating with this review left out. The gap between it
   * and `rating` is what rating manipulation looks like from the outside —
   * but only ever *with* the other signals, because a genuinely disappointed
   * customer produces the same gap.
   */
  productMeanWithout: number | null;

  /**
   * Other reviews carrying the same words. Compared on the folded search key,
   * so spacing and harakat do not hide a copy-paste.
   */
  duplicateBodies: number;

  /** The review has no words at all — a bare star. */
  bodyEmpty: boolean;
}

/** What a customer's returns and refunds look like against the platform's own norm. */
export interface RefundFacts {
  deliveredParcels: number;
  /** Parcels she asked to send back. */
  returnsRequested: number;
  /** Of those, the ones that ended in her money back. */
  refundsReceived: number;
  /** Parcels she turned away at the door. */
  refusedParcels: number;
  /** Disputes she opened. */
  disputesOpened: number;
  /** Of those, the ones decided against her. */
  disputesLost: number;

  /**
   * The platform's own refund rate over the same window, as a fraction.
   * Everything here is judged against this rather than a number somebody
   * picked: a marketplace where one parcel in five comes back should not be
   * flagging the customers who match it.
   */
  platformRefundRate: number;
}

/** What ties one account to others. */
export interface IdentityFacts {
  accountAgeDays: number | null;
  phoneVerified: boolean;

  /**
   * Other accounts that have shipped to a recipient phone this account also
   * ships to. A family sharing a handset looks exactly like this, which is
   * why it is a signal and not a verdict.
   */
  accountsSharingPhone: number;

  /** Other accounts that have signed from a device key this account uses. */
  accountsSharingDevice: number;

  /** Other accounts with an address line identical to one of hers. */
  accountsSharingAddress: number;

  /** Coupon redemptions across the accounts she is tied to. */
  linkedCouponRedemptions: number;
}

/**
 * What a boutique's conduct looks like, against what her category does.
 *
 * Not performance — `SellerHealth` owns that, and a slow shop is a shop to
 * help rather than a shop to investigate. These are the facts that say the
 * platform may be carrying a risk by listing her.
 *
 * Every rate here comes with the category's own rate beside it. A boutique
 * selling occasionwear will be returned against more than one selling
 * perfume, and a scorer that does not know the difference spends its time
 * accusing whoever sells the hardest category.
 */
export interface SellerConductFacts {
  accountAgeDays: number | null;
  /** Parcels she has actually delivered, in the window. */
  deliveredParcels: number;

  /** Parcels refunded to the customer. */
  refundedParcels: number;
  /** The same rate across her categories, as a fraction. */
  categoryRefundRate: number;

  /** Orders she cancelled after accepting them. */
  cancelledBySeller: number;

  /** Disputes raised against her, and the ones she lost. */
  disputesAgainst: number;
  disputesLost: number;

  /**
   * Reviews on her listings that a moderator has confirmed were bought.
   * Confirmed, not merely flagged — a suspicion is not evidence of her
   * involvement, and a competitor can flag anybody.
   */
  confirmedFakeReviews: number;

  /** Listings of hers taken down by moderation. */
  removedListings: number;
  /** Listings she has live. Context for the number above. */
  liveListings: number;
}
