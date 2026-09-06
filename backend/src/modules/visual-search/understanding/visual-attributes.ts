import { OutfitSlot } from '@prisma/client';
import { COLOURS, colourLabel } from '../../ai-stylist/understanding/stylist-lexicon';
import { SignalReadings, rgbToLab } from '../embedding/image-signals';

/**
 * What a photograph is allowed to be understood as.
 *
 * The same closed-vocabulary discipline the stylist's `StyleBrief` is built
 * on, applied to pixels. Everything below is either a key from the stylist's
 * existing lexicon — so a colour read out of a screenshot and a colour read
 * out of a sentence are the same string and reach the same `WHERE` — or a
 * member of one of the small enumerations declared here.
 *
 * ── What is honestly derivable from pixels, and what is not ──────────────
 *
 * This distinction is the whole ethics of the feature and it is drawn in
 * `provenance`, which travels with every attribute to the client.
 *
 *  - **PIXELS.** Colour, pattern, tone, contrast, framing, background. These
 *    are measurements. They are as true as the descriptor is, they need no
 *    model, and they are reproducible.
 *  - **NEIGHBOURS.** Category and slot. A photograph does not contain the
 *    word "فساتين"; a bitmap cannot tell you it is a dress. What it *can*
 *    tell you is which catalogue rows look like it, and the categories those
 *    rows sit in are then a genuine inference — one made from the shop's own
 *    data rather than from a guess. This is inference, and it is labelled as
 *    inference.
 *  - **VISION.** Anything a configured vision model proposed. Sanitised
 *    through the same gate as everything else, and never trusted further than
 *    the closed vocabularies allow.
 *
 * Nothing is ever produced by "it is probably a dress because most things
 * are". An attribute with no evidence is simply absent.
 */

export type AttributeProvenance = 'PIXELS' | 'NEIGHBOURS' | 'VISION';

/** How busy the garment's surface is. */
export type VisualPattern = 'plain' | 'textured' | 'patterned';

/** Overall lightness of the subject. */
export type VisualTone = 'dark' | 'mid' | 'light';

/** How the photograph was taken, which is a hint about what it is showing. */
export type VisualFraming = 'closeup' | 'product' | 'full_look';

export interface VisualColour {
  /** A key from the stylist's `COLOURS` table. */
  key: string;
  labelAr: string;
  /** 0–1 share of the (centre-weighted) frame. */
  share: number;
}

export interface VisualAttributes {
  colours: VisualColour[];
  pattern: VisualPattern;
  tone: VisualTone;
  framing: VisualFraming;
  /** True when the subject sits on a plain, even ground — a studio shot. */
  studioBackground: boolean;
  /** 0–1, how much of the frame the subject occupies. */
  subjectFill: number;

  /**
   * Filled from the catalogue neighbours, or by a vision model.
   *
   * Carries the Arabic name beside the slug. A slug is an identifier — the app
   * rendered "الأقرب: abayas" into a chip row that was otherwise entirely
   * Arabic, because it was handed nothing else to show.
   */
  categories: Array<{ slug: string; label: string }>;
  slots: OutfitSlot[];

  /** Per-field, so the client can label an inference as an inference. */
  provenance: Partial<Record<keyof VisualAttributes, AttributeProvenance>>;

  /** 0–1. How much of the picture the reading actually accounts for. */
  confidence: number;
}

/**
 * One sRGB anchor per lexicon colour.
 *
 * These are the shop's colours, not a colour scientist's: `white` has to catch
 * ivory and cream because the lexicon's own forms include كريمي and عاجي, and
 * `gold` has to catch champagne for the same reason. Matching is nearest
 * neighbour in CIE Lab rather than in RGB, so "a slightly darker beige" lands
 * on beige instead of on brown the way an RGB distance would have it.
 */
