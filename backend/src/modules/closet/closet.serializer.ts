import {
  Closet,
  ClosetGap,
  ClosetGapKind,
  ClosetItem,
  ClosetItemSource,
  ClosetSeason,
  OutfitSlot,
  Prisma,
} from '@prisma/client';
import { Money } from '../../common/money';
import { serializeProduct } from '../../common/serializers';
import { ProductRecord } from '../../common/catalog/product-include';
import {
  colourLabel,
  modestyLabel,
  occasionLabel,
  slotLabel,
} from '../ai-stylist/understanding/stylist-lexicon';
import { LookRecord } from './looks/closet-look.service';
import { ClosetSuggestion } from './suggestions/closet-suggestion.service';
import { PairingReason } from './suggestions/pairing';
import { OutfitReason } from './today/today-picker';
import { TodayOutfit } from './today/today.service';

/**
 * The wire shape of the closet.
 *
 * Products go out through `serializeProduct` — the same function the catalog,
 * search, the stylist and discovery use — so a suggestion card in the closet is
 * byte-for-byte the same object as a search result, and the Flutter client draws
 * it with the widget it already has. The closet adds only what is closet-
 * specific: the slot, the pairing, the reason.
 *
 * Every code the engines produce is rendered into Arabic *here* and nowhere
 * else. The engines deal in codes precisely so that the sentence a woman reads
 * is a rendering of the arithmetic that fired rather than a second opinion about
 * it — the same rule the stylist's `ReasonCode` follows.
 */

// ── Labels ──────────────────────────────────────────────────────────────

export function seasonLabel(season: ClosetSeason): string {
  switch (season) {
    case ClosetSeason.SUMMER:
      return 'صيفي';
    case ClosetSeason.WINTER:
      return 'شتوي';
    case ClosetSeason.TRANSITIONAL:
      return 'بين الفصلين';
    default:
      return 'كل الفصول';
  }
}

export function sourceLabel(source: ClosetItemSource): string {
  switch (source) {
    case ClosetItemSource.PURCHASE:
      return 'من مشترياتكِ';
    case ClosetItemSource.CATALOG:
      return 'من ريم';
    default:
      return 'قطعة شخصية';
  }
}

/**
 * The headline of a gap card.
 *
 * Written from the row, so the sentence cannot claim something the priority
 * arithmetic did not. A COVERAGE gap says how many outfits the piece unlocks
 * because `components.outfits_unlocked` is that number — if the engine ever
 * stops producing it, the sentence loses the clause rather than inventing one.
 */
export function gapHeadline(gap: ClosetGap): string {
  const slot = slotLabel(gap.slot);
  const occasion = occasionLabel(gap.occasion);
  const components = (gap.components ?? {}) as Record<string, number>;

  switch (gap.kind) {
    case ClosetGapKind.LOOK_SLOT:
      return `ينقصكِ ${slot} لتكتمل إطلالتكِ`;
    case ClosetGapKind.OCCASION:
      return occasion
        ? `ليس لديكِ ${slot} مناسب لـ${occasion}`
        : `ليس لديكِ ${slot} لهذه المناسبة`;
    case ClosetGapKind.COVERAGE: {
      const unlocked = components['outfits_unlocked'];
      return unlocked
        ? `${slot} واحد يفتح لكِ ${unlocked} إطلالة جديدة`
        : `ينقص خزانتكِ ${slot}`;
    }
    case ClosetGapKind.SEASON:
      return `ليس لديكِ ${slot} للموسم الحالي`;
    default:
      return `${slot} لديكِ يحتاج إلى تبديل`;
  }
}

/** The supporting line: why the engine believes it. */
export function gapRationale(gap: ClosetGap): string {
  const components = (gap.components ?? {}) as Record<string, number>;

  switch (gap.kind) {
    case ClosetGapKind.LOOK_SLOT:
      return components['nearly_complete']
        ? 'قطعة واحدة وتكتمل الإطلالة.'
        : 'إطلالة محفوظة لديكِ تنقصها هذه القطعة.';
    case ClosetGapKind.OCCASION:
      return 'لديكِ قطع لهذه المناسبة لكنها لا تكفي لإطلالة كاملة.';
    case ClosetGapKind.COVERAGE: {
      const now = components['outfits_now'];
      return now === 0
        ? 'هذه القطعة تجعل خزانتكِ تعطي إطلالة كاملة.'
        : `لديكِ الآن ${now} إطلالة كاملة، وهذه القطعة تزيدها أكثر من غيرها.`;
    }
    case ClosetGapKind.SEASON: {
      const shelved = components['owned_out_of_season'];
      return shelved
        ? `لديكِ ${shelved} قطع في هذه الخانة لكنها لا تناسب الطقس الآن.`
        : 'لا قطعة في هذه الخانة تناسب الموسم.';
    }
    default: {
      const wears = components['wear_count'];
      return wears
        ? `ارتديتِها ${wears} مرة، وليس لديكِ بديل في هذه الخانة.`
        : 'ليس لديكِ بديل في هذه الخانة.';
    }
  }
}

