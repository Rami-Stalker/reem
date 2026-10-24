import { Injectable } from '@nestjs/common';
import { DuplicateVerdict, ProductStatus } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * How alike two titles must read before a person is asked to look.
 *
 * Titles are compared whole, unlike a search query — both sides are a full
 * name for a garment, so the dilution that made `similarity` wrong for
 * querying is exactly what is wanted here: «فستان سهرة أحمر» and «فستان سهرة
 * احمر» score high, «فستان سهرة أحمر» and «فستان صيفي قصير» do not.
 *
 * 0.62 was chosen against the seeded catalogue: below about 0.5 the queue
 * fills with pieces that merely share a category word, and above about 0.75 it
 * misses the pairs that differ by a colour or a size in the title — which is
 * the commonest way one garment gets listed twice.
 */
const DEFAULT_THRESHOLD = 0.62;

/** A pair worth a person's attention, with what they need to judge it. */
export interface DuplicateCandidate {
  score: number;
  sharesSeller: boolean;
  left: DuplicateSide;
  right: DuplicateSide;
}

interface DuplicateSide {
  id: string;
  title: string;
  slug: string;
  categoryId: string;
  offersCount: number;
  createdAt: Date;
}

interface CandidateRow {
  score: number;
  shares_seller: boolean;
  left_id: string;
  left_title: string;
  left_slug: string;
  left_category: string;
  left_offers: number;
  left_created: Date;
  right_id: string;
  right_title: string;
  right_slug: string;
  right_category: string;
  right_offers: number;
  right_created: Date;
}

/**
 * Finds canonical products that look like the same garment listed twice.
 *
 * Ohara's catalogue separates the product from the seller's offer on purpose:
 * one `Product` row, many `SellerOffer` rows, so five boutiques selling the
 * same dress compete on one page. That design only holds while they are all
 * attached to the *same* product row. When a second row is created for a
 * garment that already exists, the offers split across two pages, neither
 * looks well stocked, the comparison the design exists to provide never
 * happens, and the reviews are counted twice over. Nothing detected that.
 *
 * Detection is a query rather than a stored table, because similarity is a
 * property of the catalogue as it stands and a title edited this morning
 * should change the answer this morning. What is stored is the *verdict*: a
 * pair a merchandiser has ruled on never comes back, which is the difference
 * between a queue that gets worked and a report that gets ignored.
 */
