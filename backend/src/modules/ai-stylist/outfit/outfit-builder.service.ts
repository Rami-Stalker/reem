import { Injectable } from '@nestjs/common';
import { OutfitSlot } from '@prisma/client';
import { defaultOffer } from '../../../common/catalog/product-include';
import { StyleProfile } from '../preferences/style-profile';
import {
  ProductRetrievalService,
  Relaxation,
  StylistCandidate,
} from '../retrieval/product-retrieval.service';
import {
  ScoredProduct,
  productColourKeys,
  rankProducts,
  renderReason,
} from '../retrieval/stylist-ranker';
import { StyleBrief } from '../understanding/style-brief';
import {
  colourLabel,
  occasionEntry,
  slotEntry,
  slotLabel,
} from '../understanding/stylist-lexicon';

export interface OutfitPiece {
  slot: OutfitSlot;
  product: StylistCandidate;
  offerId: string | null;
  priceSyp: number | null;
  score: number;
  reason: string;
  reasonCodes: string[];
}

export interface BuiltOutfit {
  title: string;
  occasion: string | null;
  note: string | null;
  palette: string[];
  totalSyp: number | null;
  pieces: OutfitPiece[];
  relaxations: Relaxation[];
  /** Slots the catalog simply had nothing live for. */
  missingSlots: OutfitSlot[];
}

/**
 * Assembles a complete look out of real, separately-sold products.
 *
 * The order of operations is what makes the result cohere. An **anchor** is
 * chosen first — the dress, the abaya, whatever carries the look — and every
 * other slot is then ranked *against* it, so the bag is picked to go with that
 * dress rather than picked well on its own and hoped to match. Budget is
 * allocated per slot up front for the same reason: without it, the anchor
 * takes the whole allowance and the shoes come from whatever is left.
 */
@Injectable()
export class OutfitBuilderService {
  constructor(private readonly retrieval: ProductRetrievalService) {}

  async build(
    brief: StyleBrief,
    profile: StyleProfile,
    options: { maxPieces?: number } = {},
  ): Promise<BuiltOutfit | null> {
    const slots = this.planSlots(brief).slice(0, options.maxPieces ?? 5);
    if (!slots.length) return null;

    const allowances = this.allocateBudget(slots, brief.budgetMax);
    const relaxations = new Map<string, Relaxation>();
    const pieces: OutfitPiece[] = [];
    const missingSlots: OutfitSlot[] = [];

    // The anchor leads: it decides the palette every other slot answers to.
    const anchorSlot = this.anchorSlot(slots);
    const ordered = [anchorSlot, ...slots.filter((slot) => slot !== anchorSlot)];

    let anchorColour: string | null = null;
    const usedProductIds = new Set<string>();
    const usedSellerIds = new Set<string>();

    for (const slot of ordered) {
      const allowance = allowances.get(slot) ?? { min: null, max: null };
      const result = await this.retrieval.retrieveForSlot(brief, slot, allowance);
      for (const relaxation of result.relaxations) {
        relaxations.set(relaxation.code, relaxation);
      }

      const ranked = rankProducts(
        result.candidates.filter((candidate) => !usedProductIds.has(candidate.id)),
        {
          brief,
          profile,
          slot,
          anchorColour: slot === anchorSlot ? null : anchorColour,
          // One piece per slot, so the list-level diversity caps do not apply;
          // the spread across sellers is handled below instead.
          diversity: null,
        },
        6,
      );

      const picked = this.pickForSlot(ranked, usedSellerIds);
      if (!picked) {
        missingSlots.push(slot);
        continue;
      }

      usedProductIds.add(picked.product.id);
      const offer = defaultOffer(picked.product);
      if (offer) usedSellerIds.add(offer.sellerId);

      if (slot === anchorSlot) {
        anchorColour = picked.dominantColour ?? brief.colours[0] ?? null;
      }

      pieces.push({
        slot,
        product: picked.product,
        offerId: offer?.id ?? null,
        priceSyp: picked.product.minPriceSyp ? Number(picked.product.minPriceSyp) : null,
        score: picked.score,
        reason: renderReason(picked, brief, { slot }),
        reasonCodes: picked.reasons,
      });
    }

    if (!pieces.length) return null;

    // Keep the anchor first in the returned order regardless of what the loop
    // did, so the look reads top-down on the screen.
    pieces.sort((a, b) => this.slotOrder(a.slot) - this.slotOrder(b.slot));

    const totalSyp = pieces.reduce<number | null>((sum, piece) => {
      if (sum === null || piece.priceSyp === null) return null;
      return sum + piece.priceSyp;
    }, 0);

    return {
      title: this.title(brief),
      occasion: brief.occasion,
      note: this.note(brief, pieces, totalSyp),
      palette: this.palette(pieces),
      totalSyp,
      pieces,
      relaxations: [...relaxations.values()],
      missingSlots,
    };
  }

  /**
   * Prefers a piece from a boutique not already in the look.
   *
   * Not a rule about taste — a rule about delivery. Every extra seller is
   * another sub-order, another courier and another parcel (Q58), so when the
   * top two candidates are close, the one that does not add a shipment wins.
   * A clearly better piece still wins outright.
   */
  private pickForSlot(
    ranked: ScoredProduct[],
    usedSellerIds: Set<string>,
  ): ScoredProduct | null {
    if (!ranked.length) return null;
    const best = ranked[0];
    if (!usedSellerIds.size) return best;

    const sameSeller = ranked.find((entry) => {
      const offer = defaultOffer(entry.product);
      return offer ? usedSellerIds.has(offer.sellerId) : false;
    });

    if (sameSeller && sameSeller.score >= best.score * 0.9) return sameSeller;
    return best;
  }

