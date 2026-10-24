import assert from 'node:assert/strict';
import test from 'node:test';
import { ReviewFit } from '@prisma/client';
import {
  FitVoice,
  bandLabel,
  hasProfile,
  heightBand,
  isNearMe,
  suggestedSize,
  tally,
  usualSizeOf,
} from './fit-reviews';

/** «تقييمات من بمقاسي», without a database. */

const voice = (overrides: Partial<FitVoice>): FitVoice => ({
  fit: null,
  sizeBought: null,
  heightBand: null,
  usualSize: null,
  ...overrides,
});

test('height is published as a 5 cm band, never the centimetre', () => {
  assert.equal(heightBand(163), 160);
  assert.equal(heightBand(160), 160);
  assert.equal(heightBand(164), 160);
  assert.equal(heightBand(165), 165);
  assert.equal(bandLabel(160), '160–164');
  // A typo is not a height.
  assert.equal(heightBand(16), null);
  assert.equal(heightBand(260), null);
  assert.equal(heightBand(null), null);
});

test('a usual size is one every boutique can be compared on', () => {
  assert.equal(usualSizeOf(' m '), 'M');
  assert.equal(usualSizeOf('2XL'), 'XXL');
  assert.equal(usualSizeOf('38'), '38');
  assert.equal(usualSizeOf('37'), '37');
  assert.equal(usualSizeOf('free size'), null);
  assert.equal(usualSizeOf('99'), null);
  assert.equal(usualSizeOf(''), null);
});

test('near means: every dimension both sides gave agrees', () => {
  const me = { heightCm: 162, usualSize: 'M' };

  assert.equal(isNearMe(me, voice({ heightBand: 160, usualSize: 'M' })), true);
  assert.equal(isNearMe(me, voice({ heightBand: 165, usualSize: 'M' })), true, '165–169 is close');
  assert.equal(isNearMe(me, voice({ heightBand: 175, usualSize: 'M' })), false, 'a head taller');
  assert.equal(isNearMe(me, voice({ heightBand: 160, usualSize: 'L' })), false);
  // Only the size is known: matched on the size.
  assert.equal(isNearMe(me, voice({ usualSize: 'M' })), true);
  // Only the height is known.
  assert.equal(isNearMe(me, voice({ heightBand: 160 })), true);
});

test('the size she bought counts as hers, so an M finds the M who sized up', () => {
  const me = { heightCm: null, usualSize: 'M' };
  assert.equal(isNearMe(me, voice({ usualSize: 'S', sizeBought: 'm' })), true);
});

test('a review with no body attached is never "from someone like me"', () => {
  const me = { heightCm: 162, usualSize: 'M' };
  assert.equal(isNearMe(me, voice({ fit: ReviewFit.TRUE_TO_SIZE })), false);
  assert.equal(isNearMe({ heightCm: null, usualSize: null }, voice({ usualSize: 'M' })), false);
  assert.equal(hasProfile({ heightCm: null, usualSize: null }), false);
  assert.equal(hasProfile(null), false);
  assert.equal(hasProfile({ heightCm: 160, usualSize: null }), true);
});

test('no verdict below three voices', () => {
  const two = tally([
    voice({ fit: ReviewFit.RUNS_SMALL }),
    voice({ fit: ReviewFit.RUNS_SMALL }),
    voice({}),
  ]);
  assert.equal(two.total, 2, 'a review without a fit is not a voice');
  assert.equal(two.enough, false);
  assert.equal(two.verdict, null);
});

test('a verdict needs a majority, not a plurality', () => {
  const clear = tally([
    voice({ fit: ReviewFit.RUNS_SMALL }),
    voice({ fit: ReviewFit.RUNS_SMALL }),
    voice({ fit: ReviewFit.TRUE_TO_SIZE }),
  ]);
  assert.equal(clear.verdict, ReviewFit.RUNS_SMALL);

  const split = tally([
    voice({ fit: ReviewFit.RUNS_SMALL }),
    voice({ fit: ReviewFit.RUNS_SMALL }),
    voice({ fit: ReviewFit.TRUE_TO_SIZE }),
    voice({ fit: ReviewFit.TRUE_TO_SIZE }),
    voice({ fit: ReviewFit.RUNS_LARGE }),
  ]);
  assert.equal(split.enough, true);
  assert.equal(split.verdict, null, 'opinions differ');
});

test('the suggested size: two or more, and no tie', () => {
  const kept = (size: string) => voice({ fit: ReviewFit.TRUE_TO_SIZE, sizeBought: size });

  assert.equal(suggestedSize([kept('L'), kept('l'), kept('M')]), 'L');
  assert.equal(suggestedSize([kept('L')]), null, 'one woman is an anecdote');
  assert.equal(suggestedSize([kept('L'), kept('L'), kept('M'), kept('M')]), null, 'a tie');
  // Only voices that called it right.
  assert.equal(
    suggestedSize([
      voice({ fit: ReviewFit.RUNS_SMALL, sizeBought: 'M' }),
      voice({ fit: ReviewFit.RUNS_SMALL, sizeBought: 'M' }),
    ]),
    null,
  );
});
