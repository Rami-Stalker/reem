import {
  BlockName,
  DESCRIPTOR_BLOCKS,
  DESCRIPTOR_DIMENSIONS,
  normaliseBlock,
} from './visual-descriptor';

/**
 * Pixels in, five blocks out.
 *
 * Everything in this file is a pure function over a raw RGB buffer. No sharp,
 * no database, no configuration, no clock — which is what lets the whole
 * similarity story be tested with a handful of synthetic bitmaps and lets a
 * product's vector be recomputed years later and come out identical.
 *
 * The signals were chosen to answer the question a woman is actually asking
 * when she holds up a screenshot, in the order she would ask it: what colour
 * is it, where is that colour, what shape is it, is it plain or patterned. A
 * learned embedding would answer all four at once and better; this answers
 * them separately, today, with no model to host, and — because the blocks stay
 * separate — leaves the door open for a learned one to replace any single
 * block later.
 */

/** The square every image is resampled to before any of this runs. */
export const CANVAS = 224;

/** How many cells on a side the layout and texture grids use. */
const GRID = 4;

/** Below this saturation a pixel is treated as a shade of grey, not a hue. */
const ACHROMATIC_SATURATION = 0.16;

/**
 * The absolute colourfulness below which a pixel has no hue worth recording.
 *
 * Saturation alone is not enough, and getting this wrong was a real bug: HSV
 * saturation is `chroma ÷ value`, so it *rises* as a pixel gets darker for the
 * same absolute colour difference. Near-black `rgb(18, 18, 22)` — four units
 * of blue introduced by JPEG quantisation — computes a saturation of 0.18 and
 * was being filed under "dark blue", while `rgb(28, 26, 30)`, the same black
 * one stop brighter, computed 0.13 and was filed under "black". Two
 * photographs of the same black dress landed in different colour bins and
 * scored 0.67 against each other.
 *
 * Chroma (`max − min`, which is `value × saturation`) does not have that
 * behaviour: it is small whenever the pixel is actually close to grey,
 * whatever its brightness. A real navy clears this comfortably.
 */
const MIN_CHROMA = 0.06;

export interface RawImage {
  /** Tightly packed RGB, `CANVAS * CANVAS * 3` bytes. */
  data: Uint8Array | Buffer;
  /** The source's dimensions before the square resample, for the aspect read. */
  sourceWidth: number;
  sourceHeight: number;
}

export interface VisualSignals {
  /** The flat descriptor: five unit-length blocks, laid end to end. */
  vector: number[];
  /** The interpretable readings, for attributes and for the card's reason. */
  readings: SignalReadings;
}

export interface SignalReadings {
  /**
   * Dominant hue/tone buckets in descending share, as `{ bucket, share }`.
   * Mapped to lexicon colour names by `visual-attributes.ts` — this file has
   * no opinion about what "أسود" is called.
   */
  palette: Array<{ hue: number | null; lightness: number; saturation: number; share: number }>;
  /** 0–1. How busy the surface is: near 0 plain, above ~0.45 patterned. */
  patternEnergy: number;
  /** 0–1. How much of the frame the subject occupies. */
  subjectFill: number;
  /** 0–1. How uniform the border is — a proxy for a studio background. */
  borderUniformity: number;
  /** Source aspect, width ÷ height. */
  aspect: number;
  /** 0–1 per third, top to bottom: where the edge energy sits. */
  edgeProfile: [number, number, number];
  /** Mean lightness, 0–1. */
  lightness: number;
}

