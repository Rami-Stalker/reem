import { Injectable, Logger } from '@nestjs/common';
import { Prisma, ProductStatus, PromotionPlacement, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { TrendSignalService } from '../trends/collection/trend-signal.service';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import {
  serializeLegacyPost,
  serializeProduct,
  serializePublicUser,
} from '../../common/serializers';
import { ProductSearchDto, SearchSort } from './dto/search-query.dto';
import { ProductMatch, ProductMatcher } from './product-matcher.service';
import { MAX_SLOTS, PromotionsService } from '../promotions/promotions.service';
import { ValueVisibilityService } from '../value/value-visibility.service';
import {
  PRODUCT_CARD_INCLUDE,
  LIVE_OFFER_WHERE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../common/catalog/product-include';
import { categorySubtreeIds } from '../../common/catalog/category-subtree';

/** Matches no user — keeps personalised includes static for anonymous viewers. */
const NIL_UUID = '00000000-0000-0000-0000-000000000000';

/**
 * What the search screen offers before anyone has searched anything.
 *
 * In Arabic, because the catalogue is: these are run as real queries against
 * `title`, `description` and brand, and the English list that used to sit here
 * — dresses, perfume, handbags, heels, gifts, makeup — matched not one product
 * in the shop. Every chip on the customer's search screen opened an empty
 * result page. Each term below is one a listing actually contains.
 */
const TRENDING_FALLBACK = [
  'فستان',
  'عطر',
  'حقيبة',
  'حذاء',
  'هدية',
  'ورد',
];

@Injectable()
export class SearchService {
  private readonly logger = new Logger(SearchService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly signals: TrendSignalService,
    private readonly matcher: ProductMatcher,
    private readonly promotions: PromotionsService,
    private readonly visibility: ValueVisibilityService,
  ) {}

  // ── Products ─────────────────────────────────────────────────────────────

  async searchProducts(dto: ProductSearchDto, viewerId?: string) {
    // The phrase decides which products are in play; every other filter is
    // still Prisma's, applied to that set. See `ProductMatcher` for why the
    // two are split.
    const matches = await this.matcher.match(dto.q);
    // Ohara Value's visibility rule, in the query so the count and the pages
    // agree. Without it, search listed new arrivals inside their early-access
    // window to women who could not open them — a tap answered «not found».
    const gate = await this.visibility.catalogFilter(viewerId);
    // A department filter means its whole subtree: products hang off leaves,
    // so matching the one slug answered «ملابس» with an empty page.
    const categoryIds = dto.category
      ? await categorySubtreeIds(this.prisma, dto.category.toLowerCase())
      : undefined;
    const filtered = this.buildProductWhere(
      dto,
      matches?.map((m) => m.id),
      categoryIds,
    );
    const where: Prisma.ProductWhereInput = Object.keys(gate).length
      ? { AND: [filtered, gate] }
      : filtered;

    const relevance = matches !== null && (dto.sort ?? 'relevance') === 'relevance';
    const [products, total] = relevance
      ? await this.byRelevance(where, matches, dto)
      : await Promise.all([
          this.prisma.product.findMany({
            where,
            orderBy: this.sortBy(dto.sort),
            skip: dto.skip,
            take: dto.limit,
            include: PRODUCT_CARD_INCLUDE,
          }),
          this.prisma.product.count({ where }),
        ]);

    this.recordHistory(viewerId, dto.q);
    // Search Intelligence: the query, how many rows answered it, and which
    // products were on the page. A search that returns nothing is the clearest
    // purchase intent this platform ever sees, and until now it left no trace.
    this.signals.recordSearch({
      query: dto.q,
      resultCount: total,
      productIds: products.map((p) => p.id),
      userId: viewerId ?? null,
      source: 'search.products',
    });
    const favSet = await this.favoriteSet(viewerId, products.map((p) => p.id));

    return {
      data: products.map((p) =>
        serializeProduct(p, { isLiked: favSet.has(p.id) }),
      ),
      // Paid slots ride beside the results, never inside them. A sponsored
      // listing mixed into `data` would be indistinguishable from something
      // the search actually judged relevant — which is the whole objection to
      // advertising in a marketplace, and it is avoided by keeping the two
      // lists apart rather than by remembering to add a flag.
      sponsored: await this.sponsored(dto, where, viewerId),
      pagination: buildMeta(dto.page, dto.limit, total, products.length),
    };
  }

  /**
   * The paid slots for this search, as cards a client can label.
   *
   * Only on the first page: a sponsored slot repeated on page seven is not a
   * placement, it is an obstruction. Failure is swallowed — a broken ad
   * system must never take the search results down with it.
   */
  private async sponsored(
    dto: ProductSearchDto,
    where: Prisma.ProductWhereInput,
    viewerId?: string,
  ) {
    if (dto.page > 1) return [];

    try {
      // A slot is only shown when its product would have been a result of
      // this very search — same phrase, same filters, same visibility rule.
      // Paying buys the top of the page, not a place on pages it does not
      // answer.
      const candidates = await this.promotions.candidatesFor(
        PromotionPlacement.SEARCH,
        { viewerId },
      );
      if (candidates.length === 0) return [];

      const products = await this.prisma.product.findMany({
        where: {
          AND: [
            where,
            { id: { in: candidates.map((candidate) => candidate.productId) } },
          ],
        },
        include: PRODUCT_CARD_INCLUDE,
      });
      const byId = new Map(products.map((product) => [product.id, product]));
      const cards = candidates
        .filter((candidate) => byId.has(candidate.productId))
        .slice(0, MAX_SLOTS)
        .map((candidate) => ({
          offerId: candidate.offerId,
          tier: candidate.tier,
          product: byId.get(candidate.productId)!,
        }));
      if (cards.length === 0) return [];

      const favSet = await this.favoriteSet(
        viewerId,
        cards.map((card) => card.product.id),
      );

      void this.promotions
        .recordImpressions(
          cards.map((card) => card.offerId),
          PromotionPlacement.SEARCH,
          viewerId,
        )
        .catch(() => undefined);

      // Each card carries the offer that paid for it, so a tap is credited
      // to that offer and not to whichever seller happens to list it too.
      return cards.map(({ offerId, tier, product }) => ({
        ...serializeProduct(product, { isLiked: favSet.has(product.id) }),
        is_sponsored: true,
        sponsored_offer_id: offerId,
        sponsored_placement: 'search',
        sponsored_store_tier: tier.toLowerCase(),
      }));
    } catch (error) {
      this.logger.warn(`Sponsored slots not served: ${String(error)}`);
      return [];
    }
  }

  /**
   * She tapped a result. The other half of Search Intelligence: without it
   * the trend engine can see what was shown but never what was chosen, and
   * "searched a lot, clicked nothing" — the finding a seller can act on —
   * cannot be told apart from "searched a lot, bought everything".
   */
  recordResultClick(input: {
    query: string;
    productId: string;
    userId?: string | null;
  }): void {
    this.signals.recordSearchClick({
      query: input.query,
      productId: input.productId,
      userId: input.userId ?? null,
    });
  }

  // ── Sellers ──────────────────────────────────────────────────────────────

  async searchSellers(q: string | undefined, page: PaginationDto) {
    const where = this.sellerWhere(await this.matcher.matchSellerIds(q));
    const [sellers, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy: { followersCount: 'desc' },
        skip: page.skip,
        take: page.limit,
      }),
      this.prisma.user.count({ where }),
    ]);
    return {
      // The public shape: a boutique's search card is a storefront header, and
      // `serializeUser` would hand every anonymous caller the owner's phone
      // number and email.
      data: sellers.map(serializePublicUser),
      pagination: buildMeta(page.page, page.limit, total, sellers.length),
    };
  }

  // ── Shoppers ─────────────────────────────────────────────────────────────

  /**
   * Women with an open page. With no phrase there is nothing to list: a
   * directory of every public shopper is a different feature, and not one
   * anybody asked for.
   */
  async searchCustomers(q: string | undefined, page: PaginationDto) {
    const ids = await this.matcher.matchCustomerIds(q);
    if (!ids || ids.length === 0) {
      return {
        data: [],
        pagination: buildMeta(page.page, page.limit, 0, 0),
      };
    }
    const where = this.customerWhere(ids);
    const [users, total] = await Promise.all([
      this.prisma.user.findMany({
        where,
        orderBy: { followersCount: 'desc' },
        skip: page.skip,
        take: page.limit,
      }),
      this.prisma.user.count({ where }),
    ]);
    return {
      data: users.map(serializePublicUser),
      pagination: buildMeta(page.page, page.limit, total, users.length),
    };
  }

  // ── Posts ────────────────────────────────────────────────────────────────

  async searchPosts(q: string | undefined, viewerId: string | undefined, page: PaginationDto) {
    const where = this.postWhere(await this.matcher.matchContentIds(q));
    const [posts, total] = await Promise.all([
      this.prisma.commerceContent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
        include: {
          author: true,
          productTags: {
            orderBy: { sortOrder: 'asc' },
            include: { product: { include: PRODUCT_CARD_INCLUDE } },
          },
          reactions: { where: { userId: viewerId ?? NIL_UUID } },
          saves: { where: { userId: viewerId ?? NIL_UUID } },
        },
      }),
      this.prisma.commerceContent.count({ where }),
    ]);
    return {
      data: posts.map((post) =>
        serializeLegacyPost(post, {
          liked: new Set(post.reactions.map((r) => r.contentId)),
          saved: new Set(post.saves.map((s) => s.contentId)),
          viewed: new Set(),
          reactions: new Map(),
        }),
      ),
      pagination: buildMeta(page.page, page.limit, total, posts.length),
    };
  }

  // ── Unified (top hits per type) ──────────────────────────────────────────

  async unified(q: string | undefined, viewerId?: string) {
    // Each surface is matched on the same folded key, so one phrase reaches
    // products, boutiques and posts consistently.
    const [productMatches, sellerIds, contentIds, customerIds] =
      await Promise.all([
        this.matcher.match(q),
        this.matcher.matchSellerIds(q),
        this.matcher.matchContentIds(q),
        this.matcher.matchCustomerIds(q),
      ]);

    const gate = await this.visibility.catalogFilter(viewerId);
    const productWhere = this.buildProductWhere(
      { q } as ProductSearchDto,
      productMatches?.map((m) => m.id),
    );
    const [products, sellers, posts, customers] = await Promise.all([
      this.prisma.product.findMany({
        where: Object.keys(gate).length
          ? { AND: [productWhere, gate] }
          : productWhere,
        orderBy: [{ ordersCount: 'desc' }, { createdAt: 'desc' }],
        take: 8,
        include: PRODUCT_CARD_INCLUDE,
      }),
      this.prisma.user.findMany({
        where: this.sellerWhere(sellerIds),
        orderBy: { followersCount: 'desc' },
        take: 6,
      }),
      this.prisma.commerceContent.findMany({
        where: this.postWhere(contentIds),
        orderBy: { createdAt: 'desc' },
        take: 6,
        include: {
          author: true,
          productTags: {
            orderBy: { sortOrder: 'asc' },
            include: { product: { include: PRODUCT_CARD_INCLUDE } },
          },
        },
      }),
      customerIds && customerIds.length > 0
        ? this.prisma.user.findMany({
            where: this.customerWhere(customerIds),
            orderBy: { followersCount: 'desc' },
            take: 6,
          })
        : Promise.resolve([]),
    ]);

    this.recordHistory(viewerId, q);
    this.signals.recordSearch({
      query: q,
      // The unified search caps at eight products, so its own count is the
      // honest answer to "did the catalogue have anything", not to "how many".
      resultCount: products.length,
      productIds: products.map((p) => p.id),
      userId: viewerId ?? null,
      source: 'search.unified',
    });
    const favSet = await this.favoriteSet(viewerId, products.map((p) => p.id));

    return {
      products: products.map((p) =>
        serializeProduct(p, { isLiked: favSet.has(p.id) }),
      ),
      sellers: sellers.map(serializePublicUser),
      customers: customers.map(serializePublicUser),
      posts: posts.map((post) => serializeLegacyPost(post)),
    };
  }

  // ── Suggestions / trending / history ─────────────────────────────────────

  async suggestions(q: string | undefined) {
    const query = (q ?? '').trim();
    if (query.length < 1) return { products: [], categories: [] };

    // Both sides fold through the same key, so typing عبايه offers عباية.
    const [products, categories] = await Promise.all([
      this.matcher.suggest(query),
      this.matcher.matchCategories(query),
    ]);

    return { products, categories };
  }

  async trending() {
    const since = new Date(Date.now() - 7 * 24 * 60 * 60 * 1000);
    const rows = await this.prisma.searchHistory.groupBy({
      by: ['query'],
      where: { createdAt: { gte: since } },
      _count: { query: true },
      orderBy: { _count: { query: 'desc' } },
      take: 10,
    });
    const fromHistory = rows.map((r) => r.query);
    return [...new Set([...fromHistory, ...TRENDING_FALLBACK])].slice(0, 10);
  }

  async recent(userId: string) {
    const rows = await this.prisma.searchHistory.findMany({
      where: { userId },
      orderBy: { createdAt: 'desc' },
      take: 40,
    });
    const seen = new Set<string>();
    const result: { id: string; query: string; created_at: string }[] = [];
    for (const r of rows) {
      const key = r.query.toLowerCase();
      if (seen.has(key)) continue;
      seen.add(key);
      result.push({
        id: r.id,
        query: r.query,
        created_at: r.createdAt.toISOString(),
      });
      if (result.length >= 10) break;
    }
    return result;
  }

  async clearRecent(userId: string) {
    await this.prisma.searchHistory.deleteMany({ where: { userId } });
    return { message: 'Search history cleared' };
  }

  async removeRecent(userId: string, id: string) {
    await this.prisma.searchHistory.deleteMany({ where: { id, userId } });
    return { message: 'Removed from history' };
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  /**
   * A page of results in the order the phrase put them in.
   *
   * Prisma cannot order by a score the database computed in another query, so
   * the ordering is applied here. The candidate set is capped by the matcher,
   * which is what makes this affordable: the ids that survive the business
   * filters are read once, sorted by score, and only the page itself is
   * hydrated with the full card include.
   */
  private async byRelevance(
    where: Prisma.ProductWhereInput,
    matches: ProductMatch[],
    dto: ProductSearchDto,
  ): Promise<[Prisma.ProductGetPayload<{ include: typeof PRODUCT_CARD_INCLUDE }>[], number]> {
    if (matches.length === 0) return [[], 0];

    const rank = new Map(matches.map((m, index) => [m.id, index]));
    const surviving = await this.prisma.product.findMany({
      where,
      select: { id: true },
    });
    surviving.sort(
      (a, b) => (rank.get(a.id) ?? Infinity) - (rank.get(b.id) ?? Infinity),
    );

    const pageIds = surviving
      .slice(dto.skip, dto.skip + dto.limit)
      .map((row) => row.id);
    if (pageIds.length === 0) return [[], surviving.length];

    const rows = await this.prisma.product.findMany({
      where: { id: { in: pageIds } },
      include: PRODUCT_CARD_INCLUDE,
    });
    // `IN` comes back in whatever order the planner liked, so the page is put
    // back into relevance order before it is serialized.
    rows.sort((a, b) => (rank.get(a.id) ?? 0) - (rank.get(b.id) ?? 0));
    return [rows, surviving.length];
  }

  /**
   * The business filters, unchanged, plus whatever the phrase reached.
   *
   * `matchedIds` is undefined when there was no phrase to match — which is
   * why it is not defaulted to an empty array. An empty array means the
   * search found nothing and the result must be empty; undefined means the
   * customer is browsing with filters alone and every product is still in
   * play. Conflating them would empty the shop for anyone who cleared the
   * search box.
   */
  private buildProductWhere(
    dto: ProductSearchDto,
    matchedIds?: string[],
    categoryIds?: string[],
  ): Prisma.ProductWhereInput {
    return {
      ...PURCHASABLE_PRODUCT_WHERE,
      ...(matchedIds ? { id: { in: matchedIds } } : {}),
      ...(categoryIds
        ? { categoryId: { in: categoryIds } }
        : dto.category
          ? { category: { slug: dto.category.toLowerCase() } }
          : {}),
      // "Products this seller sells" is an offer filter now.
      ...(dto.seller_id
        ? { offers: { some: { ...LIVE_OFFER_WHERE, sellerId: dto.seller_id } } }
        : {}),
      ...(dto.rating ? { rating: { gte: dto.rating } } : {}),
      // Price filters run against the SYP-normalised roll-up.
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

  /** Re-checked here, not only in the matcher: the page may have closed since. */
  private customerWhere(ids: string[]): Prisma.UserWhereInput {
    return { id: { in: ids }, role: UserRole.CUSTOMER, profileIsPublic: true };
  }

  /** `null` means no phrase was typed, so every boutique is still in play. */
  private sellerWhere(matchedIds: string[] | null): Prisma.UserWhereInput {
    return {
      role: UserRole.SELLER,
      ...(matchedIds ? { id: { in: matchedIds } } : {}),
    };
  }

  /**
   * Searchable social content.
   *
   * Posts and reels, never stories: a story is gone in a day, and a search
   * result that 404s by tomorrow afternoon is worse than no result.
   */
  private postWhere(
    matchedIds: string[] | null,
  ): Prisma.CommerceContentWhereInput {
    const base: Prisma.CommerceContentWhereInput = {
      contentType: { in: ['product_post', 'reel'] },
      status: 'PUBLISHED',
      visibility: 'PUBLIC',
      authorIsPublic: true,
    };
    return matchedIds ? { ...base, id: { in: matchedIds } } : base;
  }

  private sortBy(sort?: SearchSort): Prisma.ProductOrderByWithRelationInput[] {
    switch (sort) {
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
      // Relevance is ordered by `byRelevance`, not here; reaching this arm
      // means relevance was asked for with no phrase to rank against, and
      // newest is the honest answer to that.
      case 'relevance':
      case 'newest':
      default:
        return [{ createdAt: 'desc' }];
    }
  }

  private async favoriteSet(
    userId: string | undefined,
    productIds: string[],
  ): Promise<Set<string>> {
    if (!userId || productIds.length === 0) return new Set();
    const favorites = await this.prisma.favorite.findMany({
      where: { userId, productId: { in: productIds } },
      select: { productId: true },
    });
    return new Set(favorites.map((f) => f.productId));
  }

  /** Fire-and-forget search logging for trending/recent analytics. */
  private recordHistory(userId: string | undefined, q: string | undefined) {
    const query = q?.trim();
    if (!userId || !query || query.length < 2) return;
    void this.prisma.searchHistory
      .create({ data: { userId, query } })
      .catch(() => undefined);
  }
}
