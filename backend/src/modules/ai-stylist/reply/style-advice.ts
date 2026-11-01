import { OutfitSlot } from '@prisma/client';
import { StyleBrief } from '../understanding/style-brief';
import {
  COLOURS,
  colourLabel,
  occasionEntry,
  searchable,
  slotLabel,
} from '../understanding/stylist-lexicon';

/**
 * What a good shop assistant knows without looking at the shelf.
 *
 * The catalogue answers "what is there"; this answers "what goes with what"
 * and "what suits the occasion". Every sentence here is general styling
 * knowledge — it never names a product, a price or a seller, so it can be said
 * whether or not a model is configured and whatever is in stock today.
 */

/** One short tip per occasion: the thing a stylist would say first. */
const OCCASION_TIPS: Record<string, string> = {
  wedding:
    'للأعراس يتألّق القماش اللامع أو الساتان مع إكسسوار ذهبي ناعم، والأفضل تجنّب الأبيض احتراماً للعروس.',
  engagement:
    'للخطوبة تليق الألوان الهادئة كالوردي الفاتح والبيج، مع لمسة لمعان خفيفة لا تطغى على الإطلالة.',
  evening:
    'لسهرة أنيقة اختاري قطعة واحدة لافتة — لوناً أو قصّة — واتركي الباقي بسيطاً.',
  graduation:
    'للتخرّج اختاري قصّة مريحة تتحرّك معكِ على المسرح، وحذاءً بكعب معتدل تقدرين على المشي به.',
  eid: 'للعيد تبدو الألوان المبهجة والقصّات المحتشمة الواسعة أجمل، مع حقيبة صغيرة بلون مكمّل.',
  ramadan:
    'لسهرات رمضان تناسب الجلابيات والقطع الواسعة بأقمشة خفيفة، مع لمسة ذهبية بسيطة.',
  work: 'للعمل اعتمدي على الألوان المحايدة والقصّات المرتّبة، وأضيفي لوناً واحداً في الإكسسوار.',
  daily:
    'للإطلالة اليومية الراحة أولاً: قطع أساسية بألوان محايدة تتناسق مع بعضها بسهولة.',
  birthday:
    'لعيد الميلاد جرّبي لوناً تحبينه ولا تلبسينه كثيراً — هو يومكِ، والجرأة الصغيرة تليق.',
  newborn:
    'لزيارة المولود تناسب الأقمشة الناعمة والألوان الفاتحة، والهدية العملية تُقدَّر دائماً.',
  travel:
    'للسفر اختاري قطعاً لا تتجعّد وتتناسق مع بعضها، فتصنعين إطلالات كثيرة من حقيبة صغيرة.',
  home: 'للبيت أقمشة قطنية ناعمة وقصّات واسعة، وما يمنع لمسة لون تبهج يومكِ.',
};

/** What to add next to a piece, so a single item becomes a look. */
const COMPLEMENTS: Partial<Record<OutfitSlot, OutfitSlot[]>> = {
  [OutfitSlot.DRESS]: [OutfitSlot.SHOES, OutfitSlot.BAG],
  [OutfitSlot.ABAYA]: [OutfitSlot.ACCESSORY, OutfitSlot.BAG],
  [OutfitSlot.OUTERWEAR]: [OutfitSlot.BOTTOM, OutfitSlot.SHOES],
  [OutfitSlot.TOP]: [OutfitSlot.BOTTOM, OutfitSlot.SHOES],
  [OutfitSlot.BOTTOM]: [OutfitSlot.TOP, OutfitSlot.SHOES],
  [OutfitSlot.SHOES]: [OutfitSlot.BAG],
  [OutfitSlot.BAG]: [OutfitSlot.SHOES],
  [OutfitSlot.JEWELRY]: [OutfitSlot.PERFUME],
};

