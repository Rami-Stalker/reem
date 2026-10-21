import assert from 'node:assert/strict';
import test from 'node:test';
import { PrismaClient } from '@prisma/client';

import { searchKey, SIMILARITY_FLOOR } from './arabic';

/**
 * The TypeScript key and the SQL key have to be the same function.
 *
 * They are written twice because they run in two places — the query is folded
 * in Node, the catalogue is folded inside the index — and a difference
 * between them does not raise anything. It just stops matching, which looks
 * from the outside like a shop with nothing in it. So the corpus below goes
 * through both and the two answers are compared.
 */
const prisma = new PrismaClient();

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

test.after(async () => {
  await prisma.$disconnect();
});

/** Real listings, real queries, and the ways a phone keyboard mangles them. */
const CORPUS = [
  'عباية',
  'عبايه',
  'عَبَايَة',
  'أحمر',
  'احمر',
  'إسورة',
  'آية',
  'فُسْتَان طَوِيل',
  'فستان طويل',
  'مــكـياج',
  'حقيبة يد',
  'عطر نسائي',
  'ذهب ٢١ قيراط',
  'ذهب 21 قيراط',
  'ساعة ۱۲',
  'كيس',
  'کيس',
  'لا شيء',
  'ورد جوري',
  'Dress',
  'DRESS',
  '  فستان   أبيض  ',
  '',
  '!!!',
  'حذاء كعب عالي',
  'شنطة سهرة',
];

test('the two spellings of the key agree, word for word', async (t) => {
  if (!reachable) {
    t.skip('no database reachable');
    return;
  }
  for (const input of CORPUS) {
    const [{ k }] = await prisma.$queryRawUnsafe<{ k: string }[]>(
      'SELECT reem_search_key($1) AS k',
      input,
    );
    assert.equal(
      searchKey(input),
      k,
      `TypeScript and SQL disagree on ${JSON.stringify(input)}`,
    );
  }
});

test('the three spellings of an abaya are one word', () => {
  const key = searchKey('عباية');
  assert.equal(searchKey('عبايه'), key);
  assert.equal(searchKey('عَبَايَة'), key);
  assert.equal(searchKey('عــبــايــة'), key);
});

test('a hamza the keyboard did not produce does not hide a product', () => {
  assert.equal(searchKey('أحمر'), searchKey('احمر'));
  assert.equal(searchKey('إسورة'), searchKey('اسورة'));
  assert.equal(searchKey('آية'), searchKey('ايه'));
});

test('Arabic-Indic digits are the digits they mean', () => {
  assert.equal(searchKey('٢٠٢٥'), '2025');
  assert.equal(searchKey('۲۰۲۵'), '2025');
  assert.equal(searchKey('ذهب ٢١'), searchKey('ذهب 21'));
});

test('two different garments do not collapse into one key', () => {
  assert.notEqual(searchKey('فستان'), searchKey('حقيبة'));
  assert.notEqual(searchKey('حذاء'), searchKey('حزام'));
  // ح and ه are different letters and stay different, which the obvious
  // one-letter-per-sound mapping would have got wrong.
  assert.notEqual(searchKey('حال'), searchKey('هال'));
});

test('text with nothing to match on yields an empty key, not a wildcard', () => {
  assert.equal(searchKey(''), '');
  assert.equal(searchKey('   '), '');
  assert.equal(searchKey(null), '');
  assert.equal(searchKey(undefined), '');
});

test('the key survives a round trip through the trigram index', async (t) => {
  if (!reachable) {
    t.skip('no database reachable');
    return;
  }
  const [row] = await prisma.$queryRawUnsafe<
    { variants: number; typo: number; unrelated: number }[]
  >(`
    SELECT similarity(reem_search_key('عباية'), reem_search_key('عبايه')) AS variants,
           similarity(reem_search_key('فستان'), reem_search_key('فستاان')) AS typo,
           similarity(reem_search_key('فستان'), reem_search_key('حقيبة'))  AS unrelated
  `);
  assert.equal(row.variants, 1, 'two spellings of one word are the same word');
  assert.ok(
    row.typo >= SIMILARITY_FLOOR,
    `a one-letter typo stays above the floor, scored ${row.typo}`,
  );
  assert.ok(
    row.unrelated < SIMILARITY_FLOOR,
    `a handbag is not a dress, scored ${row.unrelated}`,
  );
});

test('Arabic reaches the trigram index at all', async (t) => {
  if (!reachable) {
    t.skip('no database reachable');
    return;
  }
  // The whole reason the key is transliterated. Under a plain C ctype the
  // raw Arabic produces an empty trigram set, so the key is what keeps Arabic
  // searchable there — and must be indexable under every ctype.
  const [{ keyed, raw, ctype }] = await prisma.$queryRawUnsafe<
    { keyed: string[]; raw: string[]; ctype: string }[]
  >(
    `SELECT show_trgm(reem_search_key('عبايه')) AS keyed, show_trgm('عبايه') AS raw,
            (SELECT datctype FROM pg_database WHERE datname = current_database()) AS ctype`,
  );
  assert.ok(keyed.length > 0, 'the key is indexable');

  // Only a plain C ctype leaves raw Arabic unindexable. `C.UTF-8` and
  // `en_US.utf8` (CI's image) classify Arabic letters as letters, so there
  // the raw text is indexable too and this half says nothing.
  if (ctype === 'C' || ctype === 'POSIX') {
    assert.equal(
      raw.length,
      0,
      'and raw Arabic still is not — if this ever fails, the ctype changed and the transliteration could be revisited',
    );
  }
});
