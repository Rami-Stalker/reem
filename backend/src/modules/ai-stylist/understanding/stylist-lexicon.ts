import { ModestyLevel, OutfitSlot, StylePersona } from '@prisma/client';

/**
 * The stylist's vocabulary.
 *
 * Every value the assistant is allowed to believe lives here, and nowhere
 * else. That is the point: understanding produces keys from *these* tables,
 * retrieval turns those keys into SQL, and a language model — when one is
 * configured at all — may only choose among them. A model that answers
 * "اللون: مرجاني حالم" cannot smuggle that past `colourKey()`, so it cannot
 * reach a `WHERE` clause and cannot reach the customer.
 *
 * The surface forms are Arabic-first because the catalog is: product titles,
 * qualifiers and variant attributes are all written in Arabic (see
 * `prisma/demo/data.ts`), so a colour key has to be able to find "بلون
 * الأسود اللامع" in a title as readily as it finds `{ colour: "أسود" }` in a
 * variant.
 */

// ── Text normalisation ──────────────────────────────────────────────────

const ARABIC_INDIC = '٠١٢٣٤٥٦٧٨٩';
const EASTERN_ARABIC_INDIC = '۰۱۲۳۴۵۶۷۸۹';

/**
 * Folds the spelling variants that Arabic keyboards produce freely and that
 * would otherwise make every match miss: أ/إ/آ vs ا, ة vs ه, ى vs ي, and the
 * short vowels and tatweel that decorate a word without changing it.
 *
 * Also folds Arabic-Indic digits to ASCII, because "٥٠٠ ألف" and "500 ألف" are
 * the same budget and only one of them parses as a number.
 */
export function normaliseArabic(input: string): string {
  let text = input.normalize('NFKC');

  // Digits first — the diacritic strip below would not touch them, but the
  // budget parser downstream wants ASCII.
  text = text.replace(/[٠-٩]/g, (d) => String(ARABIC_INDIC.indexOf(d)));
  text = text.replace(/[۰-۹]/g, (d) => String(EASTERN_ARABIC_INDIC.indexOf(d)));

  text = text
    // Harakat, tanwin, shadda, sukun.
    .replace(/[ً-ٰٟ]/g, '')
    // Tatweel — decorative elongation.
    .replace(/ـ/g, '')
    .replace(/[أإآٱ]/g, 'ا')
    .replace(/ة/g, 'ه')
    .replace(/[ىئ]/g, 'ي')
    .replace(/ؤ/g, 'و')
    .toLowerCase();

  return text.replace(/\s+/g, ' ').trim();
}

/** Normalised text padded with spaces, so a match cannot start mid-word. */
export function searchable(input: string): string {
  return ` ${normaliseArabic(input).replace(/[^\p{L}\p{N}]+/gu, ' ')} `;
}

/**
 * Arabic clitics: the one-letter particles that attach to the front of a word
 * (و and, ب with, ل for, ك like, ف so), the Levantine demonstrative ها, and
 * the definite article ال, alone or after either.
 *
 * Without this a lexicon of dictionary forms matches almost nothing real. The
 * catalog writes "بلون الشامبانيا"; the entry is "شامبانيا". Customers write
 * "وحذاء"; the entry is "حذاء".
 *
 * `ها` earns its place from visual search. "بدي نفس هالفستان بس بالأسود" is
 * the single most natural way to refine a photo search in Levantine Arabic —
 * it is one of the prompts the app itself suggests — and without this the
 * garment in it was invisible: the slot came back empty while the colour and
 * the budget in the same sentence parsed fine.
 *
 * Note the shape: `هال?` rather than `ها` followed by the article. In
 * `هالفستان` the article's alif is swallowed by the demonstrative, so what
 * precedes the noun is `هال` and not `ها` + `ال`.
 */
const CLITIC_PREFIX = '(?:هال?|[وفبلك]?(?:ال)?)';

/**
 * The inflectional endings that do not change which thing is meant: the
 * accusative alif ("فستانًا" → فستانا), the feminine ه, sound plurals, and the
 * attached pronouns.
 *
 * Kept to a closed list rather than "any two letters" so "بيج" cannot match
 * "بيجاما".
 */
const INFLECTION_SUFFIX = '(?:ات|ين|ون|يه|ها|هم|هن|ا|ه|ي)?';

const MATCHER_CACHE = new Map<string, RegExp>();

function escapeRegExp(value: string): string {
  return value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
}

/**
 * A whole-word matcher for one surface form, tolerant of the affixes above.
 *
 * Compiled once per form and cached: `detectColours` alone runs eighteen
 * entries with several forms each over every message.
 */
function matcherFor(form: string): RegExp {
  const normalised = normaliseArabic(form);
  const cached = MATCHER_CACHE.get(normalised);
  if (cached) return cached;

  // Latin forms take no Arabic affixes, and letting them would match English
  // words that merely start the same way.
  const arabic = /[؀-ۿ]/.test(normalised);
  const body = escapeRegExp(normalised);
  const pattern = arabic
    ? String.raw`(?<=\s)${CLITIC_PREFIX}${body}${INFLECTION_SUFFIX}(?=\s)`
    : String.raw`(?<=\s)${body}(?=\s)`;

  const matcher = new RegExp(pattern, 'u');
  MATCHER_CACHE.set(normalised, matcher);
  return matcher;
}

/** Where a surface form occurs in already-`searchable` text, or -1. */
function indexOfForm(hay: string, form: string): number {
  return hay.search(matcherFor(form));
}

