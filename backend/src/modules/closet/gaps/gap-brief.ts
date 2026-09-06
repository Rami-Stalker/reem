import { ClosetGap, ModestyLevel, OutfitSlot } from '@prisma/client';
import { StyleBrief, emptyBrief } from '../../ai-stylist/understanding/style-brief';
import { categorySlugsForSlots } from '../../ai-stylist/understanding/stylist-lexicon';

/**
 * A gap, expressed as a question the catalog can answer.
 *
 * This function is the entire integration between the closet and the shop, and
 * it is four lines of assignment because `StyleBrief` was already the contract
 * between "what she wants" and "what we can retrieve". The closet does not need
 * its own search, its own ranking, its own relaxation ladder or its own notion
 * of what a live offer is — it needs to produce a brief, and everything the
 * stylist has built downstream applies unchanged.
 *
 * The consequence worth stating plainly: a closet suggestion cannot show a
 * product the stylist would refuse to show. Modesty filtering, the purchasable
 * predicate, size availability, the budget ladder — they are enforced in one
 * place for both features, so the two can never drift into disagreeing about
 * what she may be shown.
 */
export function briefFromGap(
  gap: Pick<
    ClosetGap,
    | 'slot'
    | 'occasion'
    | 'suggestedColours'
    | 'suggestedSize'
    | 'suggestedBudgetMinSyp'
    | 'suggestedBudgetMaxSyp'
  >,
  context: { modesty?: ModestyLevel } = {},
): StyleBrief {
  const brief = emptyBrief();

  brief.intent = 'FIND_PRODUCT';
  brief.slots = [gap.slot];
  brief.categorySlugs = categorySlugsForSlots([gap.slot]);
  brief.occasion = gap.occasion;
  brief.colours = [...gap.suggestedColours];

  brief.budgetMin =
    gap.suggestedBudgetMinSyp === null ? null : Number(gap.suggestedBudgetMinSyp);
  brief.budgetMax =
    gap.suggestedBudgetMaxSyp === null ? null : Number(gap.suggestedBudgetMaxSyp);

  if (gap.suggestedSize) brief.sizes = sizesFor(gap.slot, gap.suggestedSize);
  brief.modesty = context.modesty ?? ModestyLevel.UNSPECIFIED;

  // The gap was computed from her own rows, so every field above is a fact
  // about her wardrobe rather than a reading of a sentence. Nothing was
  // inferred and nothing can have been misheard.
  brief.confidence = 1;

  return brief;
}

/**
 * Place a size in the system its slot uses.
 *
 * `StyleBrief.sizes` is keyed by system rather than by slot — the same shape
 * `user_style_preferences.sizes` uses, and the same shape retrieval matches
 * against `product_variants.attributes`. A shoe size in the `clothing` key
 * would match nothing and look like an empty result rather than a bug.
 */
function sizesFor(slot: OutfitSlot, size: string): StyleBrief['sizes'] {
  switch (slot) {
    case OutfitSlot.SHOES:
      return { shoes: size };
    case OutfitSlot.DRESS:
    case OutfitSlot.ABAYA:
    case OutfitSlot.TOP:
    case OutfitSlot.BOTTOM:
    case OutfitSlot.OUTERWEAR:
      return { clothing: size.toUpperCase() };
    default:
      // Bags, jewellery and perfume have no size system. Sending one anyway
      // would add a variant filter that no offer in the category satisfies.
      return {};
  }
}
