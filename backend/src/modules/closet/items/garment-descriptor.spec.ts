import assert from 'node:assert/strict';
import test from 'node:test';
import { ClosetSeason, ModestyLevel, OutfitSlot } from '@prisma/client';
import {
  describeCatalogGarment,
  describePersonalGarment,
  occasionsForSlot,
  sanitiseDescriptorOverrides,
  seasonMatches,
  seasonOf,
} from './garment-descriptor';

/**
 * The property under test throughout: a catalog garment and a personal one
 * reduce to the same kind of value. Where a test asserts one, it should be read
 * as asserting the pair.
 */

test('a catalog dress lands in the dress slot with its colour read', () => {
  const descriptor = describeCatalogGarment({
    categorySlug: 'dresses',
    title: 'فستان سهرة أسود طويل',
    description: 'من الساتان',
  });

  assert.equal(descriptor.slot, OutfitSlot.DRESS);
  assert.ok(descriptor.colours.includes('black'));
  assert.ok(descriptor.materials.includes('ساتان'));
});

test('a personal garment described in Arabic reaches the same shape', () => {
  const descriptor = describePersonalGarment(
    { title: 'جاكيت جلد أسود من السوق' },
    { slot: OutfitSlot.OUTERWEAR },
  );

  assert.equal(descriptor.slot, OutfitSlot.OUTERWEAR);
  assert.ok(descriptor.colours.includes('black'));
  assert.ok(descriptor.materials.includes('جلد'));
});

test('a variant she owns describes the piece, not the family', () => {
  const descriptor = describeCatalogGarment({
    categorySlug: 'dresses',
    title: 'فستان كلاسيكي',
    variantAttributes: { size: 'M', colour: 'كحلي' },
    variantName: 'كحلي / M',
  });

  assert.ok(descriptor.colours.includes('navy'));
  assert.equal(descriptor.size, 'M');
});

test('a shoe size is not filed under clothing', () => {
  const descriptor = describeCatalogGarment({
    categorySlug: 'shoes',
    title: 'حذاء كعب',
    variantAttributes: { size: '38' },
  });

  assert.equal(descriptor.slot, OutfitSlot.SHOES);
  assert.equal(descriptor.size, '38');
});

test('an unsized slot carries no size at all', () => {
  const descriptor = describeCatalogGarment({
    categorySlug: 'handbags',
    title: 'حقيبة يد',
    variantAttributes: { size: 'M' },
  });

  assert.equal(descriptor.slot, OutfitSlot.BAG);
  assert.equal(descriptor.size, null, 'a handbag has no size system');
});

// ── Seasons ─────────────────────────────────────────────────────────────

test('fabric decides the season', () => {
  const wool = describePersonalGarment({ title: 'كنزة صوف' }, { slot: OutfitSlot.TOP });
  const linen = describePersonalGarment({ title: 'بلوزة لينن' }, { slot: OutfitSlot.TOP });

  assert.deepEqual(wool.seasons, [ClosetSeason.WINTER]);
  assert.deepEqual(linen.seasons, [ClosetSeason.SUMMER]);
});

test('a blend is a shoulder-season garment, not a contradiction', () => {
  const descriptor = describePersonalGarment(
    { title: 'بلوزة قطن وصوف' },
    { slot: OutfitSlot.TOP },
  );
  assert.deepEqual(descriptor.seasons, [ClosetSeason.TRANSITIONAL]);
});

test('outerwear keeps its season whatever it is made of', () => {
  const descriptor = describePersonalGarment(
    { title: 'جاكيت لينن' },
    { slot: OutfitSlot.OUTERWEAR },
  );
  assert.ok(descriptor.seasons.includes(ClosetSeason.WINTER));
});

test('a bag has no season and must never be filtered out by one', () => {
  const descriptor = describePersonalGarment({ title: 'شنطة' }, { slot: OutfitSlot.BAG });
  assert.deepEqual(descriptor.seasons, [ClosetSeason.ALL]);
  assert.ok(seasonMatches(descriptor.seasons, ClosetSeason.WINTER));
  assert.ok(seasonMatches(descriptor.seasons, ClosetSeason.SUMMER));
});

test('an unknown season excludes nothing', () => {
  assert.ok(seasonMatches([], ClosetSeason.WINTER));
  assert.ok(seasonMatches([ClosetSeason.ALL], ClosetSeason.SUMMER));
  assert.ok(!seasonMatches([ClosetSeason.SUMMER], ClosetSeason.WINTER));
});

test('the season of a date is the Syrian calendar', () => {
  assert.equal(seasonOf(new Date('2026-01-15')), ClosetSeason.WINTER);
  assert.equal(seasonOf(new Date('2026-07-15')), ClosetSeason.SUMMER);
  assert.equal(seasonOf(new Date('2026-04-15')), ClosetSeason.TRANSITIONAL);
});

// ── Occasions ───────────────────────────────────────────────────────────

test('occasions are the inverse of the stylist table, not a second table', () => {
  const forDress = occasionsForSlot(OutfitSlot.DRESS);
  assert.ok(forDress.includes('wedding'));
  assert.ok(forDress.includes('evening'));
  assert.ok(!occasionsForSlot(OutfitSlot.BOTTOM).includes('wedding'));
});

test('an evening dress does not claim to be daywear', () => {
  const descriptor = describeCatalogGarment({
    categorySlug: 'dresses',
    title: 'فستان سهرة مطرّز',
  });
  assert.ok(descriptor.occasions.includes('evening'));
  assert.ok(!descriptor.occasions.includes('daily'));
});

// ── Overrides ───────────────────────────────────────────────────────────

test('her correction beats the derivation', () => {
  const descriptor = describeCatalogGarment(
    { categorySlug: 'dresses', title: 'فستان أسود' },
    { colours: ['navy'], slot: OutfitSlot.ABAYA },
  );

  assert.equal(descriptor.slot, OutfitSlot.ABAYA);
  assert.deepEqual(descriptor.colours, ['navy']);
});

test('an empty override means "none", not "guess again"', () => {
  const descriptor = describeCatalogGarment(
    { categorySlug: 'dresses', title: 'فستان أسود' },
    { colours: [] },
  );
  assert.deepEqual(descriptor.colours, []);
});

test('unknown vocabulary is dropped at the door', () => {
  const clean = sanitiseDescriptorOverrides({
    colours: ['black', 'مرجاني حالم', 'navy'],
    materials: ['حرير', 'قماش فضائي'],
    occasions: ['wedding', 'not-an-occasion'],
    size: '  M  ',
  });

  assert.deepEqual(clean.colours, ['black', 'navy']);
  assert.deepEqual(clean.materials, ['حرير']);
  assert.deepEqual(clean.occasions, ['wedding']);
  assert.equal(clean.size, 'M');
});

test('a blank size clears rather than stores whitespace', () => {
  assert.equal(sanitiseDescriptorOverrides({ size: '   ' }).size, null);
});

test('an abaya is always full coverage', () => {
  const descriptor = describeCatalogGarment({
    categorySlug: 'abayas',
    title: 'عباية',
  });
  assert.equal(descriptor.modesty, ModestyLevel.FULL_COVERAGE);
});