const PAIRING_REASON_LABELS: Record<PairingReason, string> = {
  PAIRS_WITH_OWNED: 'تتناسق مع قطع في خزانتكِ',
  COMPLETES_LOOK: 'تكمل إطلالة محفوظة لديكِ',
  FILLS_EMPTY_SLOT: 'لا قطعة لديكِ في هذه الخانة',
  MATCHES_YOUR_SIZE: 'متوفرة بمقاسكِ',
  IN_SEASON: 'مناسبة للموسم الحالي',
  MATCHES_YOUR_MODESTY: 'تناسب أسلوب خزانتكِ',
  MATCHES_YOUR_PALETTE: 'من ألوان خزانتكِ',
  ALREADY_WELL_STOCKED: 'لديكِ قطع كثيرة في هذه الخانة',
  DUPLICATE_OF_OWNED: 'قريبة جداً من قطعة لديكِ',
};

const OUTFIT_REASON_LABELS: Record<OutfitReason, string> = {
  READY_TO_WEAR: 'جاهزة للبس',
  NOT_WORN_RECENTLY: 'لم ترتديها منذ فترة',
  REDISCOVERED: 'لم ترتديها منذ زمن',
  FAVOURITE: 'من مفضّلاتكِ',
  SEASON_FIT: 'تناسب الطقس',
  OCCASION_FIT: 'مناسبة للمناسبة',
  COLOURS_HARMONISE: 'ألوانها متناسقة',
  ONE_PIECE_SHORT: 'تنقصها قطعة واحدة',
};

// ── Rows ────────────────────────────────────────────────────────────────

type ItemRow = ClosetItem & {
  brand?: { id: string; nameAr: string; nameEn: string } | null;
};

export function serializeClosetItem(item: ItemRow) {
  return {
    id: item.id,
    source: item.source,
    source_label: sourceLabel(item.source),
    status: item.status,
    title: item.title,
    image_url: item.imageUrl,
    blur_hash: item.blurHash,

    slot: item.slot,
    slot_label: slotLabel(item.slot),
    colours: item.colours.map((key) => ({ key, label: colourLabel(key) })),
    materials: item.materials,
    modesty: item.modesty,
    modesty_label: modestyLabel(item.modesty),
    seasons: item.seasons.map((season) => ({
      key: season,
      label: seasonLabel(season),
    })),
    occasions: item.occasions.map((key) => ({ key, label: occasionLabel(key) })),
    size: item.size,

    brand: item.brand
      ? { id: item.brand.id, name_ar: item.brand.nameAr, name_en: item.brand.nameEn }
      : null,
    brand_name: item.brandName,

    product_id: item.productId,
    offer_id: item.offerId,
    variant_id: item.variantId,
    order_item_id: item.orderItemId,

    purchase_price: item.purchasePriceSyp
      ? Money.of(item.purchasePriceSyp, 'SYP').toJSON()
      : null,
    /**
     * The number that changes how a wardrobe feels.
     *
     * Only computed once she has actually worn the thing: dividing by zero
     * wears would print the full price as the cost of one wearing, which reads
     * as an accusation rather than a fact.
     */
    cost_per_wear:
      item.purchasePriceSyp && item.wearCount > 0
        ? Money.of(
            new Prisma.Decimal(item.purchasePriceSyp).div(item.wearCount),
            'SYP',
          ).toJSON()
        : null,

    wear_count: item.wearCount,
    last_worn_at: item.lastWornAt?.toISOString() ?? null,
    is_favourite: item.isFavourite,
    note: item.note,
    acquired_at: item.acquiredAt?.toISOString() ?? null,
    created_at: item.createdAt.toISOString(),
  };
}

export function serializeLook(look: LookRecord) {
  const items = look.items.map((item) => ({
    id: item.id,
    slot: item.slot,
    slot_label: slotLabel(item.slot),
    position: item.position,
    note: item.note,
    /**
     * The two-sided shape, kept two-sided on the wire.
     *
     * `owned` is a piece from her closet; `product` is one she does not have
     * yet. The client renders the second differently — as the gap it is — and
     * flattening them into one field here would take that distinction away from
     * it.
     */
    owned: item.closetItem ? serializeClosetItem(item.closetItem) : null,
    product: item.product
      ? serializeProduct(item.product as unknown as ProductRecord, { isLiked: false })
      : null,
    offer_id: item.offerId,
    variant_id: item.variantId,
  }));

  return {
    id: look.id,
    title: look.title,
    note: look.note,
    occasion: look.occasion,
    occasion_label: occasionLabel(look.occasion),
    seasons: look.seasons.map((season) => ({ key: season, label: seasonLabel(season) })),
    palette: look.palette.map((key) => ({ key, label: colourLabel(key) })),
    is_complete: look.isComplete,
    is_favourite: look.isFavourite,
    is_archived: look.isArchived,
    missing_slots: look.items
      .filter((item) => !item.closetItemId)
      .map((item) => ({ slot: item.slot, label: slotLabel(item.slot) })),
    wear_count: look.wearCount,
    last_worn_at: look.lastWornAt?.toISOString() ?? null,
    source_outfit_id: look.sourceOutfitId,
    items,
    created_at: look.createdAt.toISOString(),
    updated_at: look.updatedAt.toISOString(),
  };
}

