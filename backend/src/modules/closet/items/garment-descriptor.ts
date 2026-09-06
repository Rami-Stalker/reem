import { ClosetSeason, ModestyLevel, OutfitSlot } from '@prisma/client';
import {
  MATERIALS,
  OCCASIONS,
  colourEntry,
  detectColours,
  detectMaterials,
  detectSizes,
  detectSlots,
  garmentModesty,
  normaliseArabic,
  slotEntry,
  slotForCategorySlug,
} from '../../ai-stylist/understanding/stylist-lexicon';

/**
 * What the closet knows about one garment.
 *
 * This is the type that makes the feature possible. A dress bought here and a
 * dress her mother made her both reduce to one of these, and every reader
 * downstream — the gap engine, the pairing scorer, the daily picker — consumes
 * only this. Nothing downstream may ask whether a piece came from the catalog,
 * because the moment something does, personal pieces become second-class and
 * the closet degenerates into an order history.
 *
 * The vocabulary is the stylist's, deliberately and without exception: slots
 * from `OutfitSlot`, colours and materials from `stylist-lexicon`, occasions
 * from `OCCASIONS`. Inventing a parallel one here would give Reem two opinions
 * about what "كحلي" means, and the two would drift.
 */
export interface GarmentDescriptor {
  slot: OutfitSlot;
  colours: string[];
  materials: string[];
  modesty: ModestyLevel;
  seasons: ClosetSeason[];
  occasions: string[];
  size: string | null;
}

/**
 * The fields she is allowed to correct.
 *
 * Derivation is a guess made from a title and a category; she is looking at
 * the garment. So an override always wins, and — this is the part that is easy
 * to get wrong — an override of `[]` is a real answer meaning "none of them",
 * not a missing value to be re-derived. Hence `undefined` for "she said
 * nothing" throughout, never null and never empty-as-absent.
 *
 * The same shape stated-beats-derived that `UserStylePreference` uses, for the
 * same reason: she knows her own wardrobe better than a string match does.
 */
export interface DescriptorOverrides {
  slot?: OutfitSlot;
  colours?: string[];
  materials?: string[];
  modesty?: ModestyLevel;
  seasons?: ClosetSeason[];
  occasions?: string[];
  size?: string | null;
}

// ── Seasons ─────────────────────────────────────────────────────────────

/**
 * Materials that decide a season on their own.
 *
 * Fabric is the most reliable seasonal signal the catalog carries — far more
 * so than category, since `dresses` spans a linen sundress and a velvet gown.
 * Anything not listed here is season-agnostic and falls through to the slot
 * rule below.
 */
const MATERIAL_SEASONS: ReadonlyMap<string, ClosetSeason> = new Map([
  ['صوف', ClosetSeason.WINTER],
  ['كشمير', ClosetSeason.WINTER],
  ['مخمل', ClosetSeason.WINTER],
  ['جلد', ClosetSeason.WINTER],
  ['قطن', ClosetSeason.SUMMER],
  ['لينن', ClosetSeason.SUMMER],
  ['شيفون', ClosetSeason.SUMMER],
  ['حرير', ClosetSeason.TRANSITIONAL],
  ['كريب', ClosetSeason.TRANSITIONAL],
  ['جينز', ClosetSeason.TRANSITIONAL],
]);

/**
 * Slots whose pieces are worn the year round.
 *
 * A handbag has no season, and giving one a season would quietly halve the
 * pool the pairing scorer draws from every time the weather turned.
 */
const SEASONLESS_SLOTS: ReadonlySet<OutfitSlot> = new Set([
  OutfitSlot.BAG,
  OutfitSlot.JEWELRY,
  OutfitSlot.ACCESSORY,
  OutfitSlot.PERFUME,
  OutfitSlot.BEAUTY,
  OutfitSlot.GIFT,
]);

/** Words on a label that override the fabric, in either direction. */
const WINTER_WORDS = ['شتوي', 'شتوية', 'مبطن', 'مبطّن', 'ثقيل', 'صوفي', 'دافئ'];
const SUMMER_WORDS = ['صيفي', 'صيفية', 'خفيف', 'خفيفة', 'بدون أكمام', 'قصير'];

function inferSeasons(
  slot: OutfitSlot,
  materials: readonly string[],
  text: string,
): ClosetSeason[] {
  if (SEASONLESS_SLOTS.has(slot)) return [ClosetSeason.ALL];

  // Outerwear is the one slot where the category outranks the fabric: a linen
  // jacket is still the thing worn when it is cold enough to need a jacket.
  if (slot === OutfitSlot.OUTERWEAR) {
    return [ClosetSeason.WINTER, ClosetSeason.TRANSITIONAL];
  }

  const hay = normaliseArabic(text);
  const said = (words: readonly string[]) =>
    words.some((word) => hay.includes(normaliseArabic(word)));

  if (said(WINTER_WORDS)) return [ClosetSeason.WINTER];
  if (said(SUMMER_WORDS)) return [ClosetSeason.SUMMER];

  const fromFabric = new Set<ClosetSeason>();
  for (const material of materials) {
    const season = MATERIAL_SEASONS.get(material);
    if (season) fromFabric.add(season);
  }

  // Two fabrics disagreeing (a wool-and-cotton blend) is not a contradiction to
  // resolve — it is a garment that genuinely works in the shoulder season.
  if (fromFabric.size > 1) return [ClosetSeason.TRANSITIONAL];
  if (fromFabric.size === 1) return [...fromFabric];

  // Nothing said anything. `ALL` rather than a guess: an unknown season must
  // never *exclude* a piece from a look, and every consumer treats ALL as a
  // match for whatever season it is asking about.
  return [ClosetSeason.ALL];
}

