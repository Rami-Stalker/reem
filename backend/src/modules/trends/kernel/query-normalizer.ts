/**
 * Search Intelligence, part one: turning what she typed into something that
 * can be counted, and into facets that can be acted on.
 *
 * Two jobs, and they are different:
 *
 *  - `termKey` is an **identity**. «فستان سهرة أخضر»، «فستان أخضر سهرة» and
 *    «فساتين سهره خضراء» are one question asked three ways, and unless they
 *    collapse to one row the evidence for them is split three ways and none of
 *    the three clears the threshold to be reported. Stopwords out, clitics off,
 *    tokens folded and sorted.
 *  - `facets` are the **content**. "There is demand for a thing" is not a
 *    finding anyone can act on; "there is demand for long green evening
 *    dresses, and we stock none" is a buying decision. The facets are what
 *    turn one into the other.
 *
 * The Arabic normalisation and the colour/occasion/garment vocabularies are the
 * stylist's — imported rather than re-written, because two normalisers that
 * disagree about whether «فستان» matches «فساتين» will quietly disagree about
 * which searches were unmet.
 */

import { OutfitSlot } from '@prisma/client';
import {
  categorySlugsForSlots,
  colourEntry,
  colourLabel,
  containsAny,
  detectColours,
  detectOccasion,
  detectSlots,
  normaliseArabic,
  occasionEntry,
  occasionLabel,
  slotEntry,
  slotLabel,
} from '../../ai-stylist/understanding/stylist-lexicon';
import { PRICE_BANDS } from '../trend.constants';

/**
 * Words that carry no demand signal. Keeping them would split «فستان سهرة» from
 * «بدي فستان سهرة» into two terms that each miss the reporting threshold.
 */
const STOPWORDS = new Set([
  // Arabic function words and shopping filler.
  'في',
  'من',
  'على',
  'عن',
  'مع',
  'او',
  'ام',
  'ال',
  'هذا',
  'هذه',
  'ذلك',
  'التي',
  'الذي',
  'كل',
  'اي',
  'شي',
  'شيء',
  'بدي',
  'بدنا',
  'ابي',
  'اريد',
  'ابحث',
  'بحث',
  'عايزه',
  'عايزة',
  'عاوزه',
  'لو',
  'سمحت',
  'ممكن',
  'يوجد',
  'في',
  'حلو',
  'حلوه',
  'كتير',
  'شوي',
  'جدا',
  'الي',
  'يلي',
  'هيك',
  'رجاء',
  'رجاءا',
  'لطفا',
  // English filler that appears in a bilingual search box.
  'a',
  'an',
  'the',
  'for',
  'with',
  'and',
  'or',
  'of',
  'in',
  'on',
  'to',
  'my',
  'me',
  'i',
  'want',
  'need',
  'buy',
  'looking',
  'search',
  'find',
  'nice',
  'good',
  'best',
  'cheap',
]);

/** Everything the normaliser understood about a query. */
export interface QueryFacets {
  colours: string[];
  occasion: string | null;
  slots: OutfitSlot[];
  /** Leaf category slugs the slots resolve to — the assortment lookup key. */
  categorySlugs: string[];
  /** A price band code when the query named a budget. */
  priceBand: string | null;
  /** The budget as typed, in SYP, when one was parsed. */
  budgetSyp: number | null;
  /** Tokens left after stopwords and recognised facets were removed. */
  residualTokens: string[];
}

export interface NormalisedQuery {
  /** Stable identity. Empty when the query was only noise. */
  termKey: string;
  /** Tidied text for display, in her word order. */
  display: string;
  tokens: string[];
  facets: QueryFacets;
}

/**
 * Multipliers for a spoken budget: «٥٠ ألف» is fifty thousand, «مليون ونص» is
 * handled by the bare number plus the multiplier on the word before it.
 */
const MAGNITUDE_FORMS: ReadonlyArray<{ forms: string[]; factor: number }> = [
  { forms: ['الف', 'الاف', 'k'], factor: 1_000 },
  { forms: ['مليون', 'ملايين', 'm'], factor: 1_000_000 },
];

