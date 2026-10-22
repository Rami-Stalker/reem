/**
 * What happens to a garment after it is bought.
 *
 * Every other part of Reem stops at the delivery. This is the part that keeps
 * going: how a piece is cared for, whether it is actually being worn, and what
 * to do with it when it is not. The commercial argument for building it is
 * plain — a woman who wears what she owns trusts the next recommendation, and
 * a wardrobe with four dormant coats in it is a wardrobe that has stopped
 * buying — but the honest argument is simpler. Advising someone to sell
 * something is only credible from a system that also told her how to keep it.
 *
 * ── Why this refuses to be eager ─────────────────────────────────────────
 *
 * The failure mode of a feature like this is nagging: telling a woman her
 * winter coat is "dormant" in August, telling her to sell a dress she wore
 * last month, telling her anything at all about a piece she bought a week ago.
 * Each of those is individually small and collectively fatal, because the
 * moment the advice is wrong once it is ignored forever. So the thresholds
 * here are deliberately slow, the current season is an input, and a piece she
 * marked as a favourite is never put up for sale at any threshold.
 *
 * Pure — days are passed in, never read from a clock, so a reading can be
 * reproduced and argued with.
 */

/** Her wardrobe piece, reduced to what the life cycle reasons about. */
export interface ItemLife {
  slot: string;
  materials: readonly string[];
  /** `ALL` | `SUMMER` | `WINTER` | `TRANSITIONAL`. */
  seasons: readonly string[];
  wearCount: number;
  /** Null when she has never worn it. */
  daysSinceWorn: number | null;
  /** Null when we do not know when she got it. */
  daysOwned: number | null;
  purchasePriceSyp: number | null;
  isFavourite: boolean;
}

export type Rotation =
  /// Worn recently enough to count as in use.
  | 'ACTIVE'
  /// Drifting out of rotation.
  | 'SLOWING'
  /// Out of rotation.
  | 'DORMANT'
  /// Owned long enough to have been worn, and never was.
  | 'UNWORN';

export type Disposition =
  /// Leave her alone.
  | 'KEEP'
  /// She likes it; the problem is she has run out of ways to wear it.
  | 'RESTYLE'
  /// Worth enough that selling it is worth the trouble.
  | 'RESELL'
  /// Not worth the trouble, and someone else would use it.
  | 'DONATE';

export interface CareNote {
  code: string;
  text: string;
}

export interface LifeReading {
  rotation: Rotation;
  /** Purchase price over wears. Null when either is unknown. */
  costPerWear: number | null;
  disposition: Disposition;
  /** Why, in her language. Empty for KEEP — silence is the correct advice. */
  reason: string;
  care: CareNote[];
  /** 0-100. Low when we are reasoning from an unknown purchase date. */
  confidence: number;
}

// ── Thresholds ──────────────────────────────────────────────────────────

/** Out of rotation. A full season and then some, on purpose. */
export const DORMANT_DAYS = 120;

/** Drifting. Long enough that a nudge is useful and not nagging. */
export const SLOWING_DAYS = 60;

/**
 * A piece younger than this is new, not unworn.
 *
 * Without it the feature greets a woman who just bought a dress with advice
 * about selling it, which is the fastest way to make her stop reading.
 */
export const NEW_GRACE_DAYS = 45;

/** Never worn *and* owned this long is the strongest resale signal there is. */
export const UNWORN_RESALE_DAYS = 180;

/**
 * Below this, selling is not worth the photographs.
 *
 * Roughly a quarter of the platform's median price. A piece under it goes to
 * DONATE instead — which is not a softer version of RESELL, it is the correct
 * answer for something whose resale value is less than the effort of listing.
 */
export const RESALE_FLOOR_SYP = 800;

/** Enough wears to say she likes it, whatever the calendar says. */
export const LOVED_WEAR_COUNT = 8;

/** What a piece is worth used, by condition. */
export const CONDITION_RETENTION: Record<string, number> = {
  NEW_WITH_TAGS: 0.7,
  EXCELLENT: 0.55,
  GOOD: 0.4,
  FAIR: 0.25,
};

const round = (n: number): number => Math.round(n * 100) / 100;

// ── Care ────────────────────────────────────────────────────────────────

