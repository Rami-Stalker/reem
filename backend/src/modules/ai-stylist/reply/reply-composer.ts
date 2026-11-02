import { OutfitSlot } from '@prisma/client';
import { BuiltOutfit } from '../outfit/outfit-builder.service';
import { Relaxation } from '../retrieval/product-retrieval.service';
import { ScoredProduct } from '../retrieval/stylist-ranker';
import { StyleBrief, formatSyp, missingSlotQuestion } from '../understanding/style-brief';
import { colourLabel, occasionEntry, searchable, slotLabel } from '../understanding/stylist-lexicon';
import { smartFollowUps, stylingTip } from './style-advice';

export interface ComposedReply {
  text: string;
  /** Tappable next steps, so she is never facing an empty prompt. */
  followUps: string[];
}

/**
 * Writes the assistant's sentence.
 *
 * Every clause here is a fact the caller already established: how many rows
 * came back, what band they are in, what had to be relaxed. That is the whole
 * design — the prose is a rendering of the result, not a separate account of
 * it, so it cannot drift from the cards underneath it. When a model is
 * configured it rewrites this sentence more warmly; it is handed the same
 * facts and nothing else.
 */
export function composeProductReply(input: {
  brief: StyleBrief;
  results: ScoredProduct[];
  relaxations: Relaxation[];
  /** A styling answer to lead with, when she asked an opinion too. */
  advice?: string | null;
}): ComposedReply {
  const { brief, results, relaxations } = input;

  if (!results.length) {
    return {
      text: [
        'لم أجد شيئاً متوفراً فعلاً بكل التفاصيل التي طلبتِها.',
        relaxations.length
          ? 'حاولت توسيع البحث ولم ينجح.'
          : 'لنوسّع قليلاً — ',
        'هل ترفعين الميزانية قليلاً، أو نغيّر اللون، أو نجرّب قسماً قريباً؟',
      ].join(' '),
      followUps: ['وسّعي الميزانية', 'اقترحي ألوان تانية', 'شوفي أقسام قريبة'],
    };
  }

  const opening = openingLine(brief, results);
  const priceLine = priceRangeLine(results);
  const relaxationLine = summariseRelaxations(relaxations);
  const question = missingSlotQuestion(brief);
  // An opinion question gets its answer first; otherwise one styling line, so
  // the reply reads like a stylist and not like a result count.
  const advice = brief.intent === 'ADVICE' ? (input.advice ?? null) : null;
  const tip = advice ? null : question ? null : stylingTip(brief);

  const text = [advice, opening, priceLine, relaxationLine, tip, question]
    .filter((part): part is string => Boolean(part && part.trim()))
    .join(' ');

  return { text, followUps: smartFollowUps(brief, followUpsFor(brief)) };
}

export function composeOutfitReply(input: {
  brief: StyleBrief;
  outfit: BuiltOutfit;
}): ComposedReply {
  const { brief, outfit } = input;

  const pieceNames = outfit.pieces.map((piece) => slotLabel(piece.slot));
  const listed =
    pieceNames.length <= 1
      ? pieceNames[0] ?? 'قطعة'
      : `${pieceNames.slice(0, -1).join('، ')} و${pieceNames[pieceNames.length - 1]}`;

  const parts: string[] = [];
  const occasion = occasionEntry(brief.occasion);
  parts.push(
    occasion
      ? `جهّزت لكِ إطلالة كاملة لـ${occasion.labelAr}: ${listed}.`
      : `جهّزت لكِ إطلالة كاملة: ${listed}.`,
  );

  if (outfit.palette.length) {
    const palette = outfit.palette.map(colourLabel).join(' و');
    parts.push(`اللوحة اللونية ${palette}، والقطع متناسقة معاً.`);
  }

  if (outfit.totalSyp !== null) {
    const total = formatSyp(outfit.totalSyp);
    parts.push(
      brief.budgetMax !== null && outfit.totalSyp > brief.budgetMax
        ? `مجموع الإطلالة ${total} — أعلى قليلاً من ميزانيتكِ، ويمكنكِ الاستغناء عن قطعة.`
        : `مجموع الإطلالة ${total}.`,
    );
  }

  if (outfit.missingSlots.length) {
    const missing = outfit.missingSlots.map(slotLabel).join(' و');
    parts.push(`لم أجد ${missing} متوفراً حالياً بالمواصفات نفسها.`);
  }

  const relaxed = summariseRelaxations(outfit.relaxations);
  if (relaxed) parts.push(relaxed);

  const tip = stylingTip(brief);
  if (tip) parts.push(tip);

  return {
    text: parts.join(' '),
    followUps: [
      'بدّلي الحذاء',
      'بدّلي الحقيبة',
      'نفس الإطلالة بميزانية أقل',
      'احفظي الإطلالة',
    ],
  };
}