/** True when any surface form appears as a whole word in `haystack`. */
export function containsAny(haystack: string, forms: readonly string[]): boolean {
  const hay = searchable(haystack);
  return forms.some((form) => indexOfForm(hay, form) !== -1);
}

// ── Colours ─────────────────────────────────────────────────────────────

export interface ColourEntry {
  key: string;
  labelAr: string;
  /** Everything a customer, a seller title, or a variant might call it. */
  forms: readonly string[];
  /**
   * Neutrals sit with anything, which is what lets the outfit builder pair a
   * bag to a dress without a colour-theory model. Non-neutrals need `harmony`.
   */
  neutral: boolean;
  /** Colour keys this one is known to sit well beside. */
  harmony: readonly string[];
}

export const COLOURS: readonly ColourEntry[] = [
  {
    key: 'black',
    labelAr: 'أسود',
    forms: ['أسود', 'اسود', 'سوداء', 'الأسود', 'black', 'noir'],
    neutral: true,
    harmony: ['gold', 'silver', 'red', 'white', 'blush', 'burgundy'],
  },
  {
    key: 'white',
    labelAr: 'أبيض',
    forms: ['أبيض', 'ابيض', 'بيضاء', 'كريمي', 'أبيض كريمي', 'عاجي', 'white', 'ivory', 'cream'],
    neutral: true,
    harmony: ['navy', 'blush', 'gold', 'beige', 'olive'],
  },
  {
    key: 'beige',
    labelAr: 'بيج',
    forms: ['بيج', 'رملي', 'نود', 'بيچ', 'beige', 'nude', 'sand'],
    neutral: true,
    harmony: ['brown', 'caramel', 'white', 'olive', 'gold'],
  },
  {
    key: 'navy',
    labelAr: 'كحلي',
    forms: ['كحلي', 'كحلى', 'أزرق داكن', 'نيلي', 'navy'],
    neutral: true,
    harmony: ['white', 'gold', 'silver', 'beige', 'blush'],
  },
  {
    key: 'blue',
    labelAr: 'أزرق',
    forms: ['أزرق', 'ازرق', 'زرقاء', 'سماوي', 'تركوازي', 'blue', 'turquoise'],
    neutral: false,
    harmony: ['white', 'silver', 'beige', 'navy'],
  },
  {
    key: 'blush',
    labelAr: 'وردي',
    forms: ['وردي', 'زهري', 'وردي فاتح', 'بينك', 'روز', 'pink', 'blush', 'rose'],
    neutral: false,
    harmony: ['gold', 'white', 'grey', 'beige', 'burgundy'],
  },
  {
    key: 'red',
    labelAr: 'أحمر',
    forms: ['أحمر', 'احمر', 'حمراء', 'red'],
    neutral: false,
    harmony: ['black', 'gold', 'white', 'beige'],
  },
  {
    key: 'burgundy',
    labelAr: 'عنابي',
    forms: ['عنابي', 'خمري', 'نبيتي', 'مارون', 'burgundy', 'maroon'],
    neutral: false,
    harmony: ['gold', 'black', 'beige', 'blush'],
  },
  {
    key: 'green',
    labelAr: 'أخضر',
    forms: ['أخضر', 'اخضر', 'خضراء', 'green'],
    neutral: false,
    harmony: ['gold', 'beige', 'white', 'brown'],
  },
  {
    key: 'olive',
    labelAr: 'زيتي',
    forms: ['زيتي', 'زيتوني', 'olive', 'khaki'],
    neutral: false,
    harmony: ['beige', 'brown', 'gold', 'white', 'caramel'],
  },
  {
    key: 'caramel',
    labelAr: 'كاراميل',
    forms: ['كاراميل', 'كراميل', 'عسلي', 'camel', 'caramel'],
    neutral: true,
    harmony: ['beige', 'brown', 'white', 'olive', 'gold'],
  },
  {
    key: 'brown',
    labelAr: 'بني',
    forms: ['بني', 'بنّي', 'بني داكن', 'brown', 'chocolate'],
    neutral: true,
    harmony: ['beige', 'caramel', 'gold', 'olive'],
  },
  {
    key: 'grey',
    labelAr: 'رمادي',
    forms: ['رمادي', 'رصاصي', 'فحمي', 'grey', 'gray', 'charcoal'],
    neutral: true,
    harmony: ['blush', 'white', 'silver', 'black', 'burgundy'],
  },
  {
    key: 'gold',
    labelAr: 'ذهبي',
    forms: ['ذهبي', 'دهبي', 'شامبانيا', 'gold', 'golden', 'champagne'],
    neutral: true,
    harmony: ['black', 'burgundy', 'navy', 'blush', 'white', 'green'],
  },
  {
    key: 'silver',
    labelAr: 'فضي',
    forms: ['فضي', 'سلفر', 'silver'],
    neutral: true,
    harmony: ['black', 'navy', 'white', 'grey', 'blue'],
  },
  {
    key: 'purple',
    labelAr: 'بنفسجي',
    forms: ['بنفسجي', 'موف', 'لافندر', 'أرجواني', 'purple', 'lilac', 'lavender', 'mauve'],
    neutral: false,
    harmony: ['silver', 'white', 'grey', 'blush'],
  },
  {
    key: 'yellow',
    labelAr: 'أصفر',
    forms: ['أصفر', 'اصفر', 'مستردة', 'yellow', 'mustard'],
    neutral: false,
    harmony: ['white', 'brown', 'navy', 'olive'],
  },
  {
    key: 'orange',
    labelAr: 'برتقالي',
    forms: ['برتقالي', 'مشمشي', 'orange', 'peach'],
    neutral: false,
    harmony: ['beige', 'brown', 'white', 'gold'],
  },
];

