/**
 * Every tunable the cash-on-delivery trust engine has, in one file.
 *
 * Two conventions hold throughout and both are load-bearing:
 *
 * 1. **Money is USD.** Orders are placed in SYP or USD and the exchange rate
 *    moves fast enough that a threshold written in SYP would mean something
 *    different every quarter. Each order froze its own rate at checkout
 *    (`orders.fx_rate`), so dividing by it recovers the value in the only unit
 *    that stays comparable across a year of history.
 *
 * 2. **A weight is a ceiling, not a contribution.** `WEIGHTS.x` is the most
 *    points a factor may ever move the score; what it actually contributes is
 *    that ceiling scaled by how bad the evidence is, and zero when there is not
 *    enough evidence to have an opinion at all.
 */

/** Where a customer we know nothing about starts. */
export const BASE_SCORE = 22;

/**
 * The most each signal may move the score, in points.
 *
 * The positives sum to more than 100 on purpose — the score is clamped, and a
 * customer who trips five independent alarms should saturate rather than
 * arrive at a polite 60. The negatives are the trust the platform gives back
 * for a delivery history it can actually see.
 */
export const WEIGHTS = {
  /** Parcels she was there for and sent away. The strongest signal there is. */
  refusalRate: 34,
  /** Doors nobody answered. Weaker: a missed call is not a refusal. */
  failureRate: 14,
  /** Orders she killed after the seller had already been told to prepare. */
  cancellationRate: 10,
  /** This basket against the basket she normally buys. */
  valueAnomaly: 12,
  /** Nothing behind the number: no verified phone, no enrolled device. */
  weakIdentity: 10,
  /** An address a courier will struggle to find. */
  addressQuality: 9,
  /** One phone number, several accounts. */
  phoneReuse: 12,
  /** Where it is going, when that governorate has a history worth reading. */
  destinationBaseRate: 8,
  /** A first basket that looks like a dare: many sellers, many units. */
  basketShape: 8,
  /** Deliveries that went through, at the door, with cash. */
  provenHistory: -30,
} as const;

export type CodFactorCode = keyof typeof WEIGHTS;

/**
 * How much history a signal needs before it is allowed to speak.
 *
 * This is the same lesson the trend engine learned the hard way: a rate over
 * two parcels is not a rate, it is a coin toss with consequences. Under the
 * threshold the factor reports `insufficient` and contributes exactly nothing,
 * which is why a new customer scores near the base rather than near the top.
 */
export const MIN_EVIDENCE = {
  /** Completed delivery attempts before her own rates mean anything. */
  personalAttempts: 3,
  /** Delivered parcels before her median order value is a baseline. */
  personalOrders: 2,
  /** Parcels into a governorate before its base rate is quotable. */
  destinationAttempts: 40,
} as const;

/** Full confidence needs this many of her own delivery attempts. */
export const CONFIDENCE_SATURATION_ATTEMPTS = 8;

/**
 * Tier cut-offs on the 0–100 score.
 *
 * `TRUSTED` is not merely "low": it is reserved for customers with a proven
 * history, because a score of 10 on no evidence and a score of 10 on eleven
 * delivered parcels are not the same claim.
 */
export const TIER_THRESHOLDS = {
  trusted: 18,
  low: 45,
  medium: 70,
} as const;

/** Delivered parcels required before the `TRUSTED` tier is available at all. */
export const TRUSTED_MIN_DELIVERIES = 3;

/**
 * Hard rules, in USD. They may only ever *raise* the required assurance —
 * a rule that could lower it would let a high score be argued away.
 */
export const HARD_RULES = {
  /** A first cash order above this asks for a code, whatever the score says. */
  firstOrderConfirmAbove: 25,
  /** A guest — no account, no history, no recourse — above this does too. */
  guestConfirmAbove: 15,
  /** Cash above this always asks for a code. Nobody's history buys past it. */
  alwaysConfirmAbove: 400,
  /** This many refusals in the window and cash is off the table. */
  refusalsForPrepayment: 3,
} as const;

/** How far back the history behind every rate is read. */
export const HISTORY_WINDOW_DAYS = 240;

/** How long a customer has to enter the confirmation code before it lapses. */
export const CONFIRMATION_TTL_MINUTES = 30;

/**
 * An address line shorter than this is a landmark, not an address — "مشروع
 * دمر" is not somewhere a courier can stand.
 */
export const MIN_USEFUL_ADDRESS_LENGTH = 18;
