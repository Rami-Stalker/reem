import assert from 'node:assert/strict';
import test from 'node:test';
import { ModestyLevel } from '@prisma/client';

import {
  MAX_NOTES,
  OwnedPiece,
  ProductFacts,
  ShopperFacts,
  occasionCompatible,
  termMatches,
  verdictsFor,
} from './product-verdict';

/**
 * The verdict kernel.
 *
 * The cases worth having are the ones about *silence*: a layer that always has
 * something to say is a layer nobody reads. Most of these assert that a note
 * does not appear.
 */

const product: ProductFacts = {
  productId: 'p1',
  title: 'فستان سهرة كحلي',
  categoryId: 'c-dresses',
  slot: 'DRESS',
  colours: ['navy'],
  occasions: ['wedding', 'evening'],
  modesty: ModestyLevel.UNSPECIFIED,
  priceSyp: 120_000,
  sellerIds: ['s1'],
  stockUnits: 20,
  recentViews: 40,
  previousViews: 35,
};

const stranger: ShopperFacts = {
  owns: [],
  openLooks: [],
  occasions: [],
  terms: [],
  boughtFromSellerIds: [],
  needsSlots: [],
};

const navyDress: OwnedPiece = {
  itemId: 'i1',
  title: 'فستان كحلي طويل',
  slot: 'DRESS',
  colours: ['navy'],
  categoryId: 'c-dresses',
};

const blackShoes: OwnedPiece = {
  itemId: 'i2',
  title: 'حذاء كعب أسود',
  slot: 'SHOES',
  colours: ['black'],
  categoryId: 'c-shoes',
};

const run = (
  over: Partial<{
    product: ProductFacts;
    shopper: ShopperFacts;
    alternative: Parameters<typeof verdictsFor>[0]['alternative'];
    pairsWith: readonly OwnedPiece[];
    ownsSimilar: readonly OwnedPiece[];
  }> = {},
) =>
  verdictsFor({
    product: over.product ?? product,
    shopper: over.shopper ?? stranger,
    alternative: over.alternative ?? null,
    pairsWith: over.pairsWith ?? [],
    ownsSimilar: over.ownsSimilar ?? [],
  });

// ── Silence ──────────────────────────────────────────────────────────────

test('a shopper Reem knows nothing about is told nothing', () => {
  assert.deepEqual(run(), [], 'no history, no opinions');
});

test('a quiet product with a known shopper still says nothing', () => {
  const shopper: ShopperFacts = { ...stranger, owns: [blackShoes] };
  // Shoes she owns are not a reason to say anything about a dress unless the
  // graph actually pairs them.
  assert.deepEqual(run({ shopper }), []);
});

// ── «لديك شيء مشابه بالفعل» ──────────────────────────────────────────────

test('owning the same thing is said first, and said as a caution', () => {
  const shopper: ShopperFacts = { ...stranger, owns: [navyDress] };
  const notes = run({ shopper });

  assert.equal(notes[0].code, 'ALREADY_OWN_SIMILAR');
  assert.equal(notes[0].tone, 'caution');
  assert.match(notes[0].ar, /فستان كحلي طويل/, 'it names the piece she owns');
  assert.deepEqual(notes[0].evidence.itemIds, ['i1']);
});

test('the graph can call it a duplicate when no colour is named', () => {
  // The gap live data exposed: most listings name a sleeve or a cut, not a
  // shade — «فستان سهرة بأكمام منفوخة» — so a colour-only test could almost
  // never fire the note the whole design is proudest of. The graph compares
  // slot, colour, fabric, occasion and price, and is the better judge.
  const colourless: ProductFacts = { ...product, colours: [] };
  const shopper: ShopperFacts = { ...stranger, owns: [navyDress] };

  assert.ok(
    !run({ product: colourless, shopper }).some(
      (n) => n.code === 'ALREADY_OWN_SIMILAR',
    ),
    'colour alone cannot decide it',
  );

  const notes = run({
    product: colourless,
    shopper,
    ownsSimilar: [navyDress],
  });
  const note = notes.find((n) => n.code === 'ALREADY_OWN_SIMILAR');
  assert.ok(note, 'but the graph can');
  assert.match(note.ar, /فستان كحلي طويل/, 'and it still names the piece');
});

test('a piece she typed in herself is still caught by colour', () => {
  // Personal items have no product id and so no row in the affinity table.
  // The colour test is what keeps them in the duplicate check at all.
  const shopper: ShopperFacts = { ...stranger, owns: [navyDress] };
  assert.ok(
    run({ shopper }).some((n) => n.code === 'ALREADY_OWN_SIMILAR'),
  );
});

test('a different colour in the same slot is not a duplicate', () => {
  const shopper: ShopperFacts = {
    ...stranger,
    owns: [{ ...navyDress, colours: ['red'] }],
  };
  assert.ok(!run({ shopper }).some((n) => n.code === 'ALREADY_OWN_SIMILAR'));
});

