import { Injectable, Logger } from '@nestjs/common';
import { AffinityKind, OfferStatus, Prisma, ProductStatus } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import {
  detectColours,
  detectMaterials,
  detectOccasion,
  detectSlots,
} from '../../ai-stylist/understanding/stylist-lexicon';
import {
  AFFINITY_FANOUT,
  AFFINITY_FLOOR,
  CO_OCCURRENCE_MIN,
  SUBSTITUTE_MAX_RATING_DROP,
  SUBSTITUTE_MAX_SAVING_BPS,
  SUBSTITUTE_MIN_SAVING_BPS,
  SUBSTITUTE_MIN_SIMILARITY,
} from '../graph.constants';
import {
  AffinityFacts,
  complementScore,
  similarityScore,
  substituteScore,
} from '../kernel/graph-math';

/**
 * Working out how products relate to each other.
 *
 * This is the relationship the catalogue never had. `discovery.similar()` used
 * to mean "same category, ordered by rating", which is not similarity — it put
 * a child's raincoat next to an evening gown and called them alternatives.
 *
 * ── Where the facts come from ────────────────────────────────────────────
 *
 * The stylist lexicon, which already reads colours, materials and slots out of
 * Arabic titles and attributes for the closet and the stylist. Reusing it is
 * the point: one vocabulary means a dress the closet calls navy is the dress
 * the affinity builder calls navy, and the two can never disagree about the
 * same garment.
 *
 * ── What is inferred and what is observed ────────────────────────────────
 *
 * Similarity and substitution are *inferred* from attributes. Complements are
 * inferred too, but weighted heavily by something *observed*: how often two
 * products actually ended up in the same order, the same closet or the same
 * room. That co-occurrence is the only part of this file that is a fact rather
 * than a judgement, so it carries the most.
 */
@Injectable()
export class AffinityBuilderService {
  private readonly logger = new Logger(AffinityBuilderService.name);

  constructor(private readonly prisma: PrismaService) {}

  /**
   * Rebuild affinities for a whole category.
   *
   * Category at a time because that is the unit similarity is defined within —
   * comparing every product to every other product in the catalogue would be
   * quadratic over tens of thousands of rows to answer a question whose first
   * gate is "same category".
   */
  async buildCategory(categoryId: string): Promise<number> {
    const facts = await this.factsForCategory(categoryId);
    if (facts.length < 2) return 0;

    const coPurchase = await this.coOccurrence(facts.map((f) => f.productId));
    const rows: Array<{
      productId: string;
      relatedId: string;
      kind: AffinityKind;
      score: number;
      basis: Prisma.InputJsonValue;
    }> = [];

    for (const product of facts) {
      const similar: typeof rows = [];
      const substitutes: typeof rows = [];

      for (const other of facts) {
        if (other.productId === product.productId) continue;

        const sim = similarityScore(product, other);
        if (sim >= AFFINITY_FLOOR) {
          similar.push({
            productId: product.productId,
            relatedId: other.productId,
            kind: AffinityKind.SIMILAR,
            score: sim,
            basis: {
              sharedColours: product.colours.filter((c) =>
                other.colours.includes(c),
              ),
              sameSlot: product.slot === other.slot,
              priceSyp: other.priceSyp,
            },
          });
        }

        const sub = substituteScore(product, other, {
          minSavingBps: SUBSTITUTE_MIN_SAVING_BPS,
          maxSavingBps: SUBSTITUTE_MAX_SAVING_BPS,
          minSimilarity: SUBSTITUTE_MIN_SIMILARITY,
          maxRatingDrop: SUBSTITUTE_MAX_RATING_DROP,
        });
        if (sub) {
          substitutes.push({
            productId: product.productId,
            relatedId: other.productId,
            kind: AffinityKind.SUBSTITUTE,
            score: sub.score,
            basis: {
              savingBps: sub.savingBps,
              rating: other.rating,
              reviewsCount: other.reviewsCount,
            },
          });
        }

        const co = coPurchase.get(pairKey(product.productId, other.productId)) ?? 0;
        if (co >= CO_OCCURRENCE_MIN) {
          rows.push({
            productId: product.productId,
            relatedId: other.productId,
            kind: AffinityKind.BOUGHT_TOGETHER,
            score: Math.min(100, 50 + co * 10),
            basis: { coOccurrences: co },
          });
        }
      }

      rows.push(...top(similar, AFFINITY_FANOUT));
      rows.push(...top(substitutes, AFFINITY_FANOUT));
    }

    await this.replace(facts.map((f) => f.productId), rows);
    return rows.length;
  }

