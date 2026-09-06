/**
 * Seller Health.
 *
 * One pure function turns a window of a seller's own history into a number
 * between 0 and 100, the eight dimensions that produced it, a confidence that
 * says how much of it to believe, and the advice that follows.
 *
 * Nothing here reads a database and nothing here asks a model, for the same
 * reason the trend engine's kernel does not: this score will eventually decide
 * who gets ranked above whom and who is offered which benefits, and a number
 * with that much riding on it has to be arithmetic anybody can re-run by hand.
 *
 * ── The one decision worth arguing about ─────────────────────────────────
 *
 * Every dimension carries its own *evidence*, and a thin dimension is
 * discounted rather than guessed. A seller with three delivered orders has a
 * shipping speed, arithmetically — but it is one courier's Tuesday, and
 * putting it on a dashboard as though it were a fact about her shop is how a
 * marketplace teaches new sellers that the score is noise and stops them
 * reading it.
 *
 * So the score is a weighted average over the dimensions that *have* evidence,
 * with the weights renormalised across them. A seller who has never been
 * messaged is not marked down for responsiveness; she is simply scored on the
 * seven things she has actually done. Below `BUILDING_CONFIDENCE` overall she
 * is not given a band at all — `BUILDING` is the honest answer, and it is
 * deliberately not the bottom of the ladder.
 */

import { SellerHealthBand } from '@prisma/client';
import {
  BUILDING_CONFIDENCE,
  HEALTH_BANDS,
  HEALTH_DIMENSION_AR,
  HEALTH_DIMENSION_KEYS,
  HEALTH_FULL_SAMPLE,
  HEALTH_MIN_EVIDENCE,
  HEALTH_WEIGHTS,
  HealthDimensionKey,
  PREP_HOURS,
  RATE_CEILINGS,
  RESPONSE_HOURS,
  SHIP_HOURS,
} from '../intelligence.constants';

// ── What the kernel is given ─────────────────────────────────────────────

/**
 * The seller's window, as plain counts and hours.
 *
 * Deliberately not Prisma rows: every field here is something a person could
 * count by hand from the orders table, which is what makes the score
 * auditable. The service's whole job is to fill this in honestly.
 */
export interface SellerHealthFacts {
  /**
   * Orders she accepted that have *finished* — the reliability denominator.
   *
   * Settled, not merely accepted. An order still with the courier is not
   * evidence for or against her, and counting it as a non-delivery scores a
   * shop with a busy week as a failing one.
   */
  acceptedOrders: number;
  /** Accepted but still moving. Excluded from reliability, counted in cancellation. */
  openOrders: number;
  /** Of those, the ones that reached the buyer. */
  deliveredOrders: number;
  /** Cancelled after acceptance, by her. */
  cancelledBySeller: number;
  /** Cancelled by the buyer or refused at the door. Counted, never charged to her. */
  cancelledByOthers: number;

  /** Median hours from accepting an order to handing it over, and the sample. */
  prepHours: number | null;
  prepSample: number;

  /** Median hours from handover to delivery, and the sample. */
  shipHours: number | null;
  shipSample: number;

  /** Median hours to a first reply to a buyer, and how many conversations. */
  responseHours: number | null;
  responseSample: number;

  /** Delivered orders that came back, over delivered orders. */
  returnedOrders: number;

  /** Reviews on her products: the mean, and how many. */
  averageRating: number | null;
  reviewCount: number;

  /**
   * The mean health of her live listings, 0-100, and how many were scored.
   *
   * This is the seam between the two systems: product quality is not a fresh
   * opinion invented here, it is what Product Intelligence already measured,
   * averaged. One definition of a good listing, used twice.
   */
  productHealthMean: number | null;
  productHealthSample: number;
}

export interface HealthDimension {
  key: HealthDimensionKey;
  label: string;
  blurb: string;
  /** 0-100, or null when there is nothing to measure. */
  score: number | null;
  /** The weight it carried *after* renormalisation, in points of the total. */
  weight: number;
  /** 0-1: how full the sample was. */
  evidence: number;
  /** The raw count behind it, so the screen can say "over 34 orders". */
  sample: number;
  /** The measured value, for the screen to render in its own units. */
  value: number | null;
}

export interface SellerHealthResult {
  score: number;
  band: SellerHealthBand;
  confidence: number;
  dimensions: HealthDimension[];
  /** Dimensions with evidence, worst first — what to fix. */
  weakest: HealthDimensionKey[];
}

