/**
 * The shape of a visual descriptor, and the arithmetic that compares two.
 *
 * A descriptor is not one opaque vector. It is five **blocks**, laid end to
 * end, each of which answers a different question about a photograph and each
 * of which is independently unit-length:
 *
 *   colour   — what colours are in it, and how much of each
 *   layout   — where those colours sit in the frame
 *   shape    — the silhouette: which way the edges run, and at what height
 *   texture  — plain or patterned, smooth or busy
 *   geometry — the crop itself: portrait or square, garment-filling or distant
 *
 * Keeping them apart rather than concatenating into one soup buys three things
 * that matter for this feature:
 *
 *  1. **The similarity is explainable.** A card can say "نفس اللون والقصّة"
 *     because the colour and shape blocks scored, not because a black box did.
 *  2. **The comparison can be re-weighted per query.** "نفس الفستان بس بالأسود"
 *     is exactly "compare everything except colour", which here is a change of
 *     one number rather than a different model. See `weightsForQuery`.
 *  3. **A block can be replaced.** Swapping the shape block for a learned one
 *     leaves the other four, and the stored rows, alone.
 *
 * Because every block is unit-length, the dot product over a block *is* its
 * cosine, and the overall similarity is a weighted mean of five cosines — a
 * number that can be taken apart back to its parts. That is the whole reason
 * the percentages this feature renders are defensible.
 */

export type BlockName = 'colour' | 'layout' | 'shape' | 'texture' | 'geometry';

export interface DescriptorBlock {
  name: BlockName;
  /** Index of the block's first component in the flat vector. */
  offset: number;
  length: number;
  /**
   * How much this block counts when nothing about the query says otherwise.
   *
   * Colour leads because it is what a woman means first by "زي هاد" — but not
   * by so much that a black dress matches a black handbag, which is what the
   * shape and layout blocks are there to prevent.
   */
  weight: number;
}

/** 12 hues × 2 saturation levels × 2 value levels, plus 6 achromatic steps. */
const COLOUR_DIMS = 12 * 2 * 2 + 6;
/** A 4×4 grid, each cell carrying L and a signed-split a/b pair. */
const LAYOUT_DIMS = 16 * 5;
/** 8 gradient orientations at each of 3 heights. */
const SHAPE_DIMS = 8 * 3;
/** 16 cell contrasts plus 4 whole-frame statistics. */
const TEXTURE_DIMS = 20;
/** Aspect one-hot (3), subject fill, centrality, border uniformity. */
const GEOMETRY_DIMS = 6;

export const DESCRIPTOR_BLOCKS: readonly DescriptorBlock[] = (() => {
  const spec: Array<[BlockName, number, number]> = [
    ['colour', COLOUR_DIMS, 0.4],
    ['layout', LAYOUT_DIMS, 0.18],
    ['shape', SHAPE_DIMS, 0.24],
    ['texture', TEXTURE_DIMS, 0.14],
    ['geometry', GEOMETRY_DIMS, 0.04],
  ];

  let offset = 0;
  return spec.map(([name, length, weight]) => {
    const block = { name, offset, length, weight };
    offset += length;
    return block;
  });
})();

export const DESCRIPTOR_DIMENSIONS = DESCRIPTOR_BLOCKS.reduce(
  (total, block) => total + block.length,
  0,
);

export type BlockWeights = Record<BlockName, number>;

export function defaultWeights(): BlockWeights {
  return Object.fromEntries(
    DESCRIPTOR_BLOCKS.map((block) => [block.name, block.weight]),
  ) as BlockWeights;
}

/**
 * The per-block cosines between two descriptors.
 *
 * Returns zero for a block whose vectors are the wrong length rather than
 * throwing: a row written by an older build of the same embedder name would
 * otherwise take down a search, and a search that shows fewer things is a much
 * smaller failure than one that shows an error page.
 */
export function blockSimilarities(
  a: readonly number[],
  b: readonly number[],
): Record<BlockName, number> {
  const out = {} as Record<BlockName, number>;

  for (const block of DESCRIPTOR_BLOCKS) {
    const end = block.offset + block.length;
    if (a.length < end || b.length < end) {
      out[block.name] = 0;
      continue;
    }

    let dot = 0;
    for (let index = block.offset; index < end; index += 1) {
      dot += a[index] * b[index];
    }
    // Every block is stored unit-length and every component is non-negative,
    // so the dot product is already the cosine and already in [0, 1]. The
    // clamp guards against float drift at the ends, not against bad data.
    out[block.name] = clamp01(dot);
  }

  return out;
}

