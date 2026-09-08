import {
  CustomerFacts,
  EngagementFacts,
  PurchaseFacts,
  RhythmFacts,
} from './customer-facts';

/**
 * What a customer is likely to do next, and what she is worth.
 *
 * **Deterministic, and that is a decision rather than a limitation.** There is
 * no training pipeline here, no model registry, nothing to retrain when the
 * catalogue turns over. What there is instead is arithmetic on her own
 * history, every step of which can be printed next to the number — and a
 * marketplace that cannot explain why it decided a customer was leaving
 * cannot act on the decision either. When the platform has the volume and the
 * labelling discipline to train something, these scores become its features
 * and its baseline; until then they are the honest answer, not a placeholder.
 *
 * **Everything is measured against her own rhythm.** This is the idea the
 * whole file turns on. A woman who buys every three weeks and has been silent
 * for sixty days is leaving; a woman who buys twice a year and has been silent
 * for sixty days is behaving normally. A fixed "lapsed after 90 days" rule
 * gets one of those two badly wrong whichever number it picks, and it is the
 * rule almost every marketplace ships with.
 */

/** One thing the evidence said, and which way it argued. */
export interface Signal {
  code: string;
  /** Arabic, because every screen that shows these is Arabic. */
  ar: string;
}

export interface PropensityReading {
  /** 0–100. How likely she is to buy in the near horizon. */
  score: number;
  band: 'cold' | 'warm' | 'hot';
  signals: Signal[];
  /**
   * False when there is not enough history for the number to mean anything.
   * The score is still returned — it is the best available reading — but a
   * caller spending money on it should know it is a guess.
   */
  confident: boolean;
}

export interface ChurnReading {
  /** 0–100. How likely she is to be gone. */
  score: number;
  band: 'safe' | 'watch' | 'leaving' | 'gone';
  signals: Signal[];
  /**
   * Her own average gap between orders, in days. Null when she has fewer than
   * two orders — one purchase establishes no rhythm at all.
   */
  cadenceDays: number | null;
  /** How many of her own cycles have passed in silence. */
  cyclesOverdue: number | null;
  confident: boolean;
}

export interface ValueReading {
  /** What she has actually spent, net of refunds. Not a projection. */
  realisedValue: number;
  /** Her average order, net. Null before her first. */
  averageOrder: number | null;
  /**
   * What she is projected to spend over the horizon, given her own cadence
   * and her chance of still being here. An extrapolation from her history,
   * explicitly — not a model output.
   */
  projectedValue: number;
  horizonDays: number;
  confident: boolean;
}

export interface ContactWindow {
  /** Hour 0–23 she is most often active, or null when nobody knows. */
  bestHour: number | null;
  /** The hours worth trying, best first. Empty when unknown. */
  hours: number[];
  observations: number;
}

/** Below this many orders, a "cadence" is a coincidence. */
const CADENCE_MIN_ORDERS = 2;

/** Below this many observations, an activity histogram is noise. */
const RHYTHM_MIN_OBSERVATIONS = 12;

/** How far ahead value is projected. A season — long enough to matter. */
export const VALUE_HORIZON_DAYS = 180;

const clamp = (value: number, low = 0, high = 100) =>
  Math.max(low, Math.min(high, value));

// ── Cadence ──────────────────────────────────────────────────────────────────

/**
 * Her own average gap between orders.
 *
 * Measured across the span she has actually been buying over, not since she
 * registered: a woman who signed up in January and first bought in June has a
 * cadence measured from June. Counting the dormant months would make every
 * customer look slower than she is and every churn score look calmer.
 */
export function cadenceOf(purchases: PurchaseFacts): number | null {
  if (purchases.orders < CADENCE_MIN_ORDERS) return null;
  if (
    purchases.daysSinceFirstOrder === null ||
    purchases.daysSinceLastOrder === null
  ) {
    return null;
  }

  const span = purchases.daysSinceFirstOrder - purchases.daysSinceLastOrder;
  if (span <= 0) return null;

  return Math.round((span / (purchases.orders - 1)) * 10) / 10;
}

