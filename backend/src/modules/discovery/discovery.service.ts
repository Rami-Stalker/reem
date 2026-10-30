import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import { createHash } from 'node:crypto';
import { Prisma, PromotionPlacement } from '@prisma/client';
import { MAX_SLOTS, PromotionsService } from '../promotions/promotions.service';
import { buildMeta } from '../../common/dto/pagination.dto';
import { CacheService } from '../../common/cache/cache.service';
import { GraphQueryService } from '../graph/graph-query.service';
import { ValueVisibilityService } from '../value/value-visibility.service';
import { serializeProduct } from '../../common/serializers';
import {
  LIVE_OFFER_WHERE,
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
  sellerCardInclude,
} from '../../common/catalog/product-include';
import {
  DiscoveryProduct,
  DiscoveryRepository,
  ProductOrderBy,
} from './discovery.repository';
import {
  HOME_COLLECTION_KEYS,
  isStaticCollection,
  STATIC_COLLECTIONS,
} from './discovery.specs';
import { DiscoveryQueryDto, DiscoverySort } from './dto/discovery-query.dto';

const PREFIX = 'disco:';

interface CachedPage {
  products: DiscoveryProduct[];
  total: number;
}

@Injectable()
export class DiscoveryService {
  private readonly logger = new Logger(DiscoveryService.name);

  constructor(
    private readonly repo: DiscoveryRepository,
    private readonly cache: CacheService,
    private readonly graph: GraphQueryService,
    private readonly visibility: ValueVisibilityService,
    private readonly promotions: PromotionsService,
  ) {}

  async collection(key: string, dto: DiscoveryQueryDto, viewerId?: string) {
    if (!isStaticCollection(key)) {
      throw new BadRequestException(`Unknown collection: ${key}`);
    }
    const spec = STATIC_COLLECTIONS[key];
    const where: Prisma.ProductWhereInput = {
      ...PURCHASABLE_PRODUCT_WHERE,
      ...(spec.extraWhere ?? {}),
      ...this.buildFilters(dto),
    };
    return this.paginated(
      `${PREFIX}col:${key}:${dto.filterSignature()}`,
      where,
      this.resolveOrderBy(dto.sort, spec.orderBy),
      dto,
      viewerId,
      spec.ttlMs,
    );
  }

  async category(category: string, dto: DiscoveryQueryDto, viewerId?: string) {
    const cat = category.toLowerCase();
    // The whole subtree, not the one row whose slug matches. Products hang
    // off leaves, so matching `category.slug` alone answered with an empty
    // shelf for every department and root the home page links to — the entire
    // "Shop by category" rail opened onto nothing.
    const categoryIds = await this.repo.categorySubtree(cat);
    if (categoryIds.length === 0) {
      throw new NotFoundException('Category not found');
    }
    const where: Prisma.ProductWhereInput = {
      ...PURCHASABLE_PRODUCT_WHERE,
      categoryId: { in: categoryIds },
      ...this.buildFilters(dto),
    };
    const page = await this.paginated(
      `${PREFIX}cat:${cat}:${dto.filterSignature()}`,
      where,
      this.resolveOrderBy(dto.sort, [{ createdAt: 'desc' }]),
      dto,
      viewerId,
      60_000,
    );
    return {
      ...page,
      sponsored:
        dto.page > 1
          ? []
          : await this.sponsoredForCategory(categoryIds, where, viewerId),
    };
  }

  /**
   * The paid CATEGORY slots for this shelf, beside the products and never
   * inside them — the same rule search keeps, for the same reason.
   *
   * A slot qualifies when its product sits anywhere in the page's subtree and
   * passes the page's own filters; the viewer's visibility rule applies after,
   * as it does to the shelf. Never cached: the impression counter is what the
   * seller paid to see move. A failure here returns no slots, never an error.
   */
  private async sponsoredForCategory(
    categoryIds: string[],
    where: Prisma.ProductWhereInput,
    viewerId?: string,
  ) {
    try {
      const candidates = await this.promotions.candidatesFor(
        PromotionPlacement.CATEGORY,
        { categoryIds, viewerId },
      );
      if (candidates.length === 0) return [];

      const products = await this.repo.findMany(
        {
          AND: [
            where,
            { id: { in: candidates.map((candidate) => candidate.productId) } },
          ],
        },
        [{ createdAt: 'desc' }],
        0,
        candidates.length,
      );
      const visible = await this.visibility.visibleAmong(
        viewerId,
        products.map((product) => product.id),
      );
      const byId = new Map(
        products
          .filter((product) => visible.has(product.id))
          .map((product) => [product.id, product]),
      );
      const cards = candidates
        .filter((candidate) => byId.has(candidate.productId))
        .slice(0, MAX_SLOTS);
      if (cards.length === 0) return [];

      void this.promotions
        .recordImpressions(
          cards.map((card) => card.offerId),
          PromotionPlacement.CATEGORY,
          viewerId,
        )
        .catch(() => undefined);

      const favSet = viewerId
        ? await this.repo.favoriteSet(
            viewerId,
            cards.map((card) => card.productId),
          )
        : new Set<string>();
      return cards.map((card) => ({
        ...serializeProduct(byId.get(card.productId)!, {
          isLiked: favSet.has(card.productId),
        }),
        is_sponsored: true,
        sponsored_offer_id: card.offerId,
        sponsored_placement: 'category',
        sponsored_store_tier: card.tier.toLowerCase(),
      }));
    } catch (error) {
      this.logger.warn(`Sponsored category slots not served: ${String(error)}`);
      return [];
    }
  }

