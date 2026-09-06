import assert from 'node:assert/strict';
import test from 'node:test';
import { ClosetSeason, ModestyLevel, OutfitSlot } from '@prisma/client';
import { ClosetItemFact, ClosetLookFact } from '../gaps/gap-engine';
import { PairingCandidate, complementarySlots, scorePairing } from './pairing';

function item(
  overrides: Partial<ClosetItemFact> & { id: string; slot: OutfitSlot },
): ClosetItemFact {
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

function candidate(overrides: Partial<PairingCandidate> = {}): PairingCandidate {
  return {
    slot: OutfitSlot.BOTTOM,
    colours: ['navy'],
    seasons: [ClosetSeason.ALL],
    occasions: [],
    modesty: ModestyLevel.UNSPECIFIED,
    availableSizes: [],
    ...overrides,
  };
}

function context(overrides: {
  items?: ClosetItemFact[];
  looks?: ClosetLookFact[];
  sizes?: Map<OutfitSlot, string>;
  season?: ClosetSeason;
}) {
  return {
    items: overrides.items ?? [],
    looks: overrides.looks ?? [],
    season: overrides.season ?? ClosetSeason.ALL,
    sizes: overrides.sizes ?? new Map<OutfitSlot, string>(),
    occasion: null,
  };
}

test('complements are symmetric', () => {
  assert.ok(complementarySlots(OutfitSlot.TOP).includes(OutfitSlot.BOTTOM));
  assert.ok(complementarySlots(OutfitSlot.BOTTOM).includes(OutfitSlot.TOP));
});

test('a piece that goes with what she owns scores above one that does not', () => {
  const items = [
    item({ id: 'a', slot: OutfitSlot.TOP, colours: ['white'] }),
    item({ id: 'b', slot: OutfitSlot.TOP, colours: ['beige'] }),
    item({ id: 'c', slot: OutfitSlot.TOP, colours: ['black'] }),
  ];

  const goes = scorePairing(candidate({ colours: ['navy'] }), context({ items }));
  // Purple is in the lexicon but harmonises with none of white/beige/black as a
  // non-neutral, so it pairs with nothing.
  const clashes = scorePairing(candidate({ colours: ['emerald'] }), context({ items }));

  assert.ok(goes.score > clashes.score);
  assert.ok(goes.reasons.includes('PAIRS_WITH_OWNED'));
  assert.equal(goes.pairsWithItemIds.length, 3);
});

test('the fourth black top scores below the skirt she has none of', () => {
  const items = [
    item({ id: 't1', slot: OutfitSlot.TOP, colours: ['black'] }),
    item({ id: 't2', slot: OutfitSlot.TOP, colours: ['black'] }),
    item({ id: 't3', slot: OutfitSlot.TOP, colours: ['black'] }),
  ];

  const anotherTop = scorePairing(
    candidate({ slot: OutfitSlot.TOP, colours: ['black'] }),
    context({ items }),
  );
  const firstSkirt = scorePairing(
    candidate({ slot: OutfitSlot.BOTTOM, colours: ['black'] }),
    context({ items }),
  );

  assert.ok(anotherTop.score < firstSkirt.score);
  assert.ok(anotherTop.reasons.includes('DUPLICATE_OF_OWNED'));
  assert.ok(firstSkirt.reasons.includes('FILLS_EMPTY_SLOT'));
  assert.ok(anotherTop.score < 0, 'a redundant duplicate should score negative');
});

test('completing a saved look is worth more than merely matching', () => {
  const looks = [
    {
      id: 'look-1',
      title: 'إطلالة',
      occasion: 'evening',
      seasons: [ClosetSeason.ALL],
      palette: ['black'],
      isFavourite: false,
      ownedSlots: [OutfitSlot.DRESS, OutfitSlot.SHOES],
      wantedSlots: [OutfitSlot.BAG],
      updatedAt: new Date(),
    },
  ];

  const completes = scorePairing(
    candidate({ slot: OutfitSlot.BAG, colours: ['gold'] }),
    context({ looks }),
  );

  assert.ok(completes.reasons.includes('COMPLETES_LOOK'));
  assert.deepEqual(completes.completesLookIds, ['look-1']);
});

test('a look already two pieces short is not completed by one of them', () => {
  const looks = [
    {
      id: 'look-1',
      title: 'إطلالة',
      occasion: null,
      seasons: [ClosetSeason.ALL],
      palette: [],
      isFavourite: false,
      ownedSlots: [OutfitSlot.DRESS],
      wantedSlots: [OutfitSlot.BAG, OutfitSlot.SHOES],
      updatedAt: new Date(),
    },
  ];

  const result = scorePairing(candidate({ slot: OutfitSlot.BAG }), context({ looks }));
  assert.ok(!result.reasons.includes('COMPLETES_LOOK'));
});

test('out-of-season pieces are not counted as pairs', () => {
  const items = [
    item({ id: 'a', slot: OutfitSlot.TOP, colours: ['white'], seasons: [ClosetSeason.SUMMER] }),
  ];

  const result = scorePairing(
    candidate({ colours: ['navy'], seasons: [ClosetSeason.WINTER] }),
    context({ items, season: ClosetSeason.WINTER }),
  );

  assert.equal(result.pairsWithItemIds.length, 0);
});

test('an unknown colour pairs with everything rather than nothing', () => {
  const items = [item({ id: 'a', slot: OutfitSlot.TOP, colours: ['emerald'] })];
  const result = scorePairing(candidate({ colours: [] }), context({ items }));
  assert.equal(result.pairsWithItemIds.length, 1);
});

test('her size is rewarded only when the offer actually stocks it', () => {
  const sizes = new Map([[OutfitSlot.BOTTOM, 'M']]);

  const inStock = scorePairing(
    candidate({ availableSizes: ['S', 'M', 'L'] }),
    context({ sizes }),
  );
  const outOfStock = scorePairing(
    candidate({ availableSizes: ['S', 'L'] }),
    context({ sizes }),
  );

  assert.ok(inStock.reasons.includes('MATCHES_YOUR_SIZE'));
  assert.ok(!outOfStock.reasons.includes('MATCHES_YOUR_SIZE'));
});

test('a more covering piece suits a modest wardrobe', () => {
  const items = [
    item({ id: 'a', slot: OutfitSlot.TOP, modesty: ModestyLevel.MODEST }),
    item({ id: 'b', slot: OutfitSlot.TOP, modesty: ModestyLevel.MODEST }),
    item({ id: 'c', slot: OutfitSlot.TOP, modesty: ModestyLevel.MODEST }),
  ];

  const modest = scorePairing(
    candidate({ modesty: ModestyLevel.MODEST }),
    context({ items }),
  );
  const expressive = scorePairing(
    candidate({ modesty: ModestyLevel.EXPRESSIVE }),
    context({ items }),
  );

  assert.ok(modest.reasons.includes('MATCHES_YOUR_MODESTY'));
  assert.ok(!expressive.reasons.includes('MATCHES_YOUR_MODESTY'));
});

test('scores stay inside the declared range', () => {
  const items = Array.from({ length: 30 }, (_, index) =>
    item({ id: `i-${index}`, slot: OutfitSlot.TOP, colours: ['white'] }),
  );
  const result = scorePairing(candidate({ colours: ['navy'] }), context({ items }));
  assert.ok(result.score <= 1 && result.score >= -1);
});

test('an empty closet scores everything neutrally rather than badly', () => {
  const result = scorePairing(candidate(), context({}));
  assert.ok(result.score >= 0);
  assert.ok(result.reasons.includes('FILLS_EMPTY_SLOT'));
});