/** The turn where she said hello, or asked something the catalog cannot
 *  answer. Still ends with a way forward. */
export function composeConversationalReply(input: {
  brief: StyleBrief;
  greeting: boolean;
  message?: string;
  advice?: string | null;
}): ComposedReply {
  if (input.greeting && isThanks(input.message ?? '')) {
    return {
      text: 'العفو، يسعدني دائماً أن أساعدكِ! هل نكمل بشيء آخر — قطعة تكمّل الإطلالة، أو هدية لشخص تحبينه؟',
      followUps: ['نسّقيلي إطلالة كاملة', 'بدي هدية', 'شو الجديد؟'],
    };
  }
  if (input.greeting) {
    return {
      text: 'أهلاً بكِ! أنا أوهارا، مساعدتكِ الشخصية في التسوّق. أخبريني عن المناسبة أو القطعة التي تبحثين عنها، وميزانيتكِ، وأرتّب لكِ خيارات متوفرة فعلاً.',
      followUps: [
        'عندي مناسبة وبدي فستان',
        'بدي هدية لصديقتي',
        'رتّبيلي إطلالة كاملة',
      ],
    };
  }

  const question = missingSlotQuestion(input.brief);
  if (input.advice) {
    return {
      text: question ? `${input.advice} ${question}` : input.advice,
      followUps: smartFollowUps(input.brief, [
        'وريني خيارات متوفرة',
        'رتّبيلي إطلالة كاملة',
      ]),
    };
  }
  return {
    text: question
      ? `حسناً. ${question}`
      : 'أخبريني بتفاصيل أكثر — نوع القطعة واللون والميزانية — وأعود إليكِ بخيارات متوفرة.',
    followUps: followUpsFor(input.brief),
  };
}

function isThanks(message: string): boolean {
  return /(?:^| )(?:شكرا|مشكوره|يسلمو|يعطيك العافيه|thanks|thank you)(?: |$)/i.test(
    searchable(message),
  );
}

// ── Clauses ─────────────────────────────────────────────────────────────

function openingLine(brief: StyleBrief, results: ScoredProduct[]): string {
  const count = results.length;
  const occasion = occasionEntry(brief.occasion);
  const noun = pieceNoun(brief, results);

  if (!brief.forSelf) {
    const age =
      brief.recipientAge !== null ? ` تناسب عمر ${brief.recipientAge}` : '';
    return `اخترت لكِ ${count} خيارات هدية${age}، كلها متوفرة حالياً.`;
  }
  if (occasion) {
    return noun
      ? `وجدت لكِ ${count} خيارات ${noun} تناسب ${occasion.labelAr}، كلها متوفرة حالياً.`
      : `وجدت لكِ ${count} خيارات تناسب ${occasion.labelAr}، كلها متوفرة حالياً.`;
  }
  return noun
    ? `وجدت لكِ ${count} خيارات ${noun} متوفرة حالياً.`
    : `وجدت لكِ ${count} خيارات متوفرة حالياً.`;
}

/**
 * The word for what she is being shown — but only when it is true of what
 * actually came back.
 *
 * The retrieval ladder can widen past the category she named, and calling six
 * skirts "خيارات فستان" because the *brief* said dress is the assistant
 * misdescribing its own results. When the answer has strayed, the sentence
 * goes generic and the relaxation line explains why.
 */