const COLOUR_BY_KEY = new Map(COLOURS.map((colour) => [colour.key, colour]));

export function colourEntry(key: string): ColourEntry | null {
  return COLOUR_BY_KEY.get(key) ?? null;
}

export function colourLabel(key: string): string {
  return COLOUR_BY_KEY.get(key)?.labelAr ?? key;
}

/** Every colour named anywhere in `text`. */
export function detectColours(text: string): string[] {
  return detectColourHits(text).map((hit) => hit.key);
}

/**
 * Colours with their positions in the normalised text.
 *
 * The offsets are what makes "بدون أسود" separable from "أسود": a negation
 * binds to the colour immediately before it, and that cannot be decided
 * without knowing where each colour sits.
 */
export function detectColourHits(text: string): Array<{ key: string; index: number }> {
  const hay = searchable(text);
  const hits: Array<{ key: string; index: number }> = [];

  for (const colour of COLOURS) {
    let best = -1;
    for (const form of colour.forms) {
      const index = indexOfForm(hay, form);
      if (index !== -1 && (best === -1 || index < best)) best = index;
    }
    if (best !== -1) hits.push({ key: colour.key, index: best });
  }

  return hits.sort((a, b) => a.index - b.index);
}

/** Do these two colours sit together in one look? */
export function coloursHarmonise(left: string, right: string): boolean {
  if (left === right) return true;
  const a = COLOUR_BY_KEY.get(left);
  const b = COLOUR_BY_KEY.get(right);
  if (!a || !b) return false;
  if (a.neutral || b.neutral) return true;
  return a.harmony.includes(right) || b.harmony.includes(left);
}

// ── Occasions ───────────────────────────────────────────────────────────

export interface OccasionEntry {
  key: string;
  labelAr: string;
  forms: readonly string[];
  /** The look this occasion implies, in order of importance. */
  slots: readonly OutfitSlot[];
  /** Nudges modesty when she has not said, e.g. عيد/رمضان lean covered. */
  modestyHint?: ModestyLevel;
  personaHints: readonly StylePersona[];
  /** Category leaves that are on-theme even when no slot maps to them. */
  extraCategorySlugs?: readonly string[];
}

export const OCCASIONS: readonly OccasionEntry[] = [
  {
    key: 'wedding',
    labelAr: 'حفل زفاف',
    forms: ['عرس', 'زفاف', 'حفلة زفاف', 'فرح', 'عروس', 'wedding'],
    slots: [OutfitSlot.DRESS, OutfitSlot.SHOES, OutfitSlot.BAG, OutfitSlot.JEWELRY, OutfitSlot.PERFUME],
    personaHints: [StylePersona.GLAM, StylePersona.ROMANTIC],
  },
  {
    key: 'engagement',
    labelAr: 'خطوبة',
    forms: ['خطوبة', 'ملكة', 'خطبة', 'engagement'],
    slots: [OutfitSlot.DRESS, OutfitSlot.SHOES, OutfitSlot.BAG, OutfitSlot.JEWELRY],
    personaHints: [StylePersona.ROMANTIC, StylePersona.GLAM],
  },
  {
    key: 'evening',
    labelAr: 'سهرة',
    forms: ['سهرة', 'حفلة', 'مناسبة', 'مناسبه', 'عشاء', 'دعوة', 'party', 'evening'],
    slots: [OutfitSlot.DRESS, OutfitSlot.SHOES, OutfitSlot.BAG, OutfitSlot.JEWELRY],
    personaHints: [StylePersona.GLAM, StylePersona.CLASSIC],
  },
  {
    key: 'graduation',
    labelAr: 'تخرّج',
    forms: ['تخرج', 'تخرّج', 'حفل تخرج', 'graduation'],
    slots: [OutfitSlot.DRESS, OutfitSlot.SHOES, OutfitSlot.BAG, OutfitSlot.GIFT],
    personaHints: [StylePersona.CLASSIC, StylePersona.MINIMAL],
    extraCategorySlugs: ['graduation-gifts'],
  },
  {
    key: 'eid',
    labelAr: 'العيد',
    forms: ['عيد', 'العيد', 'عيد الفطر', 'عيد الاضحى', 'eid'],
    slots: [OutfitSlot.DRESS, OutfitSlot.ABAYA, OutfitSlot.SHOES, OutfitSlot.PERFUME, OutfitSlot.GIFT],
    modestyHint: ModestyLevel.MODEST,
    personaHints: [StylePersona.MODEST_CHIC, StylePersona.CLASSIC],
    extraCategorySlugs: ['ramadan-gifts'],
  },
  {
    key: 'ramadan',
    labelAr: 'رمضان',
    forms: ['رمضان', 'سحور', 'افطار', 'إفطار', 'ramadan'],
    slots: [OutfitSlot.ABAYA, OutfitSlot.DRESS, OutfitSlot.PERFUME, OutfitSlot.GIFT],
    modestyHint: ModestyLevel.FULL_COVERAGE,
    personaHints: [StylePersona.MODEST_CHIC],
    extraCategorySlugs: ['ramadan-gifts'],
  },
  {
    key: 'work',
    labelAr: 'العمل',
    forms: ['عمل', 'دوام', 'مكتب', 'شغل', 'جامعة', 'دراسة', 'work', 'office'],
    slots: [OutfitSlot.TOP, OutfitSlot.BOTTOM, OutfitSlot.SHOES, OutfitSlot.BAG],
    personaHints: [StylePersona.CLASSIC, StylePersona.MINIMAL],
  },
  {
    key: 'daily',
    labelAr: 'اليومي',
    forms: ['يومي', 'يوميه', 'كاجوال', 'عادي', 'خروجة', 'casual', 'daily'],
    slots: [OutfitSlot.TOP, OutfitSlot.BOTTOM, OutfitSlot.SHOES, OutfitSlot.BAG],
    personaHints: [StylePersona.MINIMAL, StylePersona.SPORTY],
  },
  {
    key: 'birthday',
    labelAr: 'عيد ميلاد',
    forms: ['عيد ميلاد', 'ميلاد', 'birthday'],
    slots: [OutfitSlot.GIFT, OutfitSlot.DRESS, OutfitSlot.PERFUME],
    personaHints: [StylePersona.ROMANTIC, StylePersona.GLAM],
  },
  {
    key: 'newborn',
    labelAr: 'مولود جديد',
    forms: ['مولود', 'مواليد', 'ولادة', 'نفاس', 'أمومة', 'امومة', 'newborn', 'baby shower'],
    slots: [OutfitSlot.GIFT],
    personaHints: [StylePersona.ROMANTIC],
    extraCategorySlugs: ['newborn-gifts', 'baby-sets', 'baby-shoes'],
  },
  {
    key: 'travel',
    labelAr: 'سفر',
    forms: ['سفر', 'رحلة', 'مشوار طويل', 'travel', 'trip'],
    slots: [OutfitSlot.TOP, OutfitSlot.BOTTOM, OutfitSlot.SHOES, OutfitSlot.BAG],
    personaHints: [StylePersona.MINIMAL, StylePersona.SPORTY],
  },
  {
    key: 'home',
    labelAr: 'البيت',
    forms: ['بيت', 'منزل', 'نوم', 'استراحة', 'home', 'lounge'],
    slots: [OutfitSlot.TOP, OutfitSlot.BOTTOM],
    personaHints: [StylePersona.SPORTY, StylePersona.MINIMAL],
  },
];

