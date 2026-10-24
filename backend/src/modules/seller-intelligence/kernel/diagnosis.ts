/**
 * Why a listing stopped selling.
 *
 * `product-health.ts` next door answers "how good is this listing" — a
 * standing judgement against its peers. This answers a different and much more
 * useful question, the one a seller actually asks: *it was selling and now it
 * is not, what changed?*
 *
 * The distinction matters because the two have different remedies. A listing
 * that was always weak needs better photographs; a listing that fell needs
 * whatever changed reversed, and telling a seller to improve her photographs
 * when a competitor undercut her by a third is advice that costs her a week.
 *
 * **The engine names one cause at a time.** Sales fall for a reason, and a
 * screen listing six possible reasons is a screen that has not diagnosed
 * anything. Where the evidence supports several, the strongest is returned and
 * the rest are offered as context.
 *
 * **And it refuses to guess.** A listing with too little traffic in either
 * window produces `insufficient_evidence`, which is a real answer — far better
 * than inventing a cause from four views.
 */

/** One window's worth of a listing's trade. */
export interface Period {
  views: number;
  orders: number;
  /** Median price it was listed at, in the platform's own unit. */
  price: number;
  /** Live offers on the product across all boutiques. */
  liveOffers: number;
  /** Units on her own shelf. */
  stock: number;
  /** The cheapest live price any boutique offered, hers included. */
  bestMarketPrice: number;
  /** Reviews received, and their mean. */
  reviews: number;
  rating: number;
  /** Days the window covers. */
  days: number;
}

export interface DiagnosisFacts {
  recent: Period;
  previous: Period;
  /**
   * Whether her shelf is empty right now.
   *
   * A flag rather than a duration, deliberately. Ohara does not journal stock
   * changes, so "it was empty for eleven days" is a number nobody can compute
   * — and a fabricated one would read as precise on a screen a seller acts on.
   * The advice is the same either way: restock. What she needs to know is that
   * the listing was selling and now has nothing to sell.
   */
  outOfStockNow: boolean;
  /** Whether the whole category moved the same way. */
  categoryOrdersChangePercent: number | null;
}

export type DiagnosisCode =
  | 'insufficient_evidence'
  | 'not_declining'
  | 'out_of_stock'
  | 'undercut'
  | 'lost_visibility'
  | 'conversion_fell'
  | 'category_cooled'
  | 'rating_damage';

export interface Diagnosis {
  code: DiagnosisCode;
  /** What happened, in Arabic. */
  ar: string;
  /** What to do about *this* cause. */
  actionAr: string;
  /** The figures the claim rests on. */
  evidence: Record<string, number | null>;
  /** Other things that also moved, for context. Never presented as causes. */
  alsoAr: string[];
}

/** Below this, the windows are not comparable and nothing is diagnosed. */
const MIN_VIEWS = 30;

/** A fall smaller than this is noise, not a decline. */
const MATERIAL_DROP = 0.25;

const pct = (value: number) => `${Math.round(Math.abs(value) * 100)}%`;

const change = (now: number, before: number): number | null => {
  if (before <= 0) return null;
  return (now - before) / before;
};

/** Per-day, so windows of different lengths compare. */
const rate = (count: number, days: number) => (days > 0 ? count / days : 0);