export function computeSignals(image: RawImage): VisualSignals {
  const { data } = image;
  const pixels = CANVAS * CANVAS;

  // ── One pass, five accumulators ──────────────────────────────────────
  //
  // Deliberately a single traversal that fills every per-pixel structure at
  // once. A product with eight photographs is eight of these, and the indexer
  // runs over the whole catalogue.

  const luma = new Float32Array(pixels);
  const labL = new Float32Array(pixels);
  const labA = new Float32Array(pixels);
  const labB = new Float32Array(pixels);

  const bins = new Uint8Array(pixels);
  let lightnessSum = 0;

  for (let index = 0; index < pixels; index += 1) {
    const at = index * 3;
    const r = data[at] / 255;
    const g = data[at + 1] / 255;
    const b = data[at + 2] / 255;

    luma[index] = 0.2126 * r + 0.7152 * g + 0.0722 * b;
    lightnessSum += luma[index];

    const lab = rgbToLab(r, g, b);
    labL[index] = lab[0];
    labA[index] = lab[1];
    labB[index] = lab[2];

    const [hue, saturation, value] = rgbToHsv(r, g, b);
    bins[index] = colourBin(hue, saturation, value);
  }

  // ── Colour ───────────────────────────────────────────────────────────
  //
  // Second pass, and the reason it is second is the background.
  //
  // A boutique photograph is a garment on seamless white paper, and the paper
  // is most of the frame. Accumulating every pixel made "أبيض" the *dominant*
  // colour of a black dress — which then went into the brief, into the palette
  // pre-filter and onto a chip that told her the app had misread her picture.
  // Centre weighting alone did not fix it: the backdrop is at the centre too,
  // above and below her.
  //
  // So when the border is uniform enough to trust as a background reading,
  // pixels that match it are left out of the histogram entirely. When it is
  // not — a street, a bedroom, a busy feed screenshot — the mask would eat the
  // garment along with the wall, so every pixel counts and the centre
  // weighting does what it can on its own.
  const border = borderStatistics(labL, labA, labB);
  const colour = new Array<number>(blockLength('colour')).fill(0);
  const paletteWeight = new Map<number, number>();

  const maskBackground = border.uniformity >= 0.55;
  let accumulate = (index: number, weight: number) => {
    colour[bins[index]] += weight;
    paletteWeight.set(bins[index], (paletteWeight.get(bins[index]) ?? 0) + weight);
  };

  if (maskBackground) {
    // A cut-out on white leaves almost nothing behind. Below this the mask has
    // clearly eaten the subject, and counting everything is the safer answer.
    let kept = 0;
    for (let index = 0; index < pixels; index += 1) {
      if (backgroundDistance(labL, labA, labB, border, index) > 18) kept += 1;
    }
    if (kept < pixels * 0.06) {
      // Leave `accumulate` counting every pixel.
    } else {
      const unmasked = accumulate;
      accumulate = (index, weight) => {
        if (backgroundDistance(labL, labA, labB, border, index) <= 18) return;
        unmasked(index, weight);
      };
    }
  }

  for (let index = 0; index < pixels; index += 1) {
    const y = (index / CANVAS) | 0;
    const x = index - y * CANVAS;
    // Centre weighting on top of the mask. A screenshot from Instagram is a
    // garment in the middle and a room around it, and the room is not always
    // separable from the clothes.
    accumulate(index, centreWeight(x, y));
  }

  // ── Layout ───────────────────────────────────────────────────────────
  //
  // Mean Lab per cell, with a and b split into positive and negative halves so
  // every component stays non-negative and the block cosine stays in [0, 1].

  const layout = new Array<number>(blockLength('layout')).fill(0);
  const cellSide = CANVAS / GRID;

  for (let cellY = 0; cellY < GRID; cellY += 1) {
    for (let cellX = 0; cellX < GRID; cellX += 1) {
      let sumL = 0;
      let sumA = 0;
      let sumB = 0;
      let count = 0;

      const fromY = Math.round(cellY * cellSide);
      const toY = Math.round((cellY + 1) * cellSide);
      const fromX = Math.round(cellX * cellSide);
      const toX = Math.round((cellX + 1) * cellSide);

      for (let y = fromY; y < toY; y += 1) {
        for (let x = fromX; x < toX; x += 1) {
          const index = y * CANVAS + x;
          sumL += labL[index];
          sumA += labA[index];
          sumB += labB[index];
          count += 1;
        }
      }

      if (!count) continue;
      const meanL = sumL / count / 100;
      const meanA = sumA / count / 128;
      const meanB = sumB / count / 128;

      const base = (cellY * GRID + cellX) * 5;
      layout[base] = clampUnit(meanL);
      layout[base + 1] = clampUnit(Math.max(0, meanA));
      layout[base + 2] = clampUnit(Math.max(0, -meanA));
      layout[base + 3] = clampUnit(Math.max(0, meanB));
      layout[base + 4] = clampUnit(Math.max(0, -meanB));
    }
  }

  // ── Shape and texture ────────────────────────────────────────────────
  //
  // One Sobel pass feeds both: orientation histograms by height for the
  // silhouette, magnitude statistics by cell for the surface.

  const shape = new Array<number>(blockLength('shape')).fill(0);
  const cellEnergy = new Array<number>(GRID * GRID).fill(0);
  const cellCount = new Array<number>(GRID * GRID).fill(0);
  const thirdEnergy: [number, number, number] = [0, 0, 0];

  let magnitudeSum = 0;
  let edgePixels = 0;

  for (let y = 1; y < CANVAS - 1; y += 1) {
    for (let x = 1; x < CANVAS - 1; x += 1) {
      const index = y * CANVAS + x;

      const gx =
        luma[index - CANVAS + 1] +
        2 * luma[index + 1] +
        luma[index + CANVAS + 1] -
        luma[index - CANVAS - 1] -
        2 * luma[index - 1] -
        luma[index + CANVAS - 1];
      const gy =
        luma[index + CANVAS - 1] +
        2 * luma[index + CANVAS] +
        luma[index + CANVAS + 1] -
        luma[index - CANVAS - 1] -
        2 * luma[index - CANVAS] -
        luma[index - CANVAS + 1];

      const magnitude = Math.hypot(gx, gy);
      magnitudeSum += magnitude;
      if (magnitude > 0.25) edgePixels += 1;

      // Orientation is taken modulo π: an edge running north-east is the same
      // hemline as one running south-west, and treating them as different
      // would make a mirrored photograph a different garment.
      const orientation = ((Math.atan2(gy, gx) + Math.PI) % Math.PI) / Math.PI;
      const orientationBin = Math.min(7, Math.floor(orientation * 8));
      const third = Math.min(2, Math.floor((y / CANVAS) * 3));

      shape[third * 8 + orientationBin] += magnitude;
      thirdEnergy[third] += magnitude;

      const cell =
        Math.min(GRID - 1, Math.floor((y / CANVAS) * GRID)) * GRID +
        Math.min(GRID - 1, Math.floor((x / CANVAS) * GRID));
      cellEnergy[cell] += magnitude;
      cellCount[cell] += 1;
    }
  }

  const interior = (CANVAS - 2) * (CANVAS - 2);
  const meanMagnitude = magnitudeSum / interior;
  const edgeDensity = edgePixels / interior;

  // ── Subject extent ───────────────────────────────────────────────────
  //
  // The same background reading the colour pass used, reused: how much of the
  // frame is not the backdrop, and how centred it is.

  let subjectPixels = 0;
  let subjectRadiusSum = 0;

  for (let index = 0; index < pixels; index += 1) {
    // 18 in Lab is comfortably past "the same wall under a different light"
    // and comfortably short of "a cream dress against a white backdrop".
    if (backgroundDistance(labL, labA, labB, border, index) <= 18) continue;

    subjectPixels += 1;
    const y = (index / CANVAS) | 0;
    const x = index - y * CANVAS;
    subjectRadiusSum += radiusFromCentre(x, y);
  }

  const subjectFill = subjectPixels / pixels;
  const centrality =
    subjectPixels > 0 ? clampUnit(1 - subjectRadiusSum / subjectPixels) : 0;

  let luminanceSum = 0;
  let luminanceSquares = 0;
  for (let index = 0; index < pixels; index += 1) {
    luminanceSum += luma[index];
    luminanceSquares += luma[index] * luma[index];
  }
  const luminanceMean = luminanceSum / pixels;
  const luminanceStd = Math.sqrt(
    Math.max(0, luminanceSquares / pixels - luminanceMean * luminanceMean),
  );

  const texture = new Array<number>(blockLength('texture')).fill(0);
  for (let cell = 0; cell < GRID * GRID; cell += 1) {
    texture[cell] = cellCount[cell] ? compress(cellEnergy[cell] / cellCount[cell], 0.35) : 0;
  }
  texture[16] = compress(meanMagnitude, 0.35);
  texture[17] = clampUnit(edgeDensity);
  texture[18] = compress(luminanceStd, 0.25);
  texture[19] = compress(cellDispersion(cellEnergy, cellCount), 0.25);

  // ── Geometry ─────────────────────────────────────────────────────────

  const aspect =
    image.sourceHeight > 0 ? image.sourceWidth / image.sourceHeight : 1;
  const geometry = new Array<number>(blockLength('geometry')).fill(0);
  geometry[aspect < 0.85 ? 0 : aspect > 1.18 ? 2 : 1] = 1;
  geometry[3] = clampUnit(subjectFill);
  geometry[4] = centrality;
  geometry[5] = clampUnit(border.uniformity);

  const vector = [
    ...normaliseBlock(colour),
    ...normaliseBlock(layout),
    ...normaliseBlock(shape),
    ...normaliseBlock(texture),
    ...normaliseBlock(geometry),
  ];

  /* istanbul ignore next — a length mismatch is a programming error in the
     block table above, not a runtime condition. */
  if (vector.length !== DESCRIPTOR_DIMENSIONS) {
    throw new Error(
      `Descriptor length ${vector.length} does not match the declared ${DESCRIPTOR_DIMENSIONS}.`,
    );
  }

  const energyTotal = thirdEnergy[0] + thirdEnergy[1] + thirdEnergy[2] || 1;

  return {
    vector,
    readings: {
      palette: topPalette(paletteWeight, pixels),
      // Busyness of the *surface* rather than of the frame: a plain dress on a
      // patterned rug should still read as plain, which is why this is the
      // median cell rather than the mean — one loud cell cannot carry it.
      patternEnergy: compress(medianCellEnergy(cellEnergy, cellCount), 0.35),
      subjectFill: clampUnit(subjectFill),
      borderUniformity: clampUnit(border.uniformity),
      aspect,
      edgeProfile: [
        thirdEnergy[0] / energyTotal,
        thirdEnergy[1] / energyTotal,
        thirdEnergy[2] / energyTotal,
      ],
      lightness: clampUnit(lightnessSum / pixels),
    },
  };
}

