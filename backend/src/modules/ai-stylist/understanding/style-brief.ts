import {
  ModestyLevel,
  OutfitSlot,
  Prisma,
  StylePersona,
} from '@prisma/client';
import {
  COLOURS,
  MATERIALS,
  OCCASIONS,
  colourEntry,
  occasionEntry,
} from './stylist-lexicon';

/**
 * The structured reading of what she asked for.
 *
 * This is the contract between the two halves of the stylist. Everything
 * upstream of it (rules, a language model, a filter chip she tapped) exists to
 * produce one; everything downstream (retrieval, ranking, the outfit builder,
 * the reply) reads only this and the database. Nothing else crosses.
 *
 * Consequently it is a closed, validated shape rather than a bag of strings —
 * see `sanitiseBrief`, which is the only way one is allowed to be constructed
 * from untrusted input.
 */
export interface StyleBrief {
  intent: StylistIntent;

  /** Lexicon key, e.g. `wedding`. */
  occasion: string | null;
  /** What she is shopping for. Empty means "anything on-theme". */
  slots: OutfitSlot[];
  /** Leaf category slugs, resolved against the real taxonomy. */
  categorySlugs: string[];

  /** Normalised to SYP, like `products.min_price_syp`. */
  budgetMin: number | null;
  budgetMax: number | null;

  /** Lexicon colour keys. */
  colours: string[];
  avoidColours: string[];

  sizes: { clothing?: string; shoes?: string };

  modesty: ModestyLevel;
  personas: StylePersona[];
  materials: string[];

  /** Set when shopping for someone else. */
  recipientAge: number | null;
  forSelf: boolean;

  /** Days from now she needs it by; drives the handling-time check. */
  deadlineDays: number | null;

  /** Free tokens left over, matched against title and description. */
  keywords: string[];

  /** 0–1. How much of the message the extractor actually accounted for. */
  confidence: number;
}

export type StylistIntent =
  | 'FIND_PRODUCT'
  | 'BUILD_OUTFIT'
  | 'FIND_GIFT'
  | 'REFINE'
  | 'ADVICE'
  | 'SMALL_TALK';

const INTENTS: readonly StylistIntent[] = [
  'FIND_PRODUCT',
  'BUILD_OUTFIT',
  'FIND_GIFT',
  'REFINE',
  'ADVICE',
  'SMALL_TALK',
];

/** Slots for which a clothing size is worth asking about. */
const SIZED_GARMENT_SLOTS: readonly OutfitSlot[] = [
  OutfitSlot.DRESS,
  OutfitSlot.ABAYA,
  OutfitSlot.TOP,
  OutfitSlot.BOTTOM,
];

export function emptyBrief(): StyleBrief {
  return {
    intent: 'FIND_PRODUCT',
    occasion: null,
    slots: [],
    categorySlugs: [],
    budgetMin: null,
    budgetMax: null,
    colours: [],
    avoidColours: [],
    sizes: {},
    modesty: ModestyLevel.UNSPECIFIED,
    personas: [],
    materials: [],
    recipientAge: null,
    forSelf: true,
    deadlineDays: null,
    keywords: [],
    confidence: 0,
  };
}

/**
 * The gate every untrusted brief passes through.
 *
 * "Untrusted" is meant literally and includes our own model output: the
 * extractor's job is to *propose* values, and this function is what decides
 * whether a proposal is a thing the catalog can be asked about. An unknown
 * colour, a category slug that does not exist, a negative budget and a
 * confidence of 9 are all dropped here rather than defended against in six
 * different query builders.
 */