const COLOUR_ANCHORS: Record<string, [number, number, number]> = {
  black: [17, 17, 19],
  white: [246, 244, 240],
  beige: [216, 195, 165],
  navy: [31, 42, 72],
  blue: [46, 111, 216],
  blush: [232, 169, 189],
  red: [198, 40, 40],
  burgundy: [110, 27, 46],
  green: [46, 125, 79],
  olive: [107, 112, 67],
  caramel: [176, 123, 69],
  brown: [92, 58, 33],
  grey: [154, 154, 154],
  gold: [201, 162, 39],
  silver: [192, 196, 200],
  purple: [126, 87, 194],
  yellow: [227, 196, 43],
  orange: [224, 122, 62],
};

const ANCHOR_LAB: Array<{ key: string; lab: [number, number, number] }> = Object.entries(
  COLOUR_ANCHORS,
)
  // Guard against the tables drifting apart: an anchor for a colour the
  // stylist no longer knows would produce a key that `sanitiseBrief` drops
  // silently, and the search would quietly stop filtering on colour.
  .filter(([key]) => COLOURS.some((colour) => colour.key === key))
  .map(([key, rgb]) => ({
    key,
    lab: rgbToLab(rgb[0] / 255, rgb[1] / 255, rgb[2] / 255),
  }));

/**
 * The nearest lexicon colour to one measured bin, or null when nothing is
 * close enough.
 *
 * The ceiling matters. Without it every pixel finds a "nearest" colour and a
 * muddy photograph produces a confident wrong answer; with it, an unusual
 * shade contributes nothing rather than something false.
 */
export function nearestColourKey(rgb: [number, number, number]): string | null {
  const lab = rgbToLab(rgb[0], rgb[1], rgb[2]);

  let best: { key: string; distance: number } | null = null;
  for (const anchor of ANCHOR_LAB) {
    const distance = Math.hypot(
      lab[0] - anchor.lab[0],
      lab[1] - anchor.lab[1],
      lab[2] - anchor.lab[2],
    );
    if (!best || distance < best.distance) best = { key: anchor.key, distance };
  }

  // 46 ΔE is generous — the anchors are eighteen points covering the whole
  // solid, so the average gap between them is large — but it still refuses the
  // saturated neons and deep teals this catalogue does not stock.
  return best && best.distance <= 46 ? best.key : null;
}

/**
 * The measured half of the reading: everything derivable from the pixels
 * alone, with nothing inferred and nothing guessed.
 */
export function readingsToAttributes(readings: SignalReadings): VisualAttributes {
  const shares = new Map<string, number>();

  for (const entry of readings.palette) {
    const rgb = hsvToRgb(
      entry.hue ?? 0,
      entry.hue === null ? 0 : entry.saturation,
      entry.lightness,
    );
    const key = nearestColourKey(rgb);
    if (!key) continue;
    shares.set(key, (shares.get(key) ?? 0) + entry.share);
  }

  const colours: VisualColour[] = [...shares.entries()]
    .sort((a, b) => b[1] - a[1])
    // Below a twelfth of the frame a colour is trim, a shadow or a logo. Four
    // is as many as a garment is ever usefully described by.
    .filter(([, share]) => share >= 0.08)
    .slice(0, 4)
    .map(([key, share]) => ({ key, labelAr: colourLabel(key), share }));

  const pattern: VisualPattern =
    readings.patternEnergy >= 0.45
      ? 'patterned'
      : readings.patternEnergy >= 0.22
        ? 'textured'
        : 'plain';

  const tone: VisualTone =
    readings.lightness <= 0.32 ? 'dark' : readings.lightness >= 0.68 ? 'light' : 'mid';

  // A tall source frame that the subject does not fill is somebody standing in
  // a room: the full-look case, and the only case where splitting the frame
  // into garments is meaningful. A square frame the subject fills is a
  // catalogue photograph of one thing.
  const framing: VisualFraming =
    readings.aspect < 0.8 && readings.subjectFill < 0.72
      ? 'full_look'
      : readings.subjectFill >= 0.82
        ? 'closeup'
        : 'product';

  const accounted = colours.reduce((sum, colour) => sum + colour.share, 0);

  return {
    colours,
    pattern,
    tone,
    framing,
    studioBackground: readings.borderUniformity >= 0.62,
    subjectFill: readings.subjectFill,
    categories: [],
    slots: [],
    provenance: {
      colours: 'PIXELS',
      pattern: 'PIXELS',
      tone: 'PIXELS',
      framing: 'PIXELS',
      studioBackground: 'PIXELS',
      subjectFill: 'PIXELS',
    },
    // Confidence is the share of the frame the named colours actually cover.
    // A photograph whose palette is entirely outside the lexicon scores low,
    // and the pipeline then leans harder on the vector, which never needed the
    // names in the first place.
    confidence: Math.min(1, Math.max(0, accounted)),
  };
}