export function diagnose(facts: DiagnosisFacts): Diagnosis {
  const { recent, previous } = facts;

  const ordersNow = rate(recent.orders, recent.days);
  const ordersBefore = rate(previous.orders, previous.days);
  const viewsNow = rate(recent.views, recent.days);
  const viewsBefore = rate(previous.views, previous.days);

  const nothing = (code: DiagnosisCode, ar: string, actionAr: string) => ({
    code,
    ar,
    actionAr,
    evidence: {
      orders_now: recent.orders,
      orders_before: previous.orders,
      views_now: recent.views,
      views_before: previous.views,
    },
    alsoAr: [],
  });

  if (recent.views + previous.views < MIN_VIEWS) {
    return nothing(
      'insufficient_evidence',
      'لا توجد مشاهدات كافية للحكم على اتجاه المبيعات',
      'اتركي القطعة تجمع مشاهدات، أو ادعميها بإعلان قصير قبل الحكم عليها',
    );
  }

  const ordersChange = change(ordersNow, ordersBefore);
  if (ordersChange === null || ordersChange > -MATERIAL_DROP) {
    return nothing(
      'not_declining',
      'المبيعات لم تنخفض انخفاضاً يُذكر',
      'لا إجراء مطلوب',
    );
  }

  // Context that is true regardless of which cause wins.
  const also: string[] = [];
  const viewsChange = change(viewsNow, viewsBefore);
  const conversionNow = recent.views > 0 ? recent.orders / recent.views : 0;
  const conversionBefore =
    previous.views > 0 ? previous.orders / previous.views : 0;
  const conversionChange = change(conversionNow, conversionBefore);

  const evidence = {
    orders_now: recent.orders,
    orders_before: previous.orders,
    orders_change: ordersChange,
    views_change: viewsChange,
    conversion_now: conversionNow,
    conversion_before: conversionBefore,
    out_of_stock_now: facts.outOfStockNow ? 1 : 0,
    price_now: recent.price,
    best_market_price: recent.bestMarketPrice,
  };

  const build = (
    code: DiagnosisCode,
    ar: string,
    actionAr: string,
  ): Diagnosis => ({ code, ar, actionAr, evidence, alsoAr: also });

  // ── 1. She could not sell it because it was not there.
  //
  // Checked first because it dominates everything else: no amount of price or
  // visibility analysis matters for days the shelf was empty, and it is the
  // one cause with a remedy the seller controls completely.
  if (facts.outOfStockNow) {
    return build(
      'out_of_stock',
      'نفد المخزون — القطعة كانت تبيع ولم يعد فيها ما يُباع',
      'أعيدي التوريد — لا شيء آخر في هذه القائمة يهمّ ما دامت الرفوف فارغة',
    );
  }

  // ── 2. Somebody undercut her. The most common real cause, and the one
  //      sellers most often misdiagnose as a photography problem.
  if (
    recent.bestMarketPrice > 0 &&
    recent.price > recent.bestMarketPrice * 1.15 &&
    recent.liveOffers > 1
  ) {
    const gap = (recent.price - recent.bestMarketPrice) / recent.price;
    return build(
      'undercut',
      `سعرك أعلى بـ${pct(gap)} من أرخص عرض لنفس القطعة (${Math.round(recent.bestMarketPrice).toLocaleString('en-US')})`,
      'راجعي السعر، أو اذكري في الوصف ما يبرّر الفرق — الشحن الأسرع، الضمان، التغليف',
    );
  }

  // ── 3. The season, not the listing.
  //
  // Checked before the visibility and conversion branches, and that ordering
  // is a correction rather than a preference. Orders are views times
  // conversion, so a fall in orders *always* shows up as a fall in one of
  // them — which means a late "the category cooled" branch can never be
  // reached, however true it is. When the category moved enough to account
  // for most of her fall, that is the cause, and the mechanics of how it
  // reached her are context.
  if (
    facts.categoryOrdersChangePercent !== null &&
    facts.categoryOrdersChangePercent < -0.2 &&
    // The category explains most of it.
    facts.categoryOrdersChangePercent <= ordersChange * 0.6
  ) {
    if (viewsChange !== null && viewsChange < -MATERIAL_DROP) {
      also.push(`المشاهدات انخفضت ${pct(viewsChange)} — كما انخفضت للفئة كلها`);
    }
    return build(
      'category_cooled',
      `الفئة كلها انخفضت ${pct(facts.categoryOrdersChangePercent)} — الانخفاض ليس خاصاً بقطعتك`,
      'لا تخفّضي السعر بلا داعٍ — راجعي الموسم واستعدّي للفئة الصاعدة التالية',
    );
  }

  // ── 4. Her reviews turned. Checked before the two mechanical causes below,
  //      because a fallen rating explains a fallen conversion rather than
  //      being a separate fact beside it.
  if (
    conversionChange !== null &&
    conversionChange < -MATERIAL_DROP &&
    recent.rating > 0 &&
    recent.rating < 3.8 &&
    recent.reviews >= 3
  ) {
    return build(
      'rating_damage',
      `نسبة الشراء انخفضت ${pct(conversionChange)}، والتقييم الآن ${recent.rating.toFixed(1)} من ${recent.reviews} مراجعة`,
      'اقرئي المراجعات السلبية — عالجي ما تشكو منه، وردّي عليها علناً',
    );
  }

  // ── 5. Fewer women saw it, or fewer of those who saw it bought.
  //
  // Both can fall at once, and when they do the engine names the larger and
  // offers the other as context. Naming both would be two diagnoses, which is
  // the thing this file exists not to do; naming the smaller would send her
  // to fix the wrong half.
  const viewsFell = viewsChange !== null && viewsChange < -MATERIAL_DROP;
  const conversionFell =
    conversionChange !== null && conversionChange < -MATERIAL_DROP;

  // A category that also cooled — but not enough to be the cause — is still
  // worth knowing: it tells her how much of her fall she can actually act on.
  // Context, never a second diagnosis.
  if (
    facts.categoryOrdersChangePercent !== null &&
    facts.categoryOrdersChangePercent < -0.2
  ) {
    also.push(
      `الفئة كلها انخفضت ${pct(facts.categoryOrdersChangePercent)} — جزء من الانخفاض موسمي`,
    );
  }

  if (viewsFell || conversionFell) {
    const visibilityWorse =
      viewsFell &&
      (!conversionFell || Math.abs(viewsChange!) >= Math.abs(conversionChange!));

    if (visibilityWorse) {
      if (conversionFell) {
        also.push(`ونسبة الشراء انخفضت ${pct(conversionChange!)} أيضاً`);
      }
      return build(
        'lost_visibility',
        `المشاهدات انخفضت ${pct(viewsChange!)} — عدد أقلّ يرى القطعة`,
        'حدّثي العنوان والصور، أو جرّبي إعلاناً — القطعة تحتاج أن تُرى أولاً',
      );
    }

    if (viewsFell) {
      also.push(`والمشاهدات انخفضت ${pct(viewsChange!)} أيضاً`);
    }
    return build(
      'conversion_fell',
      `العدد نفسه يشاهدها، لكن نسبة من يشترين انخفضت ${pct(conversionChange!)}`,
      'قارني صفحتك بأقرب منافسة: الصور، المقاسات، تفاصيل القماش، سياسة الإرجاع',
    );
  }

  return build(
    'conversion_fell',
    `المبيعات انخفضت ${pct(ordersChange)} دون سبب واحد واضح`,
    'راجعي الصور والسعر والمخزون معاً — لم تتغيّر إشارة واحدة بما يكفي لتفسير الانخفاض وحدها',
  );
}
