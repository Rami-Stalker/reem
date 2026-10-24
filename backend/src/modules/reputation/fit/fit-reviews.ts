import { ReviewFit } from '@prisma/client';
import { normaliseSize } from '../../intelligence/kernel/size-fit';

/**
 * «تقييمات من بمقاسي», as arithmetic.
 *
 * The question a woman asks of a review before she trusts it is "was this
 * written by someone like me?" — a five-star "fits perfectly" from a woman a
 * head taller is not information about her. Everything that answers it lives
 * here, pure: the height band, which sizes count, which reviewer is "near"
 * whom, and the fit summary with its floor. `fit-reviews.spec.ts` exercises
 * it without a database.
 */

// ── Her numbers ─────────────────────────────────────────────────────────────

/** The heights a profile accepts, in centimetres. Outside it is a typo. */
export const HEIGHT_MIN_CM = 130;
export const HEIGHT_MAX_CM = 200;

/** How coarse the height stored on a review is. */
export const HEIGHT_BAND_CM = 5;

/**
 * Her height as a review stores it: rounded *down* to a 5 cm band, so 163 is
 * 160. Never the centimetre — enough to compare bodies with, too coarse to
 * identify her by. And never served: the band is used only to match reviews
 * to women her size, server-side.
 */
export function heightBand(heightCm: number | null | undefined): number | null {
  if (heightCm == null || !Number.isFinite(heightCm)) return null;
  if (heightCm < HEIGHT_MIN_CM || heightCm > HEIGHT_MAX_CM) return null;
  return Math.floor(heightCm / HEIGHT_BAND_CM) * HEIGHT_BAND_CM;
}

/**
 * The sizes a profile may say she usually wears.
 *
 * Closed, unlike a variant's size — a variant is whatever the boutique typed,
 * but "my size" has to be comparable across boutiques or it matches nothing.
 * Letters and the European numbers Syrian shops use for dresses.
 */
const LETTER_SIZES = ['XXS', 'XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL'];
const NUMERIC_MIN = 32;
const NUMERIC_MAX = 56;

export function usualSizeOf(raw: string | null | undefined): string | null {
  const size = normaliseSize(raw);
  if (!size) return null;
  if (LETTER_SIZES.includes(size)) return size;
  const numeric = Number(size);
  if (Number.isInteger(numeric) && numeric >= NUMERIC_MIN && numeric <= NUMERIC_MAX) {
    return size;
  }
  return null;
}

export const USUAL_SIZES: readonly string[] = [
  ...LETTER_SIZES,
  ...Array.from({ length: (NUMERIC_MAX - NUMERIC_MIN) / 2 + 1 }, (_, i) =>
    String(NUMERIC_MIN + i * 2),
  ),
];

// ── «من بمقاسي» ─────────────────────────────────────────────────────────────

export interface Viewer {
  heightCm: number | null;
  usualSize: string | null;
}

export interface FitVoice {
  fit: ReviewFit | null;
  sizeBought: string | null;
  heightBand: number | null;
  usualSize: string | null;
}

/**
 * Two bodies count as "near" within this many centimetres. A band either side
 * of hers, near enough: 160 and 166 wear a midi at the same length.
 */
export const NEAR_HEIGHT_CM = 6;

/**
 * Whether this reviewer is a woman "my size".
 *
 * Compared only on what both sides said. A reviewer who shared her size but
 * not her height matches on the size alone; one who shared neither matches
 * nobody — a review with no body attached is not "from someone like me", it
 * is from someone unknown, and putting it under that filter would make the
 * filter lie.
 *
 * Her size is compared against both the reviewer's usual size and the size
 * the reviewer received, because the second is often the more useful: a
 * woman who usually wears M and bought the L "because it runs small" is
 * exactly the review an M wants to read.
 */
export function isNearMe(viewer: Viewer, voice: FitVoice): boolean {
  let compared = 0;

  if (viewer.usualSize) {
    const reviewerSizes = [voice.usualSize, normaliseSize(voice.sizeBought)].filter(
      (size): size is string => !!size,
    );
    if (reviewerSizes.length) {
      compared += 1;
      if (!reviewerSizes.includes(viewer.usualSize)) return false;
    }
  }

  if (viewer.heightCm != null && voice.heightBand != null) {
    compared += 1;
    // The middle of the reviewer's band, against her exact height.
    const reviewerHeight = voice.heightBand + (HEIGHT_BAND_CM - 1) / 2;
    if (Math.abs(reviewerHeight - viewer.heightCm) > NEAR_HEIGHT_CM) return false;
  }

  return compared > 0;
}

export function hasProfile(viewer: Viewer | null): viewer is Viewer {
  return !!viewer && (viewer.heightCm != null || viewer.usualSize != null);
}

// ── The summary ─────────────────────────────────────────────────────────────

/**
 * How many voices a fit summary needs before it says anything.
 *
 * Two reviews are not "runs small"; they are two women. Below the floor the
 * counts are still returned — the reviews themselves are public — but
 * `enough` is false and the page draws no verdict. The same reasoning as the
 * size-fit kernel's sample floor, at the scale reviews arrive at.
 */
export const MIN_FIT_VOICES = 3;

export interface FitTally {
  runsSmall: number;
  trueToSize: number;
  runsLarge: number;
  total: number;
  enough: boolean;
  /** The verdict, when there is one: the fit most voices gave. */
  verdict: ReviewFit | null;
}

export function tally(voices: readonly FitVoice[]): FitTally {
  const counts = { RUNS_SMALL: 0, TRUE_TO_SIZE: 0, RUNS_LARGE: 0 };
  for (const voice of voices) {
    if (voice.fit) counts[voice.fit] += 1;
  }
  const total = counts.RUNS_SMALL + counts.TRUE_TO_SIZE + counts.RUNS_LARGE;
  const enough = total >= MIN_FIT_VOICES;

  // A verdict needs a majority, not a plurality: 2 small, 2 true and 1 large
  // is "opinions differ", and saying "runs small" would be choosing for her.
  let verdict: ReviewFit | null = null;
  if (enough) {
    for (const fit of [ReviewFit.TRUE_TO_SIZE, ReviewFit.RUNS_SMALL, ReviewFit.RUNS_LARGE]) {
      if (counts[fit] * 2 > total) verdict = fit;
    }
  }

  return {
    runsSmall: counts.RUNS_SMALL,
    trueToSize: counts.TRUE_TO_SIZE,
    runsLarge: counts.RUNS_LARGE,
    total,
    enough,
    verdict,
  };
}

/**
 * The size women like her kept and called right: «البنات اللي بمقاسك اشتروا L».
 *
 * Only from near voices that said TRUE_TO_SIZE and whose size is known, and
 * only when one size has at least two of them and more than any other. A
 * single woman's choice is an anecdote; a tie is not a recommendation.
 */
export function suggestedSize(nearVoices: readonly FitVoice[]): string | null {
  const counts = new Map<string, number>();
  for (const voice of nearVoices) {
    if (voice.fit !== ReviewFit.TRUE_TO_SIZE) continue;
    const size = normaliseSize(voice.sizeBought);
    if (!size) continue;
    counts.set(size, (counts.get(size) ?? 0) + 1);
  }

  let best: string | null = null;
  let bestCount = 0;
  let tied = false;
  for (const [size, count] of counts) {
    if (count > bestCount) {
      best = size;
      bestCount = count;
      tied = false;
    } else if (count === bestCount) {
      tied = true;
    }
  }
  return best && bestCount >= 2 && !tied ? best : null;
}