test('the same colour in a different slot is not a duplicate either', () => {
  const shopper: ShopperFacts = {
    ...stranger,
    owns: [{ ...navyDress, slot: 'BAG' }],
  };
  assert.ok(!run({ shopper }).some((n) => n.code === 'ALREADY_OWN_SIMILAR'));
});

test('a caution outranks every encouragement', () => {
  const shopper: ShopperFacts = {
    ...stranger,
    owns: [navyDress],
    boughtFromSellerIds: ['s1'],
  };
  const notes = run({
    shopper,
    alternative: { productId: 'p2', title: 'بديل', savingBps: 2500, score: 80 },
  });

  assert.equal(notes[0].tone, 'caution');
  assert.ok(notes.length > 1, 'the others are still said, just after it');
});

test('«goes with your closet» is suppressed when she already owns one', () => {
  // Two notes arguing with each other is worse than one useful note.
  const shopper: ShopperFacts = { ...stranger, owns: [navyDress, blackShoes] };
  const notes = run({ shopper, pairsWith: [blackShoes] });

  assert.ok(notes.some((n) => n.code === 'ALREADY_OWN_SIMILAR'));
  assert.ok(!notes.some((n) => n.code === 'SUITS_YOUR_CLOSET'));
});

// ── «هذا يناسب ما لديك» و«ينقصك هذا لإكمال الـ look» ─────────────────────

test('pairing with her wardrobe is said when the graph found a pairing', () => {
  const shopper: ShopperFacts = { ...stranger, owns: [blackShoes] };
  const notes = run({ shopper, pairsWith: [blackShoes] });

  const note = notes.find((n) => n.code === 'SUITS_YOUR_CLOSET');
  assert.ok(note);
  assert.match(note.ar, /حذاء كعب أسود/);
});

test('completing a saved look is the strongest encouragement', () => {
  const shopper: ShopperFacts = {
    ...stranger,
    openLooks: [
      {
        lookId: 'l1',
        title: 'إطلالة عرس',
        missingSlots: ['DRESS'],
        occasion: 'wedding',
      },
    ],
  };
  const notes = run({ shopper });
  const note = notes.find((n) => n.code === 'COMPLETES_LOOK');

  assert.ok(note);
  assert.equal(note.tone, 'encourage');
  assert.match(note.ar, /إطلالة عرس/);
  assert.equal(notes[0].code, 'COMPLETES_LOOK', 'and it leads');
});

test('the right slot for the wrong occasion does not complete a look', () => {
  // The bug live data caught: a washable maternity bag was offered as the
  // missing piece for a wedding look. Right slot, absurd event.
  const maternityBag: ProductFacts = {
    ...product,
    title: 'حقيبة أمومة قابلة للغسل',
    slot: 'BAG',
    occasions: ['newborn'],
  };
  const shopper: ShopperFacts = {
    ...stranger,
    openLooks: [
      {
        lookId: 'l1',
        title: 'إطلالة عرس',
        missingSlots: ['BAG'],
        occasion: 'wedding',
      },
    ],
  };

  assert.ok(
    !run({ product: maternityBag, shopper }).some(
      (n) => n.code === 'COMPLETES_LOOK',
    ),
  );

  // An evening bag for the same look still completes it.
  const eveningBag = { ...maternityBag, occasions: ['wedding', 'evening'] };
  assert.ok(
    run({ product: eveningBag, shopper }).some((n) => n.code === 'COMPLETES_LOOK'),
  );

  // And an unlabelled bag is not disqualified for being unlabelled.
  const plainBag = { ...maternityBag, occasions: [] };
  assert.ok(
    run({ product: plainBag, shopper }).some((n) => n.code === 'COMPLETES_LOOK'),
  );
});

test('occasion compatibility is silent unless both sides speak', () => {
  assert.ok(occasionCompatible(null, ['newborn']), 'a look with no occasion');
  assert.ok(occasionCompatible('wedding', []), 'a product with no occasion');
  assert.ok(occasionCompatible('wedding', ['wedding', 'evening']));
  assert.ok(!occasionCompatible('wedding', ['newborn']));
});

test('a look missing a different slot is not completed by this', () => {
  const shopper: ShopperFacts = {
    ...stranger,
    openLooks: [
      { lookId: 'l1', title: 'إطلالة', missingSlots: ['BAG'], occasion: null },
    ],
  };
  assert.ok(!run({ shopper }).some((n) => n.code === 'COMPLETES_LOOK'));
});

// ── «هناك بديل أفضل قيمة» ────────────────────────────────────────────────

test('a cheaper equivalent is offered with the saving named', () => {
  const notes = run({
    alternative: { productId: 'p2', title: 'فستان مشابه', savingBps: 3000, score: 82 },
  });
  const note = notes.find((n) => n.code === 'BETTER_VALUE');

  assert.ok(note);
  assert.match(note.ar, /30%/);
  assert.equal(note.evidence.productId, 'p2');
});

