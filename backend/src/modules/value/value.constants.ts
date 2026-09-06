import { ValueBenefitKind, ValuePillar } from '@prisma/client';

/**
 * Every tunable Reem Value has, and the whole earning table, in one file.
 *
 * These are **seeds**, not law. `ValuePolicy` is a row and the active one wins;
 * what is here is what a fresh installation starts with, and what
 * `value-policy.service.ts` writes as version 1. An administrator retuning the
 * programme edits rows, not this file.
 *
 * Two conventions hold throughout:
 *
 * 1. **A weight is what one contribution is worth**, stamped onto the event at
 *    write time and never repriced. Retroactively changing what somebody
 *    already earned is the fastest way to make a standing feel arbitrary.
 * 2. **A scale is what a strong contributor looks like.** A pillar reaches
 *    about 63% of its ceiling at its scale, so `CRAFT: 90` says "ninety points
 *    of helpful reviewing is a serious contributor here".
 */

// ── Pillars ─────────────────────────────────────────────────────────────

/**
 * How much each dimension counts.
 *
 * COMMERCE is the largest single weight — pretending money does not matter to a
 * shop would be dishonest — and it is still under a third of the total, and
 * separately clipped by `COMMERCE_CEILING_BPS`. The brief was "not spending
 * alone", and this pair of numbers is what makes that true rather than said.
 */
export const DEFAULT_PILLAR_WEIGHTS: Record<ValuePillar, number> = {
  [ValuePillar.COMMERCE]: 30,
  [ValuePillar.CRAFT]: 20,
  [ValuePillar.COMMUNITY]: 15,
  [ValuePillar.ADVOCACY]: 12,
  [ValuePillar.DISCOVERY]: 8,
  [ValuePillar.RELIABILITY]: 15,
};

/**
 * The contribution at which a pillar is about 63% full.
 *
 * COMMERCE's scale is the highest because its events are the easiest to
 * accumulate — every kept order writes one — and without a high scale money
 * would fill its pillar in a month and sit there.
 */
export const DEFAULT_PILLAR_SCALES: Record<ValuePillar, number> = {
  [ValuePillar.COMMERCE]: 260,
  [ValuePillar.CRAFT]: 90,
  [ValuePillar.COMMUNITY]: 110,
  [ValuePillar.ADVOCACY]: 70,
  [ValuePillar.DISCOVERY]: 55,
  [ValuePillar.RELIABILITY]: 60,
};

/**
 * The most positive weight one pillar may take from a single day.
 *
 * The blunt anti-farming instrument. Forty reviews written on a Tuesday count
 * as roughly three, and an afternoon of comment-spraying counts as an evening
 * of ordinary use. RELIABILITY has no cap because its positive events are
 * deliveries, which nobody can manufacture.
 */
export const DEFAULT_DAILY_PILLAR_CAPS: Record<ValuePillar, number> = {
  [ValuePillar.COMMERCE]: 40,
  [ValuePillar.CRAFT]: 24,
  [ValuePillar.COMMUNITY]: 18,
  [ValuePillar.ADVOCACY]: 30,
  [ValuePillar.DISCOVERY]: 20,
  [ValuePillar.RELIABILITY]: 999,
};

/** A contribution loses half its weight in a year. */
export const DEFAULT_HALF_LIFE_DAYS = 365;

/** Beyond three years a contribution is retired; decay has made it noise. */
export const DEFAULT_HORIZON_DAYS = 1095;

/**
 * The economic guarantee, in basis points of the 1000-point scale.
 *
 * At 2500, spending contributes at most 250. Add the reliability baseline a
 * quiet customer accrues for free (105) and a pure spender tops out at 355,
 * against a third rung at 420 — so **a woman who buys everything and
 * contributes nothing else cannot pass the second rung.** That sentence is the
 * entire design brief, and this constant is where it is enforced.
 *
 * Deliberately set *below* what COMMERCE's own pillar weight would allow
 * (30/100 of 1000 = 300). A ceiling equal to or above the weight share is
 * decorative — it never binds, and it silently stops being a guarantee the
 * moment somebody raises the weight. Set under the share, it is the
 * authoritative bound and the weight is free to move beneath it.
 */
export const DEFAULT_COMMERCE_CEILING_BPS = 2500;

/** Where RELIABILITY sits before she has any delivery history. */
export const DEFAULT_RELIABILITY_BASELINE = 70;

/** Confirmed events a pillar needs before it reports a score at all. */
export const DEFAULT_MIN_EVIDENCE_PER_PILLAR = 2;

// ── The earning table ───────────────────────────────────────────────────

