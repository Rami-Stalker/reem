import { normaliseQuery, stripClitics, parseBudget } from '../modules/trends/kernel/query-normalizer';
import { detectColours, detectOccasion, detectSlots, normaliseArabic } from '../modules/ai-stylist/understanding/stylist-lexicon';

for (const q of ['فستان سهره', 'الفستان السهرة', 'شغلة غريبة']) {
  const r = normaliseQuery(q);
  console.log(JSON.stringify({ q, norm: normaliseArabic(q), key: r.termKey, tokens: r.tokens,
    colours: r.facets.colours, occ: r.facets.occasion, slots: r.facets.slots }));
}
console.log('strip:', ['الفستان','السهرة','السهره','مليون','الف','فستان'].map(t => `${t}->${stripClitics(normaliseArabic(t))}`).join(' | '));
console.log('budget 2 million:', parseBudget(normaliseArabic('حقيبة 2 مليون')));
console.log('budget bmillion:', parseBudget(normaliseArabic('فستان بمليون')));
