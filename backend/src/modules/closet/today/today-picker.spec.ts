import assert from 'node:assert/strict';
import test from 'node:test';
import { ClosetSeason, ModestyLevel, OutfitSlot } from '@prisma/client';
import { ClosetItemFact, ClosetLookFact } from '../gaps/gap-engine';
import { pickTodayOutfits } from './today-picker';

const NOW = new Date('2026-01-15T08:00:00Z');
const daysAgo = (days: number) => new Date(NOW.getTime() - days * 86_400_000);

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

function pick(input: {
  items?: ClosetItemFact[];
  looks?: ClosetLookFact[];
  season?: ClosetSeason;
  occasion?: string | null;
}) {
  return pickTodayOutfits({
    items: input.items ?? [],
    looks: input.looks ?? [],
    now: NOW,
    season: input.season ?? ClosetSeason.WINTER,
    occasion: input.occasion ?? null,
  });
}

test('a closet with no saved looks still answers the question', () => {
  const items = [
    item({ id: 'dress', slot: OutfitSlot.DRESS, colours: ['black'] }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES, colours: ['black'] }),
  ];

  const outfits = pick({ items });

  assert.ok(outfits.length > 0, 'day one must not be empty');
  assert.equal(outfits[0].origin, 'COMPOSED');
  assert.deepEqual(outfits[0].missingSlots, []);
});

test('a ready saved look outranks a composed one', () => {
  const items = [
    item({ id: 'dress', slot: OutfitSlot.DRESS }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES }),
    item({ id: 'top', slot: OutfitSlot.TOP }),
    item({ id: 'bottom', slot: OutfitSlot.BOTTOM }),
  ];
  const looks = [
    look({ id: 'saved', ownedSlots: [OutfitSlot.DRESS, OutfitSlot.SHOES] }),
  ];

  const outfits = pick({ items, looks });

  assert.equal(outfits[0].origin, 'SAVED');
  assert.equal(outfits[0].lookId, 'saved');
  assert.ok(outfits[0].reasons.includes('READY_TO_WEAR'));
});

test('an outfit missing shoes never outranks one she can walk out in', () => {
  const items = [
    item({ id: 'dress-a', slot: OutfitSlot.DRESS, colours: ['black'] }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES, colours: ['black'] }),
    // Emerald pairs with neither of the black pieces, so it gets no shoes.
    item({ id: 'dress-b', slot: OutfitSlot.DRESS, colours: ['emerald'] }),
  ];

  const outfits = pick({ items });
  const wearable = outfits.filter((outfit) => !outfit.missingSlots.length);
  const short = outfits.filter((outfit) => outfit.missingSlots.length);

  assert.ok(wearable.length > 0);
  if (short.length) {
    assert.ok(wearable[0].score > short[0].score);
  }
});

test('a piece worn yesterday sinks below one rested for months', () => {
  const items = [
    item({ id: 'fresh', slot: OutfitSlot.DRESS, lastWornAt: daysAgo(1) }),
    item({ id: 'rested', slot: OutfitSlot.DRESS, lastWornAt: daysAgo(120) }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES, lastWornAt: daysAgo(200) }),
  ];

  const outfits = pick({ items });
  const top = outfits[0];

  assert.ok(top.pieces.some((piece) => piece.itemId === 'rested'));
  assert.ok(top.reasons.includes('REDISCOVERED'));
});

test('out-of-season pieces do not appear', () => {
  const items = [
    item({ id: 'summer', slot: OutfitSlot.DRESS, seasons: [ClosetSeason.SUMMER] }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES }),
  ];

  const outfits = pick({ items, season: ClosetSeason.WINTER });
  const ids = outfits.flatMap((outfit) => outfit.pieces.map((piece) => piece.itemId));

  assert.ok(!ids.includes('summer'));
});

test('an occasion filter keeps only pieces that suit it', () => {
  const items = [
    item({ id: 'gown', slot: OutfitSlot.DRESS, occasions: ['wedding'] }),
    item({ id: 'jeans-top', slot: OutfitSlot.TOP, occasions: ['daily'] }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES, occasions: ['wedding', 'daily'] }),
  ];

  const outfits = pick({ items, occasion: 'wedding' });
  const ids = outfits.flatMap((outfit) => outfit.pieces.map((piece) => piece.itemId));

  assert.ok(ids.includes('gown'));
  assert.ok(!ids.includes('jeans-top'));
});

test('tops and bottoms are only paired when their colours sit together', () => {
  const items = [
    item({ id: 'top', slot: OutfitSlot.TOP, colours: ['emerald'] }),
    item({ id: 'bottom', slot: OutfitSlot.BOTTOM, colours: ['red'] }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES, colours: ['black'] }),
  ];

  const outfits = pick({ items });
  const paired = outfits.some(
    (outfit) =>
      outfit.pieces.some((piece) => piece.itemId === 'top') &&
      outfit.pieces.some((piece) => piece.itemId === 'bottom'),
  );

  assert.ok(!paired, 'emerald and red should not be proposed together');
});

test('the same closet on the same day gives the same answer', () => {
  const items = [
    item({ id: 'a', slot: OutfitSlot.TOP, colours: ['white'] }),
    item({ id: 'b', slot: OutfitSlot.BOTTOM, colours: ['navy'] }),
    item({ id: 'c', slot: OutfitSlot.SHOES, colours: ['black'] }),
    item({ id: 'd', slot: OutfitSlot.DRESS, colours: ['black'] }),
  ];

  assert.deepEqual(pick({ items }), pick({ items }));
});

test('one outfit is never proposed twice', () => {
  const items = [
    item({ id: 'dress', slot: OutfitSlot.DRESS }),
    item({ id: 'shoes', slot: OutfitSlot.SHOES }),
  ];
  const looks = [
    look({ id: 'saved', ownedSlots: [OutfitSlot.DRESS, OutfitSlot.SHOES] }),
  ];

  const outfits = pick({ items, looks });
  const signatures = outfits.map((outfit) =>
    outfit.pieces
      .map((piece) => piece.itemId)
      .sort()
      .join('+'),
  );

  assert.equal(new Set(signatures).size, signatures.length);
});

test('an empty closet returns nothing rather than throwing', () => {
  assert.deepEqual(pick({}), []);
});

test('a saved look one piece short is shown, and says so', () => {
  const items = [item({ id: 'dress', slot: OutfitSlot.DRESS })];
  const looks = [
    look({
      id: 'saved',
      ownedSlots: [OutfitSlot.DRESS],
      wantedSlots: [OutfitSlot.SHOES],
    }),
  ];

  const outfits = pick({ items, looks });
  const saved = outfits.find((outfit) => outfit.lookId === 'saved');

  assert.ok(saved);
  assert.ok(saved.reasons.includes('ONE_PIECE_SHORT'));
  assert.deepEqual(saved.missingSlots, [OutfitSlot.SHOES]);
});