  /**
   * Complements, which cross categories and so cannot be built one category at
   * a time.
   *
   * Driven by observation rather than by a full cross-product: only pairs that
   * have actually appeared together somewhere are considered, which is both
   * far cheaper and far more honest than scoring every dress against every bag
   * in the catalogue.
   */
  async buildComplements(): Promise<number> {
    const pairs = await this.coOccurrenceAll();

    // Observation alone is not enough to build an outfit from.
    //
    // Gating candidates on co-occurrence meant nothing was ever *considered*
    // unless it had already been bought together — so on a young catalogue,
    // where almost every order is a single line, the complement relation was
    // permanently empty and "goes with what you own" could never fire.
    //
    // The kernel can already reason about complementarity structurally: two
    // pieces that fill different slots, suit the same occasion and do not
    // fight on colour go together whether or not anybody has bought both yet.
    // So candidates come from both sources — what was observed, and what the
    // occasion lexicon says belongs in the same outfit — and `basis` records
    // which, so a rail can say "bought together" only when that is true.
    const structural = await this.structuralPairs();
    for (const key of structural) {
      if (!pairs.has(key)) pairs.set(key, 0);
    }
    if (!pairs.size) return 0;

    const ids = new Set<string>();
    for (const key of pairs.keys()) {
      const [a, b] = key.split('|');
      ids.add(a);
      ids.add(b);
    }

    const facts = new Map(
      (await this.factsForIds([...ids])).map((f) => [f.productId, f]),
    );

    const rows: Array<{
      productId: string;
      relatedId: string;
      kind: AffinityKind;
      score: number;
      basis: Prisma.InputJsonValue;
    }> = [];

    for (const [key, count] of pairs) {
      const [a, b] = key.split('|');
      const left = facts.get(a);
      const right = facts.get(b);
      if (!left || !right) continue;

      const score = complementScore(left, right, count);
      if (score < AFFINITY_FLOOR) continue;

      // Both directions: a bag complements a dress and the dress complements
      // the bag. Unlike substitution, this relation really is symmetric.
      const basis = {
        coOccurrences: count,
        // The honest label: `observed` means somebody actually put these two
        // together, `inferred` means the lexicon thinks they belong in the
        // same outfit. A screen must not say "bought together" about the
        // second kind.
        source: count > 0 ? 'observed' : 'inferred',
        slots: [left.slot, right.slot],
        occasions: left.occasions.filter((o) => right.occasions.includes(o)),
      };
      rows.push({
        productId: a,
        relatedId: b,
        kind: AffinityKind.COMPLEMENT,
        score,
        basis,
      });
      rows.push({
        productId: b,
        relatedId: a,
        kind: AffinityKind.COMPLEMENT,
        score,
        basis,
      });
    }

    for (const row of rows) {
      await this.prisma.productAffinity.upsert({
        where: {
          productId_relatedId_kind: {
            productId: row.productId,
            relatedId: row.relatedId,
            kind: row.kind,
          },
        },
        create: row,
        update: { score: row.score, basis: row.basis, computedAt: new Date() },
      });
    }

    // Drop the complements this run did not produce.
    //
    // Upserting alone leaves a relation standing after it stops being true —
    // which is exactly what happened the first time the slot-exclusivity rule
    // landed: the dress-and-abaya pairs it was written to prevent survived the
    // fix, because nothing ever deleted them. The category build already
    // replaces wholesale for this reason; complements have to as well.
    const keep = new Set(rows.map((r) => `${r.productId}|${r.relatedId}`));
    const existing = await this.prisma.productAffinity.findMany({
      where: { kind: AffinityKind.COMPLEMENT },
      select: { id: true, productId: true, relatedId: true },
    });
    const stale = existing
      .filter((row) => !keep.has(`${row.productId}|${row.relatedId}`))
      .map((row) => row.id);
    if (stale.length) {
      await this.prisma.productAffinity.deleteMany({
        where: { id: { in: stale } },
      });
    }

    return rows.length;
  }

