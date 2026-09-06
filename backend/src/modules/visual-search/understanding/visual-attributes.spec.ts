import assert from 'node:assert/strict';
import test from 'node:test';
import { COLOURS } from '../../ai-stylist/understanding/stylist-lexicon';
import { SignalReadings } from '../embedding/image-signals';
import {
  nearestColourKey,
  readingsToAttributes,
  withNeighbourCategories,
} from './visual-attributes';

function readings(overrides: Partial<SignalReadings> = {}): SignalReadings {
  return {
    palette: [],
    patternEnergy: 0.1,
    subjectFill: 0.4,
    borderUniformity: 0.8,
    aspect: 0.75,
    edgeProfile: [0.3, 0.4, 0.3],
    lightness: 0.5,
    ...overrides,
  };
}

test('every colour anchor names a colour the stylist lexicon knows', () => {
  // The gate that keeps the two vocabularies from drifting: a key produced
  // here that `sanitiseBrief` does not recognise is silently dropped, and the
  // search quietly stops filtering on colour.
  for (const rgb of [
    [0.07, 0.07, 0.07],
    [0.96, 0.95, 0.94],
    [0.85, 0.76, 0.65],
    [0.77, 0.16, 0.16],
  ] as const) {
    const key = nearestColourKey([...rgb] as [number, number, number]);
    assert.ok(key, 'a common shade should resolve');
    assert.ok(
      COLOURS.some((colour) => colour.key === key),
      `${key} is not a lexicon colour`,
    );
  }
});

test('the obvious colours resolve to the obvious keys', () => {
  assert.equal(nearestColourKey([0.05, 0.05, 0.06]), 'black');
  assert.equal(nearestColourKey([0.97, 0.96, 0.95]), 'white');
  assert.equal(nearestColourKey([0.78, 0.16, 0.16]), 'red');
  assert.equal(nearestColourKey([0.12, 0.17, 0.28]), 'navy');
});

test('pattern is read from the surface, not from the frame', () => {
  assert.equal(readingsToAttributes(readings({ patternEnergy: 0.05 })).pattern, 'plain');
  assert.equal(
    readingsToAttributes(readings({ patternEnergy: 0.3 })).pattern,
    'textured',
  );
  assert.equal(
    readingsToAttributes(readings({ patternEnergy: 0.7 })).pattern,
    'patterned',
  );
});

test('a tall frame the subject does not fill reads as a full look', () => {
  assert.equal(
    readingsToAttributes(readings({ aspect: 0.66, subjectFill: 0.35 })).framing,
    'full_look',
  );
  assert.equal(
    readingsToAttributes(readings({ aspect: 1, subjectFill: 0.9 })).framing,
    'closeup',
  );
  assert.equal(
    readingsToAttributes(readings({ aspect: 1, subjectFill: 0.5 })).framing,
    'product',
  );
});

test('a colour covering a sliver of the frame is trim, not a description', () => {
  const attributes = readingsToAttributes(
    readings({
      palette: [
        { hue: null, lightness: 0.05, saturation: 0, share: 0.7 },
        { hue: 45, lightness: 0.7, saturation: 0.8, share: 0.02 },
      ],
    }),
  );
  assert.deepEqual(
    attributes.colours.map((colour) => colour.key),
    ['black'],
  );
});

test('confidence is the share of the frame the named colours actually cover', () => {
  const thin = readingsToAttributes(
    readings({ palette: [{ hue: null, lightness: 0.05, saturation: 0, share: 0.2 }] }),
  );
  const full = readingsToAttributes(
    readings({ palette: [{ hue: null, lightness: 0.05, saturation: 0, share: 0.95 }] }),
  );
  assert.ok(thin.confidence < full.confidence);
  assert.ok(full.confidence > 0.9);
});

test('a lone dissenting neighbour does not get to name the category', () => {
  const base = readingsToAttributes(readings());
  const vote = (slug: string, label: string, similarity: number) => ({
    categorySlug: slug,
    categoryLabel: label,
    similarity,
  });

  const adopted = withNeighbourCategories(base, [
    vote('dresses', 'فساتين', 0.9),
    vote('dresses', 'فساتين', 0.85),
    vote('dresses', 'فساتين', 0.8),
    vote('dresses', 'فساتين', 0.78),
    vote('bags', 'حقائب', 0.4),
  ]);

  assert.deepEqual(adopted.categories, [{ slug: 'dresses', label: 'فساتين' }]);
  // The Arabic name travels with the slug: a chip must never render an
  // identifier into an otherwise Arabic surface.
  assert.equal(adopted.categories[0].label, 'فساتين');
  // And the client is told this was inferred, not measured.
  assert.equal(adopted.provenance.categories, 'NEIGHBOURS');
});

test('no neighbours means no category, rather than a guess', () => {
  const base = readingsToAttributes(readings());
  assert.deepEqual(withNeighbourCategories(base, []).categories, []);
  assert.equal(base.provenance.categories, undefined);
});
