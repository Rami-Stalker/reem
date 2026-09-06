import { Injectable } from '@nestjs/common';
import {
  AffinityKind,
  GraphEdge,
  GraphNode,
  OfferStatus,
  ProductStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Reading the graph.
 *
 * The only part of this module other features are meant to touch. Writing the
 * graph is the projectors' business; everything else asks questions.
 *
 * Every method here is a question somebody actually has:
 *   - what is like this?            → the product page's rail
 *   - what goes with this?          → the outfit rail, the closet
 *   - who would want this?          → the seller's audience
 *   - what does she lean towards?   → personalised ranking
 */
@Injectable()
export class GraphQueryService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Products genuinely like this one.
   *
   * Replaces "same category ordered by rating", which was what `similar` meant
   * before the graph existed. Falls back to nothing rather than to the old
   * behaviour: an empty rail is honest, and a rail of unrelated products
   * teaches shoppers to ignore rails.
   */
  async similar(productId: string, limit = 10): Promise<string[]> {
    return this.related(productId, AffinityKind.SIMILAR, limit);
  }

  /** Products worn or used with this one. */
  async complements(productId: string, limit = 10): Promise<string[]> {
    const [complements, bought] = await Promise.all([
      this.related(productId, AffinityKind.COMPLEMENT, limit),
      this.related(productId, AffinityKind.BOUGHT_TOGETHER, limit),
    ]);
    // Observed togetherness first: it is a fact, and the inferred complements
    // are a judgement.
    return unique([...bought, ...complements]).slice(0, limit);
  }

  /** Cheaper near-equivalents, best value first. */
  async substitutes(productId: string, limit = 5): Promise<string[]> {
    return this.related(productId, AffinityKind.SUBSTITUTE, limit);
  }

  private async related(
    productId: string,
    kind: AffinityKind,
    limit: number,
  ): Promise<string[]> {
    const rows = await this.prisma.productAffinity.findMany({
      where: {
        productId,
        kind,
        // Only things she could actually buy. A rail of delisted products is
        // worse than an empty one.
        related: {
          status: ProductStatus.ACTIVE,
          offers: { some: { status: OfferStatus.ACTIVE } },
        },
      },
      orderBy: { score: 'desc' },
      take: limit,
      select: { relatedId: true },
    });
    return rows.map((row) => row.relatedId);
  }

  /**
   * What she leans towards, as weights a ranker can use.
   *
   * Categories and sellers only — the two axes a catalogue query can actually
   * be biased by. Returned as plain maps so the caller does not have to know
   * what an edge is.
   */
  async affinities(userId: string): Promise<{
    categories: Map<string, number>;
    sellers: Map<string, number>;
    /** Slots a gap or an open decision says she is short of. */
    needsSlots: string[];
  }> {
    const edges = await this.prisma.commerceEdge.findMany({
      where: {
        subjectType: GraphNode.USER,
        subjectId: userId,
        kind: {
          in: [
            GraphEdge.OWNS,
            GraphEdge.PURCHASED,
            GraphEdge.SAVED,
            GraphEdge.CONSIDERED,
            GraphEdge.BUYS_FROM,
            GraphEdge.NEEDS,
          ],
        },
      },
      orderBy: { weight: 'desc' },
      take: 300,
    });

    const productIds = edges
      .filter((e) => e.objectType === GraphNode.PRODUCT)
      .map((e) => e.objectId);

    const categoryOf = new Map<string, string>();
    if (productIds.length) {
      const products = await this.prisma.product.findMany({
        where: { id: { in: productIds } },
        select: { id: true, categoryId: true },
      });
      for (const product of products) categoryOf.set(product.id, product.categoryId);
    }

    const categories = new Map<string, number>();
    const sellers = new Map<string, number>();
    const needsSlots: string[] = [];

    for (const edge of edges) {
      if (edge.objectType === GraphNode.PRODUCT) {
        const categoryId = categoryOf.get(edge.objectId);
        if (categoryId) {
          categories.set(
            categoryId,
            (categories.get(categoryId) ?? 0) + edge.weight,
          );
        }
      } else if (edge.objectType === GraphNode.SELLER) {
        sellers.set(edge.objectId, (sellers.get(edge.objectId) ?? 0) + edge.weight);
      } else if (edge.kind === GraphEdge.NEEDS) {
        const evidence = (edge.evidence ?? {}) as Record<string, unknown>;
        if (typeof evidence['slot'] === 'string') needsSlots.push(evidence['slot']);
      }
    }

    return { categories, sellers, needsSlots };
  }

  /**
   * Who would want this product — the seller's question, answered from the
   * demand side rather than from a guess.
   *
   * Returns counts, never identities. A seller learning *which women* looked
   * at her dress is a privacy failure; learning that eleven shoppers who own
   * navy dresses have an open gap for shoes is a business insight. The
   * distinction is the reason this returns aggregates only.
   */
  async audienceFor(
    productId: string,
  ): Promise<{
    interested: number;
    owners: number;
    considering: number;
    /** Categories those shoppers also engage with, strongest first. */
    alsoInterestedIn: Array<{ categoryId: string; shoppers: number }>;
  }> {
    const edges = await this.prisma.commerceEdge.findMany({
      where: {
        objectType: GraphNode.PRODUCT,
        objectId: productId,
        kind: {
          in: [
            GraphEdge.SAVED,
            GraphEdge.CONSIDERED,
            GraphEdge.PURCHASED,
            GraphEdge.OWNS,
          ],
        },
      },
      select: { subjectId: true, kind: true },
    });

    const shoppers = [...new Set(edges.map((e) => e.subjectId))];
    const owners = edges.filter((e) => e.kind === GraphEdge.OWNS).length;
    const considering = edges.filter(
      (e) => e.kind === GraphEdge.CONSIDERED || e.kind === GraphEdge.SAVED,
    ).length;

    if (!shoppers.length) {
      return { interested: 0, owners, considering, alsoInterestedIn: [] };
    }

    // What else those same shoppers engage with. One query, grouped in the
    // database, and k-anonymised below.
    const rows = await this.prisma.$queryRaw<
      Array<{ category_id: string; shoppers: bigint }>
    >`
      SELECT p.category_id::text AS category_id,
             count(DISTINCT e.subject_id)::bigint AS shoppers
      FROM commerce_edges e
      JOIN products p ON p.id = e.object_id
      WHERE e.subject_type = 'USER'
        AND e.object_type = 'PRODUCT'
        AND e.subject_id = ANY(${shoppers}::uuid[])
        AND e.object_id <> ${productId}::uuid
      GROUP BY p.category_id
      ORDER BY shoppers DESC
      LIMIT 8
    `;

    return {
      interested: shoppers.length,
      owners,
      considering,
      // Fewer than three shoppers is a person, not a segment — the same
      // k-anonymity floor the trend engine applies to its own counts.
      alsoInterestedIn: rows
        .filter((row) => Number(row.shoppers) >= 3)
        .map((row) => ({
          categoryId: row.category_id,
          shoppers: Number(row.shoppers),
        })),
    };
  }

  /**
   * What sells alongside a seller's own products — the bundle question.
   *
   * Restricted to her own catalogue, because a bundle she cannot assemble is
   * not an opportunity.
   */
  async bundleOpportunities(
    sellerId: string,
    limit = 8,
  ): Promise<
    Array<{ productId: string; relatedId: string; score: number; coOccurrences: number }>
  > {
    const rows = await this.prisma.productAffinity.findMany({
      where: {
        kind: { in: [AffinityKind.BOUGHT_TOGETHER, AffinityKind.COMPLEMENT] },
        product: { offers: { some: { sellerId, status: OfferStatus.ACTIVE } } },
        related: {
          offers: { some: { sellerId, status: OfferStatus.ACTIVE } },
          status: ProductStatus.ACTIVE,
        },
      },
      orderBy: { score: 'desc' },
      take: limit * 2,
      select: { productId: true, relatedId: true, score: true, basis: true },
    });

    // A pair appears in both directions; keep one.
    const seen = new Set<string>();
    const out: Array<{
      productId: string;
      relatedId: string;
      score: number;
      coOccurrences: number;
    }> = [];

    for (const row of rows) {
      const key = [row.productId, row.relatedId].sort().join('|');
      if (seen.has(key)) continue;
      seen.add(key);
      const basis = (row.basis ?? {}) as Record<string, unknown>;
      out.push({
        productId: row.productId,
        relatedId: row.relatedId,
        score: row.score,
        coOccurrences:
          typeof basis['coOccurrences'] === 'number'
            ? basis['coOccurrences']
            : 0,
      });
      if (out.length >= limit) break;
    }

    return out;
  }
}

function unique(ids: string[]): string[] {
  return [...new Set(ids)];
}