export function sanitiseBrief(
  input: unknown,
  options: { knownCategorySlugs?: ReadonlySet<string> } = {},
): Partial<StyleBrief> {
  if (!input || typeof input !== 'object') return {};
  const raw = input as Record<string, unknown>;
  const out: Partial<StyleBrief> = {};

  const intent = str(raw['intent'])?.toUpperCase();
  if (intent && (INTENTS as readonly string[]).includes(intent)) {
    out.intent = intent as StylistIntent;
  }

  const occasion = str(raw['occasion']);
  if (occasion && occasionEntry(occasion)) out.occasion = occasion;
  else if (occasion === null && 'occasion' in raw) out.occasion = null;

  const slots = enumList(raw['slots'], OutfitSlot);
  if (slots.length) out.slots = slots;

  const categorySlugs = strList(raw['category_slugs'] ?? raw['categorySlugs']);
  if (categorySlugs.length) {
    out.categorySlugs = options.knownCategorySlugs
      ? categorySlugs.filter((slug) => options.knownCategorySlugs!.has(slug))
      : categorySlugs;
  }

  const budgetMin = money(raw['budget_min'] ?? raw['budgetMin']);
  const budgetMax = money(raw['budget_max'] ?? raw['budgetMax']);
  if (budgetMin !== null) out.budgetMin = budgetMin;
  if (budgetMax !== null) out.budgetMax = budgetMax;
  // A model that returns min > max has misread the sentence; swap rather than
  // emit a `WHERE` that can only return nothing.
  if (
    out.budgetMin !== undefined &&
    out.budgetMax !== undefined &&
    out.budgetMin !== null &&
    out.budgetMax !== null &&
    out.budgetMin > out.budgetMax
  ) {
    [out.budgetMin, out.budgetMax] = [out.budgetMax, out.budgetMin];
  }

  const colours = colourKeys(raw['colours'] ?? raw['colors']);
  if (colours.length) out.colours = colours;
  const avoid = colourKeys(raw['avoid_colours'] ?? raw['avoidColours']);
  if (avoid.length) out.avoidColours = avoid;

  const sizes = raw['sizes'];
  if (sizes && typeof sizes === 'object') {
    const record = sizes as Record<string, unknown>;
    const clothing = str(record['clothing'])?.toUpperCase();
    const shoes = str(record['shoes']);
    const next: StyleBrief['sizes'] = {};
    if (clothing && ['XS', 'S', 'M', 'L', 'XL', 'XXL'].includes(clothing)) {
      next.clothing = clothing;
    }
    if (shoes && /^\d{2}$/.test(shoes)) next.shoes = shoes;
    if (Object.keys(next).length) out.sizes = next;
  }

  const modesty = str(raw['modesty'])?.toUpperCase();
  if (modesty && modesty in ModestyLevel) {
    out.modesty = ModestyLevel[modesty as keyof typeof ModestyLevel];
  }

  const personas = enumList(raw['personas'], StylePersona);
  if (personas.length) out.personas = personas;

  const materials = strList(raw['materials'])
    .map((material) => MATERIALS.find((known) => material.includes(known)) ?? null)
    .filter((material): material is string => material !== null);
  if (materials.length) out.materials = [...new Set(materials)];

  const age = int(raw['recipient_age'] ?? raw['recipientAge']);
  if (age !== null && age >= 1 && age <= 99) out.recipientAge = age;

  if (typeof raw['for_self'] === 'boolean') out.forSelf = raw['for_self'];
  else if (typeof raw['forSelf'] === 'boolean') out.forSelf = raw['forSelf'];

  const deadline = int(raw['deadline_days'] ?? raw['deadlineDays']);
  if (deadline !== null && deadline >= 0 && deadline <= 365) {
    out.deadlineDays = deadline;
  }

  const keywords = strList(raw['keywords'])
    .map((keyword) => keyword.slice(0, 40))
    .slice(0, 10);
  if (keywords.length) out.keywords = keywords;

  const confidence = num(raw['confidence']);
  if (confidence !== null) out.confidence = clamp(confidence, 0, 1);

  return out;
}

/**
 * Folds a new turn onto the conversation's running brief.
 *
 * The asymmetry is deliberate and is what makes follow-ups work. Scalars she
 * restates replace (a new budget is a correction, not an additional
 * constraint); sets she adds to accumulate (naming a bag after a dress extends
 * the look). `slots` is the exception among sets: when a turn names slots at
 * all it is redirecting attention, so it replaces.
 */