// ── Colour bins ─────────────────────────────────────────────────────────

/**
 * Which of the 54 colour bins a pixel falls in.
 *
 * The split between chromatic and achromatic is the important line. Black,
 * white, grey, cream and beige are the backbone of this catalogue, and folding
 * them into a hue wheel — where they land on whatever tint the camera's white
 * balance introduced — is how a beige abaya matches a pale pink one.
 */
export function colourBin(hue: number, saturation: number, value: number): number {
  if (
    saturation < ACHROMATIC_SATURATION ||
    saturation * value < MIN_CHROMA ||
    value < 0.08
  ) {
    const step = Math.min(5, Math.floor(value * 6));
    return 48 + step;
  }
  const hueBin = Math.min(11, Math.floor((hue / 360) * 12));
  const saturationLevel = saturation < 0.5 ? 0 : 1;
  const valueLevel = value < 0.5 ? 0 : 1;
  return hueBin * 4 + saturationLevel * 2 + valueLevel;
}

/** The inverse reading of a bin, for the attribute layer. */
export function binToReading(bin: number): {
  hue: number | null;
  lightness: number;
  saturation: number;
} {
  if (bin >= 48) {
    const step = bin - 48;
    return { hue: null, lightness: (step + 0.5) / 6, saturation: 0 };
  }
  const hueBin = Math.floor(bin / 4);
  const rest = bin % 4;
  return {
    hue: (hueBin + 0.5) * 30,
    saturation: rest >= 2 ? 0.75 : 0.32,
    lightness: rest % 2 === 1 ? 0.75 : 0.3,
  };
}

