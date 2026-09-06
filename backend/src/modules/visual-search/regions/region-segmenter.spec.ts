import assert from 'node:assert/strict';
import test from 'node:test';
import { OutfitSlot, VisualRegionDetector } from '@prisma/client';
import { CANVAS, RawImage } from '../embedding/image-signals';
import { VisualAttributes } from '../understanding/visual-attributes';
import { sanitiseDetections, segmentLayout, wholeFrameRegion } from './region-segmenter';

function attributes(overrides: Partial<VisualAttributes> = {}): VisualAttributes {
  return {
    colours: [],
    pattern: 'plain',
    tone: 'mid',
    framing: 'full_look',
    studioBackground: true,
    subjectFill: 0.4,
    categories: [],
    slots: [],
    provenance: {},
    confidence: 0.8,
    ...overrides,
  };
}

/**
 * A standing figure on a plain ground, built out of horizontal bands.
 *
 * `bands` is a list of `[fromShare, toShare, r, g, b]` down the frame. The
 * figure occupies the middle third horizontally, which is what a full-length
 * photograph looks like to the row walk.
 */
function figure(bands: Array<[number, number, number, number, number]>): RawImage {
  const data = new Uint8Array(CANVAS * CANVAS * 3).fill(248);
  const from = Math.round(CANVAS * 0.33);
  const to = Math.round(CANVAS * 0.67);

  for (const [top, bottom, r, g, b] of bands) {
    for (let y = Math.round(CANVAS * top); y < Math.round(CANVAS * bottom); y += 1) {
      for (let x = from; x < to; x += 1) {
        const index = (y * CANVAS + x) * 3;
        data[index] = r;
        data[index + 1] = g;
        data[index + 2] = b;
      }
    }
  }
  return { data, sourceWidth: 800, sourceHeight: 1400 };
}

test('a single-garment photograph is one whole-frame region', () => {
  const region = wholeFrameRegion(attributes());
  assert.equal(region.detector, VisualRegionDetector.WHOLE);
  assert.deepEqual(region.box, { x: 0, y: 0, w: 1, h: 1 });
  assert.equal(region.confidence, 1);
});

test('a photograph that is not a full look is never cut up', () => {
  const image = figure([
    [0.1, 0.5, 220, 60, 60],
    [0.5, 0.9, 30, 30, 40],
  ]);
  assert.deepEqual(segmentLayout(image, attributes({ framing: 'product' })), []);
  assert.deepEqual(segmentLayout(image, attributes({ framing: 'closeup' })), []);
});

test('a plain dress produces no bands, because there is no boundary to find', () => {
  const image = figure([[0.1, 0.92, 40, 40, 48]]);
  assert.deepEqual(segmentLayout(image, attributes()), []);
});

test('a top over a skirt over shoes is cut at the colour changes', () => {
  const image = figure([
    [0.1, 0.45, 205, 120, 140],
    [0.45, 0.85, 30, 32, 60],
    [0.85, 0.95, 20, 18, 18],
  ]);
  const regions = segmentLayout(image, attributes());

  assert.ok(regions.length >= 2, `expected at least two bands, got ${regions.length}`);
  assert.ok(regions.every((region) => region.detector === VisualRegionDetector.LAYOUT));

  // The vertical prior: the first band is upper-body, the last is lower.
  assert.equal(regions[0].slot, OutfitSlot.TOP);
  const last = regions[regions.length - 1].slot;
  assert.ok(
    last === OutfitSlot.BOTTOM || last === OutfitSlot.SHOES,
    `the lowest band should be lower-body, got ${last}`,
  );
});

test('a layout band never claims the confidence a detection would', () => {
  const image = figure([
    [0.1, 0.45, 205, 120, 140],
    [0.45, 0.9, 30, 32, 60],
  ]);
  for (const region of segmentLayout(image, attributes())) {
    assert.ok(region.confidence <= 0.58, `too confident: ${region.confidence}`);
    assert.ok(region.confidence > 0);
  }
});

test('a busy background makes the split less trustworthy, and says so', () => {
  const image = figure([
    [0.1, 0.45, 205, 120, 140],
    [0.45, 0.9, 30, 32, 60],
  ]);
  const studio = segmentLayout(image, attributes({ studioBackground: true }));
  const street = segmentLayout(image, attributes({ studioBackground: false }));

  assert.ok(studio.length && street.length);
  assert.ok(
    street[0].confidence < studio[0].confidence,
    'a scene behind her should cost confidence',
  );
});

test('boxes stay inside the frame and keep some air around the crop', () => {
  const image = figure([
    [0.1, 0.45, 205, 120, 140],
    [0.45, 0.9, 30, 32, 60],
  ]);
  for (const { box } of segmentLayout(image, attributes())) {
    assert.ok(box.x >= 0 && box.y >= 0);
    assert.ok(box.w > 0 && box.h > 0);
    assert.ok(box.x + box.w <= 1.0001, `box runs off the right: ${box.x + box.w}`);
    assert.ok(box.y + box.h <= 1.0001, `box runs off the bottom: ${box.y + box.h}`);
  }
});

// ── The vision-model gate ───────────────────────────────────────────────

test('a detection with an unknown slot keeps its box and loses its slot', () => {
  const [region] = sanitiseDetections([
    { slot: 'HANDBAG_OF_THE_YEAR', label: 'شنطة', box: { x: 0.1, y: 0.1, w: 0.3, h: 0.3 } },
  ]);
  assert.equal(region.slot, null);
  assert.equal(region.detector, VisualRegionDetector.VISION);
});

test('boxes that run off the frame or vanish are refused outright', () => {
  assert.deepEqual(
    sanitiseDetections([
      { slot: 'BAG', box: { x: 0.9, y: 0.9, w: 0.5, h: 0.5 } },
      { slot: 'BAG', box: { x: 0.1, y: 0.1, w: 0.01, h: 0.01 } },
      { slot: 'BAG' },
      { slot: 'BAG', box: 'nonsense' },
      null,
      'not an object',
    ]),
    [],
  );
});

test('a model that returns forty boxes proposes four', () => {
  const many = Array.from({ length: 40 }, () => ({
    slot: 'DRESS',
    box: { x: 0.1, y: 0.1, w: 0.5, h: 0.5 },
  }));
  assert.equal(sanitiseDetections(many).length, 4);
});

test('confidence from a model is clamped, and a missing one is not invented as 1', () => {
  const [high, missing] = sanitiseDetections([
    { slot: 'DRESS', confidence: 9, box: { x: 0, y: 0, w: 0.5, h: 0.5 } },
    { slot: 'BAG', box: { x: 0.5, y: 0.5, w: 0.4, h: 0.4 } },
  ]);
  assert.equal(high.confidence, 1);
  assert.equal(missing.confidence, 0.5);
});

test('anything that is not a list of detections is no detections', () => {
  assert.deepEqual(sanitiseDetections(null), []);
  assert.deepEqual(sanitiseDetections({ items: [] }), []);
  assert.deepEqual(sanitiseDetections('[]'), []);
});
