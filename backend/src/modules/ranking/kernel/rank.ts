/**
 * What a listing is worth showing, and why.
 *
 * The rule this file exists to enforce is that ordering is a *commercial*
 * judgement made from evidence, not a popularity contest and not the order the
 * database happened to return. Everything below is a ratio the marketplace can
 * defend to a seller who asks why her dress is on page three.
 *
 * Three corrections do most of the work, and each of them is a mistake almost
 * every first ranking makes:
 *
 * **Conversion, not orders.** Ranking on lifetime orders freezes the page: the
 * listing that sold well two years ago outranks the one selling well today,
 * for ever, and nothing new can ever climb. What matters is how often the
 * women who *saw* it bought it.
 *
 * **Ratings are smoothed towards the middle.** A single five-star review is
 * not evidence that a listing is better than one carrying four-point-six from
 * three hundred. Left uncorrected this is the single easiest thing in a
 * marketplace to game — one review from one friend puts a listing at the top —
 * and the correction costs nothing.
 *
 * **Views are a weak signal on purpose.** A seller can generate views. She
 * cannot generate purchases, favourites or ratings without customers, so those
 * carry the weight and views only ever serve as the denominator.
 */

/** What is known about one listing. */
export interface ListingFacts {
  views: number;
  orders: number;
  favourites: number;
  reviews: number;
  /** Mean rating, 1–5. Meaningless below a few reviews; smoothed below. */
  rating: number;

  /** Live offers a customer could buy from right now. */
  liveOffers: number;
  /** Units on the shelf across those offers. */
  stock: number;

  /** Days since the listing appeared. */
  ageDays: number;
  /** Days since it last sold. Null when it never has. */
  daysSinceLastOrder: number | null;

  /** Parcels of it that came back. The counterweight to raw sales. */
  refunds: number;
}

export interface RankComponent {
  key: string;
  /** 0–1, before weighting. */
  value: number;
  weight: number;
  /** Arabic, for the seller-facing explanation of her own position. */
  ar: string;
}

export interface RankResult {
  /** 0–100. */
  score: number;
  components: RankComponent[];
  /**
   * False when the listing has too little traffic for the ratios to mean
   * anything. Such listings are not buried — see `score` — but a caller
   * showing "why" should say the evidence is thin.
   */
  confident: boolean;
}

/**
 * The prior a rating is pulled towards, and how hard.
 *
 * `RATING_PRIOR_WEIGHT` is "how many imaginary average reviews every listing
 * starts with". At 10, a listing needs about ten real reviews before its own
 * mean dominates — which is roughly the point at which a mean stops being an
 * accident.
 */
export const RATING_PRIOR = 4.0;
export const RATING_PRIOR_WEIGHT = 10;

/** Traffic below which the ratios are not yet evidence. */
const CONFIDENCE_VIEWS = 50;

/** How the components add up. They sum to 1. */
export const RANK_WEIGHTS = {
  conversion: 0.3,
  quality: 0.22,
  desire: 0.15,
  demand: 0.15,
  availability: 0.1,
  freshness: 0.08,
} as const;

const clamp01 = (value: number) => Math.max(0, Math.min(1, value));

/**
 * A rating you can compare across listings.
 *
 * Bayesian shrinkage towards the catalogue's own middle. Five stars from one
 * review lands near the prior; five stars from three hundred lands near five.
 */
export function smoothedRating(rating: number, reviews: number): number {
  if (reviews <= 0) return RATING_PRIOR;
  return (
    (RATING_PRIOR * RATING_PRIOR_WEIGHT + rating * reviews) /
    (RATING_PRIOR_WEIGHT + reviews)
  );
}

