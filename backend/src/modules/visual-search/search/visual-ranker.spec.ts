import assert from 'node:assert/strict';
import test from 'node:test';
import { ModestyLevel, Prisma } from '@prisma/client';
import { emptyBrief } from '../../ai-stylist/understanding/style-brief';
import { VisualAttributes } from '../understanding/visual-attributes';
import { VectorMatch } from '../vector/vector-index';
import {
  MIN_DISPLAYED_SIMILARITY,
  VisualCandidate,
  rankVisualMatches,
  scoreVisualMatch,
} from './visual-ranker';

const ANCHORS = { floor: 0.62, ceiling: 0.965 };

function attributes(overrides: Partial<VisualAttributes> = {}): VisualAttributes {
  return {
    colours: [{ key: 'black', labelAr: 'أسود', share: 0.6 }],
    pattern: 'plain',
    tone: 'dark',
    framing: 'product',
    studioBackground: true,
    subjectFill: 0.5,
    categories: [{ slug: 'dresses', label: 'فساتين' }],
    slots: [],
    provenance: {},
    confidence: 0.8,
    ...overrides,
  };
}

function match(overrides: Partial<VectorMatch> = {}): VectorMatch {
  return {
    productId: 'p1',
    mediaUrl: 'https://example.test/1.jpg',
    position: 0,
    similarity: 0.9,
    parts: { colour: 0.95, layout: 0.9, shape: 0.9, texture: 0.9, geometry: 1 },
    paletteKeys: ['black'],
    pattern: 'plain',
    ...overrides,
  };
}

/** Just enough of a product row for the ranker, which never touches the rest. */
function product(overrides: Record<string, unknown> = {}): VisualCandidate {
  return {
    id: 'p1',
    title: 'فستان سهرة أسود',
    description: 'فستان طويل',
    attributes: null,
    minPriceSyp: new Prisma.Decimal(500_000),
    rating: 4.2,
    reviewsCount: 4,
    ordersCount: 5,
    category: { slug: 'dresses' },
    variants: [],
    offers: [{ id: 'o1', sellerId: 's1' }],
    media: [],
    ...overrides,
  } as unknown as VisualCandidate;
}

test('the displayed similarity is the calibrated visual score, softened by attributes', () => {
  const entry = scoreVisualMatch({
    match: match(),
    product: product(),
    attributes: attributes(),
    brief: emptyBrief(),
    anchors: ANCHORS,
  });

  assert.ok(entry.visualScore > 0 && entry.visualScore <= 1);
  assert.ok(entry.attributeScore > 0 && entry.attributeScore <= 1);
  // A weighted mean of the two halves, and nothing else — the one arithmetic
  // claim the badge on the card actually makes.
  const expected = 0.75 * entry.visualScore + 0.25 * entry.attributeScore;
  assert.ok(Math.abs(entry.similarity - expected) < 1e-9);
});

test('a raw cosine at the floor renders as zero rather than as a match', () => {
  const entry = scoreVisualMatch({
    match: match({ similarity: ANCHORS.floor }),
    product: product(),
    attributes: attributes(),
    brief: emptyBrief(),
    anchors: ANCHORS,
  });
  assert.equal(entry.visualScore, 0);
});

test('the wrong colour scores below the right one, all else equal', () => {
  const right = scoreVisualMatch({
    match: match({ paletteKeys: ['black'] }),
    product: product(),
    attributes: attributes(),
    brief: emptyBrief(),
    anchors: ANCHORS,
  });
  const wrong = scoreVisualMatch({
    match: match({ paletteKeys: ['yellow'] }),
    product: product(),
    attributes: attributes(),
    brief: emptyBrief(),
    anchors: ANCHORS,
  });

  assert.ok(right.similarity > wrong.similarity);
  assert.ok(right.reasons.includes('COLOUR_MATCH'));
  assert.ok(!wrong.reasons.includes('COLOUR_MATCH'));
});