// ── Churn ────────────────────────────────────────────────────────────────────

/**
 * How likely she is to be gone.
 *
 * For a customer with a rhythm, the question is how many of *her* cycles have
 * passed in silence. Two is a wobble; four is a departure. For a customer
 * without one — a single order, or none — there is no rhythm to be late
 * against, so the reading falls back to plain silence and says it is not
 * confident.
 */
export function scoreChurn(facts: CustomerFacts): ChurnReading {
  const { purchases, engagement } = facts;
  const signals: Signal[] = [];
  const cadence = cadenceOf(purchases);

  // Never bought, and gone quiet: she is not churning, she never arrived.
  // Reported as a low score rather than a high one, because sending a
  // win-back offer to somebody who has never been won is a different mistake.
  if (purchases.orders === 0) {
    const quiet = engagement.daysSinceLastSeen ?? 0;
    signals.push({
      code: 'never_purchased',
      ar: 'لم تشترِ من قبل — ليست عميلة منقطعة بل عميلة لم تبدأ',
    });
    return {
      score: clamp(Math.min(40, quiet)),
      band: quiet > 60 ? 'watch' : 'safe',
      signals,
      cadenceDays: null,
      cyclesOverdue: null,
      confident: false,
    };
  }

  let score = 0;
  let cyclesOverdue: number | null = null;

  if (cadence !== null && purchases.daysSinceLastOrder !== null) {
    cyclesOverdue =
      Math.round((purchases.daysSinceLastOrder / cadence) * 10) / 10;

    // The curve: one cycle is on time, two is late, four is gone. Scaled so
    // a customer at exactly her cadence scores near nothing.
    score = clamp((cyclesOverdue - 1) * 30);

    if (cyclesOverdue >= 4) {
      signals.push({
        code: 'four_cycles_silent',
        ar: `مرّت ${cyclesOverdue} أضعاف وتيرتها المعتادة (كل ${cadence} يوماً) بلا شراء`,
      });
    } else if (cyclesOverdue >= 2) {
      signals.push({
        code: 'two_cycles_silent',
        ar: `تأخّرت ${cyclesOverdue} ضعف وتيرتها المعتادة (كل ${cadence} يوماً)`,
      });
    } else {
      signals.push({
        code: 'on_cadence',
        ar: `ضمن وتيرتها المعتادة (كل ${cadence} يوماً)`,
      });
    }
  } else {
    // One order and no rhythm. Silence still means something, but far less,
    // and the reading says so rather than pretending.
    const quiet = purchases.daysSinceLastOrder ?? 0;
    score = clamp(quiet / 2);
    signals.push({
      code: 'no_cadence_yet',
      ar: 'طلب واحد فقط — لا وتيرة يمكن قياس التأخّر عليها',
    });
  }

  // Still visiting, even if not buying. That is the difference between a
  // customer who is losing interest and one who has left.
  if (engagement.daysSinceLastSeen !== null && engagement.daysSinceLastSeen <= 7) {
    score = clamp(score - 25);
    signals.push({
      code: 'still_visiting',
      ar: 'ما زالت تفتح التطبيق خلال الأسبوع الماضي',
    });
  } else if (
    engagement.daysSinceLastSeen !== null &&
    engagement.daysSinceLastSeen > 45
  ) {
    score = clamp(score + 15);
    signals.push({
      code: 'not_seen_at_all',
      ar: `لم تفتح التطبيق منذ ${engagement.daysSinceLastSeen} يوماً`,
    });
  }

  if (engagement.hasOpenCart) {
    score = clamp(score - 10);
    signals.push({ code: 'open_cart', ar: 'لديها سلّة مفتوحة' });
  }

  return {
    score: Math.round(score),
    band: bandForChurn(score),
    signals,
    cadenceDays: cadence,
    cyclesOverdue,
    confident: cadence !== null,
  };
}

