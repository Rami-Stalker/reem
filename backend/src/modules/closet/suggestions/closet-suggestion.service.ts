import { Injectable } from '@nestjs/common';
import { ClosetGap, ModestyLevel, OutfitSlot } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { defaultOffer } from '../../../common/catalog/product-include';
import { ProductRetrievalService, StylistCandidate } from '../../ai-stylist/retrieval/product-retrieval.service';
import { ReasonCode, rankProducts } from '../../ai-stylist/retrieval/stylist-ranker';
import { StylePreferenceService } from '../../ai-stylist/preferences/style-preference.service';
import { ClosetService } from '../closet.service';
import { ClosetSnapshot, modalSize } from '../gaps/gap-engine';
import { briefFromGap } from '../gaps/gap-brief';
import { describeCatalogGarment } from '../items/garment-descriptor';
import { PairingCandidate, PairingReason, scorePairing } from './pairing';

export interface ClosetSuggestion {
  product: StylistCandidate;
  /** The blended figure the list is ordered by. */
  score: number;
  /** What the stylist's ranker said, unmodified. */
  styleScore: number;
  styleReasons: ReasonCode[];
  /** What her wardrobe said. */
  pairingScore: number;
  pairingReasons: PairingReason[];
  pairsWithItemIds: string[];
  completesLookIds: string[];
}

/**
 * Products for a gap.
 *
 * The pipeline is three steps and only the last is new:
 *
 *   1. `briefFromGap`  — her wardrobe's need, as a `StyleBrief`.
 *   2. retrieval + ranking — the stylist's, unchanged, including the relaxation
 *      ladder and the purchasable predicate.
 *   3. `scorePairing`  — how each candidate sits with what she already owns.
 *
 * Step 3 adjusts rather than replaces. The stylist's ranker knows things the
 * closet does not — seller trust, ratings, delivery speed, her dismissals — and
 * throwing that away to sort purely by wardrobe fit would produce beautifully
 * co-ordinated suggestions from unreliable sellers. So the pairing score enters
 * as a bounded term on top of a normalised style score, and the weight is
 * declared as a constant below rather than tuned into the arithmetic where
 * nobody could find it.
 */
@Injectable()
export class ClosetSuggestionService {
  /**
   * How far wardrobe fit may move a ranking.
   *
   * At 0.45 a piece that goes with everything she owns can overtake one the
   * catalog likes better, but cannot rescue something the ranker scored near
   * the bottom. That is the intended balance: the closet decides *between* good
   * options, it does not override what makes an option good.
   */
  private static readonly PAIRING_WEIGHT = 0.45;

  constructor(
    private readonly prisma: PrismaService,
    private readonly closet: ClosetService,
    private readonly retrieval: ProductRetrievalService,
    private readonly preferences: StylePreferenceService,
  ) {}

  /**
   * Suggestions for one gap.
   *
   * `snapshot` is optional so a screen rendering five gap cards reads her closet
   * once instead of five times — the pairing context is identical for all of
   * them, and re-reading it per gap was the obvious way to make this endpoint
   * slow.
   */
  async forGap(
    userId: string,
    gap: ClosetGap,
    options: { limit?: number; snapshot?: ClosetSnapshot } = {},
  ): Promise<ClosetSuggestion[]> {
    const limit = options.limit ?? 8;
    const snapshot = options.snapshot ?? (await this.closet.snapshot(userId));
    const profile = await this.preferences.buildProfile(userId);

    const brief = briefFromGap(gap, { modesty: profile.modesty });
    const { candidates } = await this.retrieval.retrieve(brief, { slot: gap.slot });

    // Rank wide, then re-order. The pairing pass can only choose among rows the
    // ranker already produced, so it needs more than `limit` of them to have a
    // choice worth making.
    const ranked = rankProducts(
      candidates,
      { brief, profile, slot: gap.slot, anchorColour: gap.suggestedColours[0] ?? null },
      limit * 4,
    );
    if (!ranked.length) return [];

    const context = this.pairingContext(snapshot, gap.occasion);

    // Style scores are unbounded sums, so they are normalised against the best
    // one in this batch before being blended. Comparing a raw ranker score to a
    // −1…1 pairing score would make the weight above meaningless.
    const best = Math.max(...ranked.map((entry) => entry.score), 1);

    return ranked
      .map((entry) => {
        const pairing = scorePairing(
          this.toPairingCandidate(entry.product, gap.slot),
          context,
        );
        const styleScore = entry.score / best;
        return {
          product: entry.product,
          score:
            Math.round(
              (styleScore + pairing.score * ClosetSuggestionService.PAIRING_WEIGHT) * 1000,
            ) / 1000,
          styleScore: Math.round(styleScore * 1000) / 1000,
          styleReasons: entry.reasons,
          pairingScore: pairing.score,
          pairingReasons: pairing.reasons,
          pairsWithItemIds: pairing.pairsWithItemIds,
          completesLookIds: pairing.completesLookIds,
        };
      })
      .sort((a, b) => b.score - a.score || a.product.id.localeCompare(b.product.id))
      .slice(0, limit);
  }