test('«a shop you come back to» is not said about every shop', () => {
  // Live data: a note fired on 88 of 100 products because every seller she
  // had ever bought one thing from covered most of the catalogue. The
  // assembler now passes only repeat sellers, so the sentence means something
  // when it appears.
  const shopper: ShopperFacts = {
    ...stranger,
    boughtFromSellerIds: ['s1'],
  };
  const note = run({ shopper }).find((n) => n.code === 'TRUSTED_SELLER');
  assert.ok(note, 'a repeat seller is still worth saying');
  assert.match(note.ar, /بترجعي تشتري/, 'and the wording says returning, not once');

  // A seller she has no relationship with says nothing.
  const elsewhere: ShopperFacts = { ...stranger, boughtFromSellerIds: ['s9'] };
  assert.ok(
    !run({ shopper: elsewhere }).some((n) => n.code === 'TRUSTED_SELLER'),
  );
});

// ── «هذا المنتج بدأ يزداد عليه الطلب» ────────────────────────────────────

test('rising demand needs both growth and volume', () => {
  const climbing = { ...product, recentViews: 90, previousViews: 40 };
  assert.ok(run({ product: climbing }).some((n) => n.code === 'RISING_DEMAND'));

  // The same growth on tiny numbers is noise, not a trend.
  const tiny = { ...product, recentViews: 6, previousViews: 2 };
  assert.ok(!run({ product: tiny }).some((n) => n.code === 'RISING_DEMAND'));

  // Volume without growth is not news either.
  const flat = { ...product, recentViews: 400, previousViews: 400 };
  assert.ok(!run({ product: flat }).some((n) => n.code === 'RISING_DEMAND'));
});

// ── Scarcity ─────────────────────────────────────────────────────────────

test('«last few» is only said when it is literally true', () => {
  assert.ok(!run().some((n) => n.code === 'LAST_FEW'), '20 in stock is not few');

  const scarce = { ...product, stockUnits: 2 };
  assert.ok(run({ product: scarce }).some((n) => n.code === 'LAST_FEW'));

  const gone = { ...product, stockUnits: 0 };
  assert.ok(
    !run({ product: gone }).some((n) => n.code === 'LAST_FEW'),
    'sold out is not "last few", it is a different problem',
  );
});

// ── Intent ───────────────────────────────────────────────────────────────

test('a search term matches only when most of it is present', () => {
  assert.ok(termMatches('فستان سهرة', product));
  assert.ok(!termMatches('حقيبة ظهر جلد', product));
  // The failure mode worth guarding: one common word matching everything.
  assert.ok(!termMatches('فستان اطفال قطن', product));
});

test('the intent note quotes what she actually typed', () => {
  const shopper: ShopperFacts = {
    ...stranger,
    terms: [{ key: 'فستان سهرة', display: 'فستان سهرة' }],
  };
  const note = run({ shopper }).find((n) => n.code === 'MATCHES_INTENT');
  assert.ok(note);
  assert.match(note.ar, /فستان سهرة/);
});

test('the occasion note stands down when the intent note already fired', () => {
  const shopper: ShopperFacts = {
    ...stranger,
    terms: [{ key: 'فستان سهرة', display: 'فستان سهرة' }],
    occasions: ['wedding'],
  };
  const notes = run({ shopper });
  assert.ok(notes.some((n) => n.code === 'MATCHES_INTENT'));
  assert.ok(
    !notes.some((n) => n.code === 'FITS_OCCASION'),
    'saying both would be the same point twice',
  );
});

test('Reem says at most three things, and drops the weakest', () => {
  // A shopper Reem knows well can trip five rules at once. Saying all five
  // is not five times as useful — it is a wall the eye slides off, and the
  // line that mattered gets lost in it.
  const shopper: ShopperFacts = {
    ...stranger,
    owns: [navyDress],
    openLooks: [
      {
        lookId: 'l1',
        title: 'إطلالة عرس',
        missingSlots: ['DRESS'],
        occasion: 'wedding',
      },
    ],
    boughtFromSellerIds: ['s1'],
    terms: [{ key: 'فستان سهرة', display: 'فستان سهرة' }],
  };
  const notes = run({
    product: { ...product, stockUnits: 2, recentViews: 90, previousViews: 30 },
    shopper,
    alternative: { productId: 'p2', title: 'بديل', savingBps: 3000, score: 80 },
  });

  assert.equal(notes.length, MAX_NOTES);
  // The caution survives the cut, because it is ordered first.
  assert.equal(notes[0].code, 'ALREADY_OWN_SIMILAR');
  // And the merely contextual ones are what fell off.
  assert.ok(!notes.some((n) => n.code === 'TRUSTED_SELLER'));
  assert.ok(!notes.some((n) => n.code === 'LAST_FEW'));
});

test('every note carries evidence a screen could link to', () => {
  const shopper: ShopperFacts = {
    ...stranger,
    owns: [navyDress],
    openLooks: [
      { lookId: 'l1', title: 'إطلالة', missingSlots: ['DRESS'], occasion: null },
    ],
    boughtFromSellerIds: ['s1'],
  };
  const notes = run({ shopper, pairsWith: [blackShoes] });

  assert.ok(notes.length >= 3);
  for (const note of notes) {
    assert.ok(note.ar.trim().length > 5, `${note.code} has no sentence`);
    assert.equal(typeof note.evidence, 'object');
  }
});