@Injectable()
export class CatalogDuplicatesService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * Pairs awaiting a decision, closest first.
   *
   * Restricted to products in the same category. Two garments filed under
   * different categories are not the same garment — and without that
   * restriction this is a cross join over the whole catalogue, which is not a
   * query anybody should be able to run from a console.
   */
  async candidates(options: {
    categoryId?: string;
    threshold?: number;
    limit: number;
    skip: number;
  }): Promise<DuplicateCandidate[]> {
    const threshold = this.clampThreshold(options.threshold);

    const rows = await this.prisma.$queryRawUnsafe<CandidateRow[]>(
      `
      SELECT similarity(reem_search_key(a.title), reem_search_key(b.title))::float8 AS score,
             EXISTS (
               SELECT 1
               FROM seller_offers oa
               JOIN seller_offers ob ON ob.seller_id = oa.seller_id
               WHERE oa.product_id = a.id AND ob.product_id = b.id
             ) AS shares_seller,
             a.id AS left_id,  a.title AS left_title,  a.slug AS left_slug,
             a.category_id AS left_category, a.offers_count AS left_offers,
             a.created_at AS left_created,
             b.id AS right_id, b.title AS right_title, b.slug AS right_slug,
             b.category_id AS right_category, b.offers_count AS right_offers,
             b.created_at AS right_created
      FROM products a
      JOIN products b
        ON b.category_id = a.category_id
       -- Each pair once, in the same order the verdict is stored in, so the
       -- lookup below is a plain equality rather than a two-way test.
       AND b.id > a.id
      WHERE a.status = $1::"ProductStatus"
        AND b.status = $1::"ProductStatus"
        AND ($2::uuid IS NULL OR a.category_id = $2::uuid)
        -- The indexable prefilter, then the real threshold.
        AND reem_search_key(a.title) % reem_search_key(b.title)
        AND similarity(reem_search_key(a.title), reem_search_key(b.title)) >= $3
        AND NOT EXISTS (
          SELECT 1 FROM product_duplicate_verdicts v
          WHERE v.left_product_id = a.id AND v.right_product_id = b.id
        )
      ORDER BY score DESC, a.created_at ASC
      LIMIT $4 OFFSET $5
      `,
      ProductStatus.ACTIVE,
      options.categoryId ?? null,
      threshold,
      options.limit,
      options.skip,
    );

    return rows.map((row) => ({
      score: row.score,
      sharesSeller: row.shares_seller,
      left: {
        id: row.left_id,
        title: row.left_title,
        slug: row.left_slug,
        categoryId: row.left_category,
        offersCount: row.left_offers,
        createdAt: row.left_created,
      },
      right: {
        id: row.right_id,
        title: row.right_title,
        slug: row.right_slug,
        categoryId: row.right_category,
        offersCount: row.right_offers,
        createdAt: row.right_created,
      },
    }));
  }

  /**
   * Records what a merchandiser decided about one pair.
   *
   * The two ids are sorted before they are written, so the same pair submitted
   * from either direction lands on the same row and the unique key does its
   * job. `DISTINCT` is as valuable a verdict as `DUPLICATE`: it is the only
   * thing that stops two genuinely different dresses with similar names being
   * offered up again tomorrow.
   */
  async record(input: {
    productIdA: string;
    productIdB: string;
    verdict: DuplicateVerdict;
    note?: string | null;
    decidedById: string;
  }) {
    const [leftProductId, rightProductId] = [
      input.productIdA,
      input.productIdB,
    ].sort();

    const data = {
      verdict: input.verdict,
      note: input.note ?? null,
      decidedById: input.decidedById,
      decidedAt: new Date(),
    };

    const verdict = await this.prisma.productDuplicateVerdict.upsert({
      where: { leftProductId_rightProductId: { leftProductId, rightProductId } },
      create: { leftProductId, rightProductId, ...data },
      update: data,
    });

    return this.serialize(verdict);
  }

  /** What has already been decided, newest first. */
  async decided(options: { limit: number; skip: number }) {
    const [rows, total] = await Promise.all([
      this.prisma.productDuplicateVerdict.findMany({
        orderBy: { decidedAt: 'desc' },
        take: options.limit,
        skip: options.skip,
        include: {
          leftProduct: { select: { id: true, title: true, slug: true } },
          rightProduct: { select: { id: true, title: true, slug: true } },
          decidedBy: { select: { id: true, name: true } },
        },
      }),
      this.prisma.productDuplicateVerdict.count(),
    ]);
    return { rows, total };
  }

  /** Reopens a pair — the decision was wrong, or the titles have changed. */
  async clear(productIdA: string, productIdB: string) {
    const [leftProductId, rightProductId] = [productIdA, productIdB].sort();
    await this.prisma.productDuplicateVerdict.deleteMany({
      where: { leftProductId, rightProductId },
    });
    return { message: 'Pair returned to the queue' };
  }

  private serialize(verdict: {
    id: string;
    leftProductId: string;
    rightProductId: string;
    verdict: DuplicateVerdict;
    note: string | null;
    decidedAt: Date;
  }) {
    return {
      id: verdict.id,
      left_product_id: verdict.leftProductId,
      right_product_id: verdict.rightProductId,
      verdict: verdict.verdict.toLowerCase(),
      note: verdict.note,
      decided_at: verdict.decidedAt.toISOString(),
    };
  }

  /**
   * A threshold outside (0, 1] is not a preference, it is a mistake — and a
   * zero would return the cross product of the category.
   */
  private clampThreshold(value?: number): number {
    if (value === undefined || Number.isNaN(value)) return DEFAULT_THRESHOLD;
    return Math.min(1, Math.max(0.3, value));
  }
}