const OCCASION_BY_KEY = new Map(OCCASIONS.map((entry) => [entry.key, entry]));

export function occasionEntry(key: string | null | undefined): OccasionEntry | null {
  return key ? (OCCASION_BY_KEY.get(key) ?? null) : null;
}

export function occasionLabel(key: string | null | undefined): string | null {
  return occasionEntry(key)?.labelAr ?? null;
}

export function detectOccasion(text: string): string | null {
  const hay = searchable(text);
  // Longest form wins: "عيد ميلاد" must beat "عيد", and "حفل تخرج" must beat
  // "حفلة".
  let best: { key: string; length: number } | null = null;
  for (const occasion of OCCASIONS) {
    for (const form of occasion.forms) {
      if (indexOfForm(hay, form) === -1) continue;
      const length = normaliseArabic(form).length;
      if (!best || length > best.length) best = { key: occasion.key, length };
    }
  }
  return best?.key ?? null;
}

// ── Slots and the categories behind them ────────────────────────────────

export interface SlotEntry {
  slot: OutfitSlot;
  labelAr: string;
  forms: readonly string[];
  /** Leaf category slugs, as seeded in `prisma/seed.ts`. */
  categorySlugs: readonly string[];
  /** Which size system a variant of this slot uses, if any. */
  sizeSystem?: 'clothing' | 'shoes';
  /** Fraction of an outfit budget this slot may take, before normalisation. */
  budgetWeight: number;
}

