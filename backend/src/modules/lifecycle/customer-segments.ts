/**
 * Who a customer is to the marketplace right now.
 *
 * The notification module could already pick an audience, but only from four
 * facts — a role, a points balance, a verification flag, days since last login.
 * None of those is a commerce fact, so nothing could address "women who left
 * something in a basket last night", "women who bought twice and then stopped",
 * or "women who have never bought anything at all". Every growth feature the
 * audit found missing — abandoned cart, win-back, targeted offers — is
 * downstream of being able to name those groups.
 *
 * The stages below are a lifecycle, not a taxonomy: a customer occupies
 * exactly one of them, and moves between them by buying or by not buying. That
 * is deliberate. Overlapping segments look richer on a screen and produce
 * campaigns that reach the same woman three times in a morning.
 */

/** The one stage a customer is in. Ordered from coldest to warmest. */
export const LIFECYCLE_STAGES = [
  'prospect',
  'window_shopper',
  'first_time',
  'repeat',
  'loyal',
  'at_risk',
  'lapsed',
] as const;

export type LifecycleStage = (typeof LIFECYCLE_STAGES)[number];

/**
 * Audiences that cut across the lifecycle.
 *
 * These are not stages — a woman with something in her basket is also, at that
 * moment, `repeat` or `first_time`. They are kept separate so a campaign can
 * ask for one without disturbing the other.
 */
export const AUDIENCES = ['abandoned_cart', 'vip'] as const;
export type Audience = (typeof AUDIENCES)[number];

/**
 * The thresholds. Gathered here rather than scattered through the queries,
 * because these are the numbers a merchandiser will want changed and they
 * should be findable.
 */
export const SEGMENT_RULES = {
  /**
   * A basket is "abandoned" once it has sat untouched this long.
   *
   * Four hours, not one: a woman who adds a dress at lunchtime and buys it in
   * the evening has not abandoned anything, and a nudge that arrives while
   * she is still deciding is an interruption rather than a reminder.
   */
  abandonedAfterHours: 4,

  /**
   * And it stops being worth a nudge after this. A basket from three weeks
   * ago is a basket she has forgotten on purpose; the prices in it may not
   * even be current.
   */
  abandonedUntilDays: 14,

  /** Orders that make a customer `repeat` rather than `first_time`. */
  repeatOrders: 2,

  /** Orders inside `loyalWindowDays` that make her `loyal`. */
  loyalOrders: 4,
  loyalWindowDays: 180,

  /**
   * Silence after her last order that makes her `at_risk`, then `lapsed`.
   *
   * The gap between the two is the whole point: `at_risk` is a woman worth
   * reminding, `lapsed` is a woman worth an offer. Treating them the same
   * means either spending a discount on somebody who was coming back anyway,
   * or sending a gentle reminder to somebody who left months ago.
   */
  atRiskAfterDays: 60,
  lapsedAfterDays: 150,
} as const;

/** What each stage means, in the language of the console that shows it. */
export const STAGE_LABELS: Record<LifecycleStage, { ar: string; why: string }> = {
  prospect: {
    ar: 'لم تتصفّح بعد',
    why: 'Registered, and has not looked at anything worth recording yet.',
  },
  window_shopper: {
    ar: 'تتصفّح ولم تشترِ',
    why: 'She favourites, she views, she has never placed an order.',
  },
  first_time: {
    ar: 'اشترت مرّة',
    why: 'One order. The most fragile stage there is — most customers who ' +
      'leave, leave here.',
  },
  repeat: {
    ar: 'اشترت أكثر من مرّة',
    why: 'Two or more orders. She has decided the shop is real.',
  },
  loyal: {
    ar: 'عميلة دائمة',
    why: 'Four or more orders inside six months.',
  },
  at_risk: {
    ar: 'على وشك الانقطاع',
    why: 'She used to buy and has been quiet for two months. Worth a ' +
      'reminder, not a discount.',
  },
  lapsed: {
    ar: 'منقطعة',
    why: 'Five months of silence. If anything brings her back it is an offer.',
  },
};