/** Colours known to sit well beside [key], neutrals included. */
export function colourPairings(key: string, limit = 4): string[] {
  const entry = COLOURS.find((colour) => colour.key === key);
  if (!entry) return [];
  const pairs = [...entry.harmony];
  // Harmony is not always written in both directions; read it backwards too.
  for (const other of COLOURS) {
    if (other.key !== key && other.harmony.includes(key) && !pairs.includes(other.key)) {
      pairs.push(other.key);
    }
  }
  return pairs.slice(0, limit);
}

export function occasionTip(occasion: string | null): string | null {
  return occasion ? (OCCASION_TIPS[occasion] ?? null) : null;
}

/** "الزيتي يتناسق مع البيج والذهبي والأبيض." */
export function colourAdvice(key: string): string | null {
  const pairs = colourPairings(key);
  if (!pairs.length) return null;
  return `اللون ${colourLabel(key)} يتناسق جميلاً مع ${joinAr(pairs.map(colourLabel))}.`;
}

/**
 * The advice turn: she asked an opinion rather than for goods.
 *
 * Built only from what the brief established, so the answer is about *her*
 * question — her colour, her occasion — and never a generic paragraph.
 */
export function adviceFor(brief: StyleBrief, message: string): string | null {
  const parts: string[] = [];

  // "ينفع أبيض بعرس؟" — the one colour question with a firm answer, which
  // replaces both the colour line and the generic wedding tip.
  const whiteAtWedding =
    brief.occasion === 'wedding' && brief.colours.includes('white');
  if (whiteAtWedding) {
    parts.push(
      'الأبيض في العرس يُترك عادةً للعروس، والعاجي أو البيج الفاتح أو الوردي الهادئ بدائل راقية تعطيكِ الإحساس نفسه.',
    );
  }

  const colour = brief.colours[0];
  if (colour && !whiteAtWedding) {
    const line = colourAdvice(colour);
    if (line) parts.push(line);
  }

  const tip = whiteAtWedding ? null : occasionTip(brief.occasion);
  if (tip) parts.push(tip);

  const slot = brief.slots[0];
  if (slot && COMPLEMENTS[slot]?.length) {
    const next = COMPLEMENTS[slot]!.map(slotLabel);
    parts.push(`ولتكتمل الإطلالة، نسّقي مع ${slotLabel(slot)} ${joinAr(next)} بلون مكمّل.`);
  }

  if (!parts.length && /مقاس|قياس|size/i.test(searchable(message))) {
    parts.push(
      'إن كنتِ بين مقاسين فاختاري الأكبر في القطع المحدّدة على الجسم، والأصغر في القطع الواسعة.',
    );
  }

  return parts.length ? parts.join(' ') : null;
}

/** A single styling line to close a product or outfit answer with. */
export function stylingTip(brief: StyleBrief): string | null {
  return occasionTip(brief.occasion);
}

/**
 * Follow-ups that read the conversation rather than a fixed list.
 *
 * Each chip is a sentence she could have typed, specific to what she just
 * asked for — "أكمليها بحذاء" after a dress, "جرّبي البيج" after olive.
 */
export function smartFollowUps(brief: StyleBrief, base: string[]): string[] {
  const out: string[] = [];

  const slot = brief.slots[0];
  const complement = slot ? COMPLEMENTS[slot]?.[0] : undefined;
  if (complement && brief.intent !== 'BUILD_OUTFIT') {
    out.push(`نسّقيلي ${slotLabel(complement)} معه`);
  }

  const colour = brief.colours[0];
  const alt = colour ? colourPairings(colour, 1)[0] : undefined;
  if (alt) out.push(`نفسه بلون ${colourLabel(alt)}`);

  if (!brief.sizes.clothing && slot && slot !== OutfitSlot.BAG && slot !== OutfitSlot.SHOES) {
    out.push('مقاسي M');
  }

  for (const entry of base) {
    if (!out.includes(entry)) out.push(entry);
  }
  return out.slice(0, 5);
}

function joinAr(items: string[]): string {
  if (items.length <= 1) return items[0] ?? '';
  return `${items.slice(0, -1).join('، ')} و${items[items.length - 1]}`;
}