export const SLOTS: readonly SlotEntry[] = [
  {
    slot: OutfitSlot.DRESS,
    labelAr: 'فستان',
    forms: ['فستان', 'فساتين', 'روب', 'dress', 'gown'],
    categorySlugs: ['dresses'],
    sizeSystem: 'clothing',
    budgetWeight: 0.42,
  },
  {
    slot: OutfitSlot.ABAYA,
    labelAr: 'عباية',
    forms: ['عباية', 'عبايه', 'عبايات', 'جلابية', 'قفطان', 'abaya', 'kaftan'],
    categorySlugs: ['abayas'],
    sizeSystem: 'clothing',
    budgetWeight: 0.4,
  },
  {
    slot: OutfitSlot.TOP,
    labelAr: 'قطعة علوية',
    forms: ['بلوزة', 'قميص', 'كنزة', 'تريكو', 'كارديجان', 'بلوفر', 'تيشيرت', 'top', 'blouse', 'shirt'],
    categorySlugs: ['knitwear', 'activewear'],
    sizeSystem: 'clothing',
    budgetWeight: 0.24,
  },
  {
    slot: OutfitSlot.BOTTOM,
    labelAr: 'قطعة سفلية',
    forms: ['تنورة', 'تنانير', 'جيبة', 'بنطلون', 'ليقنز', 'skirt', 'trousers', 'pants'],
    categorySlugs: ['skirts', 'activewear'],
    sizeSystem: 'clothing',
    budgetWeight: 0.2,
  },
  {
    slot: OutfitSlot.OUTERWEAR,
    labelAr: 'قطعة خارجية',
    forms: ['جاكيت', 'معطف', 'بالطو', 'كوت', 'jacket', 'coat'],
    categorySlugs: ['knitwear'],
    sizeSystem: 'clothing',
    budgetWeight: 0.24,
  },
  {
    slot: OutfitSlot.SHOES,
    labelAr: 'حذاء',
    forms: ['حذاء', 'احذية', 'أحذية', 'كعب', 'صندل', 'بوت', 'باليرينا', 'سنيكرز', 'shoes', 'heels', 'boots'],
    categorySlugs: ['shoes'],
    sizeSystem: 'shoes',
    budgetWeight: 0.2,
  },
  {
    slot: OutfitSlot.BAG,
    labelAr: 'حقيبة',
    forms: ['حقيبة', 'حقيبه', 'حقائب', 'شنطة', 'كلاتش', 'bag', 'handbag', 'clutch', 'purse'],
    categorySlugs: ['handbags'],
    budgetWeight: 0.18,
  },
  {
    slot: OutfitSlot.JEWELRY,
    labelAr: 'مجوهرات',
    forms: ['مجوهرات', 'عقد', 'سلسال', 'خاتم', 'حلق', 'أسوارة', 'اسوارة', 'اكسسوار ذهبي', 'jewellery', 'jewelry', 'necklace', 'earrings'],
    categorySlugs: ['jewellery'],
    budgetWeight: 0.12,
  },
  {
    slot: OutfitSlot.ACCESSORY,
    labelAr: 'إكسسوار',
    forms: ['إكسسوار', 'اكسسوار', 'اكسسوارات', 'وشاح', 'ايشارب', 'شال', 'حجاب', 'scarf', 'accessory'],
    categorySlugs: ['scarves'],
    budgetWeight: 0.1,
  },
  {
    slot: OutfitSlot.PERFUME,
    labelAr: 'عطر',
    forms: ['عطر', 'عطور', 'باروفان', 'perfume', 'fragrance'],
    categorySlugs: ['perfumes'],
    budgetWeight: 0.12,
  },
  {
    slot: OutfitSlot.BEAUTY,
    labelAr: 'مكياج وعناية',
    forms: ['مكياج', 'روج', 'أحمر شفاه', 'كريم', 'مرطب', 'عناية', 'makeup', 'skincare', 'lipstick'],
    categorySlugs: ['face-makeup', 'lips', 'moisturisers', 'cleansers'],
    budgetWeight: 0.12,
  },
  {
    slot: OutfitSlot.GIFT,
    labelAr: 'هدية',
    forms: ['هدية', 'هديه', 'هدايا', 'gift', 'present'],
    categorySlugs: [
      'bouquets',
      'chocolate',
      'candy-boxes',
      'graduation-gifts',
      'newborn-gifts',
      'ramadan-gifts',
      'notebooks',
      'desk-accessories',
      'wall-art',
      'perfumes',
      'jewellery',
    ],
    budgetWeight: 1,
  },
];

const SLOT_BY_ENUM = new Map(SLOTS.map((entry) => [entry.slot, entry]));

export function slotEntry(slot: OutfitSlot): SlotEntry {
  const entry = SLOT_BY_ENUM.get(slot);
  // Every member of the enum is covered above; this keeps the types honest.
  if (!entry) throw new Error(`Unmapped outfit slot: ${slot}`);
  return entry;
}

export function slotLabel(slot: OutfitSlot): string {
  return slotEntry(slot).labelAr;
}

export function detectSlots(text: string): OutfitSlot[] {
  const hay = searchable(text);
  return SLOTS.filter((entry) =>
    entry.forms.some((form) => indexOfForm(hay, form) !== -1),
  ).map((entry) => entry.slot);
}

/** The leaf slugs a set of slots resolves to, de-duplicated, order preserved. */
export function categorySlugsForSlots(slots: readonly OutfitSlot[]): string[] {
  const slugs = new Set<string>();
  for (const slot of slots) {
    for (const slug of slotEntry(slot).categorySlugs) slugs.add(slug);
  }
  return [...slugs];
}

/** The slot a leaf category belongs to — the inverse of the table above. */
export function slotForCategorySlug(slug: string): OutfitSlot | null {
  for (const entry of SLOTS) {
    // GIFT lists half the catalog; it must not win the inverse lookup.
    if (entry.slot === OutfitSlot.GIFT) continue;
    if (entry.categorySlugs.includes(slug)) return entry.slot;
  }
  return null;
}

// ── Modesty ─────────────────────────────────────────────────────────────

const MODESTY_FORMS: ReadonlyArray<{ level: ModestyLevel; forms: readonly string[] }> = [
  {
    level: ModestyLevel.FULL_COVERAGE,
    forms: ['تغطية كاملة', 'ساتر', 'ساترة', 'شرعي', 'شرعية', 'عباية', 'جلابية', 'محجبة', 'للمحجبات'],
  },
  {
    level: ModestyLevel.MODEST,
    forms: ['محتشم', 'محتشمة', 'محتشمه', 'محافظ', 'محافظة', 'كم طويل', 'أكمام طويلة', 'مو مكشوف', 'modest'],
  },
  {
    level: ModestyLevel.BALANCED,
    forms: ['كم قصير', 'نص كم', 'عادي', 'balanced'],
  },
  {
    level: ModestyLevel.EXPRESSIVE,
    forms: ['مكشوف', 'بدون أكمام', 'بلا أكمام', 'سترابلس', 'جريء', 'sleeveless', 'strapless'],
  },
];

export function detectModesty(text: string): ModestyLevel | null {
  for (const entry of MODESTY_FORMS) {
    if (containsAny(text, entry.forms)) return entry.level;
  }
  return null;
}

export function modestyLabel(level: ModestyLevel): string {
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
      return 'غير محدد';
  }
}

/**
 * How covering a garment reads, from the fields the catalog actually carries:
 * its category, its `sleeve_length` attribute (Q27, seeded on `clothing`), and
 * the words in its title.
 *
 * Returns null when nothing in the row speaks to coverage — a handbag has no
 * modesty, and scoring one as immodest would be nonsense.
 */
