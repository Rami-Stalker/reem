/**
 * What the customer scorers are allowed to see.
 *
 * The same discipline as `trust/kernel` and `cod-trust/kernel`: counts, ratios
 * and ages in days. No names, no phone numbers, no product titles. A profile
 * that predicts what a woman will do next is exactly the place personal detail
 * quietly accumulates, so the kernel is built where it cannot.
 */

/** Her own trading history, in the shape a projection needs. */
export interface PurchaseFacts {
  orders: number;
  /** Total merchandise she has paid for, in the platform's own currency unit. */
  lifetimeSpend: number;

  /** Days since her first order, and since her last. Null when she has none. */
  daysSinceFirstOrder: number | null;
  daysSinceLastOrder: number | null;

  /** Parcels that came back, and what they were worth. */
  refundedOrders: number;
  /**
   * The money actually returned to her.
   *
   * An amount rather than a count, because the count cannot answer the
   * question. A customer who returns one dress out of eight has returned an
   * eighth of her orders and possibly half her spend, and it is the spend
   * that decides whether she was worth acquiring.
   */
  refundedSpend: number;
}

/** What she does when she is not buying. */
export interface EngagementFacts {
  /** Days since anything at all — an app open, a view, a search. */
  daysSinceLastSeen: number | null;

  /** Sessions in the recent window. */
  appOpens: number;
  productViews: number;
  searches: number;
  cartAdds: number;
  favourites: number;

  /** Length of the window the counts above cover. */
  windowDays: number;

  /** Something in her basket right now. */
  hasOpenCart: boolean;

  /** Her account's age. A three-day-old account has no cadence. */
  accountAgeDays: number | null;
}

/**
 * When she is actually awake.
 *
 * Hours 0–23 in the platform's timezone, counted from app opens and views.
 * Sparse for most customers, which is why the scorer says "unknown" rather
 * than defaulting to an hour somebody picked.
 */
export interface RhythmFacts {
  /** activityByHour[h] = events observed in that hour. */
  activityByHour: readonly number[];
  /** Total events behind the histogram. Below a floor, it means nothing. */
  observations: number;
}

/** Everything about one customer, gathered once. */
export interface CustomerFacts {
  purchases: PurchaseFacts;
  engagement: EngagementFacts;
  rhythm: RhythmFacts;
}