/**
 * Folds what the catalogue neighbours say into the reading.
 *
 * Only categories that a clear plurality of the visual matches agree on are
 * adopted. One black bag among nine black dresses must not put `bags` in the
 * brief and drag the second page sideways.
 */
export function withNeighbourCategories(
  attributes: VisualAttributes,
  neighbours: Array<{ categorySlug: string; categoryLabel: string; similarity: number }>,
): VisualAttributes {
  if (!neighbours.length) return attributes;

  const weight = new Map<string, number>();
  const labels = new Map<string, string>();
  let total = 0;
  for (const neighbour of neighbours) {
    // Weighted by how alike each neighbour actually is, so a distant match
    // cannot vote as loudly as a near one.
    const vote = Math.max(0, neighbour.similarity);
    weight.set(neighbour.categorySlug, (weight.get(neighbour.categorySlug) ?? 0) + vote);
    labels.set(neighbour.categorySlug, neighbour.categoryLabel);
    total += vote;
  }
  if (total <= 0) return attributes;

  const adopted = [...weight.entries()]
    .sort((a, b) => b[1] - a[1])
    .filter(([, vote]) => vote / total >= 0.22)
    .slice(0, 3)
    .map(([slug]) => ({ slug, label: labels.get(slug) || slug }));

  if (!adopted.length) return attributes;

  return {
    ...attributes,
    categories: adopted,
    provenance: { ...attributes.provenance, categories: 'NEIGHBOURS' },
  };
}

/** The Arabic chips shown under the uploaded photograph. */
export function attributesToChips(
  attributes: VisualAttributes,
): Array<{ key: string; label: string }> {
  const chips: Array<{ key: string; label: string }> = [];

  for (const colour of attributes.colours) {
    chips.push({ key: `colour:${colour.key}`, label: colour.labelAr });
  }
  chips.push({ key: 'pattern', label: PATTERN_LABELS[attributes.pattern] });
  chips.push({ key: 'tone', label: TONE_LABELS[attributes.tone] });
  return chips;
}

export const PATTERN_LABELS: Record<VisualPattern, string> = {
  plain: 'سادة',
  textured: 'بنقشة خفيفة',
  patterned: 'منقّش',
};

export const TONE_LABELS: Record<VisualTone, string> = {
  dark: 'ألوان غامقة',
  mid: 'ألوان متوسطة',
  light: 'ألوان فاتحة',
};

export const FRAMING_LABELS: Record<VisualFraming, string> = {
  closeup: 'لقطة قريبة للقطعة',
  product: 'صورة منتج',
  full_look: 'إطلالة كاملة',
};

/** HSV (h in degrees, s and v in 0–1) to sRGB in 0–1. */
export function hsvToRgb(
  hue: number,
  saturation: number,
  value: number,
): [number, number, number] {
  const chroma = value * saturation;
  const sector = ((hue % 360) + 360) % 360 / 60;
  const second = chroma * (1 - Math.abs((sector % 2) - 1));
  const match = value - chroma;

  const [r, g, b] =
    sector < 1
      ? [chroma, second, 0]
      : sector < 2
        ? [second, chroma, 0]
        : sector < 3
          ? [0, chroma, second]
          : sector < 4
            ? [0, second, chroma]
            : sector < 5
              ? [second, 0, chroma]
              : [chroma, 0, second];

  return [r + match, g + match, b + match];
}
