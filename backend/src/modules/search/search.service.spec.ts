import assert from 'node:assert/strict';
import test from 'node:test';
import { SearchService } from './search.service';

test('trending merges search history with fallback terms without duplicates', async () => {
  const prisma = {
    searchHistory: {
      groupBy: async () => [
        { query: 'abaya' },
        { query: 'makeup' },
      ],
    },
  };
  const service = new SearchService(prisma as never);

  assert.deepEqual(await service.trending(), [
    'abaya',
    'makeup',
    'dresses',
    'perfume',
    'handbags',
    'heels',
    'gifts',
  ]);
});

test('trending falls back when no search history exists', async () => {
  const prisma = {
    searchHistory: {
      groupBy: async () => [],
    },
  };
  const service = new SearchService(prisma as never);

  assert.deepEqual(await service.trending(), [
    'dresses',
    'perfume',
    'handbags',
    'heels',
    'gifts',
    'makeup',
  ]);
});
