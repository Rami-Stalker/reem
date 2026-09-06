import assert from 'node:assert/strict';
import test from 'node:test';
import { ClosetGapKind, ClosetSeason, ModestyLevel, OutfitSlot } from '@prisma/client';
import {
  ClosetItemFact,
  ClosetLookFact,
  ClosetSnapshot,
  budgetBandFor,
  computeGaps,
  gapFingerprint,
  harmonisingColours,
  marginalCapacityGain,
  modalSize,
  outfitCapacity,
} from './gap-engine';

/**
 * The gap engine is a pure function, so it is tested the way one should be:
 * wardrobes written by hand, no database, no fixtures. Every case below is a
 * closet a real woman could have, and the assertion is the advice she should
 * get from it.
 */

const NOW = new Date('2026-01-15T10:00:00Z');

function item(overrides: Partial<ClosetItemFact> & { id: string; slot: OutfitSlot }): ClosetItemFact {
  return {
    colours: [],
    materials: [],
    modesty: ModestyLevel.UNSPECIFIED,
    seasons: [ClosetSeason.ALL],
    occasions: [],
    size: null,
    wearCount: 0,
    lastWornAt: null,
    acquiredAt: null,
    purchasePriceSyp: null,
    isFavourite: false,
    ...overrides,
  };
}

function look(overrides: Partial<ClosetLookFact> & { id: string }): ClosetLookFact {
  return {
    title: 'إطلالة',
    occasion: null,
    seasons: [ClosetSeason.ALL],
    palette: [],
    isFavourite: false,
    ownedSlots: [],
    wantedSlots: [],
    updatedAt: NOW,
    ...overrides,
  };
}

function snapshot(overrides: Partial<ClosetSnapshot> = {}): ClosetSnapshot {
  return {
    items: [],
    looks: [],
    now: NOW,
    season: ClosetSeason.WINTER,
    typicalBudgetSyp: null,
    dismissedFingerprints: new Set(),
    ...overrides,
  };
}

// ── Capacity ────────────────────────────────────────────────────────────

test('outfit capacity pairs tops with bottoms and counts dresses whole', () => {
  const counts = new Map([
    [OutfitSlot.TOP, 3],
    [OutfitSlot.BOTTOM, 2],
    [OutfitSlot.DRESS, 1],
    [OutfitSlot.SHOES, 1],
  ]);
  // Two pairs (bounded by the bottoms) plus the dress.
  assert.equal(outfitCapacity(counts), 3);
});

test('a closet with no shoes can produce no outfits at all', () => {
  const counts = new Map([
    [OutfitSlot.DRESS, 10],
    [OutfitSlot.TOP, 4],
    [OutfitSlot.BOTTOM, 4],
  ]);
  assert.equal(outfitCapacity(counts), 0);
  // And the first pair of shoes unlocks every one of them at once, which is
  // exactly the advice such a closet should give.
  assert.equal(marginalCapacityGain(counts, OutfitSlot.SHOES), 14);
});

test('the seventh top adds nothing while the second skirt adds six', () => {
  const counts = new Map([
    [OutfitSlot.TOP, 6],
    [OutfitSlot.BOTTOM, 1],
    [OutfitSlot.SHOES, 1],
  ]);
  assert.equal(marginalCapacityGain(counts, OutfitSlot.TOP), 0);
  assert.equal(marginalCapacityGain(counts, OutfitSlot.BOTTOM), 1);
});

// ── The headline case ───────────────────────────────────────────────────

test('six tops and one skirt reports the skirt, not another top', () => {
  const items = [
    ...Array.from({ length: 6 }, (_, index) =>
      item({ id: `top-${index}`, slot: OutfitSlot.TOP, colours: ['black'] }),
    ),
    item({ id: 'skirt', slot: OutfitSlot.BOTTOM, colours: ['beige'] }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES, colours: ['black'] }),
  ];

  const gaps = computeGaps(snapshot({ items }));
  const slots = gaps.map((gap) => gap.slot);

  assert.ok(slots.includes(OutfitSlot.BOTTOM), 'should ask for a bottom');
  assert.ok(!slots.includes(OutfitSlot.TOP), 'should not ask for another top');
});

test('coverage priority carries the arithmetic that justifies it', () => {
  const items = [
    item({ id: 'dress-1', slot: OutfitSlot.DRESS }),
    item({ id: 'dress-2', slot: OutfitSlot.DRESS }),
    item({ id: 'dress-3', slot: OutfitSlot.DRESS }),
  ];

  const gap = computeGaps(snapshot({ items })).find(
    (candidate) =>
      candidate.kind === ClosetGapKind.COVERAGE && candidate.slot === OutfitSlot.SHOES,
  );

  assert.ok(gap, 'a closet of dresses and no shoes needs shoes');
  assert.equal(gap.components['outfits_now'], 0);
  assert.equal(gap.components['outfits_unlocked'], 3);
});