function bandForChurn(score: number): ChurnReading['band'] {
  if (score >= 75) return 'gone';
  if (score >= 50) return 'leaving';
  if (score >= 25) return 'watch';
  return 'safe';
}

// ── Purchase propensity ──────────────────────────────────────────────────────

/**
 * How likely she is to buy soon.
 *
 * Weighted towards intent that costs her something. A cart add is worth far
 * more than a view, because she had to decide; a view is worth more than an
 * app open. Nothing here counts impressions — a card scrolling past is not a
 * signal about her, it is a signal about the feed.
 */
export function scorePropensity(facts: CustomerFacts): PropensityReading {
  const { purchases, engagement } = facts;
  const signals: Signal[] = [];
  let score = 0;

  if (engagement.hasOpenCart) {
    score += 35;
    signals.push({ code: 'open_cart', ar: 'سلّة مفتوحة الآن' });
  }
  if (engagement.cartAdds > 0) {
    score += Math.min(20, engagement.cartAdds * 7);
    signals.push({
      code: 'recent_cart_adds',
      ar: `أضافت ${engagement.cartAdds} قطعة إلى السلّة مؤخراً`,
    });
  }
  if (engagement.favourites > 0) {
    score += Math.min(10, engagement.favourites * 3);
    signals.push({
      code: 'recent_favourites',
      ar: `حفظت ${engagement.favourites} قطعة`,
    });
  }
  if (engagement.searches > 0) {
    score += Math.min(10, engagement.searches * 2);
    signals.push({
      code: 'searching',
      ar: `بحثت ${engagement.searches} مرّة`,
    });
  }
  if (engagement.productViews >= 10) {
    score += 8;
    signals.push({
      code: 'browsing_heavily',
      ar: `شاهدت ${engagement.productViews} منتجاً`,
    });
  } else if (engagement.productViews > 0) {
    score += 4;
  }

  // A customer who has bought before buys again far more readily than one who
  // never has. The strongest single predictor there is, and the cheapest.
  if (purchases.orders >= 3) {
    score += 20;
    signals.push({
      code: 'established_buyer',
      ar: `اشترت ${purchases.orders} مرّات من قبل`,
    });
  } else if (purchases.orders > 0) {
    score += 12;
    signals.push({ code: 'has_bought_before', ar: 'اشترت من قبل' });
  }

  // Due, by her own rhythm. Both directions matter: overdue is opportunity,
  // long overdue is churn and belongs to the other scorer.
  const churn = scoreChurn(facts);
  if (churn.cyclesOverdue !== null) {
    if (churn.cyclesOverdue >= 0.8 && churn.cyclesOverdue <= 2) {
      score += 15;
      signals.push({
        code: 'due_by_cadence',
        ar: 'حان موعد شرائها المعتاد',
      });
    } else if (churn.cyclesOverdue > 3) {
      score -= 15;
      signals.push({
        code: 'long_overdue',
        ar: 'تجاوزت وتيرتها بكثير — الأرجح أنها انقطعت',
      });
    }
  }

  if (engagement.daysSinceLastSeen !== null && engagement.daysSinceLastSeen > 30) {
    score -= 20;
    signals.push({ code: 'dormant', ar: 'لم تُشاهَد منذ أكثر من شهر' });
  }

  const final = clamp(score);
  return {
    score: Math.round(final),
    band: final >= 60 ? 'hot' : final >= 30 ? 'warm' : 'cold',
    signals,
    // Thin history: a brand-new account with one cart add reads "hot" and is
    // really just unmeasured.
    confident:
      purchases.orders > 0 ||
      engagement.appOpens >= 3 ||
      engagement.productViews >= 10,
  };
}

// ── Value ────────────────────────────────────────────────────────────────────

/**
 * What she has been worth, and what she is likely to be worth next.
 *
 * The projection is deliberately simple: her own order rate, over the horizon,
 * at her own net average order, multiplied by her chance of still being here.
 * Every one of those four numbers is hers and can be shown to her account
 * manager, which is the property that makes it usable — a CLV nobody can
 * explain is a CLV nobody acts on.
 *
 * It is a projection of continuation, not a promise: "if she carries on at her
 * rate and does not leave, this is what that is worth". Over a 180-day horizon
 * a monthly customer therefore projects above her lifetime to date, which is
 * arithmetic rather than optimism — she has only been here 150 days.
 *
 * Refunds come off both sides. Her realised value is what she kept, and the
 * average that drives the projection is the net one.
 */