  async seller(sellerId: string, dto: DiscoveryQueryDto, viewerId?: string) {
    const where: Prisma.ProductWhereInput = {
      ...PURCHASABLE_PRODUCT_WHERE,
      // "This seller's storefront" is the set of products they list LIVE —
      // merged into the shared predicate rather than replacing it.
      offers: { some: { ...LIVE_OFFER_WHERE, sellerId } },
      ...this.buildFilters(dto),
    };
    return this.paginated(
      // `v2`: entries cached before the card carried her own offer must not
      // be served after a deploy.
      `${PREFIX}seller:v2:${sellerId}:${dto.filterSignature()}`,
      where,
      this.resolveOrderBy(dto.sort, [{ createdAt: 'desc' }]),
      dto,
      viewerId,
      60_000,
      sellerCardInclude(sellerId),
    );
  }

  /**
   * Products genuinely like this one.
   *
   * Reads the commerce graph's `SIMILAR` affinities, which compare slot,
   * colour, fabric, occasion and price. This used to mean "same category,
   * ordered by rating" — which is not similarity: it put a child's raincoat
   * next to an evening gown because both were highly rated in `clothing`.
   *
   * The category fallback is kept, deliberately. A product the affinity sweep
   * has not reached yet — listed an hour ago — would otherwise show an empty
   * rail, and the old behaviour is a worse answer than the graph but a better
   * one than nothing.
   */
  async similar(productId: string, dto: DiscoveryQueryDto, viewerId?: string) {
    const category = await this.repo.categoryOf(productId);
    if (category === null) throw new NotFoundException('Product not found');

    const relatedIds = await this.graph.similar(productId, 40);

    const where: Prisma.ProductWhereInput = relatedIds.length
      ? { ...PURCHASABLE_PRODUCT_WHERE, id: { in: relatedIds } }
      : {
          ...PURCHASABLE_PRODUCT_WHERE,
          category: { slug: category },
          id: { not: productId },
        };

    return this.paginated(
      `${PREFIX}similar:${productId}:${relatedIds.length}:${dto.filterSignature()}`,
      where,
      [{ rating: 'desc' }, { ordersCount: 'desc' }],
      dto,
      viewerId,
      120_000,
    );
  }

  async recommended(dto: DiscoveryQueryDto, viewerId?: string) {
    if (!viewerId) return this.collection('trending', dto, undefined);
    const [categories, dismissed] = await Promise.all([
      this.repo.preferredCategories(viewerId),
      this.repo.dismissedProductIds(viewerId),
    ]);
    const where: Prisma.ProductWhereInput = {
      ...PURCHASABLE_PRODUCT_WHERE,
      ...(categories.length ? { category: { slug: { in: categories } } } : {}),
      // «إزالة من المختارة لكِ» — gone from this shelf for good, not just
      // from the page she removed it on.
      ...(dismissed.length ? { id: { notIn: dismissed } } : {}),
    };
    const signature = [...categories].sort().join(',');
    // The page is cached by what shapes it. Two women with the same favourite
    // departments share an entry; one who removed a piece gets her own.
    const removed = dismissed.length
      ? createHash('sha1')
          .update([...dismissed].sort().join(','))
          .digest('hex')
          .slice(0, 16)
      : '-';
    return this.paginated(
      `${PREFIX}rec:${signature}:${removed}:${dto.filterSignature()}`,
      where,
      [{ rating: 'desc' }, { ordersCount: 'desc' }],
      dto,
      viewerId,
      60_000,
    );
  }

  /**
   * «إزالة من المختارة لكِ». Idempotent: removing twice is one removal.
   *
   * No cache to drop — the shelf's cache key carries her removals, so the
   * next read is already a different entry.
   */
  async dismissRecommendation(userId: string, productId: string) {
    if (!(await this.repo.productExists(productId))) {
      throw new NotFoundException('Product not found');
    }
    await this.repo.dismissRecommendation(userId, productId);
    return { product_id: productId, dismissed: true };
  }

  /** The «تراجع» on the removal: the piece may be suggested again. */
  async restoreRecommendation(userId: string, productId: string) {
    await this.repo.restoreRecommendation(userId, productId);
    return { product_id: productId, dismissed: false };
  }

