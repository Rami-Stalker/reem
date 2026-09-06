import { OutfitSlot, VisualRegionDetector } from '@prisma/client';
import { CANVAS, RawImage, rgbToLab } from '../embedding/image-signals';
import { BoundingBox } from '../processing/image-processing.service';
import { VisualAttributes } from '../understanding/visual-attributes';

export interface DetectedRegion {
  detector: VisualRegionDetector;
  slot: OutfitSlot | null;
  label: string;
  /** Normalised to the *source* frame, so it can be cropped back out of it. */
  box: BoundingBox;
  confidence: number;
}

/**
 * Splitting one photograph into the garments it shows.
 *
 * ── Why this is a geometric prior and says so ────────────────────────────
 *
 * There is no object detector here, and pretending otherwise would be the
 * dishonest version of this feature. What there is, is a fact about the kind
 * of photograph this feature receives: a full-length shot of a woman dressed
 * for something puts the top above the waist above the hem above the shoes, in
 * that order, every time. That ordering is real, it is stable, and a colour
 * discontinuity running across the figure is a genuine boundary between two
 * garments far more often than it is not.
 *
 * So the algorithm below finds the figure, walks down it, and cuts where the
 * colour changes. It is a heuristic and it is labelled `LAYOUT` in the
 * database and capped at a confidence no detection would accept, because a
 * printed band across a single dress produces exactly the same signal as a
 * skirt under a blouse and nothing in the pixels can separate those two.
 *
 * When a vision model is configured its detections replace all of this and are
 * recorded as `VISION`. The client shows the confidence either way, and a
 * low-confidence region is offered as "شفت كمان" rather than asserted.
 *
 * Everything here is a pure function over a raw buffer — no sharp, no
 * database — so the band logic is testable with a bitmap drawn by hand.
 */

/** Below this the figure is too small a part of the frame to cut up. */
const MIN_ROW_COVERAGE = 0.05;

/** Lab distance at which two bands are different garments rather than folds. */
const BAND_SPLIT_DELTA = 15;

/** A band shorter than this share of the figure is absorbed by its neighbour. */
const MIN_BAND_SHARE = 0.11;

/** The most a `LAYOUT` region is ever allowed to claim. */
const LAYOUT_CONFIDENCE_CEILING = 0.58;

/**
 * The whole frame, as one region. What a single-garment photograph produces,
 * and the fallback whenever the split is not worth trusting — which means the
 * outfit path and the ordinary path are the same code downstream.
 */
export function wholeFrameRegion(attributes: VisualAttributes): DetectedRegion {
  return {
    detector: VisualRegionDetector.WHOLE,
    slot: attributes.slots[0] ?? null,
    label: 'القطعة بالصورة',
    box: { x: 0, y: 0, w: 1, h: 1 },
    confidence: 1,
  };
}

/**
 * Cuts a full-length look into bands.
 *
 * `frame` must be the **undistorted-mapping** canvas — the whole image
 * resampled to the square with `fit: 'fill'` — so a row on the canvas maps
 * linearly back to a row in the source and a box can be cropped out again.
 * Passing the salience-cropped canvas here would produce boxes that point at
 * the wrong part of the photograph.
 *
 * Returns an empty array when the frame does not support a split, and the
 * caller then uses `wholeFrameRegion`.
 */
