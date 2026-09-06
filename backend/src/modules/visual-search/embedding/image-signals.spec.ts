import assert from 'node:assert/strict';
import test from 'node:test';
import { CANVAS, RawImage, colourBin, computeSignals, rgbToHsv, rgbToLab } from './image-signals';
import { PerceptualVisualEmbedder } from './perceptual-embedder';
import {
  DESCRIPTOR_BLOCKS,
  DESCRIPTOR_DIMENSIONS,
  blockSimilarities,
  displayedSimilarity,
  weightsForQuery,
} from './visual-descriptor';

/**
 * The similarity story, tested on bitmaps drawn by hand.
 *
 * Every number this feature renders comes out of these functions, so they are
 * exercised directly rather than through a mocked search. The images below are
 * synthetic on purpose: a solid black frame and a solid white one *must* be
 * far apart, and if a change ever makes them close, the descriptor is broken
 * in a way no catalogue fixture would show as clearly.
 */

/** A flat canvas of one colour. */
function solid(r: number, g: number, b: number, aspect = 1): RawImage {
  const data = new Uint8Array(CANVAS * CANVAS * 3);
  for (let index = 0; index < CANVAS * CANVAS; index += 1) {
    data[index * 3] = r;
    data[index * 3 + 1] = g;
    data[index * 3 + 2] = b;
  }
  return { data, sourceWidth: Math.round(1000 * aspect), sourceHeight: 1000 };
}

/** A centred rectangle of one colour on a white ground. */
function garment(
  r: number,
  g: number,
  b: number,
  options: { stripes?: boolean; width?: number } = {},
): RawImage {
  const data = new Uint8Array(CANVAS * CANVAS * 3).fill(245);
  const halfWidth = Math.round((options.width ?? 0.42) * CANVAS) >> 1;

  for (let y = Math.round(CANVAS * 0.12); y < Math.round(CANVAS * 0.9); y += 1) {
    for (let x = CANVAS / 2 - halfWidth; x < CANVAS / 2 + halfWidth; x += 1) {
      const index = (y * CANVAS + Math.round(x)) * 3;
      // Stripes are how the texture block is given something to see.
      const dark = options.stripes && Math.floor(y / 6) % 2 === 0;
      data[index] = dark ? Math.max(0, r - 90) : r;
      data[index + 1] = dark ? Math.max(0, g - 90) : g;
      data[index + 2] = dark ? Math.max(0, b - 90) : b;
    }
  }
  return { data, sourceWidth: 800, sourceHeight: 1200 };
}

test('the descriptor is exactly as long as the block table declares', () => {
  const declared = DESCRIPTOR_BLOCKS.reduce((sum, block) => sum + block.length, 0);
  assert.equal(declared, DESCRIPTOR_DIMENSIONS);
  assert.equal(computeSignals(solid(10, 10, 10)).vector.length, DESCRIPTOR_DIMENSIONS);
});

test('every block is unit length, so a block dot product is its cosine', () => {
  const { vector } = computeSignals(garment(200, 40, 60));

  for (const block of DESCRIPTOR_BLOCKS) {
    const slice = vector.slice(block.offset, block.offset + block.length);
    const norm = Math.sqrt(slice.reduce((sum, value) => sum + value * value, 0));
    // An all-zero block is allowed to stay zero — see `normaliseBlock`.
    assert.ok(
      Math.abs(norm - 1) < 1e-6 || norm === 0,
      `block ${block.name} had norm ${norm}`,
    );
  }
});

test('every component is non-negative, so every block cosine lands in [0, 1]', () => {
  const { vector } = computeSignals(garment(30, 90, 160, { stripes: true }));
  assert.ok(vector.every((value) => value >= 0));

  const other = computeSignals(garment(240, 220, 200)).vector;
  for (const value of Object.values(blockSimilarities(vector, other))) {
    assert.ok(value >= 0 && value <= 1, `cosine out of range: ${value}`);
  }
});

test('the same image scores 1 against itself', () => {
  const embedder = new PerceptualVisualEmbedder();
  const { vector } = computeSignals(garment(20, 20, 24));
  assert.ok(Math.abs(embedder.similarity(vector, vector).total - 1) < 1e-9);
});

test('a black garment is closer to another black garment than to a white one', () => {
  const embedder = new PerceptualVisualEmbedder();
  const black = computeSignals(garment(18, 18, 22)).vector;
  const alsoBlack = computeSignals(garment(28, 26, 30)).vector;
  const white = computeSignals(garment(246, 244, 240)).vector;

  const near = embedder.similarity(black, alsoBlack).total;
  const far = embedder.similarity(black, white).total;
  assert.ok(near > far, `expected ${near} > ${far}`);
  assert.ok(near > 0.9, `two black garments should be very close, got ${near}`);
});

test('a striped garment reads as busier than a plain one of the same colour', () => {
  const plain = computeSignals(garment(120, 40, 60));
  const striped = computeSignals(garment(120, 40, 60, { stripes: true }));

  assert.ok(
    striped.readings.patternEnergy > plain.readings.patternEnergy * 1.5,
    `plain ${plain.readings.patternEnergy} vs striped ${striped.readings.patternEnergy}`,
  );

  // The compression curve must leave room above a busy surface, or a dress
  // with a print and one with a heavier print become indistinguishable. This
  // is the assertion that fails if `compress` is ever swapped back for a clamp.
  assert.ok(striped.readings.patternEnergy < 0.97);
});