/** Is a piece wearable in this season? `ALL` on either side matches. */
export function seasonMatches(
  seasons: readonly ClosetSeason[],
  season: ClosetSeason,
): boolean {
  if (!seasons.length) return true;
  if (season === ClosetSeason.ALL) return true;
  return seasons.some((value) => value === ClosetSeason.ALL || value === season);
}

/**
 * The season it is, in Syria, on this date.
 *
 * A month table rather than a weather API, and that is a decision rather than a
 * shortcut: the daily suggestion has to be computable offline, has to be the
 * same for two women in the same month, and has to be explainable in one
 * sentence. A forecast service would buy precision the feature cannot spend.
 */
export function seasonOf(date: Date): ClosetSeason {
  switch (date.getMonth()) {
    case 11:
    case 0:
    case 1:
      return ClosetSeason.WINTER;
    case 5:
    case 6:
    case 7:
    case 8:
      return ClosetSeason.SUMMER;
    default:
      return ClosetSeason.TRANSITIONAL;
  }
}

// ── Occasions ───────────────────────────────────────────────────────────

/**
 * The occasions a slot appears in, read straight out of `OCCASIONS`.
 *
 * The inverse of the stylist's table rather than a second table of its own.
 * When a new occasion is seeded there, every closet piece in its slots becomes
 * eligible for it without a line changing here — and, more importantly, the
 * closet can never come to believe that a dress is for an occasion the stylist
 * would not build a dress into.
 */
export function occasionsForSlot(slot: OutfitSlot): string[] {
  return OCCASIONS.filter((entry) => entry.slots.includes(slot)).map(
    (entry) => entry.key,
  );
}

/** The slots an occasion wants, in the order it wants them. */
export function slotsForOccasion(occasion: string): OutfitSlot[] {
  const entry = OCCASIONS.find((item) => item.key === occasion);
  return entry ? [...entry.slots] : [];
}

/**
 * Occasions a garment reads as, from its slot and how formal it looks.
 *
 * The slot gives the eligible set; the words narrow it. A dress is eligible for
 * a wedding and for `daily`, and "فستان سهرة مطرّز" should not come back
 * claiming to be daywear.
 */
function inferOccasions(slot: OutfitSlot, text: string): string[] {
  const eligible = occasionsForSlot(slot);
  if (!eligible.length) return [];

  const hay = normaliseArabic(text);
  const said = (words: readonly string[]) =>
    words.some((word) => hay.includes(normaliseArabic(word)));

  const FORMAL = ['سهرة', 'سواريه', 'مطرز', 'مطرّز', 'ترتر', 'زفاف', 'عرس', 'فخم'];
  const CASUAL = ['كاجوال', 'يومي', 'رياضي', 'بيتي', 'قطن'];

  const CASUAL_KEYS = ['daily', 'work', 'home', 'travel'];
  const FORMAL_KEYS = ['wedding', 'engagement', 'evening', 'graduation'];

  if (said(FORMAL)) {
    const narrowed = eligible.filter((key) => !CASUAL_KEYS.includes(key));
    if (narrowed.length) return narrowed;
  }
  if (said(CASUAL)) {
    const narrowed = eligible.filter((key) => !FORMAL_KEYS.includes(key));
    if (narrowed.length) return narrowed;
  }
  return eligible;
}

// ── Derivation ──────────────────────────────────────────────────────────

/** Everything the catalog can tell us about a product she owns. */
export interface CatalogGarmentInput {
  categorySlug: string;
  title: string;
  description?: string | null;
  /** `products.attributes`, already parsed. */
  attributes?: Record<string, unknown> | null;
  /** `product_variants.attributes` of the variant she owns, when known. */
  variantAttributes?: Record<string, unknown> | null;
  variantName?: string | null;
}

/**
 * Describe a product she owns.
 *
 * Runs once, when the piece enters the closet, and the result is stored on the
 * row. Deriving it on every read would be cheaper to write and wrong to live
 * with: a seller may re-title or delist the product tomorrow, and her closet
 * must not change shape because someone else edited a listing. The snapshot is
 * the same instinct `order_items.title_snapshot` follows.
 */
