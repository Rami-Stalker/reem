import assert from 'node:assert/strict';
import test from 'node:test';

import { LIKE_GLYPH, summarise } from './reaction-summary';

test('a plain like is counted as the heart, with explicit hearts', () => {
  const summary = summarise([
    { key: 'a', emoji: null, count: 3 },
    { key: 'a', emoji: '❤️', count: 1 },
    { key: 'a', emoji: '🔥', count: 2 },
  ]).get('a');
  assert.deepEqual(summary, [
    { emoji: LIKE_GLYPH, count: 4 },
    { emoji: '🔥', count: 2 },
  ]);
});

test('the summary keeps the three most chosen, most first', () => {
  const summary = summarise([
    { key: 'a', emoji: '😢', count: 1 },
    { key: 'a', emoji: '😍', count: 5 },
    { key: 'a', emoji: '🔥', count: 3 },
    { key: 'a', emoji: '👏', count: 2 },
  ]).get('a');
  assert.deepEqual(
    summary?.map((r) => r.emoji),
    ['😍', '🔥', '👏'],
  );
});

test('each piece gets its own summary', () => {
  const summaries = summarise([
    { key: 'a', emoji: '🔥', count: 1 },
    { key: 'b', emoji: '😂', count: 2 },
  ]);
  assert.equal(summaries.get('a')?.[0].emoji, '🔥');
  assert.equal(summaries.get('b')?.[0].emoji, '😂');
});
