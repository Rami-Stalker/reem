import assert from 'node:assert/strict';
import test from 'node:test';
import { ModestyLevel, OutfitSlot, StylePersona } from '@prisma/client';
import {
  colourEntry,
  coloursHarmonise,
  detectBudget,
  detectColours,
  detectDeadlineDays,
  detectModesty,
  detectOccasion,
  detectPersonas,
  detectRecipientAge,
  detectSizes,
  detectSlots,
  garmentModesty,
  looksLikeGift,
  looksLikeOutfit,
  normaliseArabic,
  slotForCategorySlug,
} from './stylist-lexicon';

// The three sentences the feature was specified against. If these stop
// parsing, the stylist has stopped understanding its own brief.
const WEDDING = 'عندي مناسبة بعد أسبوع وأريد فستانًا أنيقًا ومحتشمًا بميزانية 500 ألف.';
const GIFT = 'أريد هدية لصديقتي عمرها 25 سنة وتحب الأشياء الناعمة.';
const OUTFIT = 'أريد فستانًا أسود مع حقيبة وحذاء مناسبين.';

test('Arabic spelling variants fold to one form', () => {
  // أ/إ/آ, ة/ه, ى/ي and the diacritics are all keyboard accidents, not
  // different words — every lookup would miss if they were not folded.
  assert.equal(normaliseArabic('أنيقًا'), normaliseArabic('انيقا'));
  assert.equal(normaliseArabic('مناسبة'), normaliseArabic('مناسبه'));
  assert.equal(normaliseArabic('فسـ__تان'.replace(/_/g, '')), normaliseArabic('فستان'));
});

test('Arabic-Indic digits fold to ASCII so a budget can be parsed', () => {
  assert.equal(normaliseArabic('٥٠٠'), '500');
  assert.deepEqual(detectBudget('ميزانية ٥٠٠ ألف'), { max: 500_000 });
});

test('«٥٠٠ ألف» is half a million, not five hundred', () => {
  // The single most consequential parse in the feature: reading the
  // multiplier as decoration puts every result below the cheapest row in
  // the catalog.
  assert.deepEqual(detectBudget('بميزانية 500 ألف'), { max: 500_000 });
  assert.deepEqual(detectBudget('تحت مليون'), { max: 1_000_000 });
  assert.deepEqual(detectBudget('فوق 300 الف'), { min: 300_000 });
});

test('a budget range is read as a band', () => {
  const range = detectBudget('بين 500 ألف و مليون');
  assert.ok(range);
  assert.equal(range.min, 500_000);
  assert.equal(range.max, 1_000_000);
});

test('a sentence with no money in it yields no budget', () => {
  assert.equal(detectBudget('بدي فستان أسود'), null);
  // A bare small number is not a budget — it is far more likely a size.
  assert.equal(detectBudget('مقاس 38'), null);
});

test('the wedding sentence parses into every field it states', () => {
  assert.equal(detectOccasion(WEDDING), 'evening');
  assert.deepEqual(detectSlots(WEDDING), [OutfitSlot.DRESS]);
  assert.deepEqual(detectBudget(WEDDING), { max: 500_000 });
  assert.equal(detectModesty(WEDDING), ModestyLevel.MODEST);
  assert.ok(detectPersonas(WEDDING).includes(StylePersona.CLASSIC));
  assert.equal(detectDeadlineDays(WEDDING), 7);
});

test('the gift sentence is recognised as a gift with an age', () => {
  assert.equal(looksLikeGift(GIFT), true);
  assert.equal(detectRecipientAge(GIFT), 25);
  assert.ok(detectPersonas(GIFT).includes(StylePersona.ROMANTIC));
});

test('naming several pieces is an outfit request even without the word', () => {
  assert.equal(looksLikeOutfit(OUTFIT), true);
  const slots = detectSlots(OUTFIT);
  assert.ok(slots.includes(OutfitSlot.DRESS));
  assert.ok(slots.includes(OutfitSlot.BAG));
  assert.ok(slots.includes(OutfitSlot.SHOES));
  assert.deepEqual(detectColours(OUTFIT), ['black']);
});