// ── Shapes ───────────────────────────────────────────────────────────────

const clamp01 = (n: number): number => Math.min(1, Math.max(0, n));
const round = (n: number, dp = 2): number => {
  const f = 10 ** dp;
  return Math.round(n * f) / f;
};

/**
 * A measurement where less is better, scored on a ramp.
 *
 * At or under `good` is 100, at or over `bad` is 0, straight line between.
 * The ramp is the point: a seller who ships in 30 hours against a 24-hour
 * target should see 96, not a failure, or the number stops being a thing she
 * can steer by and becomes a thing she resents.
 */
export function rampDown(value: number, good: number, bad: number): number {
  if (!Number.isFinite(value)) return 0;
  if (value <= good) return 100;
  if (value >= bad) return 0;
  return round((1 - (value - good) / (bad - good)) * 100);
}

/** A rate where zero is perfect and `ceiling` is the floor of the score. */
export function rateScore(rate: number, ceiling: number): number {
  if (!Number.isFinite(rate) || rate <= 0) return 100;
  if (rate >= ceiling) return 0;
  return round((1 - rate / ceiling) * 100);
}

/** How much of a full sample we have, 0-1. */
export function evidenceOf(sample: number, full: number): number {
  if (full <= 0) return 1;
  return clamp01(sample / full);
}

// ── The kernel ───────────────────────────────────────────────────────────

export function scoreSellerHealth(facts: SellerHealthFacts): SellerHealthResult {
  const raw = measureDimensions(facts);

  // Only dimensions with enough evidence are allowed to move the score. The
  // rest are still returned — she should see that shipping is unmeasured
  // rather than find it missing — but with a weight of zero.
  const scored = raw.filter(
    (d) => d.score !== null && d.evidence >= HEALTH_MIN_EVIDENCE,
  );

  const nominal = scored.reduce((t, d) => t + HEALTH_WEIGHTS[d.key], 0);

  // Renormalised across what she has actually done, so a shop with no messages
  // is scored out of the seven dimensions it does have rather than being
  // quietly docked ten points for a conversation that never happened.
  const dimensions: HealthDimension[] = raw.map((d) => {
    const counts = scored.includes(d);
    return {
      ...d,
      weight: counts && nominal > 0
        ? round((HEALTH_WEIGHTS[d.key] / nominal) * 100, 1)
        : 0,
    };
  });

  const score = nominal
    ? round(
        scored.reduce(
          (total, d) => total + (d.score as number) * HEALTH_WEIGHTS[d.key],
          0,
        ) / nominal,
      )
    : 0;

  // Confidence is depth × coverage, and the second half is the one that
  // matters.
  //
  // Depth alone — the evidence behind the dimensions that scored — reported
  // `1.0` for a shop measured on exactly one axis, because that axis happened
  // to have a deep sample. Live data made the consequence plain: a seller
  // whose orders all arrived on time, who replied in under an hour and had a
  // four-star rating was branded AT_RISK "with full confidence" on the
  // strength of her product pages alone, while the seven dimensions that
  // would have exonerated her were measured and discarded for thin evidence.
  //
  // Coverage is the share of the total weight we were able to score at all.
  // Multiplying by it says the honest thing: knowing one eighth of a shop
  // very well is not knowing the shop.
  const totalWeight = HEALTH_DIMENSION_KEYS.reduce(
    (t, key) => t + HEALTH_WEIGHTS[key],
    0,
  );
  const depth = nominal
    ? scored.reduce((t, d) => t + d.evidence * HEALTH_WEIGHTS[d.key], 0) /
      nominal
    : 0;
  const coverage = nominal / totalWeight;
  const confidence = round(depth * coverage);

  return {
    score,
    band: bandFor(score, confidence),
    confidence,
    dimensions,
    weakest: scored
      .slice()
      .sort((a, b) => (a.score as number) - (b.score as number))
      .filter((d) => (d.score as number) < 80)
      .map((d) => d.key),
  };
}

/**
 * The band, which confidence can veto.
 *
 * A seller with a 96 over six orders is not exemplary, she is new. Reporting
 * her as exemplary would make the top band meaningless the first time a buyer
 * relied on it.
 */
export function bandFor(
  score: number,
  confidence: number,
): SellerHealthBand {
  if (confidence < BUILDING_CONFIDENCE) return SellerHealthBand.BUILDING;
  return (
    HEALTH_BANDS.find((rung) => score >= rung.min)?.band ??
    SellerHealthBand.AT_RISK
  );
}

