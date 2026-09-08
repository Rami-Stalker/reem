/**
 * The Arabic matching key, in TypeScript.
 *
 * This is the twin of the `reem_search_key` SQL function created by the
 * `20260907120000_arabic_search` migration, and the two have to agree
 * character for character: the database indexes catalogue text through the
 * SQL one, and every query is put through this one before being compared
 * against that index. A disagreement would not throw — it would quietly stop
 * matching, which is the failure mode this whole thing exists to fix. So
 * `arabic.spec.ts` runs a corpus through both and asserts they produce the
 * same string.
 *
 * Why the key is ASCII rather than tidy Arabic is explained at length in the
 * migration: this database is provisioned with `datctype = 'C'`, under which
 * PostgreSQL treats no Arabic character as a word character, and `pg_trgm`
 * therefore cuts Arabic text into no trigrams at all. Transliterating gives
 * the index something it can see.
 */

/** Harakat, the superscript alef, and tatweel — dropped outright. */
const STRIP = /[ً-ٰٟـﻵ-ﻼ]/g;

/** Spelling variants collapsed onto one form. */
const FOLD: ReadonlyMap<string, string> = new Map([
  ['أ', 'ا'],
  ['إ', 'ا'],
  ['آ', 'ا'],
  ['ٱ', 'ا'],
  ['ة', 'ه'],
  ['ى', 'ي'],
  ['ؤ', 'و'],
  ['ئ', 'ي'],
  ['ک', 'ك'],
  ['ی', 'ي'],
  ['ڪ', 'ك'],
  ...Array.from({ length: 10 }, (_, i): [string, string] => [
    String.fromCharCode(0x0660 + i),
    String(i),
  ]),
  ...Array.from({ length: 10 }, (_, i): [string, string] => [
    String.fromCharCode(0x06f0 + i),
    String(i),
  ]),
]);

/** One Arabic letter, one ASCII alphanumeric. */
const TRANSLITERATE: ReadonlyMap<string, string> = new Map([
  ['ا', 'a'],
  ['ب', 'b'],
  ['ت', 't'],
  ['ث', 'v'],
  ['ج', 'j'],
  ['ح', '7'],
  ['خ', 'x'],
  ['د', 'd'],
  ['ذ', 'z'],
  ['ر', 'r'],
  ['ز', '5'],
  ['س', 's'],
  ['ش', 'c'],
  ['ص', '9'],
  ['ض', '6'],
  ['ط', '4'],
  ['ظ', '8'],
  ['ع', '3'],
  ['غ', 'g'],
  ['ف', 'f'],
  ['ق', 'q'],
  ['ك', 'k'],
  ['ل', 'l'],
  ['م', 'm'],
  ['ن', 'n'],
  ['ه', 'h'],
  ['و', 'w'],
  ['ي', 'y'],
  ['ء', '2'],
]);

/**
 * The form a query and a listing are both reduced to before they are compared.
 *
 * Empty for input that carries nothing to match on — punctuation, or an empty
 * string. Callers treat an empty key as "no text query", never as "a query
 * that matches nothing", because the two mean opposite things to a customer.
 */
export function searchKey(input: string | null | undefined): string {
  if (!input) return '';
  // The lam-alef ligature is the one letter that decomposes into two, so it
  // is spelled out before anything else runs.
  const decomposed = input.toLowerCase().replace(/ﻵ/g, 'لا');
  let out = '';
  for (const char of decomposed.replace(STRIP, '')) {
    const folded = FOLD.get(char) ?? char;
    out += TRANSLITERATE.get(folded) ?? folded;
  }
  return out.replace(/\s+/g, ' ').trim();
}

/**
 * The similarity below which two strings are not the same word.
 *
 * 0.3 is pg_trgm's own default and it behaves sensibly on the transliterated
 * keys: a one-letter typo in a five-letter word scores about 0.6, and two
 * unrelated garments score 0. Raising it starts refusing real typos; lowering
 * it starts offering حقيبة to someone who asked for فستان.
 */
export const SIMILARITY_FLOOR = 0.3;