function pieceNoun(brief: StyleBrief, results: ScoredProduct[]): string {
  const slot = brief.slots[0];
  if (!slot) return '';
  if (slot === OutfitSlot.GIFT) return 'هدية';

  const wanted = new Set(brief.categorySlugs);
  if (wanted.size && results.length) {
    const onTopic = results.filter((entry) =>
      wanted.has(entry.product.category.slug),
    ).length;
    // A stray result or two is still a dress rail; half of them is not.
    if (onTopic < results.length * 0.6) return '';
  }
  return slotLabel(slot);
}

/**
 * At most two relaxations, most consequential first.
 *
 * The ladder records every rung it passed through, which is the right thing
 * to store and the wrong thing to say: five stacked apologies read as an
 * assistant making excuses, and the one that actually matters — the budget —
 * gets lost among them.
 */
function summariseRelaxations(relaxations: Relaxation[]): string {
  const priority: Record<string, number> = {
    BUDGET_DROPPED: 0,
    CATEGORY_WIDENED: 1,
    BUDGET_RAISED: 2,
    SIZE_DROPPED: 3,
    COLOUR_DROPPED: 4,
    KEYWORDS_DROPPED: 5,
  };

  // Dropping the ceiling supersedes raising it — the ladder passed through
  // both, but saying "I widened your budget a bit" right after "nothing here
  // is within your budget at all" is one sentence too many.
  const meaningful = relaxations.some((entry) => entry.code === 'BUDGET_DROPPED')
    ? relaxations.filter((entry) => entry.code !== 'BUDGET_RAISED')
    : relaxations;

  return [...meaningful]
    .sort((a, b) => (priority[a.code] ?? 9) - (priority[b.code] ?? 9))
    .slice(0, 2)
    .map((relaxation) => relaxation.message)
    .join(' ');
}

/** "من ٦٠٠ ألف لـ١٫٢ مليون" — the single most useful sentence after the
 *  count, and the one she would otherwise have to derive by scrolling. */
function priceRangeLine(results: ScoredProduct[]): string | null {
  const prices = results
    .map((entry) => (entry.product.minPriceSyp ? Number(entry.product.minPriceSyp) : null))
    .filter((price): price is number => price !== null);

  if (!prices.length) return null;
  const low = Math.min(...prices);
  const high = Math.max(...prices);
  if (low === high) return `السعر ${formatSyp(low)}.`;
  return `الأسعار من ${formatSyp(low)} إلى ${formatSyp(high)}.`;
}

function followUpsFor(brief: StyleBrief): string[] {
  const suggestions: string[] = [];

  if (brief.intent !== 'BUILD_OUTFIT') suggestions.push('رتّبيلي إطلالة كاملة');
  if (brief.budgetMax !== null) suggestions.push('وريني أرخص');
  else suggestions.push('حدّدي ميزانية');
  if (!brief.colours.length) suggestions.push('بلون تاني');
  else suggestions.push(`بغير لون`);
  suggestions.push('وريني المزيد');

  return suggestions.slice(0, 4);
}

/** Opening prompts on an empty stylist screen, tuned by what we know of her. */
export function starterPrompts(input: {
  hasHistory: boolean;
  favouriteCategory: string | null;
}): string[] {
  const prompts = [
    'عندي مناسبة بعد أسبوع وبدي فستان أنيق ومحتشم بميزانية 500 ألف',
    'بدي هدية لصديقتي عمرها 25 سنة وبتحب الأشياء الناعمة',
    'بدي فستان أسود مع حقيبة وحذاء مناسبين',
  ];

  if (input.hasHistory) {
    prompts.push('كمّلي معي من آخر مرة');
  }
  if (input.favouriteCategory) {
    prompts.push(`شو الجديد بقسم ${input.favouriteCategory}؟`);
  }
  prompts.push('رتّبيلي إطلالة يومية مريحة');

  return prompts.slice(0, 5);
}