/** The weighted mean of the block cosines. Always in [0, 1]. */
export function weightedSimilarity(
  similarities: Record<BlockName, number>,
  weights: BlockWeights,
): number {
  let total = 0;
  let mass = 0;
  for (const block of DESCRIPTOR_BLOCKS) {
    const weight = Math.max(0, weights[block.name] ?? 0);
    total += weight * (similarities[block.name] ?? 0);
    mass += weight;
  }
  return mass > 0 ? clamp01(total / mass) : 0;
}

export function cosine(a: readonly number[], b: readonly number[]): number {
  return weightedSimilarity(blockSimilarities(a, b), defaultWeights());
}

/**
 * The weights this particular query should be compared with.
 *
 * One rule, and it is the one that makes text refinement work honestly. When
 * she names a colour the photograph does not contain — "نفس هالفستان بس
 * بالأسود" — she has told us that the colour block is no longer evidence.
 * Leaving it at full weight would rank every black dress *below* the ones that
 * match her screenshot's cream, which is the opposite of what she asked for.
 *
 * The block is not dropped to zero: a black dress with cream trim is still
 * closer to a cream photograph than a black one is, and that little bit of
 * signal is worth keeping. The freed weight goes to shape and texture, which
 * is what "the same dress" means once colour is off the table.
 */
export function weightsForQuery(options: {
  /** Colour keys read out of the photograph. */
  imageColours: readonly string[];
  /** Colour keys she asked for in words, if any. */
  requestedColours: readonly string[];
}): BlockWeights {
  const weights = defaultWeights();

  const requested = options.requestedColours.filter(Boolean);
  if (!requested.length) return weights;

  const overlaps = requested.some((colour) => options.imageColours.includes(colour));
  if (overlaps) return weights;

  const freed = weights.colour - 0.08;
  weights.colour = 0.08;
  weights.shape += freed * 0.6;
  weights.texture += freed * 0.4;
  return weights;
}

/**
 * Turns a raw cosine into the percentage on the card.
 *
 * This exists because a raw cosine is not a percentage and printing one as if
 * it were would be a lie. Two unrelated fashion photographs share a great deal
 * under this descriptor — a garment, centred, on a plain ground, shot in
 * portrait — so their cosine lands well above zero. Rendering that as "٦٨٪
 * مشابه" would put a number next to a product that is not a match.
 *
 * So the scale is anchored: `floor` is the cosine below which two images are
 * not usefully alike, `ceiling` the cosine at which they are the same
 * photograph of the same garment. Between them the mapping is linear, then
 * eased so the top of the range is harder to reach than the bottom — 95% has
 * to be earned.
 *
 * The anchors are a property of the descriptor, not of the catalogue, which is
 * why they travel on the embedder (`VisualEmbedder.anchors`) and why a swapped
 * provider must bring its own. They are asserted in `similarity.spec.ts`.
 */
export function displayedSimilarity(
  rawSimilarity: number,
  anchors: { floor: number; ceiling: number },
): number {
  const { floor, ceiling } = anchors;
  if (ceiling <= floor) return 0;

  const linear = clamp01((rawSimilarity - floor) / (ceiling - floor));
  // Ease-out below the midpoint, ease-in above it: the curve is flat where
  // "somewhat alike" lives and steep where "the same thing" does.
  return clamp01(Math.pow(linear, 1.25));
}

/** L2-normalises in place and returns the array, for a block builder. */
export function normaliseBlock(values: number[]): number[] {
  let sum = 0;
  for (const value of values) sum += value * value;

  const norm = Math.sqrt(sum);
  // An all-zero block — a pure white image has no edges — stays all-zero
  // rather than becoming NaN. It then contributes a cosine of 0, which is the
  // truthful answer: there is nothing here to agree about.
  if (norm <= 1e-9) return values;

  for (let index = 0; index < values.length; index += 1) {
    values[index] /= norm;
  }
  return values;
}

export function clamp01(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return value < 0 ? 0 : value > 1 ? 1 : value;
}