function measureDimensions(
  facts: SellerHealthFacts,
): Array<Omit<HealthDimension, 'weight'>> {
  const dim = (
    key: HealthDimensionKey,
    score: number | null,
    sample: number,
    value: number | null,
  ): Omit<HealthDimension, 'weight'> => ({
    key,
    label: HEALTH_DIMENSION_AR[key].label,
    blurb: HEALTH_DIMENSION_AR[key].blurb,
    score: score === null ? null : round(score),
    evidence: round(evidenceOf(sample, HEALTH_FULL_SAMPLE[key]), 2),
    sample,
    value: value === null ? null : round(value),
  });

  // Reliability. The denominator is orders she accepted, and cancellations
  // that were not hers are removed from it rather than counted against her —
  // a buyer changing her mind is not a fact about the seller.
  const answerable = Math.max(0, facts.acceptedOrders - facts.cancelledByOthers);
  const reliabilityRate = answerable
    ? facts.deliveredOrders / answerable
    : null;

  // Cancellation divides by everything she took on, settled or not: pulling
  // out is a decision made while an order is live, so excluding live orders
  // from the denominator would inflate the rate of a busy shop.
  const takenOn = facts.acceptedOrders + facts.openOrders;
  const cancelRate = takenOn ? facts.cancelledBySeller / takenOn : null;

  const returnRate = facts.deliveredOrders
    ? facts.returnedOrders / facts.deliveredOrders
    : null;

  // Quality is the listings themselves and what came back, not the star
  // rating — that is its own dimension and counting it twice would let one
  // good month carry two.
  const quality =
    facts.productHealthMean === null
      ? returnRate === null
        ? null
        : rateScore(returnRate, RATE_CEILINGS.returns)
      : returnRate === null
        ? facts.productHealthMean
        : facts.productHealthMean * 0.6 +
          rateScore(returnRate, RATE_CEILINGS.returns) * 0.4;

  return [
    dim(
      'reliability',
      reliabilityRate === null ? null : reliabilityRate * 100,
      answerable,
      reliabilityRate === null ? null : reliabilityRate * 100,
    ),
    dim(
      'prepSpeed',
      facts.prepHours === null
        ? null
        : rampDown(facts.prepHours, PREP_HOURS.good, PREP_HOURS.bad),
      facts.prepSample,
      facts.prepHours,
    ),
    dim(
      'productQuality',
      quality,
      Math.max(facts.productHealthSample, facts.deliveredOrders),
      facts.productHealthMean,
    ),
    dim(
      'satisfaction',
      facts.averageRating === null ? null : (facts.averageRating / 5) * 100,
      facts.reviewCount,
      facts.averageRating,
    ),
    dim(
      'shipSpeed',
      facts.shipHours === null
        ? null
        : rampDown(facts.shipHours, SHIP_HOURS.good, SHIP_HOURS.bad),
      facts.shipSample,
      facts.shipHours,
    ),
    dim(
      'returns',
      returnRate === null ? null : rateScore(returnRate, RATE_CEILINGS.returns),
      facts.deliveredOrders,
      returnRate === null ? null : returnRate * 100,
    ),
    dim(
      'responsiveness',
      facts.responseHours === null
        ? null
        : rampDown(facts.responseHours, RESPONSE_HOURS.good, RESPONSE_HOURS.bad),
      facts.responseSample,
      facts.responseHours,
    ),
    dim(
      'cancellation',
      cancelRate === null
        ? null
        : rateScore(cancelRate, RATE_CEILINGS.cancellation),
      takenOn,
      cancelRate === null ? null : cancelRate * 100,
    ),
  ].sort(
    (a, b) => HEALTH_DIMENSION_KEYS.indexOf(a.key) - HEALTH_DIMENSION_KEYS.indexOf(b.key),
  );
}

// ── Advice ───────────────────────────────────────────────────────────────

export interface HealthAdvice {
  code: string;
  dimension: HealthDimensionKey;
  severity: 'critical' | 'warning' | 'opportunity';
  /** Points on the total she would recover by reaching the good threshold. */
  gainPoints: number;
  ar: string;
}

/**
 * What to do next, ordered by what it is worth.
 *
 * Ordered by *recoverable points* rather than by how bad each dimension looks,
 * because those are different questions: a dimension scoring 40 at a weight of
 * five matters less than one scoring 70 at a weight of twenty, and telling her
 * to fix the first one first would be advice that costs her money.
 *
 * Nothing here is generated. Each line is a sentence about a measured number,
 * which is what lets the screen show it without a disclaimer.
 */