type GapRow = ClosetGap & {
  look?: { id: string; title: string; occasion: string | null } | null;
};

export function serializeGap(gap: GapRow) {
  return {
    id: gap.id,
    kind: gap.kind,
    status: gap.status,
    slot: gap.slot,
    slot_label: slotLabel(gap.slot),
    occasion: gap.occasion,
    occasion_label: occasionLabel(gap.occasion),
    season: gap.season,
    season_label: gap.season ? seasonLabel(gap.season) : null,
    look: gap.look ? { id: gap.look.id, title: gap.look.title } : null,

    headline: gapHeadline(gap),
    rationale: gapRationale(gap),

    priority: gap.priority,
    /**
     * The arithmetic, shipped.
     *
     * Every number on a gap card can be taken apart back to the components that
     * produced it — the same contract the trend scores keep. A recommendation
     * she cannot interrogate is one she has to take on trust, and this feature
     * asks for enough trust already by holding a list of her clothes.
     */
    components: gap.components,

    suggested_colours: gap.suggestedColours.map((key) => ({
      key,
      label: colourLabel(key),
    })),
    suggested_size: gap.suggestedSize,
    suggested_budget_min: gap.suggestedBudgetMinSyp
      ? Money.of(gap.suggestedBudgetMinSyp, 'SYP').toJSON()
      : null,
    suggested_budget_max: gap.suggestedBudgetMaxSyp
      ? Money.of(gap.suggestedBudgetMaxSyp, 'SYP').toJSON()
      : null,
    computed_at: gap.computedAt.toISOString(),
  };
}

export function serializeSuggestion(suggestion: ClosetSuggestion) {
  return {
    product: serializeProduct(suggestion.product as unknown as ProductRecord, {
      isLiked: false,
    }),
    score: suggestion.score,
    style_score: suggestion.styleScore,
    pairing_score: suggestion.pairingScore,
    // Both vocabularies travel: the catalog's reasons and the wardrobe's. They
    // answer different questions and the client shows them in different places.
    style_reasons: suggestion.styleReasons,
    pairing_reasons: suggestion.pairingReasons.map((reason) => ({
      code: reason,
      label: PAIRING_REASON_LABELS[reason],
    })),
    pairs_with_item_ids: suggestion.pairsWithItemIds,
    completes_look_ids: suggestion.completesLookIds,
  };
}

export function serializeTodayOutfit(outfit: TodayOutfit) {
  return {
    key: outfit.key,
    origin: outfit.origin,
    look_id: outfit.lookId,
    look_title: outfit.lookTitle,
    occasion: outfit.occasion,
    occasion_label: occasionLabel(outfit.occasion),
    score: outfit.score,
    reasons: outfit.reasons.map((reason) => ({
      code: reason,
      label: OUTFIT_REASON_LABELS[reason],
    })),
    missing_slots: outfit.missingSlots.map((slot) => ({
      slot,
      label: slotLabel(slot),
    })),
    pieces: outfit.pieceItems.map(serializeClosetItem),
  };
}

export function serializeCloset(closet: Closet) {
  return {
    id: closet.id,
    auto_add_purchases: closet.autoAddPurchases,
    suggestions_enabled: closet.suggestionsEnabled,
    items_count: closet.itemsCount,
    looks_count: closet.looksCount,
    gaps_computed_at: closet.gapsComputedAt?.toISOString() ?? null,
  };
}

export function serializeOverview(
  overview: Awaited<ReturnType<import('./closet.service').ClosetService['overview']>>,
) {
  return {
    closet: serializeCloset(overview.closet),
    season: overview.season,
    season_label: seasonLabel(overview.season),
    items_count: overview.itemsCount,
    archived_count: overview.archivedCount,
    looks_count: overview.looksCount,
    complete_looks_count: overview.completeLooksCount,
    worn_this_month: overview.wornThisMonth,
    /**
     * How many complete outfits her wardrobe can produce, and how many of them
     * work in the weather she is actually in. The gap between the two numbers is
     * the seasonal story, and it is the single most useful thing the header can
     * tell her.
     */
    outfit_capacity: overview.outfitCapacity,
    season_outfit_capacity: overview.seasonOutfitCapacity,
    slot_counts: overview.slotCounts.map((entry) => ({
      slot: entry.slot,
      label: slotLabel(entry.slot as OutfitSlot),
      count: entry.count,
    })),
    neglected: overview.neglected.map(serializeClosetItem),
  };
}