export function scoreValue(
  facts: CustomerFacts,
  horizonDays = VALUE_HORIZON_DAYS,
): ValueReading {
  const { purchases } = facts;

  if (purchases.orders === 0) {
    return {
      realisedValue: 0,
      averageOrder: null,
      projectedValue: 0,
      horizonDays,
      confident: false,
    };
  }

  // Net of what came back. A customer whose gross is high because she buys
  // and returns is not a valuable customer, and a marketplace that ranks her
  // as one spends its retention budget in exactly the wrong place.
  const kept = Math.max(0, purchases.orders - purchases.refundedOrders);
  const realised = Math.max(
    0,
    purchases.lifetimeSpend - purchases.refundedSpend,
  );
  const averageOrder =
    purchases.orders > 0
      ? Math.round((realised / purchases.orders) * 100) / 100
      : null;

  const cadence = cadenceOf(purchases);
  const churn = scoreChurn(facts);
  const survival = 1 - churn.score / 100;

  // Without a cadence there is no rate to project. Rather than invent one,
  // the projection is her keeping-rate applied to a single expected repeat —
  // small, and honest about being small.
  const expectedOrders =
    cadence !== null && cadence > 0
      ? Math.min(horizonDays / cadence, 12)
      : kept > 0
        ? 0.5
        : 0;

  const projected =
    averageOrder !== null
      ? Math.round(expectedOrders * averageOrder * survival * 100) / 100
      : 0;

  return {
    realisedValue: Math.round(realised * 100) / 100,
    averageOrder,
    projectedValue: Math.max(0, projected),
    horizonDays,
    confident: cadence !== null,
  };
}

// ── When to reach her ────────────────────────────────────────────────────────

/**
 * The hours she is actually awake and shopping.
 *
 * Read from her own activity rather than assumed. Returns nothing at all below
 * a floor of observations — a notification sent at "her best hour" computed
 * from four app opens is a notification sent at a random hour with a
 * justification attached, and the justification is the harmful part.
 */
export function contactWindow(rhythm: RhythmFacts): ContactWindow {
  if (
    rhythm.observations < RHYTHM_MIN_OBSERVATIONS ||
    rhythm.activityByHour.length !== 24
  ) {
    return { bestHour: null, hours: [], observations: rhythm.observations };
  }

  const ranked = rhythm.activityByHour
    .map((count, hour) => ({ hour, count }))
    .filter((entry) => entry.count > 0)
    .sort((a, b) => b.count - a.count || a.hour - b.hour);

  if (ranked.length === 0) {
    return { bestHour: null, hours: [], observations: rhythm.observations };
  }

  // Only hours carrying a real share. A tail hour with one event is not a
  // preference, and offering it as one invites somebody to schedule on it.
  const meaningful = ranked.filter(
    (entry) => entry.count >= rhythm.observations * 0.1,
  );
  const hours = (meaningful.length > 0 ? meaningful : ranked.slice(0, 1)).map(
    (entry) => entry.hour,
  );

  return {
    bestHour: hours[0],
    hours: hours.slice(0, 4),
    observations: rhythm.observations,
  };
}

/** Everything about one customer, in one reading. */
export interface CustomerReading {
  propensity: PropensityReading;
  churn: ChurnReading;
  value: ValueReading;
  contact: ContactWindow;
}

export function readCustomer(
  facts: CustomerFacts,
  horizonDays = VALUE_HORIZON_DAYS,
): CustomerReading {
  return {
    propensity: scorePropensity(facts),
    churn: scoreChurn(facts),
    value: scoreValue(facts, horizonDays),
    contact: contactWindow(facts.rhythm),
  };
}
