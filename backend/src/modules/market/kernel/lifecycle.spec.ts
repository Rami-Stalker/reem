import assert from 'node:assert/strict';
import test from 'node:test';

import {
  DORMANT_DAYS,
  ItemLife,
  RESALE_FLOOR_SYP,
  UNWORN_RESALE_DAYS,
  careFor,
  readLife,
  readRotation,
  suggestResalePrice,
} from './lifecycle';

/**
 * Life cycle.
 *
 * Almost every test here is about the system keeping quiet. Advice about a
 * woman's own wardrobe is only tolerated while it is right, so the cases worth
 * pinning down are the ones where the obvious rule would produce a wrong and
 * slightly insulting sentence.
 */

const item = (over: Partial<ItemLife> = {}): ItemLife => ({
  slot: 'DRESS',
  materials: [],
  seasons: ['ALL'],
  wearCount: 4,
  daysSinceWorn: 10,
  daysOwned: 200,
  purchasePriceSyp: 4000,
  isFavourite: false,
  ...over,
});

// ── Restraint ────────────────────────────────────────────────────────────

test('a piece in use is left alone', () => {
  const reading = readLife(item());
  assert.equal(reading.rotation, 'ACTIVE');
  assert.equal(reading.disposition, 'KEEP');
  assert.equal(reading.reason, '', 'KEEP must say nothing at all');
});

test('a dress bought last week is new, not unworn', () => {
  const reading = readLife(item({ wearCount: 0, daysSinceWorn: null, daysOwned: 6 }));
  assert.equal(reading.rotation, 'ACTIVE');
  assert.equal(reading.disposition, 'KEEP');
});

test('a winter coat untouched since March is not dormant in August', () => {
  const coat = item({
    slot: 'OUTERWEAR',
    seasons: ['WINTER'],
    daysSinceWorn: 150,
    wearCount: 12,
  });
  assert.equal(readRotation(coat, 'SUMMER'), 'ACTIVE');
  // And in its own season the same coat is judged normally.
  assert.equal(readRotation(coat, 'WINTER'), 'DORMANT');
});

test('a favourite is never put up for sale', () => {
  const loved = item({
    isFavourite: true,
    wearCount: 1,
    daysSinceWorn: DORMANT_DAYS + 90,
  });
  const reading = readLife(loved);
  assert.equal(reading.rotation, 'DORMANT');
  assert.equal(reading.disposition, 'RESTYLE', 'her own answer outranks the clock');
});

test('a much-worn piece that stopped needs ideas, not a buyer', () => {
  const reading = readLife(item({ wearCount: 20, daysSinceWorn: 200 }));
  assert.equal(reading.disposition, 'RESTYLE');
});

test('unworn for four months is not yet unwanted', () => {
  const reading = readLife(
    item({ wearCount: 0, daysSinceWorn: null, daysOwned: UNWORN_RESALE_DAYS - 60 }),
  );
  assert.equal(reading.rotation, 'UNWORN');
  assert.equal(reading.disposition, 'RESTYLE');
});

// ── The advice that is meant to fire ─────────────────────────────────────

test('unworn for a year, and worth something, is a resale', () => {
  const reading = readLife(
    item({ wearCount: 0, daysSinceWorn: null, daysOwned: 400, purchasePriceSyp: 6000 }),
  );
  assert.equal(reading.rotation, 'UNWORN');
  assert.equal(reading.disposition, 'RESELL');
  assert.ok(reading.reason.length > 0);
});

test('a cheap unworn piece is a donation, not a listing', () => {
  // Selling it would cost more effort than it is worth, and saying so is the
  // honest answer rather than the softer one.
  const reading = readLife(
    item({
      wearCount: 0,
      daysSinceWorn: null,
      daysOwned: 400,
      purchasePriceSyp: RESALE_FLOOR_SYP - 100,
    }),
  );
  assert.equal(reading.disposition, 'DONATE');
});

test('a barely worn dormant piece is a resale candidate', () => {
  const reading = readLife(item({ wearCount: 2, daysSinceWorn: 200 }));
  assert.equal(reading.rotation, 'DORMANT');
  assert.equal(reading.disposition, 'RESELL');
});

test('slowing down earns a styling nudge, never a sale', () => {
  const reading = readLife(item({ daysSinceWorn: 75 }));
  assert.equal(reading.rotation, 'SLOWING');
  assert.equal(reading.disposition, 'RESTYLE');
});

// ── Cost per wear ────────────────────────────────────────────────────────

test('cost per wear is null when it cannot be known', () => {
  assert.equal(readLife(item({ purchasePriceSyp: null })).costPerWear, null);
  assert.equal(
    readLife(item({ wearCount: 0, daysSinceWorn: null, daysOwned: 10 })).costPerWear,
    null,
    'dividing by zero wears is not "expensive", it is unknown',
  );
});

test('cost per wear falls as she wears it', () => {
  const once = readLife(item({ wearCount: 1, purchasePriceSyp: 4000 })).costPerWear;
  const often = readLife(item({ wearCount: 20, purchasePriceSyp: 4000 })).costPerWear;
  assert.equal(once, 4000);
  assert.equal(often, 200);
});

test('confidence drops when the purchase date is unknown', () => {
  const known = readLife(item()).confidence;
  const unknown = readLife(item({ daysOwned: null, purchasePriceSyp: null })).confidence;
  assert.ok(unknown < known);
});

// ── Care ─────────────────────────────────────────────────────────────────

test('care comes from the fabric she actually owns', () => {
  const notes = careFor(item({ materials: ['حرير'] }));
  assert.equal(notes.length, 1);
  assert.equal(notes[0].code, 'SILK');
});

test('care is capped at two notes', () => {
  const notes = careFor(
    item({ slot: 'SHOES', materials: ['جلد', 'قطن', 'حرير', 'صوف'] }),
  );
  assert.equal(notes.length, 2, 'a manual is not advice');
});

test('an unknown fabric produces no invented care', () => {
  assert.deepEqual(careFor(item({ slot: 'TOP', materials: ['بوليستر'] })), []);
});

// ── Resale pricing ───────────────────────────────────────────────────────

test('a used price is a share of what she paid, by condition', () => {
  assert.equal(suggestResalePrice(4000, 'NEW_WITH_TAGS'), 2800);
  assert.equal(suggestResalePrice(4000, 'GOOD'), 1600);
  assert.ok(
    (suggestResalePrice(4000, 'FAIR') ?? 0) < (suggestResalePrice(4000, 'GOOD') ?? 0),
  );
});

test('no original price means no suggestion, not a guess', () => {
  assert.equal(suggestResalePrice(null, 'GOOD'), null);
  assert.equal(suggestResalePrice(4000, 'SHREDDED'), null);
});