export function garmentModesty(input: {
  categorySlug: string;
  title: string;
  attributes: Record<string, unknown> | null;
}): ModestyLevel | null {
  if (input.categorySlug === 'abayas') return ModestyLevel.FULL_COVERAGE;

  const clothing = ['dresses', 'knitwear', 'skirts', 'activewear'].includes(
    input.categorySlug,
  );
  if (!clothing) return null;

  const sleeve = String(input.attributes?.['sleeve_length'] ?? '');
  const text = `${input.title} ${sleeve}`;

  if (containsAny(text, ['بدون أكمام', 'بلا أكمام', 'سترابلس', 'مكشوف', 'كتف واحد'])) {
    return ModestyLevel.EXPRESSIVE;
  }
  if (containsAny(text, ['كم طويل', 'أكمام طويلة', 'ماكسي', 'محتشم', 'واسع'])) {
    return ModestyLevel.MODEST;
  }
  if (containsAny(text, ['كم ثلاثة أرباع', 'كم قصير', 'أكمام منفوخة'])) {
    return ModestyLevel.BALANCED;
  }
  return null;
}

/** Ordering used to compare "covered enough". */
export function modestyRank(level: ModestyLevel): number {
  switch (level) {
    case ModestyLevel.FULL_COVERAGE:
      return 4;
    case ModestyLevel.MODEST:
      return 3;
    case ModestyLevel.BALANCED:
      return 2;
    case ModestyLevel.EXPRESSIVE:
      return 1;
    case ModestyLevel.UNSPECIFIED:
      return 0;
  }
}

// ── Personas ────────────────────────────────────────────────────────────

const PERSONA_FORMS: ReadonlyArray<{
  persona: StylePersona;
  labelAr: string;
  forms: readonly string[];
}> = [
  {
    persona: StylePersona.CLASSIC,
    labelAr: 'كلاسيكي',
    forms: ['كلاسيك', 'كلاسيكي', 'كلاسيكية', 'رسمي', 'أنيق', 'انيق', 'راقي', 'classic', 'elegant'],
  },
  {
    persona: StylePersona.ROMANTIC,
    labelAr: 'رومانسي ناعم',
    forms: ['ناعم', 'ناعمة', 'رومانسي', 'رقيق', 'رقيقة', 'دلع', 'romantic', 'soft', 'feminine'],
  },
  {
    persona: StylePersona.MINIMAL,
    labelAr: 'بسيط',
    forms: ['بسيط', 'بسيطة', 'مينيمال', 'هادئ', 'سادة', 'minimal', 'simple'],
  },
  {
    persona: StylePersona.GLAM,
    labelAr: 'فخم',
    forms: ['فخم', 'فخمة', 'لماع', 'براق', 'مبهر', 'glam', 'glamorous', 'luxury'],
  },
  {
    persona: StylePersona.BOHO,
    labelAr: 'بوهيمي',
    forms: ['بوهيمي', 'بوهو', 'boho', 'bohemian'],
  },
  {
    persona: StylePersona.SPORTY,
    labelAr: 'رياضي',
    forms: ['رياضي', 'رياضية', 'مريح', 'مريحة', 'كاجوال', 'sporty', 'comfortable'],
  },
  {
    persona: StylePersona.MODEST_CHIC,
    labelAr: 'محتشم أنيق',
    forms: ['محتشم أنيق', 'ستايل محتشم', 'modest chic'],
  },
  {
    persona: StylePersona.VINTAGE,
    labelAr: 'ڤينتاج',
    forms: ['فينتاج', 'ڤينتاج', 'ريترو', 'تراثي', 'vintage', 'retro'],
  },
];

const PERSONA_LABELS = new Map(
  PERSONA_FORMS.map((entry) => [entry.persona, entry.labelAr]),
);

export function personaLabel(persona: StylePersona): string {
  return PERSONA_LABELS.get(persona) ?? persona;
}

export function detectPersonas(text: string): StylePersona[] {
  return PERSONA_FORMS.filter((entry) => containsAny(text, entry.forms)).map(
    (entry) => entry.persona,
  );
}

// ── Materials ───────────────────────────────────────────────────────────

/**
 * Matched against `products.attributes.material`, which the seller fills from
 * the category's attribute schema (Q27). The keys are the Arabic values the
 * catalog stores, so a match here is a literal one.
 */
export const MATERIALS: readonly string[] = [
  'حرير',
  'شيفون',
  'ساتان',
  'كريب',
  'قطن',
  'كشمير',
  'صوف',
  'لينن',
  'جلد',
  'دانتيل',
  'مخمل',
  'جينز',
  'نيدا',
  'فضة',
];

/**
 * Words for a fabric that are not the word we store.
 *
 * `MATERIALS` is a canonical list — one entry per fabric — because a linen
 * dress described two ways must not become two materials, or the seasonal rule
 * and the pairing scorer would disagree about the same garment. But women do
 * not type the canonical word: `لينن` is the transliteration a catalogue uses,
 * while `كتان` is simply what linen is called. Detecting only the first meant a
 * linen piece read as fabric-less, and fabric is the strongest seasonal signal
 * the descriptor has.
 *
 * Only true synonyms belong here. Inflections need no entry — `صوفي` already
 * contains `صوف`, and the match is on substrings.
 */
const MATERIAL_ALIASES: ReadonlyMap<string, string> = new Map([
  ['كتان', 'لينن'],
  ['دنيم', 'جينز'],
]);