// ── Helpers ─────────────────────────────────────────────────────────────

function blockLength(name: BlockName): number {
  const block = DESCRIPTOR_BLOCKS.find((entry) => entry.name === name);
  /* istanbul ignore next — unreachable while the block table is complete. */
  if (!block) throw new Error(`Unknown descriptor block: ${name}`);
  return block.length;
}

function topPalette(
  weights: Map<number, number>,
  pixels: number,
): SignalReadings['palette'] {
  const total = [...weights.values()].reduce((sum, value) => sum + value, 0) || pixels;
  return [...weights.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 6)
    .map(([bin, weight]) => ({ ...binToReading(bin), share: weight / total }));
}

function centreWeight(x: number, y: number): number {
  const radius = radiusFromCentre(x, y);
  return 0.35 + 0.65 * Math.exp(-(radius * radius) / (2 * 0.42 * 0.42));
}

/** Distance from the frame's centre, 0 at the middle and 1 at a corner. */
function radiusFromCentre(x: number, y: number): number {
  const half = CANVAS / 2;
  const dx = (x - half) / half;
  const dy = (y - half) / half;
  return Math.min(1, Math.hypot(dx, dy) / Math.SQRT2);
}

/** Lab distance from one pixel to the frame's background reading. */
function backgroundDistance(
  labL: Float32Array,
  labA: Float32Array,
  labB: Float32Array,
  border: { meanL: number; meanA: number; meanB: number },
  index: number,
): number {
  return Math.hypot(
    labL[index] - border.meanL,
    labA[index] - border.meanA,
    labB[index] - border.meanB,
  );
}