/**
 * How a contribution matures.
 *
 * `immediate` counts on write — used only where the act and the evidence are
 * the same thing, such as a parcel refused at the door.
 * `deferred` writes PENDING and waits for `ValueMaturityService` to find the
 * evidence. Everything a person could manufacture is deferred.
 */
export type MaturityMode = 'immediate' | 'deferred';

export interface EarningRule {
  code: string;
  pillar: ValuePillar;
  weight: number;
  maturity: MaturityMode;
  /** What has to become true for a deferred rule to confirm. Prose, for the
   *  admin screen and for whoever maintains the sweeper. */
  evidenceAr: string;
  labelAr: string;
}

/**
 * Every way standing can move.
 *
 * Read this table as the answer to "what does Reem actually value?". Note what
 * is absent: nothing here pays for opening the app, for a streak, for a daily
 * check-in, or for any act whose only cost is attention. A standing that rises
 * because she scrolled is a engagement metric wearing a status badge.
 */
export const EARNING_RULES: readonly EarningRule[] = [
  // ── Commerce ──────────────────────────────────────────────────────────
  {
    code: 'order_kept',
    pillar: ValuePillar.COMMERCE,
    weight: 8,
    maturity: 'deferred',
    labelAr: 'طلب وصل وانتهت مدة إرجاعه',
    evidenceAr: 'الطلب تسلّم، وانتهت مدة الاسترجاع بدون إرجاع.',
  },
  {
    code: 'order_kept_new_seller',
    pillar: ValuePillar.COMMERCE,
    weight: 4,
    maturity: 'deferred',
    labelAr: 'شراء من متجر جديد عليكِ',
    evidenceAr: 'أول طلب محتفظ فيه من هالمتجر — الاتّساع بيتحسب، مو بس المبلغ.',
  },

  // ── Craft ─────────────────────────────────────────────────────────────
  {
    code: 'review_helpful',
    pillar: ValuePillar.CRAFT,
    weight: 12,
    maturity: 'deferred',
    labelAr: 'تقييم لقته غيرك مفيد',
    evidenceAr: 'تقييم عن شراء موثّق، منشور، وصله ٣ إعجابات «مفيد» على الأقل.',
  },
  {
    code: 'review_written',
    pillar: ValuePillar.CRAFT,
    weight: 3,
    maturity: 'deferred',
    labelAr: 'تقييم عن شراء موثّق',
    evidenceAr: 'التقييم اننشر بعد المراجعة، وعن طلب فعلي.',
  },
  {
    code: 'seller_review_written',
    pillar: ValuePillar.CRAFT,
    weight: 3,
    maturity: 'deferred',
    labelAr: 'تقييم متجر',
    evidenceAr: 'تقييم متجر عن تجربة شراء موثّقة، واننشر.',
  },

  // ── Community ─────────────────────────────────────────────────────────
  {
    code: 'post_engaged',
    pillar: ValuePillar.COMMUNITY,
    weight: 6,
    maturity: 'deferred',
    labelAr: 'منشور تفاعلت معه البنات',
    evidenceAr: 'منشورك وصله ٥ إعجابات أو حفظات على الأقل.',
  },
  {
    code: 'comment_engaged',
    pillar: ValuePillar.COMMUNITY,
    weight: 2,
    maturity: 'deferred',
    labelAr: 'تعليق مفيد',
    evidenceAr: 'تعليق على منشور نشط، وبقي منشور بعد المراجعة.',
  },
  {
    code: 'look_shared',
    pillar: ValuePillar.COMMUNITY,
    weight: 4,
    maturity: 'deferred',
    labelAr: 'إطلالة شاركتيها',
    evidenceAr: 'إطلالة من خزانتك انحطت بمنشور تفاعلت معه البنات.',
  },

  // ── Advocacy ──────────────────────────────────────────────────────────
  {
    code: 'referral_kept',
    pillar: ValuePillar.ADVOCACY,
    weight: 25,
    maturity: 'deferred',
    labelAr: 'صديقة دعوتيها وصارت زبونة',
    evidenceAr:
      'الشخص يلي دعوتيه عمل طلب وتسلّمه وما رجّعه، وما انرفعت عليه أي شبهة.',
  },
  {
    code: 'referral_seller_active',
    pillar: ValuePillar.ADVOCACY,
    weight: 35,
    maturity: 'deferred',
    labelAr: 'متجر دللتي عليه وصار يبيع',
    evidenceAr: 'المتجر يلي دعوتيه انوثّق وباع أول طلب انتسلّم.',
  },

  // ── Discovery ─────────────────────────────────────────────────────────
  {
    code: 'early_product',
    pillar: ValuePillar.DISCOVERY,
    weight: 10,
    maturity: 'deferred',
    labelAr: 'منتج اكتشفتيه قبل الناس',
    evidenceAr:
      'حبّيتي أو اشتريتي منتج وهو لسا تحت ٥ طلبات، وبعدين صار فوق ٥٠.',
  },
  {
    code: 'early_seller',
    pillar: ValuePillar.DISCOVERY,
    weight: 14,
    maturity: 'deferred',
    labelAr: 'متجر اكتشفتيه بدايته',
    evidenceAr: 'اشتريتي من متجر بأول ١٠ طلبات إلو، وبعدين وصل ١٠٠ طلب.',
  },

  // ── Reliability ───────────────────────────────────────────────────────
  //
  // The only pillar with negative rules, and the only one that confirms
  // immediately: a courier turned away at the door is not a claim awaiting
  // evidence, it is the evidence.
  {
    code: 'parcel_delivered',
    pillar: ValuePillar.RELIABILITY,
    weight: 4,
    maturity: 'immediate',
    labelAr: 'طلب استلمتيه بسلام',
    evidenceAr: 'الطلب وصل واستلمتيه.',
  },
  {
    code: 'parcel_refused',
    pillar: ValuePillar.RELIABILITY,
    weight: -22,
    maturity: 'immediate',
    labelAr: 'طلب رفضتيه عالباب',
    evidenceAr: 'المندوب وصل والطلب انرفض.',
  },
  {
    code: 'parcel_failed',
    pillar: ValuePillar.RELIABILITY,
    weight: -8,
    maturity: 'immediate',
    labelAr: 'محاولة توصيل ما نجحت',
    evidenceAr: 'المندوب ما قدر يوصّل — أخف من الرفض، لأنو مكالمة ضايعة مو قرار.',
  },
  {
    code: 'dispute_lost',
    pillar: ValuePillar.RELIABILITY,
    weight: -18,
    maturity: 'deferred',
    labelAr: 'نزاع انحسم ضدّك',
    evidenceAr: 'نزاع فتحتيه أو انفتح عليكِ وانحسم لغير صالحك.',
  },
];