export function describeCatalogGarment(
  input: CatalogGarmentInput,
  overrides: DescriptorOverrides = {},
): GarmentDescriptor {
  // Variant attributes first: they describe the exact piece in her hands,
  // where the product title describes the family it belongs to.
  const variantText = [
    input.variantName ?? '',
    ...Object.values(input.variantAttributes ?? {}).map((value) => String(value)),
  ].join(' ');
  const text = `${input.title} ${input.description ?? ''} ${variantText}`;

  const slot =
    overrides.slot ??
    slotForCategorySlug(input.categorySlug) ??
    detectSlots(text)[0] ??
    OutfitSlot.ACCESSORY;

  const colours = overrides.colours ?? detectColours(text);
  const materials = overrides.materials ?? detectMaterials(text);

  const modesty =
    overrides.modesty ??
    garmentModesty({
      categorySlug: input.categorySlug,
      title: input.title,
      attributes: input.attributes ?? null,
    }) ??
    ModestyLevel.UNSPECIFIED;

  return {
    slot,
    colours,
    materials,
    modesty,
    seasons: overrides.seasons ?? inferSeasons(slot, materials, text),
    occasions: overrides.occasions ?? inferOccasions(slot, text),
    size:
      overrides.size !== undefined
        ? overrides.size
        : (sizeFromVariant(slot, input.variantAttributes ?? null) ?? null),
  };
}

/** The size the variant she owns encodes, in the system her slot uses. */
function sizeFromVariant(
  slot: OutfitSlot,
  attributes: Record<string, unknown> | null,
): string | null {
  if (!attributes) return null;
  const system = slotEntry(slot).sizeSystem;
  if (!system) return null;

  // `size` is the seeded key (Q34); `مقاس` covers a seller who typed the
  // Arabic word as her attribute name.
  const raw = attributes['size'] ?? attributes['مقاس'];
  return raw === undefined || raw === null ? null : String(raw).trim() || null;
}

/**
 * Describe a garment Reem has never seen.
 *
 * The only input is what she wrote — a title, maybe a note — so the derivation
 * leans entirely on the lexicon's Arabic surface forms. It is expected to be
 * partial, and that is fine: the gap engine treats an unknown colour as "no
 * constraint" rather than as a mismatch, so a piece described only as "جاكيت
 * أمي" still counts as outerwear, still fills a slot, and still completes a
 * look.
 *
 * `slot` is the one field that cannot be left to inference, because everything
 * keys off it — so when nothing in the text names a garment, the caller is
 * required to have asked her. See `ClosetItemService.addPersonal`.
 */
export function describePersonalGarment(
  input: { title: string; note?: string | null },
  overrides: DescriptorOverrides = {},
): GarmentDescriptor {
  const text = `${input.title} ${input.note ?? ''}`;

  const slot = overrides.slot ?? detectSlots(text)[0] ?? OutfitSlot.ACCESSORY;
  const colours = overrides.colours ?? detectColours(text);
  const materials = overrides.materials ?? detectMaterials(text);

  let size: string | null;
  if (overrides.size !== undefined) {
    size = overrides.size;
  } else {
    const detected = detectSizes(text);
    const system = slotEntry(slot).sizeSystem;
    size =
      system === 'shoes'
        ? (detected.shoes ?? null)
        : system === 'clothing'
          ? (detected.clothing ?? null)
          : null;
  }

  return {
    slot,
    colours,
    materials,
    modesty: overrides.modesty ?? ModestyLevel.UNSPECIFIED,
    seasons: overrides.seasons ?? inferSeasons(slot, materials, text),
    occasions: overrides.occasions ?? inferOccasions(slot, text),
    size,
  };
}

// ── Validation ──────────────────────────────────────────────────────────

/**
 * Drop anything that is not in the lexicon.
 *
 * The same gate `sanitiseBrief` is for the stylist, and here for the same
 * reason: descriptor arrays reach `WHERE` clauses and colour-harmony lookups,
 * so a key that no entry recognises is a value that silently matches nothing
 * forever. Better to refuse it at the door than to store a colour the closet
 * can never reason about.
 */
export function sanitiseDescriptorOverrides(
  input: DescriptorOverrides,
): DescriptorOverrides {
  const clean: DescriptorOverrides = {};

  if (input.slot !== undefined) clean.slot = input.slot;
  if (input.modesty !== undefined) clean.modesty = input.modesty;

  if (input.colours !== undefined) {
    clean.colours = unique(input.colours.filter((key) => colourEntry(key) !== null));
  }
  if (input.materials !== undefined) {
    clean.materials = unique(input.materials.filter((m) => MATERIALS.includes(m)));
  }
  if (input.seasons !== undefined) clean.seasons = unique(input.seasons);
  if (input.occasions !== undefined) {
    const known = new Set(OCCASIONS.map((entry) => entry.key));
    clean.occasions = unique(input.occasions.filter((key) => known.has(key)));
  }
  if (input.size !== undefined) {
    const trimmed = input.size?.trim();
    clean.size = trimmed ? trimmed : null;
  }

  return clean;
}

function unique<T>(values: readonly T[]): T[] {
  return [...new Set(values)];
}
