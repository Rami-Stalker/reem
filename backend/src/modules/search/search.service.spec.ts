import assert from 'node:assert/strict';
import test from 'node:test';
import { SearchService } from './search.service';

/**
 * `trending` reads history and records nothing, so the signal recorder is a
 * stub here. It is passed rather than omitted because the constructor is the
 * only place the dependency is visible, and a test that fakes it away would
 * stop noticing if the seam moved.
 */
const noSignals = {
  recordSearch: () => {},
  recordSearchClick: () => {},
} as never;

/** What `trending` offers before anyone has searched. */
const FALLBACK = ['فستان', 'عطر', 'حقيبة', 'حذاء', 'هدية', 'ورد'];

test('trending merges search history with fallback terms without duplicates', async () => {
  const prisma = {
    searchHistory: {
      groupBy: async () => [
        { query: 'abaya' },
        { query: 'makeup' },
      ],
    },
  };
  const service = new SearchService(prisma as never, noSignals);

  assert.deepEqual(await service.trending(), [
    'abaya',
    'makeup',
    ...FALLBACK,
  ]);
});

test('trending falls back when no search history exists', async () => {
  const prisma = {
    searchHistory: {
      groupBy: async () => [],
    },
  };
  const service = new SearchService(prisma as never, noSignals);

  assert.deepEqual(await service.trending(), FALLBACK);
});

test('every fallback term is Arabic, because the catalogue is', () => {
  // The list used to be English — dresses, perfume, handbags … — and each of
  // those chips ran as a real query against Arabic titles, so every one of
  // them opened an empty result page. Pinning the script here is what stops
  // that regressing; pinning the exact words would only pin today's stock.
  const arabic = /^[؀-ۿ\s]+$/;
  for (const term of FALLBACK) {
    assert.ok(arabic.test(term), `${term} is not Arabic`);
  }
});