export function scoreListing(facts: ListingFacts): RankResult {
  const components: RankComponent[] = [];

  const add = (
    key: keyof typeof RANK_WEIGHTS,
    value: number,
    ar: string,
  ) => {
    components.push({
      key,
      value: clamp01(value),
      weight: RANK_WEIGHTS[key],
      ar,
    });
  };

  // ── Conversion: of the women who saw it, how many bought.
  //
  // Refunds are subtracted from the numerator rather than ignored. A listing
  // that sells and comes back has not converted anybody; it has cost the
  // platform a delivery in each direction and a customer's afternoon.
  const netOrders = Math.max(0, facts.orders - facts.refunds);
  const conversion = facts.views > 0 ? netOrders / facts.views : 0;
  // 8% is an exceptional rate for a fashion listing; the scale tops out there
  // rather than at 100%, which nothing ever reaches.
  add(
    'conversion',
    conversion / 0.08,
    `${(conversion * 100).toFixed(1)}% ممّن شاهدنها اشترينها`,
  );

  // ── Quality: what buyers said, corrected for how many said it.
  const smoothed = smoothedRating(facts.rating, facts.reviews);
  add(
    'quality',
    (smoothed - 1) / 4,
    `تقييم ${smoothed.toFixed(2)} من ${facts.reviews} مراجعة`,
  );

  // ── Desire: saved without being bought. The clearest signal of intent a
  // listing gets from women who did not convert.
  const desire = facts.views > 0 ? facts.favourites / facts.views : 0;
  add('desire', desire / 0.15, `${facts.favourites} حفظت القطعة`);

  // ── Demand: is it selling *now*. This is what keeps the page from
  // freezing around whatever sold best in its first month.
  const demand =
    facts.daysSinceLastOrder === null
      ? 0
      : Math.exp(-facts.daysSinceLastOrder / 21);
  add(
    'demand',
    demand,
    facts.daysSinceLastOrder === null
      ? 'لم تُبَع بعد'
      : `آخر عملية بيع قبل ${facts.daysSinceLastOrder} يوماً`,
  );

  // ── Availability: a listing nobody can buy is worth nothing at the top of
  // a page, however good it is.
  const availability =
    facts.liveOffers === 0 || facts.stock <= 0
      ? 0
      : Math.min(1, 0.6 + Math.min(facts.liveOffers, 4) * 0.1);
  add(
    'availability',
    availability,
    facts.stock > 0
      ? `${facts.liveOffers} عرضاً متاحاً`
      : 'غير متوفّرة حالياً',
  );

  // ── Freshness: a small, decaying allowance so a new listing gets seen at
  // all. Without it nothing new can ever accumulate the traffic the other
  // components are computed from, and the catalogue ossifies.
  const freshness = Math.exp(-facts.ageDays / 30);
  add('freshness', freshness, `عُرضت قبل ${facts.ageDays} يوماً`);

  const score = components.reduce(
    (total, component) => total + component.value * component.weight,
    0,
  );

  return {
    score: Math.round(score * 100 * 10) / 10,
    components,
    confident: facts.views >= CONFIDENCE_VIEWS,
  };
}

// ── Sellers ──────────────────────────────────────────────────────────────────

/** What is known about one boutique, for ordering boutiques against each other. */
export interface SellerRankFacts {
  /** Parcels delivered in the window. */
  delivered: number;
  /** Of those, the ones she cancelled or that were refunded. */
  cancelled: number;
  refunded: number;

  /** Her mean review score and how many reviews it rests on. */
  rating: number;
  reviews: number;

  /** Listings a customer could buy right now. */
  liveListings: number;

  /** Median hours to answer a customer. Null when nobody has asked. */
  responseHours: number | null;

  /** Days since she last sold anything. Null when she never has. */
  daysSinceLastSale: number | null;
}

/**
 * How a boutique ranks against other boutiques.
 *
 * Reliability first, deliberately. A shop that sells a great deal and cancels
 * one order in five is worse for the marketplace than a quieter shop that
 * always delivers — the cancelled order costs a customer, and customers are
 * the scarce thing. Ordering boutiques by volume alone rewards exactly the
 * behaviour that loses them.
 */
export function scoreSeller(facts: SellerRankFacts): RankResult {
  const components: RankComponent[] = [];
  const add = (key: string, value: number, weight: number, ar: string) => {
    components.push({ key, value: clamp01(value), weight, ar });
  };

  const handled = Math.max(1, facts.delivered + facts.cancelled);
  const reliability = 1 - facts.cancelled / handled;
  add(
    'reliability',
    reliability,
    0.3,
    `${facts.cancelled} إلغاءً من ${handled} طلباً`,
  );

  const smoothed = smoothedRating(facts.rating, facts.reviews);
  add(
    'quality',
    (smoothed - 1) / 4,
    0.25,
    `تقييم ${smoothed.toFixed(2)} من ${facts.reviews} مراجعة`,
  );

  const keepRate =
    facts.delivered > 0
      ? 1 - Math.min(1, facts.refunded / facts.delivered)
      : 0.6;
  add('kept', keepRate, 0.15, `${facts.refunded} طرداً أُرجع`);

  // Answering matters, and not answering matters more. Six hours is good;
  // beyond two days a customer has already bought elsewhere.
  const responsiveness =
    facts.responseHours === null
      ? 0.5
      : clamp01(1 - (facts.responseHours - 6) / 42);
  add(
    'responsiveness',
    responsiveness,
    0.15,
    facts.responseHours === null
      ? 'لم تصلها أسئلة بعد'
      : `تجيب خلال ${facts.responseHours.toFixed(1)} ساعة`,
  );

  const active =
    facts.daysSinceLastSale === null
      ? 0
      : Math.exp(-facts.daysSinceLastSale / 30);
  add('activity', active, 0.1, `${facts.liveListings} قطعة معروضة`);

  const assortment = Math.min(1, facts.liveListings / 20);
  add('assortment', assortment, 0.05, `${facts.liveListings} قطعة معروضة`);

  const score = components.reduce(
    (total, component) => total + component.value * component.weight,
    0,
  );

  return {
    score: Math.round(score * 100 * 10) / 10,
    components,
    confident: facts.delivered >= 10,
  };
}