/**
 * The frame's background, read from its four corners.
 *
 * Corners rather than a band around the whole edge, and the reason is the
 * salience crop upstream. `ImageProcessingService` resamples by attention, so
 * the canvas is centred on the garment and the top and bottom edges of a
 * full-length photograph are *dress*, not backdrop. Averaging the whole border
 * therefore mixed paper with fabric, reported a uniformity of 0.31 for a black
 * dress on seamless white, and stopped the background mask from ever engaging.
 *
 * Corners survive that crop: a subject is centred by construction, so the four
 * corners are the last places the backdrop remains. It is the same reading the
 * region segmenter takes, for the same reason, and having the two agree is
 * worth more than either being marginally cleverer.
 *
 * `uniformity` is the agreement *among* the corners. Seamless paper puts all
 * four within a couple of Lab units of each other; a room, a street or a busy
 * feed screenshot does not, and the mask stays off.
 */
function borderStatistics(
  labL: Float32Array,
  labA: Float32Array,
  labB: Float32Array,
): { meanL: number; meanA: number; meanB: number; uniformity: number } {
  const patch = Math.max(8, Math.round(CANVAS * 0.12));

  let sumL = 0;
  let sumA = 0;
  let sumB = 0;
  let count = 0;

  const corners: Array<[number, number]> = [];
  for (let y = 0; y < patch; y += 1) {
    for (let x = 0; x < patch; x += 1) {
      corners.push([x, y]);
      corners.push([CANVAS - 1 - x, y]);
      corners.push([x, CANVAS - 1 - y]);
      corners.push([CANVAS - 1 - x, CANVAS - 1 - y]);
    }
  }

  for (const [x, y] of corners) {
    const index = y * CANVAS + x;
    sumL += labL[index];
    sumA += labA[index];
    sumB += labB[index];
    count += 1;
  }

  const meanL = sumL / count;
  const meanA = sumA / count;
  const meanB = sumB / count;

  let deviation = 0;
  for (const [x, y] of corners) {
    const index = y * CANVAS + x;
    deviation += Math.hypot(
      labL[index] - meanL,
      labA[index] - meanA,
      labB[index] - meanB,
    );
  }

  // 25 units of mean Lab deviation is a busy street scene; 2 is a seamless
  // paper backdrop.
  return {
    meanL,
    meanA,
    meanB,
    uniformity: clampUnit(1 - deviation / count / 25),
  };
}