/**
 * Fabric care, keyed by the same material vocabulary the stylist uses.
 *
 * Written as one woman telling another, not as a laundry symbol. These are the
 * notes that make the rest of the advice credible.
 */
const MATERIAL_CARE: Record<string, CareNote> = {
  حرير: {
    code: 'SILK',
    text: 'يحتاج الحرير غسيلاً بارداً باليد وتجفيفاً في الظل — الشمس تبهت لونه.',
  },
  شيفون: {
    code: 'CHIFFON',
    text: 'الشيفون يعلق بسهولة؛ خزّنيه معلّقاً بعيداً عن القطع ذات السحّابات.',
  },
  ساتان: {
    code: 'SATIN',
    text: 'الساتان يُظهر كل أثر؛ اكويه من الداخل وعلى حرارة منخفضة.',
  },
  دانتيل: {
    code: 'LACE',
    text: 'الدانتيل يتمزّق في الغسالة؛ ضعيه في كيس غسيل أو اغسليه باليد.',
  },
  مخمل: {
    code: 'VELVET',
    text: 'لا يُكوى المخمل مباشرة؛ علّقيه في الحمّام مع البخار فيستعيد شكله.',
  },
  صوف: {
    code: 'WOOL',
    text: 'الصوف يتمدّد إن عُلّق؛ اطويه، وهوّيه بعد كل لبسة بدل غسله.',
  },
  كشمير: {
    code: 'CASHMERE',
    text: 'الكشمير يُطوى ولا يُعلّق، ومعه قليل من الخزامى أو خشب الأرز في الخزانة صيفاً.',
  },
  جلد: {
    code: 'LEATHER',
    text: 'الجلد يجفّ ويتشقّق؛ رطّبيه كل موسم وأبعديه عن الشمس المباشرة.',
  },
  جينز: {
    code: 'DENIM',
    text: 'يحتفظ الجينز بلونه أطول إن غسلتِه مقلوباً وعلى فترات متباعدة.',
  },
  لينن: {
    code: 'LINEN',
    text: 'الكتّان يتجعّد بطبعه؛ علّقيه وهو رطب قليلاً فيستوي وحده.',
  },
  قطن: {
    code: 'COTTON',
    text: 'القطن ينكمش في الماء الساخن؛ اغسليه بارداً فيبقى على مقاسه.',
  },
  فضة: {
    code: 'SILVER',
    text: 'الفضة تسودّ مع الرطوبة؛ خزّنيها في كيس مغلق وامسحيها بقطعة ناعمة.',
  },
};

/** Care that comes from the kind of thing it is, not the fabric. */
const SLOT_CARE: Record<string, CareNote> = {
  SHOES: {
    code: 'SHOES_ROTATE',
    text: 'اتركي الحذاء يرتاح يوماً بين لبسة وأخرى، فيدوم أطول بكثير.',
  },
  BAG: {
    code: 'BAG_STORE',
    text: 'احشي الحقيبة بورق ناعم وهي في الخزانة كي تحافظ على شكلها.',
  },
  PERFUME: {
    code: 'PERFUME_LIGHT',
    text: 'يفسد العطر بالضوء والحرارة؛ احفظيه في مكان مظلم وبارد لا أمام المرآة.',
  },
};

export function careFor(item: ItemLife): CareNote[] {
  const notes: CareNote[] = [];
  for (const material of item.materials) {
    const note = MATERIAL_CARE[material];
    if (note) notes.push(note);
  }
  const slotNote = SLOT_CARE[item.slot];
  if (slotNote) notes.push(slotNote);
  // Two notes is advice; five is a manual nobody reads.
  return notes.slice(0, 2);
}

// ── Rotation ────────────────────────────────────────────────────────────

/**
 * Whether a piece is out of season rather than out of favour.
 *
 * A wool coat untouched since March is not dormant in August, it is a coat.
 * Judging it now would be wrong, and being wrong once costs the feature every
 * subsequent piece of advice.
 */
function outOfSeason(item: ItemLife, season: string | null): boolean {
  if (!season) return false;
  if (!item.seasons.length) return false;
  if (item.seasons.includes('ALL')) return false;
  return !item.seasons.includes(season);
}

