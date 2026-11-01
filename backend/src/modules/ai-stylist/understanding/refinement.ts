import { searchable } from './stylist-lexicon';
import { StyleBrief } from './style-brief';

/**
 * The follow-ups that refer to the *last answer* rather than to the catalogue.
 *
 * "وريني أرخص" has no budget in it, and "كمان" names nothing — read on their
 * own they are empty sentences, and a stylist that answers them with the same
 * six cards is a stylist that was not listening. They only mean something
 * against what she was just shown, so this reads them against exactly that.
 */
export interface Refinement {
  /** She wants the same thing for less. */
  cheaper: boolean;
  /** She wants something more special, and is willing to spend. */
  pricier: boolean;
  /** She wants different options, not the ones on screen. */
  more: boolean;
}

const CHEAPER = /(?:ارخص|أرخص|ارخاص|اقل سعر|أقل سعر|سعر اقل|سعر أقل|بميزانيه اقل|بميزانية أقل|cheaper|less expensive)/;
const PRICIER = /(?:اغلي|اغلى|أغلى|افخم|أفخم|فخم|اشيك|أشيك|ارقى|أرقى|premium|luxury|fancier)/;
const MORE = /(?:المزيد|كمان|غيرهن|غيرها|غيرهم|خيارات تانيه|خيارات ثانيه|خيارات أخرى|خيارات اخرى|شي تاني|شي ثاني|غير هيك|more options|show more)/;

export function detectRefinement(message: string): Refinement {
  const hay = searchable(message);
  return {
    cheaper: CHEAPER.test(hay),
    pricier: PRICIER.test(hay) && !CHEAPER.test(hay),
    more: MORE.test(hay),
  };
}

/**
 * Moves the budget the way she asked, from the prices she was actually shown.
 *
 * "أرخص" means cheaper than *those*, not cheaper than an abstract ceiling she
 * never stated — so the anchor is her stated budget when there is one, and the
 * middle of the last answer's prices when there is not.
 */
export function applyPriceRefinement(
  brief: StyleBrief,
  refinement: Refinement,
  lastPrices: number[],
): StyleBrief {
  if (!refinement.cheaper && !refinement.pricier) return brief;
  const prices = lastPrices.filter((price) => price > 0).sort((a, b) => a - b);
  const next = { ...brief };

  if (refinement.cheaper) {
    const anchor = prices.length ? median(prices) : brief.budgetMax;
    if (anchor === null) return brief;
    const ceiling = Math.min(anchor, brief.budgetMax ?? Infinity) * 0.8;
    next.budgetMax = roundSyp(ceiling);
    next.budgetMin = null;
  } else {
    const anchor = prices.length ? prices[prices.length - 1] : brief.budgetMax;
    if (anchor === null) return brief;
    next.budgetMin = roundSyp(anchor * 0.9);
    next.budgetMax = null;
  }
  return next;
}

function median(sorted: number[]): number {
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

/** To the nearest thousand: no one has a budget of 412,367 ل.س. */
function roundSyp(value: number): number {
  return Math.max(1000, Math.round(value / 1000) * 1000);
}