export const EARNING_RULE_BY_CODE = new Map(
  EARNING_RULES.map((rule) => [rule.code, rule]),
);

export const DEFAULT_EVENT_WEIGHTS: Record<string, number> = Object.fromEntries(
  EARNING_RULES.map((rule) => [rule.code, rule.weight]),
);

// ── Maturity thresholds ─────────────────────────────────────────────────

/**
 * What "the evidence matured" means, numerically.
 *
 * Separate from the weights because these are not economics — they are the
 * definition of the words in the earning table, and moving one changes what a
 * rule *means* rather than what it is worth.
 */
export const MATURITY = {
  /** Helpful votes a review needs before it counts as helpful. */
  reviewHelpfulVotes: 3,
  /** Likes plus saves a post needs before it counts as engaged with. */
  postEngagement: 5,
  /** A referral's fraud score must be at or under this. */
  referralMaxFraudScore: 0.4,
  /** Orders a product must be under when she finds it. */
  discoveryEarlyOrders: 5,
  /** Orders it must later exceed for the find to have been proven right. */
  discoveryProvenOrders: 50,
  /** Orders a seller must be under when she first buys. */
  discoverySellerEarlyOrders: 10,
  /** Orders the seller must later exceed. */
  discoverySellerProvenOrders: 100,
} as const;

// ── The ladder ──────────────────────────────────────────────────────────

/**
 * The rungs a fresh installation starts with.
 *
 * The names are deliberately not metals. Bronze/Silver/Gold is the visual
 * language of a spending ladder, and the whole point here is that this is not
 * one. These are stages of a relationship, and they read as such in Arabic.
 *
 * Note the third rung at 420 against a spending ceiling of 350: the ladder and
 * the ceiling are designed against each other, and `spendingAloneCeiling`
 * checks it.
 */
export const DEFAULT_TIERS = [
  {
    key: 'new',
    name: 'New',
    nameAr: 'جديدة',
    minScore: 0,
    rank: 0,
    demotionBufferScore: 0,
    holdDays: 0,
    presentation: { tone: 'neutral', blurbAr: 'أهلًا فيكِ — مكانتك عم تبلّش.' },
  },
  {
    key: 'known',
    name: 'Known',
    nameAr: 'معروفة',
    minScore: 180,
    rank: 1,
    demotionBufferScore: 30,
    holdDays: 60,
    presentation: { tone: 'rose', blurbAr: 'صرنا نعرفك — وصار إلك وزن عنا.' },
  },
  {
    key: 'trusted',
    name: 'Trusted',
    nameAr: 'موثوقة',
    minScore: 420,
    rank: 2,
    demotionBufferScore: 40,
    holdDays: 90,
    presentation: { tone: 'mauve', blurbAr: 'رأيك بيفرق، وبيوصل قبل غيرك.' },
  },
  {
    key: 'insider',
    name: 'Insider',
    nameAr: 'من الدائرة',
    minScore: 640,
    rank: 3,
    demotionBufferScore: 50,
    holdDays: 120,
    presentation: { tone: 'champagne', blurbAr: 'بتشوفي الجديد قبل ما ينزل.' },
  },
  {
    key: 'circle',
    name: 'Inner Circle',
    nameAr: 'الدائرة الأولى',
    minScore: 820,
    rank: 4,
    demotionBufferScore: 60,
    holdDays: 180,
    presentation: { tone: 'gold', blurbAr: 'إنتِ من يلي بيبنوا ريم.' },
  },
] as const;