  /** What the look is made of: what she named, or what the occasion implies. */
  private planSlots(brief: StyleBrief): OutfitSlot[] {
    if (brief.slots.length >= 2) return [...new Set(brief.slots)];

    const occasion = occasionEntry(brief.occasion);
    if (occasion?.slots.length) {
      const named = brief.slots[0];
      // She named one piece and an occasion: keep her piece first, then fill
      // the rest of the look around it.
      const rest = occasion.slots.filter((slot) => slot !== named);
      return named ? [named, ...rest] : [...occasion.slots];
    }

    if (brief.slots.length === 1) {
      return this.companionSlots(brief.slots[0]);
    }

    return [OutfitSlot.DRESS, OutfitSlot.SHOES, OutfitSlot.BAG, OutfitSlot.JEWELRY];
  }

  /** "أريد فستانًا أسود مع حقيبة وحذاء" reduced to its one named piece still
   *  has an obvious rest-of-the-look. */
  private companionSlots(slot: OutfitSlot): OutfitSlot[] {
    switch (slot) {
      case OutfitSlot.DRESS:
      case OutfitSlot.ABAYA:
        return [slot, OutfitSlot.SHOES, OutfitSlot.BAG, OutfitSlot.JEWELRY];
      case OutfitSlot.TOP:
        return [slot, OutfitSlot.BOTTOM, OutfitSlot.SHOES, OutfitSlot.BAG];
      case OutfitSlot.BOTTOM:
        return [OutfitSlot.TOP, slot, OutfitSlot.SHOES, OutfitSlot.BAG];
      case OutfitSlot.SHOES:
        return [OutfitSlot.DRESS, slot, OutfitSlot.BAG];
      case OutfitSlot.BAG:
        return [OutfitSlot.DRESS, OutfitSlot.SHOES, slot];
      default:
        return [slot, OutfitSlot.DRESS, OutfitSlot.SHOES];
    }
  }

  private anchorSlot(slots: OutfitSlot[]): OutfitSlot {
    const priority = [
      OutfitSlot.DRESS,
      OutfitSlot.ABAYA,
      OutfitSlot.OUTERWEAR,
      OutfitSlot.TOP,
      OutfitSlot.BOTTOM,
    ];
    return priority.find((slot) => slots.includes(slot)) ?? slots[0];
  }

  /**
   * Splits the budget across the look.
   *
   * Weights come from the lexicon (a dress is 42% of an outfit, jewellery
   * 12%) and are renormalised over the slots actually being filled, so a
   * two-piece look does not leave 40% of her money unspent. Each slot gets
   * generous headroom on its share — the allowance shapes the search, and the
   * total is checked afterwards.
   */
  private allocateBudget(
    slots: OutfitSlot[],
    total: number | null,
  ): Map<OutfitSlot, { min: number | null; max: number | null }> {
    const allowances = new Map<OutfitSlot, { min: number | null; max: number | null }>();
    if (total === null) {
      for (const slot of slots) allowances.set(slot, { min: null, max: null });
      return allowances;
    }

    const weights = slots.map((slot) => slotEntry(slot).budgetWeight);
    const sum = weights.reduce((acc, weight) => acc + weight, 0) || 1;

    for (const [index, slot] of slots.entries()) {
      const share = (weights[index] / sum) * total;
      allowances.set(slot, {
        min: null,
        // 1.35 rather than 1.0: the shares are a guide, and a look that comes
        // in under budget overall is fine even if one piece ran over its slice.
        max: Math.round(share * 1.35),
      });
    }
    return allowances;
  }

  private palette(pieces: OutfitPiece[]): string[] {
    const colours = new Set<string>();
    for (const piece of pieces) {
      for (const colour of productColourKeys(piece.product)) colours.add(colour);
    }
    return [...colours].slice(0, 4);
  }

  private title(brief: StyleBrief): string {
    const occasion = occasionEntry(brief.occasion);
    if (occasion) return `إطلالة ${occasion.labelAr}`;
    if (brief.colours.length) return `إطلالة ${colourLabel(brief.colours[0])}`;
    return 'إطلالة مختارة لكِ';
  }

  private note(
    brief: StyleBrief,
    pieces: OutfitPiece[],
    totalSyp: number | null,
  ): string | null {
    const names = pieces.map((piece) => slotLabel(piece.slot));
    if (!names.length) return null;

    const listed =
      names.length === 1
        ? names[0]
        : `${names.slice(0, -1).join('، ')} و${names[names.length - 1]}`;

    const overBudget =
      brief.budgetMax !== null && totalSyp !== null && totalSyp > brief.budgetMax;

    return overBudget
      ? `تضم الإطلالة ${listed}، وجاءت أعلى قليلاً من الميزانية — يمكنكِ حذف قطعة لتبقي ضمن الرقم.`
      : `تضم الإطلالة ${listed}، والقطع متناسقة الألوان.`;
  }

  /** Top-down: the garment, then what goes under it, then the extras. */
  private slotOrder(slot: OutfitSlot): number {
    const order: OutfitSlot[] = [
      OutfitSlot.ABAYA,
      OutfitSlot.DRESS,
      OutfitSlot.OUTERWEAR,
      OutfitSlot.TOP,
      OutfitSlot.BOTTOM,
      OutfitSlot.SHOES,
      OutfitSlot.BAG,
      OutfitSlot.JEWELRY,
      OutfitSlot.ACCESSORY,
      OutfitSlot.PERFUME,
      OutfitSlot.BEAUTY,
      OutfitSlot.GIFT,
    ];
    const index = order.indexOf(slot);
    return index === -1 ? order.length : index;
  }
}