export function adviseSellerHealth(
  result: SellerHealthResult,
  facts: SellerHealthFacts,
): HealthAdvice[] {
  const out: HealthAdvice[] = [];
  const byKey = new Map(result.dimensions.map((d) => [d.key, d]));

  const gain = (key: HealthDimensionKey, target = 100): number => {
    const d = byKey.get(key);
    if (!d || d.score === null || !d.weight) return 0;
    return round(((target - d.score) * d.weight) / 100, 1);
  };

  const push = (
    code: string,
    dimension: HealthDimensionKey,
    severity: HealthAdvice['severity'],
    ar: string,
  ) => {
    const gainPoints = gain(dimension);
    if (gainPoints <= 0.5) return;
    out.push({ code, dimension, severity, gainPoints, ar });
  };

  const prep = byKey.get('prepSpeed');
  if (prep?.value !== null && prep?.value !== undefined && prep.value > PREP_HOURS.good) {
    push(
      'PREP_SLOW',
      'prepSpeed',
      prep.value > PREP_HOURS.bad ? 'critical' : 'warning',
      `وسطي تجهيزك ${Math.round(prep.value)} ساعة. لو نزّلتيه تحت ${PREP_HOURS.good} ساعة، بيوصل الطلب أسرع وبترتفع صحّة متجرك.`,
    );
  }

  const ship = byKey.get('shipSpeed');
  if (ship?.value !== null && ship?.value !== undefined && ship.value > SHIP_HOURS.good) {
    push(
      'SHIP_SLOW',
      'shipSpeed',
      'warning',
      `الشحن عندك عم ياخد ${Math.round(ship.value / 24)} يوم بالوسطي. راجعي مع المندوب أو غيّري طريقة التسليم.`,
    );
  }

  const resp = byKey.get('responsiveness');
  if (resp?.value !== null && resp?.value !== undefined && resp.value > RESPONSE_HOURS.good) {
    push(
      'RESPONSE_SLOW',
      'responsiveness',
      resp.value > RESPONSE_HOURS.bad ? 'critical' : 'warning',
      `الزبونة بتستنّى ${Math.round(resp.value)} ساعة لتردّي عليها. الردّ بأول ساعتين بيرفع فرصة الشراء كتير.`,
    );
  }

  const cancel = byKey.get('cancellation');
  if (cancel?.value !== null && cancel?.value !== undefined && cancel.value > 0) {
    push(
      'CANCEL_RATE',
      'cancellation',
      cancel.value > RATE_CEILINGS.cancellation * 100 ? 'critical' : 'warning',
      `ألغيتي ${facts.cancelledBySeller} طلب من أصل ${facts.acceptedOrders + facts.openOrders}. أكتر سبب بيكون المخزون مو محدّث — راجعي الكميات.`,
    );
  }

  const ret = byKey.get('returns');
  if (ret?.value !== null && ret?.value !== undefined && ret.value > 5) {
    push(
      'RETURN_RATE',
      'returns',
      ret.value > RATE_CEILINGS.returns * 100 ? 'critical' : 'warning',
      `${Math.round(ret.value)}% من طلباتك رجعت. غالبًا القياسات أو الصور مو مطابقة — دقّقي وصف القطع الأكتر رجوعًا.`,
    );
  }

  const quality = byKey.get('productQuality');
  if (
    quality?.score !== null &&
    quality?.score !== undefined &&
    quality.score < 70 &&
    facts.productHealthMean !== null
  ) {
    push(
      'LISTING_QUALITY',
      'productQuality',
      'opportunity',
      'صفحات منتجاتك ناقصها صور أو معلومات. افتحي «ذكاء المنتجات» وشوفي القطع الأقل صحّة.',
    );
  }

  const sat = byKey.get('satisfaction');
  if (sat?.value !== null && sat?.value !== undefined && sat.value < 4.2 && facts.reviewCount >= 3) {
    push(
      'RATING_LOW',
      'satisfaction',
      'warning',
      `تقييمك ${sat.value.toFixed(1)} من ٥. اقري آخر التقييمات — عادة بيكون في سبب واحد بيتكرر.`,
    );
  }

  return out.sort((a, b) => b.gainPoints - a.gainPoints);
}