export function readRotation(
  item: ItemLife,
  season: string | null = null,
): Rotation {
  if (outOfSeason(item, season)) return 'ACTIVE';

  if (item.wearCount === 0) {
    // New is not unworn.
    if (item.daysOwned === null || item.daysOwned < NEW_GRACE_DAYS) {
      return 'ACTIVE';
    }
    return 'UNWORN';
  }

  const idle = item.daysSinceWorn;
  if (idle === null) return 'ACTIVE';
  if (idle >= DORMANT_DAYS) return 'DORMANT';
  if (idle >= SLOWING_DAYS) return 'SLOWING';
  return 'ACTIVE';
}

// ── The reading ─────────────────────────────────────────────────────────

export function readLife(
  item: ItemLife,
  season: string | null = null,
): LifeReading {
  const rotation = readRotation(item, season);
  const care = careFor(item);
  const costPerWear =
    item.purchasePriceSyp !== null && item.wearCount > 0
      ? round(item.purchasePriceSyp / item.wearCount)
      : null;

  // How much of this reading rests on something we actually know.
  let confidence = 60;
  if (item.daysOwned !== null) confidence += 20;
  if (item.purchasePriceSyp !== null) confidence += 10;
  if (item.wearCount > 0 || item.daysSinceWorn !== null) confidence += 10;

  let disposition: Disposition = 'KEEP';
  let reason = '';

  if (rotation === 'ACTIVE') {
    // Silence is the correct advice.
  } else if (rotation === 'SLOWING') {
    disposition = 'RESTYLE';
    reason = 'بقيت في الخزانة فترة — هناك طريقة أخرى لارتدائها.';
  } else if (item.isFavourite) {
    // She said she loves it. That ends the conversation about selling it, and
    // no threshold outranks her own answer.
    disposition = 'RESTYLE';
    reason = 'من قطعكِ المفضّلة لكنكِ لم ترتديها منذ مدة — جرّبيها بتنسيق جديد.';
  } else if (item.wearCount >= LOVED_WEAR_COUNT) {
    // Worn a lot and then stopped: she likes it and has run out of ideas.
    disposition = 'RESTYLE';
    reason = 'ارتديتِها كثيراً ثم توقّفتِ — غالباً تحتاج تنسيقاً جديداً لا استبدالاً.';
  } else if (
    rotation === 'UNWORN' &&
    item.daysOwned !== null &&
    item.daysOwned < UNWORN_RESALE_DAYS
  ) {
    // Unworn but not yet unwanted. Six months is the point at which "I will
    // wear it eventually" stops being true.
    disposition = 'RESTYLE';
    reason = 'لم ترتديها بعد — انظري ما يليق بها قبل أن تستغني عنها.';
  } else {
    const worthSelling =
      item.purchasePriceSyp !== null &&
      item.purchasePriceSyp >= RESALE_FLOOR_SYP;
    disposition = worthSelling ? 'RESELL' : 'DONATE';

    if (rotation === 'UNWORN') {
      reason = worthSelling
        ? 'لم ترتديها منذ اشتريتِها — تستحق أن تُعرض للبيع.'
        : 'لم ترتديها ولا مرة — قد تستفيد منها امرأة أخرى أكثر.';
    } else {
      reason = worthSelling
        ? 'لم ترتديها منذ أشهر، وما زالت بحالة جيدة تسمح ببيعها.'
        : 'لم ترتديها منذ أشهر؛ التبرّع بها أسهل من بيعها.';
    }
  }

  return {
    rotation,
    costPerWear,
    disposition,
    reason,
    care,
    confidence: Math.min(100, confidence),
  };
}

/**
 * A fair asking price for a used piece.
 *
 * Retention by condition against what she paid. Returns null rather than a
 * guess when the original price is unknown — an invented price is worse than
 * an empty field, because she will believe it.
 */
export function suggestResalePrice(
  originalPriceSyp: number | null,
  condition: string,
): number | null {
  if (originalPriceSyp === null || originalPriceSyp <= 0) return null;
  const retention = CONDITION_RETENTION[condition];
  if (!retention) return null;
  // Rounded to the nearest 50 so it reads like a price, not a calculation.
  return Math.max(50, Math.round((originalPriceSyp * retention) / 50) * 50);
}