export function normaliseQuery(raw: string | null | undefined): NormalisedQuery {
  const text = normaliseArabic(raw ?? '');
  const display = (raw ?? '').replace(/\s+/g, ' ').trim().slice(0, 120);

  const tokens = text
    .replace(/[^\p{L}\p{N}\s]+/gu, ' ')
    .split(/\s+/)
    .map(stripClitics)
    .filter((token) => token.length > 1 && !STOPWORDS.has(token));

  // The lexicon is matched against the un-elided spelling — see
  // `expandLamArticle` for why «للسهرة» would otherwise be a different
  // question from «السهرة».
  const detectable = expandLamArticle(text);
  const colours = detectColours(detectable);
  const occasion = detectOccasion(detectable);
  const slots = detectSlots(detectable);
  const budgetSyp = parseBudget(text);

  // Everything a recognised facet already accounts for. Removing these is what
  // lets «فساتين» and «فستان» land on one row: the *facet* is the token, and
  // the surface spelling that produced it stops mattering.
  const claimed = new Set<string>();
  const claim = (forms: readonly string[] | undefined): void => {
    if (!forms) return;
    for (const token of tokens) if (containsAny(token, forms)) claimed.add(token);
  };
  for (const slot of slots) claim(slotEntry(slot).forms);
  claim(occasionEntry(occasion)?.forms);
  for (const colour of colours) claim(colourEntry(colour)?.forms);

  const residualTokens = tokens.filter(
    (token) => !claimed.has(token) && !/^\d+$/.test(token),
  );

  const facets: QueryFacets = {
    colours,
    occasion,
    slots,
    categorySlugs: categorySlugsForSlots(slots),
    priceBand: budgetSyp === null ? null : priceBandFor(budgetSyp),
    budgetSyp,
    residualTokens,
  };

  return { termKey: termKeyFrom(facets, residualTokens), display, tokens, facets };
}

/**
 * The identity of a query: its facets, plus whatever words the facets did not
 * account for, sorted and joined.
 *
 * Keying on facets rather than on words is what makes the identity survive the
 * way Arabic is actually typed. «فستان سهرة أخضر»، «فساتين سهره خضراء» and
 * «الفستان الأخضر للسهرة» are three spellings, three word orders and two
 * plurals of one question, and they all reduce to
 * `col:green occ:evening slot:DRESS`. Stemming could never have got there —
 * «فساتين» is a broken plural, and no suffix rule turns it into «فستان» — but
 * the stylist's vocabulary already lists both, so the lookup that answers her
 * question is the same lookup that counts it.
 *
 * A query with no recognisable facet falls back to its own words, which is the
 * honest answer: the engine does not understand it yet, but it can still count
 * how often it is asked.
 */
export function termKeyFrom(
  facets: Pick<QueryFacets, 'colours' | 'occasion' | 'slots' | 'priceBand'>,
  residualTokens: readonly string[],
): string {
  const parts = [
    ...facets.slots.map((slot) => `slot:${slot}`),
    ...(facets.occasion ? [`occ:${facets.occasion}`] : []),
    ...facets.colours.map((colour) => `col:${colour}`),
    ...(facets.priceBand ? [`band:${facets.priceBand}`] : []),
    ...residualTokens,
  ];
  return [...new Set(parts)].filter(Boolean).sort().join(' ');
}

/**
 * Strips the definite article, alone or behind one of the particles Arabic
 * glues in front of it (و ف ب ل ك), so «الفستان» و«بالفستان» و«فستان» are one
 * token.
 *
 * It does **not** strip a bare one-letter particle, and it does not strip
 * plural endings, even though both look tempting. «فستان» begins with ف and
 * «مليون» ends with ون; a stripper naive enough to take those apart turns a
 * dress into «ستان» and a million into «ملي», and then the price parser stops
 * seeing budgets. Known vocabulary does not need the help — the lexicon's own
 * matcher already tolerates every clitic and inflection — and unknown
 * vocabulary is exactly where guessing is most likely to be wrong.
 */