  /** Every category with live products. */
  async buildAll(): Promise<{ categories: number; edges: number }> {
    const categories = await this.prisma.category.findMany({
      where: { products: { some: { status: ProductStatus.ACTIVE } } },
      select: { id: true },
    });

    let edges = 0;
    for (const category of categories) {
      try {
        edges += await this.buildCategory(category.id);
      } catch (error) {
        this.logger.warn(
          `Affinity build failed for category ${category.id}: ${String(error)}`,
        );
      }
    }
    edges += await this.buildComplements();

    this.logger.log(
      `Product affinities: ${categories.length} categories, ${edges} edges`,
    );
    return { categories: categories.length, edges };
  }

  // ── Facts ──────────────────────────────────────────────────────────────

  private async factsForCategory(categoryId: string): Promise<AffinityFacts[]> {
    const products = await this.prisma.product.findMany({
      where: {
        categoryId,
        status: ProductStatus.ACTIVE,
        offers: { some: { status: OfferStatus.ACTIVE } },
      },
      select: PRODUCT_FACT_SELECT,
      take: 400,
    });
    return products.map(toFacts);
  }

  private async factsForIds(ids: string[]): Promise<AffinityFacts[]> {
    const products = await this.prisma.product.findMany({
      where: { id: { in: ids } },
      select: PRODUCT_FACT_SELECT,
    });
    return products.map(toFacts);
  }

  /**
   * How often two products ended up together, among a given set.
   *
   * Three sources, all of them real togetherness: the same order, the same
   * closet, the same room. A pair that has never co-occurred simply is not in
   * the map, which is what keeps the complement build cheap.
   */
  private async coOccurrence(
    productIds: string[],
  ): Promise<Map<string, number>> {
    if (productIds.length < 2) return new Map();
    const rows = await this.prisma.$queryRaw<
      Array<{ a: string; b: string; n: bigint }>
    >`
      SELECT LEAST(x.product_id, y.product_id)::text AS a,
             GREATEST(x.product_id, y.product_id)::text AS b,
             count(*)::bigint AS n
      FROM order_items x
      JOIN order_items y
        ON y.seller_order_id = x.seller_order_id
       AND y.product_id > x.product_id
      WHERE x.product_id = ANY(${productIds}::uuid[])
        AND y.product_id = ANY(${productIds}::uuid[])
      GROUP BY 1, 2
    `;
    return new Map(rows.map((r) => [`${r.a}|${r.b}`, Number(r.n)]));
  }

  /**
   * Every pair that has co-occurred anywhere, across the whole platform.
   *
   * Bounded by the `HAVING` rather than by a limit, so what comes back is
   * every pair with enough evidence to be worth a row and nothing else.
   */
  private async coOccurrenceAll(): Promise<Map<string, number>> {
    const rows = await this.prisma.$queryRaw<
      Array<{ a: string; b: string; n: bigint }>
    >`
      WITH pairs AS (
        -- Bought in the same parcel.
        SELECT LEAST(x.product_id, y.product_id) AS a,
               GREATEST(x.product_id, y.product_id) AS b
        FROM order_items x
        JOIN order_items y
          ON y.seller_order_id = x.seller_order_id
         AND y.product_id > x.product_id
        WHERE x.product_id IS NOT NULL AND y.product_id IS NOT NULL

        UNION ALL

        -- Hanging in the same wardrobe.
        SELECT LEAST(x.product_id, y.product_id),
               GREATEST(x.product_id, y.product_id)
        FROM closet_items x
        JOIN closet_items y
          ON y.closet_id = x.closet_id AND y.product_id > x.product_id
        WHERE x.product_id IS NOT NULL AND y.product_id IS NOT NULL

        UNION ALL

        -- Weighed in the same room.
        SELECT LEAST(x.product_id, y.product_id),
               GREATEST(x.product_id, y.product_id)
        FROM room_candidates x
        JOIN room_decisions dx ON dx.id = x.decision_id
        JOIN room_decisions dy ON dy.room_id = dx.room_id
        JOIN room_candidates y
          ON y.decision_id = dy.id AND y.product_id > x.product_id
        WHERE x.status <> 'REJECTED' AND y.status <> 'REJECTED'
      )
      SELECT a::text, b::text, count(*)::bigint AS n
      FROM pairs
      GROUP BY a, b
      HAVING count(*) >= ${CO_OCCURRENCE_MIN}
    `;
    return new Map(rows.map((r) => [`${r.a}|${r.b}`, Number(r.n)]));
  }