export function segmentLayout(
  frame: RawImage,
  attributes: VisualAttributes,
): DetectedRegion[] {
  // Only a full-length look is worth cutting. A catalogue photograph of one
  // handbag has bands too — the strap, the body, the shadow — and splitting it
  // would search for three handbags.
  if (attributes.framing !== 'full_look') return [];

  const rows = measureRows(frame);
  const figure = figureExtent(rows);
  if (!figure) return [];

  const height = figure.to - figure.from + 1;
  // Under a third of the frame there is not enough figure for the vertical
  // prior to mean anything.
  if (height < CANVAS * 0.32) return [];

  const cuts = findCuts(rows, figure);
  if (!cuts.length) return [];

  const bounds = [figure.from, ...cuts, figure.to + 1];
  const bands: Array<{ from: number; to: number }> = [];
  for (let index = 0; index < bounds.length - 1; index += 1) {
    bands.push({ from: bounds[index], to: bounds[index + 1] - 1 });
  }

  const merged = mergeShortBands(bands, height);
  // One band means the walk found no real boundary; two to four is a look.
  if (merged.length < 2) return [];

  const regions = merged.slice(0, 4).map((band, index) => {
    const share = (band.to - band.from + 1) / height;
    const centre = (band.from + band.to) / 2;
    const position = (centre - figure.from) / height;

    const extent = horizontalExtent(rows, band);
    const slot = slotForBand({ position, share, index, total: merged.length });

    return {
      detector: VisualRegionDetector.LAYOUT,
      slot,
      label: slotRegionLabel(slot),
      box: {
        // A little air around the crop: a hem cut exactly at the boundary
        // loses the shape of the hem, which is most of what identifies it.
        x: clamp01(extent.from / CANVAS - 0.03),
        y: clamp01(band.from / CANVAS - 0.01),
        w: clamp01((extent.to - extent.from) / CANVAS + 0.06),
        h: clamp01((band.to - band.from + 1) / CANVAS + 0.02),
      },
      confidence: bandConfidence(rows, band, attributes),
    } satisfies DetectedRegion;
  });

  return regions.filter((region) => region.box.w > 0.08 && region.box.h > 0.06);
}

// ── The walk ────────────────────────────────────────────────────────────

interface RowStats {
  /** Share of the row that is subject rather than background. */
  coverage: number;
  /** Mean Lab of the subject pixels in the row. */
  lab: [number, number, number];
  from: number;
  to: number;
}

function measureRows(frame: RawImage): RowStats[] {
  const { data } = frame;
  const labL = new Float32Array(CANVAS * CANVAS);
  const labA = new Float32Array(CANVAS * CANVAS);
  const labB = new Float32Array(CANVAS * CANVAS);

  for (let index = 0; index < CANVAS * CANVAS; index += 1) {
    const at = index * 3;
    const lab = rgbToLab(data[at] / 255, data[at + 1] / 255, data[at + 2] / 255);
    labL[index] = lab[0];
    labA[index] = lab[1];
    labB[index] = lab[2];
  }

  // The background is read off the top corners rather than the whole border:
  // in a full-length photograph the bottom border is floor, which is a
  // different colour from the wall and would blur the reference.
  const background = cornerBackground(labL, labA, labB);

  const rows: RowStats[] = [];
  for (let y = 0; y < CANVAS; y += 1) {
    let count = 0;
    let sumL = 0;
    let sumA = 0;
    let sumB = 0;
    let from = CANVAS;
    let to = -1;

    for (let x = 0; x < CANVAS; x += 1) {
      const index = y * CANVAS + x;
      const distance = Math.hypot(
        labL[index] - background[0],
        labA[index] - background[1],
        labB[index] - background[2],
      );
      if (distance <= 18) continue;

      count += 1;
      sumL += labL[index];
      sumA += labA[index];
      sumB += labB[index];
      if (x < from) from = x;
      if (x > to) to = x;
    }

    rows.push({
      coverage: count / CANVAS,
      lab: count ? [sumL / count, sumA / count, sumB / count] : [0, 0, 0],
      from: count ? from : 0,
      to: count ? to : 0,
    });
  }

  return rows;
}

function cornerBackground(
  labL: Float32Array,
  labA: Float32Array,
  labB: Float32Array,
): [number, number, number] {
  const patch = Math.round(CANVAS * 0.12);
  let sumL = 0;
  let sumA = 0;
  let sumB = 0;
  let count = 0;

  for (let y = 0; y < patch; y += 1) {
    for (let x = 0; x < patch; x += 1) {
      for (const index of [y * CANVAS + x, y * CANVAS + (CANVAS - 1 - x)]) {
        sumL += labL[index];
        sumA += labA[index];
        sumB += labB[index];
        count += 1;
      }
    }
  }

  return [sumL / count, sumA / count, sumB / count];
}