export function detectMaterials(text: string): string[] {
  const hay = searchable(text);
  const found = MATERIALS.filter((material) =>
    hay.includes(normaliseArabic(material)),
  );
  for (const [alias, canonical] of MATERIAL_ALIASES) {
    if (hay.includes(normaliseArabic(alias)) && !found.includes(canonical)) {
      found.push(canonical);
    }
  }
  return found;
}

// ── Sizes ───────────────────────────────────────────────────────────────

const CLOTHING_SIZE_FORMS: ReadonlyArray<{ size: string; forms: readonly string[] }> = [
  { size: 'S', forms: ['s', 'سمول', 'صغير'] },
  { size: 'M', forms: ['m', 'ميديم', 'متوسط', 'وسط'] },
  { size: 'L', forms: ['l', 'لارج', 'كبير'] },
  { size: 'XL', forms: ['xl', 'اكس لارج', 'إكس لارج', 'كبير جدا'] },
];

export interface DetectedSizes {
  clothing?: string;
  shoes?: string;
}

/**
 * Reads "مقاس M" and "مقاس ٣٨" out of a sentence.
 *
 * Anchored on the word مقاس/قياس/size rather than scanning for a bare letter,
 * because a loose "L" matches half the Latin text in a bilingual message and a
 * loose "38" matches a price.
 */
export function detectSizes(text: string): DetectedSizes {
  const hay = normaliseArabic(text);
  const sizes: DetectedSizes = {};

  const anchored = /(?:مقاس|قياس|مقاسي|قياسي|size)\s*[:،-]?\s*([a-z]{1,3}|\d{2})/gi;
  for (const match of hay.matchAll(anchored)) {
    const token = match[1];
    if (!token) continue;
    if (/^\d{2}$/.test(token)) {
      const number = Number(token);
      // Women's EU shoe sizes; anything outside is a stray number.
      if (number >= 34 && number <= 44) sizes.shoes = token;
      continue;
    }
    const entry = CLOTHING_SIZE_FORMS.find((candidate) =>
      candidate.forms.includes(token.toLowerCase()),
    );
    if (entry) sizes.clothing = entry.size;
  }

  // Spelled-out sizes need no anchor — "لارج" is never anything else.
  if (!sizes.clothing) {
    for (const entry of CLOTHING_SIZE_FORMS) {
      const spelled = entry.forms.filter((form) => form.length > 2);
      if (spelled.length && containsAny(text, spelled)) {
        sizes.clothing = entry.size;
        break;
      }
    }
  }

  return sizes;
}

// ── Money ───────────────────────────────────────────────────────────────

const THOUSAND_FORMS = ['الف', 'الاف', 'ألف', 'آلاف', 'k'];
const MILLION_FORMS = ['مليون', 'ملايين', 'm'];

/**
 * Parses the budget out of a sentence, in SYP.
 *
 * The multiplier words matter more than the digits here: Syrian prices are
 * quoted as "٥٠٠ ألف", and reading that as 500 would put every single result
 * below the cheapest thing in the catalog.
 */
export function detectBudget(text: string): { min?: number; max?: number } | null {
  const hay = normaliseArabic(text);

  const scaled = (value: number, suffix: string | undefined): number => {
    if (!suffix) return value;
    const token = suffix.trim();
    if (THOUSAND_FORMS.some((form) => token.startsWith(normaliseArabic(form)))) {
      return value * 1_000;
    }
    if (MILLION_FORMS.some((form) => token.startsWith(normaliseArabic(form)))) {
      return value * 1_000_000;
    }
    return value;
  };

  // The digits are optional, because a multiplier is a quantity on its own:
  // "تحت مليون" states a ceiling of 1,000,000 without writing a single digit,
  // and requiring one there was silently dropping the constraint entirely.
  const number = String.raw`(\d[\d,.]*)?\s*(الف|الاف|مليون|ملايين|k|m)?`;

  /** A match is only a number if at least one of its two halves is present. */
  const amount = (digits?: string, suffix?: string): number => {
    if (!digits && !suffix) return 0;
    return scaled(digits ? toNumber(digits) : 1, suffix);
  };

  // "بين ٥٠٠ ألف و مليون" / "من ... إلى ..."
  const range = new RegExp(
    String.raw`(?:بين|من)\s*${number}\s*(?:و|الى|إلى|ل|-)\s*${number}`,
    'i',
  );
  const rangeMatch = hay.match(range);
  if (rangeMatch) {
    // "بين ٥٠٠ و٧٠٠ ألف" — the multiplier is written once, at the end, so the
    // low bound inherits it when it has none of its own.
    const low = rangeMatch[2]
      ? amount(rangeMatch[1], rangeMatch[2])
      : amount(rangeMatch[1], rangeMatch[4]);
    const high = amount(rangeMatch[3], rangeMatch[4]);
    if (low > 0 && high > 0) {
      return { min: Math.min(low, high), max: Math.max(low, high) };
    }
  }

  // "تحت ٥٠٠ ألف" / "بحدود" / "ميزانية"
  const ceiling = new RegExp(
    String.raw`(?:تحت|اقل من|أقل من|لا يتجاوز|بحدود|حدود|ميزانيتي|ميزانية|حوالي|تقريبا|بحدود ال|under|max)\s*${number}`,
    'i',
  );
  const ceilingMatch = hay.match(ceiling);
  if (ceilingMatch) {
    const value = amount(ceilingMatch[1], ceilingMatch[2]);
    if (value > 0) return { max: value };
  }

  // "فوق ٣٠٠ ألف"
  const floor = new RegExp(String.raw`(?:فوق|اكثر من|أكثر من|over|min)\s*${number}`, 'i');
  const floorMatch = hay.match(floor);
  if (floorMatch) {
    const value = amount(floorMatch[1], floorMatch[2]);
    if (value > 0) return { min: value };
  }

  // A bare amount still counts, but only when something marks it as money:
  // a multiplier word or a currency. Otherwise every size and every age in
  // the sentence would read as a budget.
  const bare = hay.match(new RegExp(String.raw`(\d[\d,.]*)\s*(الف|الاف|مليون|ملايين|k|m)?`, 'i'));
  const currencyNamed = /ل\.س|ليره|سوري|syp/.test(hay);
  if (bare && (bare[2] || currencyNamed)) {
    const value = amount(bare[1], bare[2]);
    if (value >= 1_000) return { max: value };
  }

  return null;
}