export function mergeBriefs(base: StyleBrief, next: Partial<StyleBrief>): StyleBrief {
  const merged: StyleBrief = { ...base };

  if (next.intent) merged.intent = next.intent;
  if (next.occasion !== undefined && next.occasion !== null) {
    merged.occasion = next.occasion;
  }

  if (next.slots?.length) merged.slots = [...new Set(next.slots)];
  if (next.categorySlugs?.length) {
    merged.categorySlugs = [...new Set(next.categorySlugs)];
  }

  if (next.budgetMin !== undefined && next.budgetMin !== null) {
    merged.budgetMin = next.budgetMin;
  }
  if (next.budgetMax !== undefined && next.budgetMax !== null) {
    merged.budgetMax = next.budgetMax;
  }

  if (next.colours?.length) {
    merged.colours = [...new Set([...next.colours, ...base.colours])].slice(0, 4);
  }
  if (next.avoidColours?.length) {
    merged.avoidColours = [...new Set([...base.avoidColours, ...next.avoidColours])];
  }
  // A colour asked for now outranks the same colour ruled out earlier.
  merged.avoidColours = merged.avoidColours.filter(
    (colour) => !merged.colours.includes(colour),
  );

  if (next.sizes && Object.keys(next.sizes).length) {
    merged.sizes = { ...base.sizes, ...next.sizes };
  }

  if (next.modesty && next.modesty !== ModestyLevel.UNSPECIFIED) {
    merged.modesty = next.modesty;
  }
  if (next.personas?.length) {
    merged.personas = [...new Set([...next.personas, ...base.personas])].slice(0, 3);
  }
  if (next.materials?.length) {
    merged.materials = [...new Set([...next.materials, ...base.materials])].slice(0, 4);
  }

  if (next.recipientAge !== undefined && next.recipientAge !== null) {
    merged.recipientAge = next.recipientAge;
  }
  if (next.forSelf !== undefined) merged.forSelf = next.forSelf;
  if (next.deadlineDays !== undefined && next.deadlineDays !== null) {
    merged.deadlineDays = next.deadlineDays;
  }

  // Keywords are the most volatile field — they describe this turn, not the
  // thread — so the new turn's set replaces rather than accumulates.
  merged.keywords = next.keywords?.length ? next.keywords : [];

  if (next.confidence !== undefined) merged.confidence = next.confidence;

  return merged;
}

/** True when the brief says enough to be worth querying the catalog with. */
export function briefIsActionable(brief: StyleBrief): boolean {
  return (
    brief.slots.length > 0 ||
    brief.categorySlugs.length > 0 ||
    brief.occasion !== null ||
    brief.colours.length > 0 ||
    brief.keywords.length > 0 ||
    brief.budgetMax !== null
  );
}

/** The one question most worth asking, when the brief is thin. */
export function missingSlotQuestion(brief: StyleBrief): string | null {
  if (!brief.slots.length && !brief.categorySlugs.length && !brief.occasion) {
    return 'ما المناسبة، وما نوع القطعة التي تبحثين عنها؟';
  }
  if (brief.budgetMax === null && brief.intent !== 'ADVICE') {
    return 'ما الميزانية التي ترتاحين إليها؟';
  }
  if (
    !brief.sizes.clothing &&
    brief.slots.some((slot) => SIZED_GARMENT_SLOTS.includes(slot))
  ) {
    return 'ما مقاسكِ في الملابس؟ لأعرض عليكِ المتوفر فعلاً بمقاسكِ.';
  }
  if (!brief.sizes.shoes && brief.slots.includes(OutfitSlot.SHOES)) {
    return 'ما مقاس حذائكِ؟';
  }
  return null;
}

// ── Persistence ─────────────────────────────────────────────────────────

export function briefToJson(brief: StyleBrief): Prisma.InputJsonValue {
  return {
    intent: brief.intent,
    occasion: brief.occasion,
    slots: brief.slots,
    category_slugs: brief.categorySlugs,
    budget_min: brief.budgetMin,
    budget_max: brief.budgetMax,
    colours: brief.colours,
    avoid_colours: brief.avoidColours,
    sizes: brief.sizes,
    modesty: brief.modesty,
    personas: brief.personas,
    materials: brief.materials,
    recipient_age: brief.recipientAge,
    for_self: brief.forSelf,
    deadline_days: brief.deadlineDays,
    keywords: brief.keywords,
    confidence: brief.confidence,
  } satisfies Record<string, unknown> as Prisma.InputJsonValue;
}

