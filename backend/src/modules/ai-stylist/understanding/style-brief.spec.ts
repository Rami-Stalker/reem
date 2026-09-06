import assert from 'node:assert/strict';
import test from 'node:test';
import { ModestyLevel, OutfitSlot, StylePersona } from '@prisma/client';
import {
  briefFromJson,
  briefToJson,
  emptyBrief,
  formatSyp,
  mergeBriefs,
  sanitiseBrief,
} from './style-brief';

test('a value outside the closed vocabulary is dropped, not stored', () => {
  // The guarantee the whole feature rests on: a model may propose anything,
  // and only vocabulary members survive to reach a query.
  const brief = sanitiseBrief({
    occasion: 'moon-landing',
    colours: ['black', 'iridescent-dream'],
    slots: ['DRESS', 'SPACESUIT'],
    personas: ['GLAM', 'CHAOTIC'],
    modesty: 'VERY_MODEST',
  });

  assert.equal(brief.occasion, undefined);
  assert.deepEqual(brief.colours, ['black']);
  assert.deepEqual(brief.slots, [OutfitSlot.DRESS]);
  assert.deepEqual(brief.personas, [StylePersona.GLAM]);
  assert.equal(brief.modesty, undefined);
});

test('a category slug that does not exist is refused', () => {
  const known = new Set(['dresses', 'handbags']);

  const brief = sanitiseBrief(
    { category_slugs: ['dresses', 'spacesuits'] },
    { knownCategorySlugs: known },
  );

  assert.deepEqual(brief.categorySlugs, ['dresses']);
});

test('an impossible budget is repaired rather than emitted', () => {
  // min > max can only ever return nothing, so it is a misread sentence, not
  // a constraint to honour literally.
  const brief = sanitiseBrief({ budget_min: 900_000, budget_max: 400_000 });

  assert.equal(brief.budgetMin, 400_000);
  assert.equal(brief.budgetMax, 900_000);
});

test('nonsense numbers are dropped', () => {
  const brief = sanitiseBrief({
    budget_max: -5,
    recipient_age: 400,
    confidence: 9,
    deadline_days: -3,
  });

  assert.equal(brief.budgetMax, undefined);
  assert.equal(brief.recipientAge, undefined);
  assert.equal(brief.confidence, 1);
  assert.equal(brief.deadlineDays, undefined);
});

test('a restated budget replaces; a named colour accumulates', () => {
  // The asymmetry that makes follow-ups work: correcting a scalar is a
  // correction, adding a colour extends the look.
  const base = { ...emptyBrief(), budgetMax: 500_000, colours: ['black'] };

  const merged = mergeBriefs(base, { budgetMax: 800_000, colours: ['gold'] });

  assert.equal(merged.budgetMax, 800_000);
  assert.deepEqual(merged.colours, ['gold', 'black']);
});

test('naming slots redirects the conversation rather than adding to it', () => {
  const base = { ...emptyBrief(), slots: [OutfitSlot.DRESS] };

  const merged = mergeBriefs(base, { slots: [OutfitSlot.BAG] });

  assert.deepEqual(merged.slots, [OutfitSlot.BAG]);
});

test('asking for a colour lifts an earlier refusal of it', () => {
  const base = { ...emptyBrief(), avoidColours: ['red'] };

  const merged = mergeBriefs(base, { colours: ['red'] });

  assert.deepEqual(merged.colours, ['red']);
  assert.deepEqual(merged.avoidColours, []);
});

test('keywords describe the turn, so they do not accumulate', () => {
  const base = { ...emptyBrief(), keywords: ['مطرز'] };

  const merged = mergeBriefs(base, { keywords: ['حرير'] });

  assert.deepEqual(merged.keywords, ['حرير']);
});

test('a brief survives a round trip through the database column', () => {
  const original = {
    ...emptyBrief(),
    intent: 'BUILD_OUTFIT' as const,
    occasion: 'wedding',
    slots: [OutfitSlot.DRESS, OutfitSlot.SHOES],
    budgetMax: 750_000,
    colours: ['black', 'gold'],
    sizes: { clothing: 'M', shoes: '38' },
    modesty: ModestyLevel.MODEST,
    personas: [StylePersona.GLAM],
    recipientAge: 25,
    forSelf: false,
    deadlineDays: 7,
    confidence: 0.83,
  };

  const restored = briefFromJson(briefToJson(original) as never);

  assert.equal(restored.intent, 'BUILD_OUTFIT');
  assert.equal(restored.occasion, 'wedding');
  assert.deepEqual(restored.slots, [OutfitSlot.DRESS, OutfitSlot.SHOES]);
  assert.equal(restored.budgetMax, 750_000);
  assert.deepEqual(restored.colours, ['black', 'gold']);
  assert.deepEqual(restored.sizes, { clothing: 'M', shoes: '38' });
  assert.equal(restored.modesty, ModestyLevel.MODEST);
  assert.equal(restored.forSelf, false);
  assert.equal(restored.deadlineDays, 7);
});

test('money is written the way she said it', () => {
  assert.equal(formatSyp(500_000), '500 ألف ل.س');
  assert.equal(formatSyp(1_000_000), '1 مليون ل.س');
  assert.equal(formatSyp(1_200_000), '1.2 مليون ل.س');
});