function toNumber(raw: string | undefined): number {
  if (!raw) return 0;
  const cleaned = raw.replace(/[,\s]/g, '');
  // A dot in "1.500" is a thousands separator here, not a decimal point:
  // nothing in this catalog is priced in fractions of a lira.
  const value = Number(cleaned.replace(/\.(?=\d{3}\b)/g, ''));
  return Number.isFinite(value) ? value : 0;
}

// ── Recipient age ───────────────────────────────────────────────────────

/** "عمرها ٢٥ سنة" → 25. Bounded so a price never reads as an age. */
export function detectRecipientAge(text: string): number | null {
  const hay = normaliseArabic(text);
  const match = hay.match(/(?:عمرها|عمره|عمري|بعمر|بعمرها|age)\s*(\d{1,2})/);
  if (!match) {
    const trailing = hay.match(/(\d{1,2})\s*(?:سنة|سنه|عام|years?)/);
    if (!trailing) return null;
    const age = Number(trailing[1]);
    return age >= 1 && age <= 99 ? age : null;
  }
  const age = Number(match[1]);
  return age >= 1 && age <= 99 ? age : null;
}

// ── Deadline ────────────────────────────────────────────────────────────

/**
 * "بعد أسبوع" → a date. Used to check a seller can actually hand the parcel
 * over in time, which is the difference between a recommendation and a
 * disappointment.
 */
export function detectDeadlineDays(text: string): number | null {
  const hay = normaliseArabic(text);

  if (/(?:بكرا|بكره|غدا|غدًا|tomorrow)/.test(hay)) return 1;
  if (/(?:اليوم|هلق|حالا|today|now)/.test(hay)) return 0;

  // The dual is a whole grammatical number in Arabic, not a plural of two:
  // "بعد يومين" carries its count in the ending, with no digit to read.
  const match = hay.match(
    /بعد\s*(\d{1,3})?\s*(يومين|اسبوعين|شهرين|يوم|ايام|اسبوع|اسابيع|شهر|اشهر|weeks?|days?|months?)/,
  );
  if (match) {
    const unit = match[2] ?? '';
    const dual = /ين$/.test(unit) && !match[1];
    const count = match[1] ? Number(match[1]) : dual ? 2 : 1;
    // "ايام" is the broken plural — it shares no stem with "يوم".
    if (/يوم|ايام|day/.test(unit)) return count;
    if (/اسبوع|اسابيع|week/.test(unit)) return count * 7;
    if (/شهر|اشهر|month/.test(unit)) return count * 30;
  }

  if (/(?:هذا الاسبوع|هالاسبوع|this week)/.test(hay)) return 7;
  return null;
}

// ── Gift detection ──────────────────────────────────────────────────────

const GIFT_FORMS = [
  'هدية',
  'هديه',
  'هدايا',
  'اهدي',
  'أهدي',
  'لصديقتي',
  'لاختي',
  'لأختي',
  'لامي',
  'لأمي',
  'لخطيبتي',
  'لزوجتي',
  'لبنتي',
  'لابنتي',
  'gift',
  'present',
  'for my friend',
];

export function looksLikeGift(text: string): boolean {
  return containsAny(text, GIFT_FORMS);
}

const OUTFIT_FORMS = [
  'اطلالة',
  'إطلالة',
  'اطلاله',
  'لوك',
  'تنسيق',
  'انسقي',
  'نسقي',
  'طقم كامل',
  'من راسي لرجلي',
  'outfit',
  'look',
  'style me',
];

export function looksLikeOutfit(text: string): boolean {
  // "فستان مع حقيبة وحذاء" is an outfit request even without the word.
  if (containsAny(text, OUTFIT_FORMS)) return true;
  return detectSlots(text).length >= 2;
}

// ── Stop words, for the free-keyword residue ────────────────────────────

const STOP_WORDS = new Set(
  [
    'اريد',
    'أريد',
    'بدي',
    'ابغى',
    'ممكن',
    'لو',
    'سمحت',
    'عندي',
    'في',
    'من',
    'الى',
    'إلى',
    'على',
    'مع',
    'عن',
    'هذا',
    'هذه',
    'شي',
    'شيء',
    'كمان',
    'يكون',
    'تكون',
    'اللي',
    'الي',
    'كتير',
    'وين',
    'كيف',
    'شو',
    'مناسب',
    'مناسبة',
    'want',
    'need',
    'looking',
    'please',
    'some',
    'that',
    'with',
    'this',
    'have',
    'for',
    'the',
    'and',
  ].map(normaliseArabic),
);

/** What is left of a message once the structured fields have taken their cut. */
export function residualKeywords(text: string, limit = 8): string[] {
  const tokens = normaliseArabic(text)
    .split(/[^\p{L}\p{N}]+/u)
    .filter((token) => token.length >= 3 && !STOP_WORDS.has(token) && !/^\d+$/.test(token));
  return [...new Set(tokens)].slice(0, limit);
}