test('one named piece is not an outfit request', () => {
  assert.equal(looksLikeOutfit('بدي فستان أسود'), false);
});

test('the Levantine ها clitic does not hide the garment', () => {
  // "هالفستان" is ها + الفستان, and it is how a refinement to a photo search
  // is actually typed. Before this the colour and the budget in the same
  // sentence parsed while the piece itself did not.
  assert.deepEqual(detectSlots('بدي نفس هالفستان بس بالأسود'), [OutfitSlot.DRESS]);
  assert.deepEqual(detectColours('بدي نفس هالفستان بس بالأسود'), ['black']);

  // And the ordinary forms still work, with and without the article.
  assert.deepEqual(detectSlots('بدي فستان'), [OutfitSlot.DRESS]);
  assert.deepEqual(detectSlots('بدي الفستان'), [OutfitSlot.DRESS]);
  assert.deepEqual(detectSlots('وحذاء'), [OutfitSlot.SHOES]);
});

test('colours are found in the forms the catalog actually writes', () => {
  // Seed titles read "بلون الشامبانيا" / "بلون الأسود اللامع" — the colour is
  // in the prose, not only in a variant attribute.
  assert.deepEqual(detectColours('فستان سهرة بلون الشامبانيا'), ['gold']);
  assert.deepEqual(detectColours('حذاء بلون الأسود اللامع'), ['black']);
  assert.deepEqual(detectColours('كنزة بلون اللافندر'), ['purple']);
});

test('a neutral sits with anything and two clashing colours do not', () => {
  assert.equal(coloursHarmonise('black', 'red'), true);
  assert.equal(coloursHarmonise('gold', 'burgundy'), true);
  assert.equal(coloursHarmonise('green', 'purple'), false);
  assert.equal(colourEntry('beige')?.neutral, true);
});

test('sizes need an anchor word, so a price is never read as a size', () => {
  assert.deepEqual(detectSizes('مقاس M'), { clothing: 'M' });
  assert.deepEqual(detectSizes('مقاس 38'), { shoes: '38' });
  assert.deepEqual(detectSizes('بدي لارج'), { clothing: 'L' });
  // 500,000 contains no anchored size; a naive scan would call this shoes 50.
  assert.deepEqual(detectSizes('بميزانية 500 ألف'), {});
});

test('deadlines are read in days', () => {
  assert.equal(detectDeadlineDays('بعد أسبوع'), 7);
  // The dual carries its own count: "يومين" is two days with no digit in it.
  assert.equal(detectDeadlineDays('بعد يومين'), 2);
  assert.equal(detectDeadlineDays('بعد 3 ايام'), 3);
  assert.equal(detectDeadlineDays('بكرا'), 1);
});

test('modesty is read from the garment, not only from the request', () => {
  assert.equal(
    garmentModesty({ categorySlug: 'abayas', title: 'عباية يومية', attributes: null }),
    ModestyLevel.FULL_COVERAGE,
  );
  assert.equal(
    garmentModesty({
      categorySlug: 'dresses',
      title: 'فستان سهرة',
      attributes: { sleeve_length: 'كم طويل' },
    }),
    ModestyLevel.MODEST,
  );
  assert.equal(
    garmentModesty({
      categorySlug: 'dresses',
      title: 'فستان كوكتيل بدون أكمام',
      attributes: null,
    }),
    ModestyLevel.EXPRESSIVE,
  );
  // A handbag has no modesty; scoring one as immodest would be nonsense.
  assert.equal(
    garmentModesty({ categorySlug: 'handbags', title: 'حقيبة يد', attributes: null }),
    null,
  );
});

test('slots and leaf categories map both ways', () => {
  assert.equal(slotForCategorySlug('dresses'), OutfitSlot.DRESS);
  assert.equal(slotForCategorySlug('handbags'), OutfitSlot.BAG);
  // GIFT lists half the catalog and must not win the inverse lookup.
  assert.equal(slotForCategorySlug('chocolate'), null);
});