function figureExtent(rows: RowStats[]): { from: number; to: number } | null {
  let from = -1;
  let to = -1;
  for (let y = 0; y < rows.length; y += 1) {
    if (rows[y].coverage < MIN_ROW_COVERAGE) continue;
    if (from === -1) from = y;
    to = y;
  }
  return from === -1 || to - from < 8 ? null : { from, to };
}

/**
 * Where the colour changes going down the figure.
 *
 * A sliding comparison rather than a per-row difference: a single row differs
 * from its neighbour because of a shadow or a fold, and cutting on that
 * produces forty bands. Comparing the mean of the eight rows above against the
 * eight below asks the question that actually matters — has the garment
 * changed — and answers it once per boundary.
 */
function findCuts(rows: RowStats[], figure: { from: number; to: number }): number[] {
  const window = Math.max(6, Math.round((figure.to - figure.from) * 0.05));
  const cuts: number[] = [];
  let lastCut = figure.from;

  for (let y = figure.from + window; y <= figure.to - window; y += 1) {
    if (y - lastCut < window * 2) continue;

    const above = meanLab(rows, y - window, y - 1);
    const below = meanLab(rows, y, y + window - 1);
    if (!above || !below) continue;

    const delta = Math.hypot(
      above[0] - below[0],
      above[1] - below[1],
      above[2] - below[2],
    );
    if (delta < BAND_SPLIT_DELTA) continue;

    cuts.push(y);
    lastCut = y;
    if (cuts.length >= 3) break;
  }

  return cuts;
}

function meanLab(
  rows: RowStats[],
  from: number,
  to: number,
): [number, number, number] | null {
  let count = 0;
  let sumL = 0;
  let sumA = 0;
  let sumB = 0;

  for (let y = from; y <= to; y += 1) {
    if (!rows[y] || rows[y].coverage < MIN_ROW_COVERAGE) continue;
    sumL += rows[y].lab[0];
    sumA += rows[y].lab[1];
    sumB += rows[y].lab[2];
    count += 1;
  }

  return count ? [sumL / count, sumA / count, sumB / count] : null;
}

function mergeShortBands(
  bands: Array<{ from: number; to: number }>,
  height: number,
): Array<{ from: number; to: number }> {
  const out: Array<{ from: number; to: number }> = [];

  for (const band of bands) {
    const share = (band.to - band.from + 1) / height;
    if (share >= MIN_BAND_SHARE || !out.length) {
      out.push({ ...band });
      continue;
    }
    // Absorb upward. A short band at the hem is the shoes and is worth
    // keeping; one in the middle is a belt, and a belt is not a search.
    out[out.length - 1].to = band.to;
  }

  return out;
}

function horizontalExtent(
  rows: RowStats[],
  band: { from: number; to: number },
): { from: number; to: number } {
  let from = CANVAS;
  let to = 0;
  for (let y = band.from; y <= band.to; y += 1) {
    const row = rows[y];
    if (!row || row.coverage < MIN_ROW_COVERAGE) continue;
    if (row.from < from) from = row.from;
    if (row.to > to) to = row.to;
  }
  return from > to ? { from: 0, to: CANVAS - 1 } : { from, to };
}

/**
 * Which garment a band probably is.
 *
 * "Probably" is doing real work here and is why the confidence is capped. The
 * bottom eighth of a standing figure is shoes with high reliability; the top
 * half is a top *or* the upper half of a dress, and the only thing that
 * separates them is whether a boundary was found lower down — which is
 * precisely what `total` says.
 */