  /** Aggregated home payload — sections are de-duplicated across each other. */
  async home(viewerId?: string) {
    const sections = await Promise.all(
      HOME_COLLECTION_KEYS.map(async (key) => {
        const spec = STATIC_COLLECTIONS[key];
        const where: Prisma.ProductWhereInput = {
          ...PURCHASABLE_PRODUCT_WHERE,
          ...(spec.extraWhere ?? {}),
        };
        // Over-fetch so dedup still leaves a full section.
        const products = await this.cachedList(
          `${PREFIX}home:${key}`,
          where,
          spec.orderBy,
          spec.homeSize * 2,
          spec.ttlMs,
        );
        return { key, homeSize: spec.homeSize, products };
      }),
    );

    // The lists are cached for everyone; what this viewer may not open yet
    // (Ohara Value's early access and exclusives) leaves after the cache.
    const visible = await this.visibility.visibleAmong(
      viewerId,
      sections.flatMap((section) => section.products.map((p) => p.id)),
    );

    const seen = new Set<string>();
    const trimmed = sections.map(({ key, homeSize, products }) => {
      const unique = products
        .filter((p) => visible.has(p.id) && !seen.has(p.id))
        .slice(0, homeSize);
      unique.forEach((p) => seen.add(p.id));
      return { key, products: unique };
    });

    const allIds = trimmed.flatMap((t) => t.products.map((p) => p.id));
    const favSet = viewerId
      ? await this.repo.favoriteSet(viewerId, allIds)
      : new Set<string>();

    const payload: Record<string, unknown> = {};
    for (const { key, products } of trimmed) {
      payload[key] = products.map((p) =>
        serializeProduct(p, { isLiked: favSet.has(p.id) }),
      );
    }
    return payload;
  }

  /** Called after product mutations to drop stale collection caches. */
  invalidate(): void {
    this.cache.invalidate(PREFIX);
  }

  // ── internals ──────────────────────────────────────────────────────────

  private cachedList(
    cacheKey: string,
    where: Prisma.ProductWhereInput,
    orderBy: ProductOrderBy,
    take: number,
    ttlMs: number,
  ): Promise<DiscoveryProduct[]> {
    return this.cache.wrap(`${cacheKey}:take${take}`, ttlMs, () =>
      this.repo.findMany(where, orderBy, 0, take),
    );
  }

  private async paginated(
    cacheKey: string,
    where: Prisma.ProductWhereInput,
    orderBy: ProductOrderBy,
    dto: DiscoveryQueryDto,
    viewerId: string | undefined,
    ttlMs: number,
    include?: typeof PRODUCT_CARD_INCLUDE,
  ) {
    // The heavy query (findMany + count) is cached; per-user `is_liked` is a
    // cheap overlay applied after the cache hit.
    const { products, total } = await this.cache.wrap<CachedPage>(
      cacheKey,
      ttlMs,
      async () => {
        const [products, total] = await Promise.all([
          this.repo.findMany(where, orderBy, dto.skip, dto.limit, include),
          this.repo.count(where),
        ]);
        return { products, total };
      },
    );

    // Cached for everyone, so the viewer's visibility rule applies after the
    // cache. The page can come back a card or two short of `limit`; the
    // alternative was cards whose product page answers «not found».
    const visible = await this.visibility.visibleAmong(
      viewerId,
      products.map((p) => p.id),
    );
    const shown = products.filter((p) => visible.has(p.id));

    const favSet = viewerId
      ? await this.repo.favoriteSet(
          viewerId,
          shown.map((p) => p.id),
        )
      : new Set<string>();

    return {
      data: shown.map((p) =>
        serializeProduct(p, { isLiked: favSet.has(p.id) }),
      ),
      pagination: buildMeta(dto.page, dto.limit, total, products.length),
    };
  }

  private buildFilters(dto: DiscoveryQueryDto): Prisma.ProductWhereInput {
    return {
      ...(dto.rating ? { rating: { gte: dto.rating } } : {}),
      // Price lives on the offer, not the product: filtering has to run
      // against the SYP-normalised roll-up, the same column search and the
      // public catalog already use. `price` is not a Product field at all, so
      // the previous form failed at the database, not at validation.
      ...(dto.min_price !== undefined || dto.max_price !== undefined
        ? {
            minPriceSyp: {
              ...(dto.min_price !== undefined ? { gte: dto.min_price } : {}),
              ...(dto.max_price !== undefined ? { lte: dto.max_price } : {}),
            },
          }
        : {}),
    };
  }

  private resolveOrderBy(
    sort: DiscoverySort | undefined,
    fallback: ProductOrderBy,
  ): ProductOrderBy {
    switch (sort) {
      case 'newest':
        return [{ createdAt: 'desc' }];
      // Price sorting runs off the SYP-normalised roll-up so offers priced
      // in different currencies interleave correctly.
      case 'price_asc':
        return [{ minPriceSyp: 'asc' }];
      case 'price_desc':
        return [{ minPriceSyp: 'desc' }];
      case 'best_selling':
        return [{ ordersCount: 'desc' }];
      case 'rating':
        return [{ rating: 'desc' }, { reviewsCount: 'desc' }];
      case 'popular':
        return [{ viewsCount: 'desc' }, { favoritesCount: 'desc' }];
      // What the marketplace thinks is worth showing, rather than any single
      // counter. Ordered on the stored column so it is an index rather than a
      // scan — see `ranking/kernel` for what it weighs, and why it is
      // conversion rather than lifetime orders.
      case 'recommended':
        return [{ rankScore: 'desc' }, { createdAt: 'desc' }];
      default:
        return fallback;
    }
  }
}