/** Reads a stored brief back, re-validating it — the row may predate a
 *  vocabulary change. */
export function briefFromJson(value: Prisma.JsonValue | null): StyleBrief {
  return { ...emptyBrief(), ...sanitiseBrief(value) };
}

/** The customer-facing summary of what the stylist understood. */
export function briefToChips(brief: StyleBrief): Array<{ key: string; label: string }> {
  const chips: Array<{ key: string; label: string }> = [];
  const occasion = occasionEntry(brief.occasion);
  if (occasion) chips.push({ key: 'occasion', label: occasion.labelAr });
  for (const colour of brief.colours) {
    const entry = colourEntry(colour);
    if (entry) chips.push({ key: `colour:${colour}`, label: entry.labelAr });
  }
  if (brief.budgetMax !== null) {
    chips.push({ key: 'budget', label: `حتى ${formatSyp(brief.budgetMax)}` });
  }
  if (brief.sizes.clothing) {
    chips.push({ key: 'size', label: `مقاس ${brief.sizes.clothing}` });
  }
  if (brief.sizes.shoes) {
    chips.push({ key: 'shoe-size', label: `حذاء ${brief.sizes.shoes}` });
  }
  if (brief.modesty !== ModestyLevel.UNSPECIFIED) {
    chips.push({ key: 'modesty', label: modestyChip(brief.modesty) });
  }
  return chips;
}

function modestyChip(level: ModestyLevel): string {
  switch (level) {
    case ModestyLevel.FULL_COVERAGE:
      return 'تغطية كاملة';
    case ModestyLevel.MODEST:
      return 'محتشم';
    case ModestyLevel.BALANCED:
      return 'متوازن';
    case ModestyLevel.EXPRESSIVE:
      return 'بلا قيود';
    case ModestyLevel.UNSPECIFIED:
      return '';
  }
}

/** "١٬٢٠٠٬٠٠٠" reads badly in a chip; "1.2 مليون" reads the way she said it. */
export function formatSyp(amount: number): string {
  if (amount >= 1_000_000) {
    const millions = amount / 1_000_000;
    const rendered = Number.isInteger(millions) ? String(millions) : millions.toFixed(1);
    return `${rendered} مليون ل.س`;
  }
  if (amount >= 1_000) {
    const thousands = amount / 1_000;
    const rendered = Number.isInteger(thousands) ? String(thousands) : thousands.toFixed(0);
    return `${rendered} ألف ل.س`;
  }
  return `${Math.round(amount)} ل.س`;
}

// ── Coercion helpers ────────────────────────────────────────────────────

function str(value: unknown): string | null {
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function strList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .map((item) => (typeof item === 'string' ? item.trim() : ''))
    .filter(Boolean);
}

function num(value: unknown): number | null {
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : null;
}

function int(value: unknown): number | null {
  const parsed = num(value);
  return parsed === null ? null : Math.round(parsed);
}

function money(value: unknown): number | null {
  const parsed = num(value);
  if (parsed === null || parsed <= 0 || parsed > 1e12) return null;
  return Math.round(parsed);
}

function clamp(value: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, value));
}

function enumList<T extends Record<string, string>>(
  value: unknown,
  enumObject: T,
): Array<T[keyof T]> {
  const members = new Set(Object.values(enumObject));
  return strList(value)
    .map((item) => item.toUpperCase())
    .filter((item): item is T[keyof T] => members.has(item as T[keyof T]))
    .filter((item, index, list) => list.indexOf(item) === index);
}

function colourKeys(value: unknown): string[] {
  const known = new Set(COLOURS.map((colour) => colour.key));
  return strList(value)
    .map((item) => item.toLowerCase())
    .filter((item) => known.has(item))
    .filter((item, index, list) => list.indexOf(item) === index)
    .slice(0, 4);
}

/** Every occasion key the vocabulary knows — used by the model prompt. */
export const OCCASION_KEYS: readonly string[] = OCCASIONS.map((entry) => entry.key);
export const COLOUR_KEYS: readonly string[] = COLOURS.map((colour) => colour.key);