// ── Looks ───────────────────────────────────────────────────────────────

test('a saved look one piece short outranks a structural gap', () => {
  const items = [
    item({ id: 'dress', slot: OutfitSlot.DRESS, colours: ['navy'] }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES, colours: ['black'] }),
    item({ id: 'top', slot: OutfitSlot.TOP }),
    item({ id: 'bottom', slot: OutfitSlot.BOTTOM }),
  ];
  const looks = [
    look({
      id: 'look-1',
      occasion: 'wedding',
      palette: ['navy'],
      ownedSlots: [OutfitSlot.DRESS, OutfitSlot.SHOES],
      wantedSlots: [OutfitSlot.BAG],
    }),
  ];

  const gaps = computeGaps(snapshot({ items, looks }));

  assert.equal(gaps[0].kind, ClosetGapKind.LOOK_SLOT);
  assert.equal(gaps[0].slot, OutfitSlot.BAG);
  assert.equal(gaps[0].lookId, 'look-1');
  assert.ok(gaps[0].components['nearly_complete'] > 0);
});

test('a look gap suggests colours that harmonise with its palette', () => {
  const looks = [
    look({
      id: 'look-1',
      occasion: 'evening',
      palette: ['black'],
      ownedSlots: [OutfitSlot.DRESS],
      wantedSlots: [OutfitSlot.BAG],
    }),
  ];
  const items = [item({ id: 'dress', slot: OutfitSlot.DRESS, colours: ['black'] })];

  const gap = computeGaps(snapshot({ items, looks }))[0];

  assert.ok(gap.suggestedColours.length > 0);
  for (const colour of gap.suggestedColours) {
    assert.ok(
      harmonisingColours(['black']).includes(colour),
      `${colour} should sit with black`,
    );
  }
});

// ── Occasions ───────────────────────────────────────────────────────────

test('an occasion she has never mentioned raises no gap', () => {
  const items = [
    item({ id: 'top', slot: OutfitSlot.TOP, occasions: ['daily'] }),
    item({ id: 'bottom', slot: OutfitSlot.BOTTOM, occasions: ['daily'] }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES, occasions: ['daily'] }),
  ];

  const gaps = computeGaps(snapshot({ items }));
  assert.ok(
    !gaps.some((gap) => gap.occasion === 'wedding'),
    'a catalog would push a wedding dress; a wardrobe should not',
  );
});

test('an occasion she cannot complete raises one', () => {
  const items = [
    item({ id: 'shoes', slot: OutfitSlot.SHOES, occasions: ['wedding'] }),
    item({ id: 'bag', slot: OutfitSlot.BAG, occasions: ['wedding'] }),
  ];
  const looks = [look({ id: 'look-1', occasion: 'wedding' })];

  const gaps = computeGaps(snapshot({ items, looks }));

  assert.ok(
    gaps.some((gap) => gap.occasion === 'wedding' && gap.slot === OutfitSlot.DRESS),
  );
});

// ── Suppression and identity ────────────────────────────────────────────

test('a dismissed gap stays dismissed across a recompute', () => {
  const items = [
    item({ id: 'dress-1', slot: OutfitSlot.DRESS }),
    item({ id: 'dress-2', slot: OutfitSlot.DRESS }),
    item({ id: 'dress-3', slot: OutfitSlot.DRESS }),
  ];
  const fingerprint = gapFingerprint({
    kind: ClosetGapKind.COVERAGE,
    slot: OutfitSlot.SHOES,
  });

  const before = computeGaps(snapshot({ items }));
  assert.ok(before.some((gap) => gap.fingerprint === fingerprint));

  const after = computeGaps(
    snapshot({ items, dismissedFingerprints: new Set([fingerprint]) }),
  );
  assert.ok(!after.some((gap) => gap.fingerprint === fingerprint));
});

test('fingerprints are stable and keep nullable segments distinct', () => {
  assert.equal(
    gapFingerprint({ kind: ClosetGapKind.COVERAGE, slot: OutfitSlot.TOP }),
    'COVERAGE:TOP:::',
  );
  assert.notEqual(
    gapFingerprint({ kind: ClosetGapKind.LOOK_SLOT, slot: OutfitSlot.TOP, lookId: 'a' }),
    gapFingerprint({ kind: ClosetGapKind.LOOK_SLOT, slot: OutfitSlot.TOP, lookId: 'b' }),
  );
});

