import assert from 'node:assert/strict';
import test from 'node:test';
import { OutfitSlot } from '@prisma/client';
import { applyPriceRefinement, detectRefinement } from './refinement';
import { emptyBrief } from './style-brief';
import { adviceFor, colourPairings, smartFollowUps } from '../reply/style-advice';
import { composeConversationalReply } from '../reply/reply-composer';

test('"وريني أرخص" is read as cheaper, "أغلى" as pricier, "كمان" as more', () => {
  assert.equal(detectRefinement('وريني أرخص').cheaper, true);
  assert.equal(detectRefinement('بدي شي أغلى وأفخم').pricier, true);
  assert.equal(detectRefinement('وريني كمان خيارات').more, true);
  const plain = detectRefinement('بدي فستان أسود');
  assert.deepEqual(plain, { cheaper: false, pricier: false, more: false });
});

test('cheaper lowers the ceiling below what she was just shown', () => {
  const brief = emptyBrief();
  const next = applyPriceRefinement(
    brief,
    { cheaper: true, pricier: false, more: false },
    [400000, 600000, 800000],
  );
  assert.equal(next.budgetMax, 480000);
  assert.equal(next.budgetMin, null);
});

test('cheaper never goes above a budget she already stated', () => {
  const brief = { ...emptyBrief(), budgetMax: 300000 };
  const next = applyPriceRefinement(
    brief,
    { cheaper: true, pricier: false, more: false },
    [500000, 900000],
  );
  assert.equal(next.budgetMax, 240000);
});

test('pricier sets a floor near the top of the last answer', () => {
  const next = applyPriceRefinement(
    { ...emptyBrief(), budgetMax: 500000 },
    { cheaper: false, pricier: true, more: false },
    [200000, 450000],
  );
  assert.equal(next.budgetMin, 405000);
  assert.equal(next.budgetMax, null);
});

test('colour advice reads harmony in both directions', () => {
  const pairs = colourPairings('black');
  assert.ok(pairs.includes('gold'));
  const advice = adviceFor({ ...emptyBrief(), colours: ['black'] }, 'شو بيلبق مع الأسود؟');
  assert.match(advice ?? '', /أسود/);
});

test('white at a wedding gets the honest answer', () => {
  const advice = adviceFor(
    { ...emptyBrief(), colours: ['white'], occasion: 'wedding' },
    'ينفع ألبس أبيض بعرس؟',
  );
  assert.match(advice ?? '', /عروس/);
  // The direct answer replaces the generic colour line rather than stacking on it.
  assert.doesNotMatch(advice ?? '', /يتناسق/);
});

test('follow-ups suggest completing the look after a dress', () => {
  const chips = smartFollowUps(
    { ...emptyBrief(), slots: [OutfitSlot.DRESS], colours: ['olive'] },
    ['وريني المزيد'],
  );
  assert.ok(chips.some((chip) => chip.includes('حذاء')));
  assert.ok(chips.some((chip) => chip.startsWith('نفسه بلون')));
  assert.ok(chips.length <= 5);
});

test('a thank-you is answered as one, not as a greeting', () => {
  const reply = composeConversationalReply({
    brief: emptyBrief(),
    greeting: true,
    message: 'شكراً كتير',
  });
  assert.match(reply.text, /العفو/);
});
