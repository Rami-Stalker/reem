import { Injectable } from '@nestjs/common';
import {
  AffinityKind,
  ClosetItemStatus,
  GraphEdge,
  GraphNode,
  OfferStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import {
  detectColours,
  detectOccasion,
  detectSlots,
} from '../ai-stylist/understanding/stylist-lexicon';
import {
  OwnedPiece,
  ProductFacts,
  ShopperFacts,
  Verdict,
  verdictsFor,
} from './kernel/product-verdict';

/**
 * What Ohara knows about one woman looking at one product.
 *
 * The seam between the commerce graph and the verdict kernel. Its job is to
 * assemble `ShopperFacts` and `ProductFacts` honestly and hand them over; every
 * judgement happens in the kernel, which is pure and therefore testable and
 * re-derivable.
 *
 * ── Why it reads the graph rather than the source tables ─────────────────
 *
 * It could join five tables per product page. The graph exists so it does not
 * have to: one indexed read of her edges answers "what does she own, what is
 * she short of, what has she searched for, whose shop does she trust", and the
 * cost does not grow as more behaviours are projected into it.
 *
 * The exception is her closet, which is read directly. Verdicts have to *name*
 * the garment — «عندك فستان كحلي طويل وهي قريبة منها» — and a graph edge
 * carries a weight, not a title.
 */
@Injectable()
export class ShopperIntelligenceService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * The notes for one product.
   *
   * Returns an empty array freely: a shopper with no history, or a product
   * nothing can be said about, gets nothing rather than filler.
   */
  async verdicts(
    userId: string | null,
    productId: string,
    options: { now?: Date } = {},
  ): Promise<Verdict[]> {
    if (!userId) return [];

    const [product, shopper] = await Promise.all([
      this.productFacts(productId, options.now),
      this.shopperFacts(userId),
    ]);
    if (!product) return [];

    const [alternative, pairsWith, ownsSimilar] = await Promise.all([
      this.betterValue(productId),
      this.relatedToHers(productId, shopper.owns, 'complement'),
      this.relatedToHers(productId, shopper.owns, 'similar'),
    ]);

    return verdictsFor({
      product,
      shopper,
      alternative,
      pairsWith,
      ownsSimilar,
    });
  }

  /**
   * Everything the graph knows about her, in one read.
   *
   * Public because the seller side and the ranking both want the same picture,
   * and two assemblies of "who she is" would eventually disagree.
   */
  async shopperFacts(userId: string): Promise<ShopperFacts> {
    const [edges, closet, looks] = await Promise.all([
      this.prisma.commerceEdge.findMany({
        where: {
          subjectType: GraphNode.USER,
          subjectId: userId,
          kind: {
            in: [
              GraphEdge.SEARCHED,
              GraphEdge.SHOPS_FOR,
              GraphEdge.BUYS_FROM,
              GraphEdge.NEEDS,
            ],
          },
        },
        orderBy: { weight: 'desc' },
        take: 60,
      }),
      this.prisma.closetItem.findMany({
        where: { userId, status: ClosetItemStatus.ACTIVE },
        select: {
          id: true,
          title: true,
          slot: true,
          colours: true,
          productId: true,
          product: { select: { categoryId: true } },
        },
        take: 200,
      }),
      this.prisma.closetLook.findMany({
        where: { userId, isArchived: false, isComplete: false },
        select: {
          id: true,
          title: true,
          occasion: true,
          items: { select: { slot: true, closetItemId: true } },
        },
        take: 30,
      }),
    ]);

    const terms: { key: string; display: string }[] = [];
    const occasions: string[] = [];
    const sellers: string[] = [];
    const needs: string[] = [];

    for (const edge of edges) {
      // The human key lives in `evidence` because the object id is a hash —
      // see `KEYED_NODES`.
      const evidence = (edge.evidence ?? {}) as Record<string, unknown>;
      switch (edge.kind) {
        case GraphEdge.SEARCHED: {
          const key = evidence['term'];
          if (typeof key === 'string') {
            terms.push({
              key,
              display:
                typeof evidence['display'] === 'string'
                  ? (evidence['display'] as string)
                  : key,
            });
          }
          break;
        }
        case GraphEdge.SHOPS_FOR: {
          const key = evidence['occasion'];
          if (typeof key === 'string') occasions.push(key);
          break;
        }
        case GraphEdge.BUYS_FROM:
          // Repeat custom only — see `ShopperFacts.boughtFromSellerIds`. The
          // edge carries how many orders it was built from.
          if (edge.observations > 1) sellers.push(edge.objectId);
          break;
        case GraphEdge.NEEDS: {
          const key = evidence['slot'];
          if (typeof key === 'string') needs.push(key);
          break;
        }
        default:
          break;
      }
    }

    return {
      owns: closet.map((item) => ({
        itemId: item.id,
        title: item.title,
        slot: item.slot,
        colours: item.colours,
        categoryId: item.product?.categoryId ?? null,
      })),
      openLooks: looks.map((look) => ({
        lookId: look.id,
        title: look.title,
        missingSlots: look.items
          .filter((i) => !i.closetItemId)
          .map((i) => i.slot),
        occasion: look.occasion,
      })),
      occasions,
      terms,
      boughtFromSellerIds: sellers,
      needsSlots: needs,
    };
  }

  /** The catalogue side, including the demand split the verdict needs. */
  private async productFacts(
    productId: string,
    now = new Date(),
  ): Promise<ProductFacts | null> {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: {
        id: true,
        title: true,
        description: true,
        categoryId: true,
        attributes: true,
        minPriceSyp: true,
        offers: {
          where: { status: OfferStatus.ACTIVE },
          select: { sellerId: true, stock: true },
        },
      },
    });
    if (!product) return null;

    const half = 14;
    const since = utcDay(new Date(now.getTime() - half * 2 * 86_400_000));
    const midpoint = utcDay(new Date(now.getTime() - half * 86_400_000));

    const [recent, previous] = await Promise.all([
      this.prisma.productDemandDaily.aggregate({
        where: { productId, day: { gte: midpoint } },
        _sum: { views: true },
      }),
      this.prisma.productDemandDaily.aggregate({
        where: { productId, day: { gte: since, lt: midpoint } },
        _sum: { views: true },
      }),
    ]);

    const attributes = (product.attributes ?? {}) as Record<string, unknown>;
    const text = [
      product.title,
      product.description,
      ...Object.values(attributes).filter(
        (v): v is string => typeof v === 'string',
      ),
    ].join(' ');
    const slots = detectSlots(text);

    return {
      productId: product.id,
      title: product.title,
      categoryId: product.categoryId,
      slot: slots.length ? slots[0] : null,
      colours: detectColours(text),
      occasions: occasionsOf(text),
      modesty: 'UNSPECIFIED' as ProductFacts['modesty'],
      priceSyp: product.minPriceSyp ? Number(product.minPriceSyp) : null,
      sellerIds: product.offers.map((o) => o.sellerId),
      stockUnits: product.offers.reduce((t, o) => t + o.stock, 0),
      recentViews: recent._sum.views ?? 0,
      previousViews: previous._sum.views ?? 0,
    };
  }

  /**
   * The best cheaper equivalent, if there is one.
   *
   * Read straight from the affinity table — the judgement about what counts as
   * a substitute was already made by the kernel when the graph was built, and
   * remaking it here would be a second opinion nobody asked for.
   */
  private async betterValue(productId: string) {
    const row = await this.prisma.productAffinity.findFirst({
      where: { productId, kind: AffinityKind.SUBSTITUTE },
      orderBy: { score: 'desc' },
      include: { related: { select: { id: true, title: true, status: true } } },
    });
    if (!row || row.related.status !== 'ACTIVE') return null;

    const basis = (row.basis ?? {}) as Record<string, unknown>;
    return {
      productId: row.related.id,
      title: row.related.title,
      savingBps:
        typeof basis['savingBps'] === 'number' ? basis['savingBps'] : 0,
      score: row.score,
    };
  }

  /**
   * Which of her own pieces this product relates to, and how.
   *
   * One method for both questions because they differ only in which affinity
   * kinds they read — `complement` answers "does this go with what she owns",
   * `similar` answers "has she already got one of these". Two nearly identical
   * methods would drift the first time one of them gained a filter.
   *
   * Only catalogue-linked closet items can be reached this way: a garment she
   * typed in herself has no product id and so no row in the affinity table.
   * That is the reason the colour test in the kernel still exists.
   */
  private async relatedToHers(
    productId: string,
    owns: readonly OwnedPiece[],
    relation: 'complement' | 'similar',
  ): Promise<OwnedPiece[]> {
    if (!owns.length) return [];

    const items = await this.prisma.closetItem.findMany({
      where: {
        id: { in: owns.map((piece) => piece.itemId) },
        productId: { not: null },
      },
      select: { id: true, productId: true },
    });
    const byProduct = new Map(
      items
        .filter((i): i is typeof i & { productId: string } => !!i.productId)
        .map((i) => [i.productId, i.id]),
    );
    if (!byProduct.size) return [];

    const kinds =
      relation === 'complement'
        ? [AffinityKind.COMPLEMENT, AffinityKind.BOUGHT_TOGETHER]
        : [AffinityKind.SIMILAR];

    const rows = await this.prisma.productAffinity.findMany({
      where: {
        productId,
        kind: { in: kinds },
        relatedId: { in: [...byProduct.keys()] },
      },
      orderBy: { score: 'desc' },
      take: 4,
      select: { relatedId: true },
    });

    const wanted = new Set(
      rows
        .map((row) => byProduct.get(row.relatedId))
        .filter((id): id is string => !!id),
    );
    return owns.filter((piece) => wanted.has(piece.itemId));
  }
}

function utcDay(date: Date): Date {
  return new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()),
  );
}

/** The dominant occasion, as a list so the kernel's shape stays uniform. */
function occasionsOf(text: string): string[] {
  const occasion = detectOccasion(text);
  return occasion ? [occasion] : [];
}

export type { Verdict };