test('the engine is deterministic', () => {
  const items = [
    item({ id: 'a', slot: OutfitSlot.TOP, colours: ['black'] }),
    item({ id: 'b', slot: OutfitSlot.TOP, colours: ['white'] }),
    item({ id: 'c', slot: OutfitSlot.BOTTOM, colours: ['navy'] }),
    item({ id: 'd', slot: OutfitSlot.SHOES }),
  ];
  const first = computeGaps(snapshot({ items }));
  const second = computeGaps(snapshot({ items }));
  assert.deepEqual(first, second);
});

test('an almost-empty closet gets no structural lecture', () => {
  const gaps = computeGaps(snapshot({ items: [item({ id: 'a', slot: OutfitSlot.TOP })] }));
  assert.equal(gaps.filter((gap) => gap.kind === ClosetGapKind.COVERAGE).length, 0);
});

// ── Seasons and replacement ─────────────────────────────────────────────

test('a slot she owns but cannot wear this season is a season gap', () => {
  const items = [
    item({ id: 'dress-1', slot: OutfitSlot.DRESS, seasons: [ClosetSeason.SUMMER] }),
    item({ id: 'dress-2', slot: OutfitSlot.DRESS, seasons: [ClosetSeason.SUMMER] }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES }),
    item({ id: 'top', slot: OutfitSlot.TOP }),
  ];

  const gap = computeGaps(snapshot({ items, season: ClosetSeason.WINTER })).find(
    (candidate) => candidate.kind === ClosetGapKind.SEASON,
  );

  assert.ok(gap);
  assert.equal(gap.slot, OutfitSlot.DRESS);
  assert.equal(gap.components['owned_out_of_season'], 2);
});

test('a worn-out favourite with a spare behind it is not a replacement gap', () => {
  const worn = item({
    id: 'coat',
    slot: OutfitSlot.OUTERWEAR,
    wearCount: 60,
    acquiredAt: new Date('2024-01-01'),
  });
  const spare = item({ id: 'coat-2', slot: OutfitSlot.OUTERWEAR });

  const alone = computeGaps(snapshot({ items: [worn] }));
  const paired = computeGaps(snapshot({ items: [worn, spare] }));

  assert.ok(alone.some((gap) => gap.kind === ClosetGapKind.REPLACEMENT));
  assert.ok(!paired.some((gap) => gap.kind === ClosetGapKind.REPLACEMENT));
});

test('thirty wears in a fortnight is a logging habit, not wear and tear', () => {
  const items = [
    item({
      id: 'dress',
      slot: OutfitSlot.DRESS,
      wearCount: 40,
      acquiredAt: new Date('2026-01-05'),
    }),
  ];
  const gaps = computeGaps(snapshot({ items }));
  assert.ok(!gaps.some((gap) => gap.kind === ClosetGapKind.REPLACEMENT));
});

// ── Constraints from her own wardrobe ───────────────────────────────────

test('budget is read from what she paid in that slot, not a global band', () => {
  const items = [
    item({ id: 'a', slot: OutfitSlot.SHOES, purchasePriceSyp: 200_000 }),
    item({ id: 'b', slot: OutfitSlot.SHOES, purchasePriceSyp: 400_000 }),
    item({ id: 'c', slot: OutfitSlot.SHOES, purchasePriceSyp: 300_000 }),
  ];

  const band = budgetBandFor(items, OutfitSlot.SHOES, { min: 5_000, max: 10_000 });
  assert.equal(band.min, 150_000);
  assert.equal(band.max, 450_000);
});

test('a slot with no history falls back to her typical band', () => {
  const band = budgetBandFor([], OutfitSlot.BAG, { min: 100_000, max: 500_000 });
  assert.deepEqual(band, { min: 100_000, max: 500_000 });
});

test('size is modal, and borrows across slots on the same system', () => {
  const items = [
    item({ id: 'a', slot: OutfitSlot.TOP, size: 'M' }),
    item({ id: 'b', slot: OutfitSlot.TOP, size: 'M' }),
    item({ id: 'c', slot: OutfitSlot.TOP, size: 'L' }),
  ];
  assert.equal(modalSize(items, OutfitSlot.TOP), 'M');
  // Nothing in BOTTOM yet, but it shares the clothing size system.
  assert.equal(modalSize(items, OutfitSlot.BOTTOM), 'M');
  // Shoes are a different system entirely and must not borrow.
  assert.equal(modalSize(items, OutfitSlot.SHOES), null);
});

test('an empty palette constrains nothing rather than everything', () => {
  assert.deepEqual(harmonisingColours([]), []);
});