function slotForBand(band: {
  position: number;
  share: number;
  index: number;
  total: number;
}): OutfitSlot | null {
  if (band.position >= 0.86) return OutfitSlot.SHOES;
  // A band covering most of the figure with nothing below it but shoes is a
  // dress or an abaya, not a top.
  if (band.share >= 0.55) return OutfitSlot.DRESS;
  if (band.position < 0.46) return OutfitSlot.TOP;
  if (band.position < 0.86) return OutfitSlot.BOTTOM;
  return null;
}

function bandConfidence(
  rows: RowStats[],
  band: { from: number; to: number },
  attributes: VisualAttributes,
): number {
  let covered = 0;
  for (let y = band.from; y <= band.to; y += 1) {
    if (rows[y] && rows[y].coverage >= MIN_ROW_COVERAGE) covered += 1;
  }
  const solidity = covered / Math.max(1, band.to - band.from + 1);

  // A plain, even background is what makes the subject mask trustworthy; a
  // busy street behind her makes every row look like subject.
  const backing = attributes.studioBackground ? 1 : 0.72;

  return Math.min(LAYOUT_CONFIDENCE_CEILING, 0.34 + solidity * 0.2 * backing + 0.1 * backing);
}

const SLOT_LABELS: Partial<Record<OutfitSlot, string>> = {
  [OutfitSlot.DRESS]: 'الفستان',
  [OutfitSlot.TOP]: 'القطعة العلوية',
  [OutfitSlot.BOTTOM]: 'القطعة السفلية',
  [OutfitSlot.SHOES]: 'الحذاء',
  [OutfitSlot.BAG]: 'الحقيبة',
  [OutfitSlot.JEWELRY]: 'الإكسسوار',
  [OutfitSlot.OUTERWEAR]: 'الجاكيت',
  [OutfitSlot.ABAYA]: 'العباية',
};

export function slotRegionLabel(slot: OutfitSlot | null): string {
  return (slot && SLOT_LABELS[slot]) || 'قطعة بالإطلالة';
}

/**
 * The gate a vision model's detections pass through.
 *
 * Same contract as `sanitiseBrief`: unknown slots dropped, boxes clamped into
 * the frame, confidences clamped to 0–1, degenerate boxes discarded, and the
 * list capped. A model that returns forty overlapping boxes proposes four.
 */
export function sanitiseDetections(input: unknown): DetectedRegion[] {
  if (!Array.isArray(input)) return [];

  const slots = new Set<string>(Object.values(OutfitSlot));
  const out: DetectedRegion[] = [];

  for (const raw of input) {
    if (!raw || typeof raw !== 'object') continue;
    const record = raw as Record<string, unknown>;

    const slotValue = String(record['slot'] ?? '').toUpperCase();
    const slot = slots.has(slotValue) ? (slotValue as OutfitSlot) : null;

    const boxValue = record['box'];
    if (!boxValue || typeof boxValue !== 'object') continue;
    const boxRecord = boxValue as Record<string, unknown>;

    const x = clamp01(number(boxRecord['x']));
    const y = clamp01(number(boxRecord['y']));
    const w = clamp01(number(boxRecord['w']));
    const h = clamp01(number(boxRecord['h']));
    // A box smaller than a twelfth of the frame in either direction is not a
    // garment worth searching for; one that runs past the edge is a model that
    // has lost track of the coordinate system.
    if (w < 0.08 || h < 0.06 || x + w > 1.001 || y + h > 1.001) continue;

    const label = typeof record['label'] === 'string' ? record['label'].trim() : '';

    out.push({
      detector: VisualRegionDetector.VISION,
      slot,
      label: label.slice(0, 40) || slotRegionLabel(slot),
      box: { x, y, w: Math.min(w, 1 - x), h: Math.min(h, 1 - y) },
      confidence: Math.min(1, Math.max(0, number(record['confidence']) || 0.5)),
    });
    if (out.length >= 4) break;
  }

  return out;
}

function number(value: unknown): number {
  const parsed = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return value < 0 ? 0 : value > 1 ? 1 : value;
}