  /**
   * Pairs the occasion lexicon says belong in the same outfit.
   *
   * Bounded rather than a cross-product: products are grouped by occasion and
   * then by slot, and only a handful of the best-rated per slot are paired
   * across slots. A wedding needs a dress, shoes and a bag — that is a dozen
   * pairs per occasion, not a hundred thousand.
   *
   * Only live, purchasable products, because a complement she cannot buy is
   * not a complement.
   */
  private async structuralPairs(perSlot = 6): Promise<Set<string>> {
    const products = await this.prisma.product.findMany({
      where: {
        status: ProductStatus.ACTIVE,
        offers: { some: { status: OfferStatus.ACTIVE } },
      },
      select: PRODUCT_FACT_SELECT,
      orderBy: { rating: 'desc' },
      take: 600,
    });

    // occasion → slot → the best few products in it.
    const byOccasion = new Map<string, Map<string, string[]>>();
    for (const row of products) {
      const facts = toFacts(row);
      if (!facts.slot || !facts.occasions.length) continue;
      for (const occasion of facts.occasions) {
        const slots = byOccasion.get(occasion) ?? new Map<string, string[]>();
        const bucket = slots.get(facts.slot) ?? [];
        if (bucket.length < perSlot) bucket.push(facts.productId);
        slots.set(facts.slot, bucket);
        byOccasion.set(occasion, slots);
      }
    }

    const pairs = new Set<string>();
    for (const slots of byOccasion.values()) {
      const entries = [...slots.entries()];
      for (let i = 0; i < entries.length; i += 1) {
        for (let j = i + 1; j < entries.length; j += 1) {
          for (const a of entries[i][1]) {
            for (const b of entries[j][1]) {
              pairs.add(pairKey(a, b));
            }
          }
        }
      }
    }
    return pairs;
  }

  /**
   * Replace a category's affinities wholesale.
   *
   * Deleting first is what makes a rebuild honest: a product that stopped
   * being similar to another — because its price moved, or its offer went
   * away — must lose the edge, and an upsert-only build would leave it there
   * forever. Complements are excluded from the delete because they are built
   * separately and across categories.
   */
  private async replace(
    productIds: string[],
    rows: Array<{
      productId: string;
      relatedId: string;
      kind: AffinityKind;
      score: number;
      basis: Prisma.InputJsonValue;
    }>,
  ): Promise<void> {
    await this.prisma.productAffinity.deleteMany({
      where: {
        productId: { in: productIds },
        kind: { in: [AffinityKind.SIMILAR, AffinityKind.SUBSTITUTE, AffinityKind.BOUGHT_TOGETHER] },
      },
    });
    if (!rows.length) return;

    // `skipDuplicates` because a pair can be reached twice in one pass when
    // two products are each other's best match.
    await this.prisma.productAffinity.createMany({
      data: rows,
      skipDuplicates: true,
    });
  }
}

const PRODUCT_FACT_SELECT = {
  id: true,
  title: true,
  description: true,
  categoryId: true,
  attributes: true,
  minPriceSyp: true,
  rating: true,
  reviewsCount: true,
} as const;

type ProductFactRow = {
  id: string;
  title: string;
  description: string;
  categoryId: string;
  attributes: Prisma.JsonValue;
  minPriceSyp: Prisma.Decimal | null;
  rating: number;
  reviewsCount: number;
};

/**
 * A catalogue row reduced to the handful of things a comparison needs.
 *
 * Read through the stylist lexicon rather than through a second parser, so the
 * colours here are the same colours the closet and the stylist see.
 */
function toFacts(product: ProductFactRow): AffinityFacts {
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
    categoryId: product.categoryId,
    colours: detectColours(text),
    materials: detectMaterials(text),
    slot: slots.length ? slots[0] : null,
    // One occasion, not a list: the lexicon resolves the *dominant* one, and
    // a garment described for a wedding is not also a work outfit.
    occasions: (() => {
      const occasion = detectOccasion(text);
      return occasion ? [occasion] : [];
    })(),
    priceSyp: product.minPriceSyp ? Number(product.minPriceSyp) : null,
    rating: product.rating,
    reviewsCount: product.reviewsCount,
  };
}

function pairKey(a: string, b: string): string {
  return a < b ? `${a}|${b}` : `${b}|${a}`;
}

function top<T extends { score: number }>(rows: T[], n: number): T[] {
  return rows.sort((a, b) => b.score - a.score).slice(0, n);
}