function medianCellEnergy(energy: number[], counts: number[]): number {
  const values = energy
    .map((total, cell) => (counts[cell] ? total / counts[cell] : 0))
    .sort((a, b) => a - b);
  const middle = values.length >> 1;
  return values.length % 2
    ? values[middle]
    : (values[middle - 1] + values[middle]) / 2;
}

function cellDispersion(energy: number[], counts: number[]): number {
  const values = energy.map((total, cell) => (counts[cell] ? total / counts[cell] : 0));
  const mean = values.reduce((sum, value) => sum + value, 0) / (values.length || 1);
  const variance =
    values.reduce((sum, value) => sum + (value - mean) ** 2, 0) / (values.length || 1);
  return Math.sqrt(variance);
}

/**
 * Squashes an unbounded measurement into 0–1 without ever flattening.
 *
 * `value ÷ (value + k)` rather than `min(1, value ÷ k)`, and the difference is
 * not cosmetic — it was a bug. Gradient magnitudes run from near zero on a
 * plain surface to about four across a hard edge, and a hard clamp sent every
 * cell above the ceiling to exactly 1. A plain dress (bright only at its
 * outline) and a striped one (bright everywhere) both became vectors of ones
 * in the same cells and scored 0.999 on the texture block, which is precisely
 * the distinction the block exists to make.
 *
 * This curve is monotone over the whole range, so a busier surface always
 * scores higher than a calmer one, and `k` is simply the value that maps to a
 * half.
 */
function compress(value: number, k: number): number {
  if (!Number.isFinite(value) || value <= 0) return 0;
  return value / (value + k);
}

export function rgbToHsv(r: number, g: number, b: number): [number, number, number] {
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const delta = max - min;

  let hue = 0;
  if (delta > 1e-6) {
    if (max === r) hue = 60 * (((g - b) / delta) % 6);
    else if (max === g) hue = 60 * ((b - r) / delta + 2);
    else hue = 60 * ((r - g) / delta + 4);
  }
  if (hue < 0) hue += 360;

  return [hue, max <= 1e-6 ? 0 : delta / max, max];
}

/** sRGB (0–1) to CIE L*a*b* under D65. */
export function rgbToLab(r: number, g: number, b: number): [number, number, number] {
  const lr = srgbToLinear(r);
  const lg = srgbToLinear(g);
  const lb = srgbToLinear(b);

  const x = (lr * 0.4124564 + lg * 0.3575761 + lb * 0.1804375) / 0.95047;
  const y = lr * 0.2126729 + lg * 0.7151522 + lb * 0.072175;
  const z = (lr * 0.0193339 + lg * 0.119192 + lb * 0.9503041) / 1.08883;

  const fx = labF(x);
  const fy = labF(y);
  const fz = labF(z);

  return [116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz)];
}

function srgbToLinear(channel: number): number {
  return channel <= 0.04045
    ? channel / 12.92
    : Math.pow((channel + 0.055) / 1.055, 2.4);
}

function labF(value: number): number {
  return value > 0.008856 ? Math.cbrt(value) : 7.787 * value + 16 / 116;
}

function clampUnit(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return value < 0 ? 0 : value > 1 ? 1 : value;
}