// ── The benefits ────────────────────────────────────────────────────────

/**
 * What standing opens, as a fresh installation ships it.
 *
 * Every entry carries its own economics — a quota, a budget, or a unit cost of
 * zero where the benefit genuinely costs nothing to give. Priority in a support
 * queue is free; a gift is not, and the difference is a column rather than a
 * hope.
 */
export const DEFAULT_BENEFITS = [
  {
    key: 'early-access-48',
    kind: ValueBenefitKind.EARLY_ACCESS,
    title: 'Early access',
    titleAr: 'وصول مبكر',
    descriptionAr: 'بتشوفي النزولات الجديدة قبل ٤٨ ساعة من الكل.',
    minTierKey: 'trusted',
    config: { hours: 48 },
    perUserQuota: null,
    quotaPeriodDays: null,
    totalBudget: null,
    unitCostSyp: 0,
    grantTtlDays: null,
  },
  {
    key: 'priority-support',
    kind: ValueBenefitKind.PRIORITY_SUPPORT,
    title: 'Priority support',
    titleAr: 'أولوية بالدعم',
    descriptionAr: 'تذاكرك بتنشتغل قبل غيرها.',
    minTierKey: 'known',
    config: { queueBoost: 2 },
    perUserQuota: null,
    quotaPeriodDays: null,
    totalBudget: null,
    unitCostSyp: 0,
    grantTtlDays: null,
  },
  {
    key: 'extended-returns',
    kind: ValueBenefitKind.ENHANCED_RETURNS,
    title: 'Longer returns',
    titleAr: 'مدة إرجاع أطول',
    descriptionAr: 'سبع أيام زيادة على مدة الإرجاع العادية.',
    minTierKey: 'trusted',
    config: { extraDays: 7 },
    perUserQuota: null,
    quotaPeriodDays: null,
    totalBudget: null,
    unitCostSyp: 0,
    grantTtlDays: null,
  },
  {
    key: 'priority-delivery',
    kind: ValueBenefitKind.PRIORITY_DELIVERY,
    title: 'Priority dispatch',
    titleAr: 'أولوية بالشحن',
    descriptionAr: 'طلباتك بتتجهّز قبل غيرها عند المتجر.',
    minTierKey: 'insider',
    config: { dispatchBoost: 1 },
    perUserQuota: null,
    quotaPeriodDays: null,
    totalBudget: null,
    unitCostSyp: 0,
    grantTtlDays: null,
  },
  {
    key: 'exclusive-drops',
    kind: ValueBenefitKind.EXCLUSIVE_PRODUCT,
    title: 'Exclusive pieces',
    titleAr: 'قطع خاصة',
    descriptionAr: 'قطع ما بتنعرض إلا لمكانتك.',
    minTierKey: 'insider',
    config: { productIds: [] },
    perUserQuota: null,
    quotaPeriodDays: null,
    totalBudget: null,
    unitCostSyp: 0,
    grantTtlDays: null,
  },
  {
    key: 'seasonal-gift',
    kind: ValueBenefitKind.GIFT,
    title: 'Seasonal gift',
    titleAr: 'هدية الموسم',
    descriptionAr: 'هدية منّا، مرة بالموسم.',
    minTierKey: 'circle',
    config: {},
    // The only benefit here with real money behind it, so it is the only one
    // with both a quota and a budget.
    perUserQuota: 1,
    quotaPeriodDays: 120,
    totalBudget: 200,
    unitCostSyp: 75_000,
    grantTtlDays: 45,
  },
  {
    key: 'personal-offer',
    kind: ValueBenefitKind.PERSONALISED_OFFER,
    title: 'An offer built for you',
    titleAr: 'عرض على ذوقك',
    descriptionAr: 'عرض مبني على خزانتك وذوقك، مو على شي عام.',
    minTierKey: 'trusted',
    config: { source: 'closet_gaps' },
    perUserQuota: 2,
    quotaPeriodDays: 30,
    totalBudget: null,
    unitCostSyp: 25_000,
    grantTtlDays: 14,
  },
] as const;