test('a reason code only fires when the thing it claims actually scored', () => {
  const overBudget = scoreVisualMatch({
    match: match(),
    product: product({ minPriceSyp: new Prisma.Decimal(900_000) }),
    attributes: attributes(),
    brief: { ...emptyBrief(), budgetMax: 400_000 },
    anchors: ANCHORS,
  });
  assert.ok(!overBudget.reasons.includes('BUDGET_FIT'));

  const inBudget = scoreVisualMatch({
    match: match(),
    product: product({ minPriceSyp: new Prisma.Decimal(300_000) }),
    attributes: attributes(),
    brief: { ...emptyBrief(), budgetMax: 400_000 },
    anchors: ANCHORS,
  });
  assert.ok(inBudget.reasons.includes('BUDGET_FIT'));
});

test('the sentence is built from the codes and never claims more than two things', () => {
  const entry = scoreVisualMatch({
    match: match({
      similarity: 0.96,
      parts: { colour: 1, layout: 0.98, shape: 0.95, texture: 0.95, geometry: 1 },
    }),
    product: product(),
    attributes: attributes(),
    brief: emptyBrief(),
    anchors: ANCHORS,
  });

  assert.ok(entry.reasons.length > 2, 'several components should have fired');
  assert.ok(entry.reason.endsWith('.'));
  assert.ok(entry.reason.split('، و').length <= 2, entry.reason);
});

test('no attribute evidence at all leaves the pixels to answer alone', () => {
  const entry = scoreVisualMatch({
    match: match({ paletteKeys: [], pattern: null }),
    product: product({ title: '', variants: [] }),
    attributes: attributes({ colours: [], categories: [] }),
    brief: emptyBrief(),
    anchors: ANCHORS,
  });
  // Rather than a zero attribute score dragging an honest visual match down.
  assert.equal(entry.attributeScore, entry.visualScore);
  assert.ok(Math.abs(entry.similarity - entry.visualScore) < 1e-9);
});

test('a modesty request is honoured, and an unknowable garment is not refused', () => {
  const entry = scoreVisualMatch({
    match: match(),
    // Perfume has no sleeves, so `garmentModesty` returns null. The right
    // behaviour is to let it pass, not to score it as immodest.
    product: product({ category: { slug: 'perfumes' } }),
    attributes: attributes({ categories: [] }),
    brief: { ...emptyBrief(), modesty: ModestyLevel.MODEST },
    anchors: ANCHORS,
  });
  assert.ok(entry.reasons.includes('MODESTY_MATCH'));
});

test('anything under the display floor is not shown at all', () => {
  const ranked = rankVisualMatches(
    {
      matches: [match({ similarity: 0.63 })],
      products: new Map([['p1', product()]]),
      attributes: attributes(),
      brief: emptyBrief(),
      anchors: ANCHORS,
    },
    10,
  );
  assert.deepEqual(ranked, []);
  assert.ok(MIN_DISPLAYED_SIMILARITY > 0.3);
});

test('one boutique cannot own the page, but a thin page is not made empty', () => {
  const matches = Array.from({ length: 6 }, (_, index) =>
    match({ productId: `p${index}`, similarity: 0.95 - index * 0.01 }),
  );
  const products = new Map(
    matches.map((entry) => [
      entry.productId,
      product({ id: entry.productId, offers: [{ id: 'o1', sellerId: 'one-seller' }] }),
    ]),
  );

  const ranked = rankVisualMatches(
    { matches, products, attributes: attributes(), brief: emptyBrief(), anchors: ANCHORS },
    6,
  );
  // All six are real matches from one seller: the cap reorders, it does not
  // withhold.
  assert.equal(ranked.length, 6);
});

test('a match whose product row was not loaded is dropped, not rendered blank', () => {
  const ranked = rankVisualMatches(
    {
      matches: [match({ productId: 'missing' })],
      products: new Map(),
      attributes: attributes(),
      brief: emptyBrief(),
      anchors: ANCHORS,
    },
    10,
  );
  assert.deepEqual(ranked, []);
});
