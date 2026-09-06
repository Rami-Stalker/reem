import { Inject, Injectable, NotFoundException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { CacheService } from '../../../common/cache/cache.service';
import {
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../../common/catalog/product-include';
import { PrismaService } from '../../../prisma/prisma.service';
import { emptyBrief } from '../../ai-stylist/understanding/style-brief';
import { EmbeddingService } from '../embedding/embedding.service';
import { VisualAttributes } from '../understanding/visual-attributes';
import { VECTOR_INDEX, VectorIndex } from '../vector/vector-index';
import { ScoredVisualMatch, rankVisualMatches } from '../search/visual-ranker';

/**
 * "قطع شبيهة" — visual recommendation, without a photograph.
 *
 * The same machinery as a search by image, with the query vector taken from a
 * product the platform has already indexed instead of from an upload. That is
 * the whole difference, and keeping it that way is the point: the rail under a
 * product page, the "shop this look" strip, and the search-by-image page all
 * rank by the same numbers and can never disagree about which two dresses are
 * alike.
 *
 * ── Where the other two AI features attach ───────────────────────────────
 *
 * This service is the seam, because it is the one that produces visual
 * neighbours without needing a customer to do anything.
 *
 *  - **Reem AI Stylist.** `similarTo` is what "لقيتلك بديل أرخص بنفس الشكل"
 *    needs: hand it the product she liked and a budget ceiling and it returns
 *    the cheaper twin. The stylist's `StyleBrief` is already the filter
 *    parameter here, so no adapter is required.
 *  - **Reem Trend Engine.** `ProductTrendScore` says a product is climbing;
 *    this says which listings look like it. Together they answer the question
 *    a seller actually asks — "شو الشبيه اللي عم يبيع؟" — which neither can
 *    answer alone.
 */
@Injectable()
export class VisualRecommendationService {
  /** Five minutes. A rail on a product page, not a live search. */
  private static readonly TTL_MS = 5 * 60 * 1000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
    private readonly embeddings: EmbeddingService,
    @Inject(VECTOR_INDEX) private readonly index: VectorIndex,
  ) {}

  /**
   * Products that look like this one.
   *
   * Uses the product's primary photograph — the one on its card — because that
   * is the image a shopper is comparing against. Falls back to the next
   * indexed image when the primary was never described (an unreachable URL at
   * index time), and returns an empty list rather than a keyword search when
   * none of them were: an empty visual rail is honest, while a rail labelled
   * "شبيه بصريًا" filled by a text match is not.
   */
  async similarTo(
    productId: string,
    options: {
      limit?: number;
      /** Ceiling in SYP, for the stylist's "same look, less money" case. */
      maxPriceSyp?: number | null;
      /** Keep the search inside the source product's category. */
      sameCategory?: boolean;
    } = {},
  ): Promise<ScoredVisualMatch[]> {
    const limit = Math.min(24, Math.max(1, options.limit ?? 8));
    const key = [
      'visual:similar',
      this.embeddings.name,
      productId,
      limit,
      options.maxPriceSyp ?? '-',
      options.sameCategory ? 'cat' : 'all',
    ].join(':');

    return this.cache.wrap(key, VisualRecommendationService.TTL_MS, async () => {
      const source = await this.prisma.product.findFirst({
        where: { id: productId },
        include: PRODUCT_CARD_INCLUDE,
      });
      if (!source) throw new NotFoundException('PRODUCT_NOT_FOUND');

      const seed = await this.prisma.productImageEmbedding.findFirst({
        where: { productId, embedder: this.embeddings.name },
        orderBy: { position: 'asc' },
      });
      if (!seed || !seed.vector.length) return [];

      const and: Prisma.ProductWhereInput[] = [PURCHASABLE_PRODUCT_WHERE];
      if (options.sameCategory) and.push({ categoryId: source.categoryId });
      if (options.maxPriceSyp) {
        and.push({ minPriceSyp: { lte: new Prisma.Decimal(options.maxPriceSyp) } });
      }

      const matches = await this.index.search(seed.vector, {
        productWhere: { AND: and },
        paletteKeys: seed.paletteKeys,
        candidateLimit: 2500,
        limit: limit * 3,
        minSimilarity: this.embeddings.anchors.floor * 0.92,
        // Itself, obviously — and its own other photographs, which the
        // one-row-per-product rule in the index would otherwise let through as
        // a perfect match against itself.
        excludeProductIds: [productId],
      });
      if (!matches.length) return [];

      const products = await this.prisma.product.findMany({
        where: {
          id: { in: [...new Set(matches.map((match) => match.productId))] },
          ...PURCHASABLE_PRODUCT_WHERE,
        },
        include: PRODUCT_CARD_INCLUDE,
      });

      // The source product's own category is the attribute evidence here: a
      // rail on a dress page that fills with cushions scores badly and
      // deserves to.
      const attributes: VisualAttributes = {
        colours: seed.paletteKeys.map((key) => ({ key, labelAr: key, share: 0 })),
        pattern: (seed.pattern as VisualAttributes['pattern']) ?? 'plain',
        tone: 'mid',
        framing: 'product',
        studioBackground: false,
        subjectFill: 0,
        categories: [{ slug: source.category.slug, label: source.category.nameAr }],
        slots: [],
        provenance: { categories: 'NEIGHBOURS' },
        confidence: 1,
      };

      return rankVisualMatches(
        {
          matches,
          products: new Map(products.map((row) => [row.id, row])),
          attributes,
          brief: {
            ...emptyBrief(),
            budgetMax: options.maxPriceSyp ?? null,
          },
          anchors: this.embeddings.anchors,
          diversity: { perSeller: 2 },
        },
        limit,
      );
    });
  }

  /**
   * Every piece of a look, each with its own neighbours.
   *
   * Reads a finished visual search rather than doing one, so "shop the look"
   * on a saved session costs one query per region and no image processing at
   * all — the regions and their descriptors are already rows.
   */
  async shopTheLook(
    userId: string,
    sessionId: string,
    limit = 6,
  ): Promise<Array<{ regionId: string; label: string; matches: ScoredVisualMatch[] }>> {
    const regions = await this.prisma.visualSearchRegion.findMany({
      where: { sessionId, session: { userId } },
      orderBy: { position: 'asc' },
    });
    if (!regions.length) throw new NotFoundException('VISUAL_SEARCH_NOT_FOUND');

    const out: Array<{ regionId: string; label: string; matches: ScoredVisualMatch[] }> = [];

    for (const region of regions) {
      const results = await this.prisma.visualSearchResult.findMany({
        where: { regionId: region.id },
        orderBy: { position: 'asc' },
        take: limit,
        include: { product: { include: PRODUCT_CARD_INCLUDE } },
      });

      out.push({
        regionId: region.id,
        label: region.label,
        matches: results.map((row) => ({
          match: {
            productId: row.productId,
            mediaUrl: row.matchedMediaUrl ?? '',
            position: row.position,
            similarity: row.similarity,
            parts: {},
            paletteKeys: [],
            pattern: null,
          },
          product: row.product,
          similarity: row.similarity,
          visualScore: row.visualScore,
          attributeScore: row.attributeScore,
          reasons: row.reasonCodes as ScoredVisualMatch['reasons'],
          reason: row.reason,
        })),
      });
    }

    return out;
  }
}