  /**
   * Would this product go with what she owns?
   *
   * The product page's question, and the inverse of everything else here: the
   * garment is given and the wardrobe is the unknown. Answering it is what turns
   * a product page from a listing into a fitting room — she is not asked whether
   * she likes the dress, she is told which three things in her closet it works
   * with and which look it finishes.
   */
  async pairingFor(
    userId: string,
    productId: string,
    options: { snapshot?: ClosetSnapshot } = {},
  ) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      include: { category: true, variants: true, offers: { include: { variants: { include: { variant: true } } } } },
    });
    if (!product) return null;

    const snapshot = options.snapshot ?? (await this.closet.snapshot(userId));
    const descriptor = describeCatalogGarment({
      categorySlug: product.category.slug,
      title: product.title,
      description: product.description,
      attributes: product.attributes as Record<string, unknown> | null,
    });

    const pairing = scorePairing(
      {
        slot: descriptor.slot,
        colours: descriptor.colours,
        seasons: descriptor.seasons,
        occasions: descriptor.occasions,
        modesty: descriptor.modesty,
        availableSizes: availableSizes(product.offers),
      },
      this.pairingContext(snapshot, null),
    );

    const owned = snapshot.items.filter((item) =>
      pairing.pairsWithItemIds.includes(item.id),
    );

    return {
      slot: descriptor.slot,
      alreadyOwned: await this.prisma.closetItem.count({
        where: { userId, productId, status: { not: 'RELEASED' } },
      }),
      pairsWith: owned,
      completesLookIds: pairing.completesLookIds,
      reasons: pairing.reasons,
      score: pairing.score,
    };
  }

  // ── Plumbing ──────────────────────────────────────────────────────────

  private pairingContext(snapshot: ClosetSnapshot, occasion: string | null) {
    const sizes = new Map<OutfitSlot, string>();
    for (const slot of new Set(snapshot.items.map((item) => item.slot))) {
      const size = modalSize(snapshot.items, slot);
      if (size) sizes.set(slot, size);
    }
    return {
      items: snapshot.items,
      looks: snapshot.looks,
      season: snapshot.season,
      sizes,
      occasion,
    };
  }

  /**
   * A catalog row, described in the closet's own vocabulary.
   *
   * The same `describeCatalogGarment` that runs when a piece is added, so a
   * product is scored against her wardrobe using exactly the description it
   * would have if she bought it. A second, suggestion-only description would
   * mean a dress could pair well before purchase and badly after.
   *
   * `slot` is forced to the gap's rather than re-derived: retrieval was asked
   * for this slot, and a category that maps ambiguously must not quietly produce
   * a candidate that answers a different question.
   */
  private toPairingCandidate(
    product: StylistCandidate,
    slot: OutfitSlot,
  ): PairingCandidate {
    const descriptor = describeCatalogGarment({
      categorySlug: product.category.slug,
      title: product.title,
      description: product.description,
      attributes: product.attributes as Record<string, unknown> | null,
    });

    return {
      slot,
      colours: descriptor.colours,
      seasons: descriptor.seasons,
      occasions: descriptor.occasions,
      modesty: descriptor.modesty,
      availableSizes: availableSizes(product.offers),
    };
  }
}

/**
 * Sizes a customer could actually receive today.
 *
 * In-stock variants only. A size listed but unavailable is the single most
 * annoying thing a recommendation can get wrong, and the offer rows already
 * carry the stock, so there is no reason to promise from the catalog.
 */
function availableSizes(
  offers: ReadonlyArray<{
    variants: ReadonlyArray<{ stock: number; variant: { attributes: unknown } }>;
  }>,
): string[] {
  const sizes = new Set<string>();
  for (const offer of offers) {
    for (const row of offer.variants) {
      if (row.stock <= 0) continue;
      const attributes = row.variant.attributes as Record<string, unknown> | null;
      const size = attributes?.['size'] ?? attributes?.['مقاس'];
      if (size) sizes.add(String(size).trim().toUpperCase());
    }
  }
  return [...sizes];
}

/** Kept for the serializer, which renders modesty into Arabic. */
export const UNSPECIFIED_MODESTY = ModestyLevel.UNSPECIFIED;
