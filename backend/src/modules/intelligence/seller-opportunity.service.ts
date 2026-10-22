import { Injectable } from '@nestjs/common';
import { PrismaService } from '../../prisma/prisma.service';
import { GraphQueryService } from '../graph/graph-query.service';

/**
 * The graph, read from the seller's side.
 *
 * Phase two told her how her shop is doing. This tells her who is out there:
 * who would want a given product, what her catalogue sells alongside itself,
 * and which of her listings sit next to demand she is not serving.
 *
 * ── The rule that shapes every method here ───────────────────────────────
 *
 * **Counts, never identities.** A seller learning that eleven shoppers who own
 * navy dresses are short of shoes is a business insight; a seller learning
 * *which women* is a privacy failure, and the difference between the two is
 * one careless `select`. Every query below aggregates in the database and the
 * small groups are dropped, the same k-anonymity floor the trend engine holds
 * itself to.
 */
@Injectable()
export class SellerOpportunityService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly graph: GraphQueryService,
  ) {}

  /**
   * Who would want this listing, and what else they care about.
   *
   * Scoped to a product she actually sells — the same rule as the rest of the
   * seller console, enforced by the query rather than by a check somebody
   * could forget.
   */
  async audience(sellerId: string, productId: string) {
    const owned = await this.prisma.product.findFirst({
      where: { id: productId, offers: { some: { sellerId } } },
      select: { id: true, title: true },
    });
    if (!owned) return null;

    const audience = await this.graph.audienceFor(productId);
    const categoryIds = audience.alsoInterestedIn.map((r) => r.categoryId);
    const categories = categoryIds.length
      ? await this.prisma.category.findMany({
          where: { id: { in: categoryIds } },
          select: { id: true, nameAr: true, nameEn: true },
        })
      : [];
    const nameOf = new Map(
      categories.map((c) => [c.id, c.nameAr || c.nameEn]),
    );

    return {
      productId: owned.id,
      title: owned.title,
      interested: audience.interested,
      owners: audience.owners,
      considering: audience.considering,
      alsoInterestedIn: audience.alsoInterestedIn.map((row) => ({
        categoryId: row.categoryId,
        name: nameOf.get(row.categoryId) ?? '',
        shoppers: row.shoppers,
      })),
      ar: sentenceFor(audience.interested, audience.considering),
    };
  }

  /**
   * Pairs from her own catalogue that already sell together.
   *
   * The bundle question, answered from observation. A suggestion to sell two
   * things together is only worth making when somebody has already bought them
   * together — anything else is a guess dressed as a recommendation.
   */
  async bundles(sellerId: string, limit = 6) {
    const pairs = await this.graph.bundleOpportunities(sellerId, limit);
    if (!pairs.length) return [];

    const ids = [...new Set(pairs.flatMap((p) => [p.productId, p.relatedId]))];
    const products = await this.prisma.product.findMany({
      where: { id: { in: ids } },
      select: { id: true, title: true, media: { take: 1, select: { url: true } } },
    });
    const byId = new Map(products.map((p) => [p.id, p]));

    return pairs
      .map((pair) => {
        const left = byId.get(pair.productId);
        const right = byId.get(pair.relatedId);
        if (!left || !right) return null;
        return {
          product: {
            id: left.id,
            title: left.title,
            imageUrl: left.media[0]?.url ?? null,
          },
          related: {
            id: right.id,
            title: right.title,
            imageUrl: right.media[0]?.url ?? null,
          },
          score: pair.score,
          coOccurrences: pair.coOccurrences,
          ar: pair.coOccurrences > 0
            ? `«${left.title}» و«${right.title}» اشتُريا معاً ${pair.coOccurrences} مرات — جرّبي عرضهما معاً.`
            : `«${left.title}» و«${right.title}» يكمل أحدهما الآخر — يمكنكِ عرضهما معاً.`,
        };
      })
      .filter((row): row is NonNullable<typeof row> => row !== null);
  }

  /**
   * Demand sitting next to her catalogue that she is not serving.
   *
   * The join phase two could not make: her categories against the slots
   * shoppers have open gaps for. `NEEDS` edges are the most actionable thing
   * in the graph — they are not "people looked at dresses", they are "people
   * have a dress-shaped hole in a saved outfit".
   */
  async unservedNeeds(sellerId: string, limit = 6) {
    const rows = await this.prisma.$queryRaw<
      Array<{ slot: string; shoppers: bigint; hers: bigint }>
    >`
      WITH needs AS (
        SELECT e.evidence->>'slot' AS slot,
               count(DISTINCT e.subject_id)::bigint AS shoppers
        FROM commerce_edges e
        WHERE e.subject_type = 'USER'
          AND e.kind = 'NEEDS'
          AND e.evidence->>'slot' IS NOT NULL
        GROUP BY 1
      ),
      -- How much of that slot she already lists, so the answer is about the
      -- gap rather than about the demand.
      hers AS (
        SELECT needs.slot, count(DISTINCT p.id)::bigint AS hers
        FROM needs
        LEFT JOIN products p
          ON p.status = 'ACTIVE'
         AND EXISTS (
           SELECT 1 FROM seller_offers o
           WHERE o.product_id = p.id AND o.seller_id = ${sellerId}::uuid
             AND o.status = 'ACTIVE'
         )
         AND upper(p.title) LIKE '%' || needs.slot || '%'
        GROUP BY needs.slot
      )
      SELECT needs.slot, needs.shoppers, coalesce(hers.hers, 0) AS hers
      FROM needs
      LEFT JOIN hers ON hers.slot = needs.slot
      WHERE needs.shoppers >= 3
      ORDER BY needs.shoppers DESC
      LIMIT ${limit}
    `;

    return rows.map((row) => ({
      slot: row.slot,
      shoppers: Number(row.shoppers),
      herListings: Number(row.hers),
      ar: `${Number(row.shoppers)} امرأة ينقصهن «${slotLabel(row.slot)}» لإكمال إطلالة.`,
    }));
  }
}

/**
 * Arabic for the audience line.
 *
 * Silent below the k-anonymity floor: "one shopper is considering this" is
 * both useless and a step towards identifying her.
 */
function sentenceFor(interested: number, considering: number): string | null {
  if (interested < 3) return null;
  if (considering >= 3) {
    return `${interested} امرأة مهتمّات به، و${considering} منهن وضعنه في غرفة أو في محفوظاتهن.`;
  }
  return `${interested} امرأة مهتمّات به.`;
}

/** The wardrobe slots, in the words the rest of the app uses. */
function slotLabel(slot: string): string {
  const labels: Record<string, string> = {
    DRESS: 'فستان',
    ABAYA: 'عباية',
    TOP: 'قطعة علوية',
    BOTTOM: 'قطعة سفلية',
    OUTERWEAR: 'قطعة خارجية',
    SHOES: 'حذاء',
    BAG: 'حقيبة',
    JEWELRY: 'مجوهرات',
    ACCESSORY: 'إكسسوار',
    PERFUME: 'عطر',
    BEAUTY: 'منتج تجميل',
    GIFT: 'هدية',
  };
  return labels[slot] ?? slot;
}