export function stripClitics(token: string): string {
  if (token.length > 4 && /^[وفبلك]ال/.test(token)) return token.slice(3);
  // The elided form: لـ + الـ is written لل, not لال.
  if (token.length > 4 && token.startsWith('لل')) return token.slice(2);
  if (token.length > 3 && token.startsWith('ال')) return token.slice(2);
  return token;
}

/**
 * Un-elides the lam of the definite article.
 *
 * Arabic writes لـ + الـ as a single doubled lam: «للسهرة», not «لالسهرة». The
 * stylist's clitic matcher expects the article spelled out, so «فستان للسهرة»
 * fails to match the evening occasion that «فستان السهرة» matches — and the
 * same question, asked the way half of people write it, lands on a different
 * row and never clears the reporting threshold.
 *
 * Three letters are required after the لل so the rewrite cannot fire on a
 * two-letter stem that merely starts that way.
 */
export function expandLamArticle(text: string): string {
  return text.replace(/(^|\s)لل(\p{L}{3,})/gu, '$1ال$2');
}

/**
 * A budget in SYP, or null.
 *
 * Reads a bare number plus an optional magnitude word: «تحت ١٠٠ الف»، «500k»،
 * «مليون». A number with no magnitude under a thousand is ignored — «فستان 38»
 * is a size, not a budget, and guessing wrong here would file a real search
 * under the wrong price band.
 */
export function parseBudget(text: string): number | null {
  const tokens = text.replace(/[^\p{L}\p{N}\s]+/gu, ' ').split(/\s+/);
  let best: number | null = null;

  for (let i = 0; i < tokens.length; i += 1) {
    const token = tokens[i] ?? '';
    const inline = /^(\d+)(k|m)$/.exec(token);
    if (inline) {
      const factor = inline[2] === 'm' ? 1_000_000 : 1_000;
      best = Math.max(best ?? 0, Number(inline[1]) * factor);
      continue;
    }
    if (!/^\d+$/.test(token)) continue;

    const value = Number(token);
    const next = tokens[i + 1] ?? '';
    // Both spellings: «١٠٠ الف» writes the article, «100 ألف» does not.
    const magnitude = MAGNITUDE_FORMS.find(
      (entry) =>
        entry.forms.includes(next) || entry.forms.includes(stripClitics(next)),
    );
    if (magnitude) {
      best = Math.max(best ?? 0, value * magnitude.factor);
    } else if (value >= 1_000) {
      best = Math.max(best ?? 0, value);
    }
  }
  return best;
}

/** The band a SYP price falls in. */
export function priceBandFor(priceSyp: number): string | null {
  if (!Number.isFinite(priceSyp) || priceSyp < 0) return null;
  const band = PRICE_BANDS.find(
    (entry) => priceSyp >= entry.min && (entry.max === null || priceSyp < entry.max),
  );
  return band?.code ?? PRICE_BANDS[PRICE_BANDS.length - 1]?.code ?? null;
}

export function priceBandLabel(code: string): string {
  return PRICE_BANDS.find((band) => band.code === code)?.labelAr ?? code;
}

/**
 * The facets, written out as an Arabic noun phrase.
 *
 * This is what makes an Unmet Demand row a sentence a buyer can act on rather
 * than a search string she has to interpret: "فساتين — سهرة — أخضر — ١٠٠–٢٥٠
 * ألف" reads as a purchase order.
 */
export function describeFacets(facets: QueryFacets): string {
  const parts: string[] = [];
  for (const slot of facets.slots) parts.push(slotLabel(slot));
  if (facets.occasion) {
    const label = occasionLabel(facets.occasion);
    if (label) parts.push(label);
  }
  for (const colour of facets.colours) parts.push(colourLabel(colour));
  if (facets.priceBand) parts.push(priceBandLabel(facets.priceBand));
  return parts.join(' · ');
}

/**
 * True when the facets are specific enough to source against.
 *
 * A term that resolves to nothing but residual words may still be real demand,
 * but it is not yet a buying instruction, and the admin list says so rather
 * than inventing a category for it.
 */
export function facetsAreActionable(facets: QueryFacets): boolean {
  return (
    facets.slots.length > 0 ||
    facets.colours.length > 0 ||
    facets.occasion !== null
  );
}