test('the surface distinction survives into the descriptor', () => {
  const plain = computeSignals(garment(120, 40, 60)).vector;
  const alsoPlain = computeSignals(garment(124, 44, 62)).vector;
  const striped = computeSignals(garment(120, 40, 60, { stripes: true })).vector;

  const same = blockSimilarities(plain, alsoPlain);
  const different = blockSimilarities(plain, striped);

  assert.ok(
    different.texture < same.texture,
    `striped should agree less on texture: ${different.texture} vs ${same.texture}`,
  );
  // Stripes change the silhouette's edge distribution most of all, which is
  // the block that should carry this distinction.
  assert.ok(different.shape < 0.8, `shape should notice stripes: ${different.shape}`);
});

test('a studio backdrop is not one of the garment colours', () => {
  // The bug this pins: a black dress on white paper reported "white" as its
  // dominant colour, which went into the brief, into the palette pre-filter,
  // and onto a chip telling her the app had misread her photograph.
  const { readings } = computeSignals(garment(20, 20, 24));
  const dominant = readings.palette[0];

  assert.ok(dominant, 'a garment on a plain ground should have a palette');
  assert.equal(dominant.hue, null, 'black is achromatic');
  assert.ok(
    dominant.lightness < 0.3,
    `the dark garment should lead, not the paper: ${dominant.lightness}`,
  );
});

test('a busy background is counted rather than masked away', () => {
  // The mask is only trustworthy when the border says "seamless paper". On a
  // photograph taken in a room it would eat the clothes along with the wall,
  // so every pixel counts and the centre weighting does what it can alone.
  const noisy = new Uint8Array(CANVAS * CANVAS * 3);
  for (let index = 0; index < CANVAS * CANVAS; index += 1) {
    // Deterministic pseudo-noise: a real photograph's background, without a
    // random source that would make the test flake.
    const value = (index * 2654435761) % 256;
    noisy[index * 3] = value;
    noisy[index * 3 + 1] = (value * 3) % 256;
    noisy[index * 3 + 2] = (value * 7) % 256;
  }
  const { readings } = computeSignals({
    data: noisy,
    sourceWidth: 800,
    sourceHeight: 1000,
  });

  assert.ok(readings.borderUniformity < 0.55, 'this frame has no plain border');
  assert.ok(readings.palette.length > 0, 'nothing should be masked away here');
});

test('the displayed percentage is zero below the floor and one at the ceiling', () => {
  const anchors = { floor: 0.62, ceiling: 0.965 };
  assert.equal(displayedSimilarity(0.4, anchors), 0);
  assert.equal(displayedSimilarity(0.62, anchors), 0);
  assert.equal(displayedSimilarity(0.965, anchors), 1);
  assert.equal(displayedSimilarity(1, anchors), 1);
});

test('the displayed percentage rises monotonically between the anchors', () => {
  const anchors = { floor: 0.62, ceiling: 0.965 };
  let previous = -1;
  for (let raw = 0.6; raw <= 1; raw += 0.005) {
    const value = displayedSimilarity(raw, anchors);
    assert.ok(value >= previous, `not monotone at ${raw}`);
    previous = value;
  }
});

test('a requested colour the photograph lacks demotes the colour block', () => {
  const unchanged = weightsForQuery({
    imageColours: ['black'],
    requestedColours: ['black'],
  });
  assert.equal(unchanged.colour, DESCRIPTOR_BLOCKS[0].weight);

  const rebalanced = weightsForQuery({
    imageColours: ['white'],
    requestedColours: ['black'],
  });
  assert.ok(rebalanced.colour < 0.1, 'colour should stop being the evidence');
  assert.ok(rebalanced.shape > unchanged.shape, 'shape should take up the slack');
  // Nothing is lost — the freed weight is redistributed, not discarded.
  const before = Object.values(unchanged).reduce((sum, value) => sum + value, 0);
  const after = Object.values(rebalanced).reduce((sum, value) => sum + value, 0);
  assert.ok(Math.abs(before - after) < 1e-9);
});

test('achromatic pixels bin as shades rather than as hues', () => {
  // A near-grey with a faint warm cast must not land on "orange", which is
  // exactly how a beige wall used to make every beige dress a match.
  const [hue, saturation, value] = rgbToHsv(0.5, 0.49, 0.48);
  assert.ok(colourBin(hue, saturation, value) >= 48);

  const [redHue, redSaturation, redValue] = rgbToHsv(0.78, 0.16, 0.16);
  assert.ok(colourBin(redHue, redSaturation, redValue) < 48);
});

test('Lab conversion agrees with the published reference points', () => {
  const white = rgbToLab(1, 1, 1);
  assert.ok(Math.abs(white[0] - 100) < 0.5);
  assert.ok(Math.abs(white[1]) < 0.5 && Math.abs(white[2]) < 0.5);

  const black = rgbToLab(0, 0, 0);
  assert.ok(Math.abs(black[0]) < 0.5);
});

test('aspect ratio reaches the geometry block', () => {
  const portrait = computeSignals(solid(120, 120, 120, 0.6));
  const landscape = computeSignals(solid(120, 120, 120, 1.8));
  const parts = blockSimilarities(portrait.vector, landscape.vector);

  assert.equal(parts.colour, 1, 'the same grey is the same grey');
  assert.ok(parts.geometry < 1, 'a portrait and a landscape are framed differently');
});
