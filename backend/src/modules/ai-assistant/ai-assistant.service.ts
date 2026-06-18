import { Injectable, NotFoundException } from '@nestjs/common';
import {
  AiGenerationType,
  AiInteractionType,
  Prisma,
  ProductStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { serializeProduct, serializeUser } from '../../common/serializers';
import {
  AiRecommendationQueryDto,
  AiSuggestionQueryDto,
  GenerateProductDescriptionDto,
  GenerateTagsDto,
} from './dto/ai-assistant.dto';

const productInclude = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
  variants: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductInclude;

const availableWhere: Prisma.ProductWhereInput = {
  status: ProductStatus.ACTIVE,
  isAvailable: true,
  stock: { gt: 0 },
};

type ProductRecord = Prisma.ProductGetPayload<{ include: typeof productInclude }>;

interface BehaviorProfile {
  categories: Map<string, number>;
  sellers: Map<string, number>;
  queries: string[];
  viewedProductIds: Set<string>;
  purchasedProductIds: Set<string>;
}

@Injectable()
export class AiAssistantService {
  constructor(private readonly prisma: PrismaService) {}

  async productRecommendations(
    userId: string | undefined,
    dto: AiRecommendationQueryDto,
  ) {
    const profile = userId ? await this.behaviorProfile(userId) : this.emptyProfile();
    const products = await this.prisma.product.findMany({
      where: {
        ...availableWhere,
        ...(dto.category ? { category: dto.category.toLowerCase() } : {}),
        ...(profile.purchasedProductIds.size
          ? { id: { notIn: [...profile.purchasedProductIds] } }
          : {}),
      },
      include: productInclude,
      take: Math.min(dto.limit * 4, 120),
      orderBy: [{ rating: 'desc' }, { ordersCount: 'desc' }, { createdAt: 'desc' }],
    });
    const ranked = this.rankProducts(products, profile).slice(0, dto.limit);
    await this.recordInteraction(userId, AiInteractionType.RECOMMENDATION_VIEW, {
      metadata: { count: ranked.length, category: dto.category },
    });
    return ranked.map((row) => ({
      product: serializeProduct(row.product, { isLiked: false }),
      score: this.round(row.score),
      ...(dto.include_explanations
        ? { reasons: this.productReasons(row.product, profile) }
        : {}),
    }));
  }

  async similarProducts(
    productId: string,
    userId: string | undefined,
    dto: AiRecommendationQueryDto,
  ) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      include: productInclude,
    });
    if (!product) throw new NotFoundException('Product not found');

    const tokens = this.tokens(`${product.title} ${product.description}`);
    const candidates = await this.prisma.product.findMany({
      where: {
        ...availableWhere,
        id: { not: productId },
        OR: [
          { category: product.category },
          { title: { contains: product.title.split(' ')[0] ?? '', mode: 'insensitive' } },
        ],
      },
      include: productInclude,
      take: Math.min(dto.limit * 5, 120),
      orderBy: [{ rating: 'desc' }, { favoritesCount: 'desc' }],
    });

    const ranked = candidates
      .map((candidate) => {
        const overlap = this.tokenOverlap(
          tokens,
          this.tokens(`${candidate.title} ${candidate.description}`),
        );
        const score =
          (candidate.category === product.category ? 45 : 0) +
          overlap * 12 +
          candidate.rating * 6 +
          Math.log1p(candidate.ordersCount + candidate.favoritesCount);
        return { product: candidate, score };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, dto.limit);

    await this.recordInteraction(userId, AiInteractionType.SIMILAR_PRODUCTS, {
      productId,
      metadata: { count: ranked.length },
    });
    return ranked.map((row) => ({
      product: serializeProduct(row.product, { isLiked: false }),
      score: this.round(row.score),
      ...(dto.include_explanations
        ? { reasons: ['Same category', 'Close title and description match'] }
        : {}),
    }));
  }

  async sellerRecommendations(
    userId: string | undefined,
    dto: AiRecommendationQueryDto,
  ) {
    const profile = userId ? await this.behaviorProfile(userId) : this.emptyProfile();
    const sellers = await this.prisma.user.findMany({
      where: {
        role: UserRole.SELLER,
        disabledAt: null,
        products: {
          some: {
            ...availableWhere,
            ...(dto.category ? { category: dto.category.toLowerCase() } : {}),
          },
        },
      },
      include: {
        sellerReputation: true,
        sellerBadges: true,
        _count: { select: { products: true, followers: true } },
      },
      take: Math.min(dto.limit * 4, 80),
      orderBy: [{ followersCount: 'desc' }, { createdAt: 'desc' }],
    });

    const ranked = sellers
      .map((seller) => {
        const affinity = profile.sellers.get(seller.id) ?? 0;
        const reputation = seller.sellerReputation?.performanceScore ?? 0;
        const score = reputation * 0.7 + affinity * 20 + Math.log1p(seller.followersCount) * 4;
        return { seller, score };
      })
      .sort((a, b) => b.score - a.score)
      .slice(0, dto.limit);

    await this.recordInteraction(userId, AiInteractionType.SELLER_RECOMMENDATION, {
      metadata: { count: ranked.length, category: dto.category },
    });
    return ranked.map(({ seller, score }) => ({
      seller: serializeUser(seller),
      score: this.round(score),
      badges: seller.sellerBadges.map((badge) => badge.label),
      performance_score: seller.sellerReputation?.performanceScore ?? 0,
    }));
  }

  async smartSearchSuggestions(userId: string | undefined, dto: AiSuggestionQueryDto) {
    const query = (dto.q ?? '').trim();
    const profile = userId ? await this.behaviorProfile(userId) : this.emptyProfile();
    const [products, categories, history] = await Promise.all([
      this.prisma.product.findMany({
        where: query
          ? {
              ...availableWhere,
              OR: [
                { title: { contains: query, mode: 'insensitive' } },
                { description: { contains: query, mode: 'insensitive' } },
              ],
            }
          : { ...availableWhere },
        select: { title: true, category: true },
        take: 20,
        orderBy: [{ ordersCount: 'desc' }, { rating: 'desc' }],
      }),
      this.prisma.product.findMany({
        where: query
          ? { ...availableWhere, category: { contains: query, mode: 'insensitive' } }
          : { ...availableWhere },
        distinct: ['category'],
        select: { category: true },
        take: 12,
      }),
      userId
        ? this.prisma.searchHistory.findMany({
            where: { userId, ...(query ? { query: { contains: query, mode: 'insensitive' } } : {}) },
            orderBy: { createdAt: 'desc' },
            take: 12,
          })
        : [],
    ]);
    const suggestions = [
      ...history.map((entry) => ({ text: entry.query, type: 'recent', score: 95 })),
      ...products.map((product) => ({
        text: product.title,
        type: 'product',
        score: 70 + (profile.categories.get(product.category) ?? 0) * 8,
      })),
      ...categories.map((category) => ({
        text: category.category,
        type: 'category',
        score: 65 + (profile.categories.get(category.category) ?? 0) * 10,
      })),
      ...profile.queries.map((entry) => ({ text: entry, type: 'personal', score: 60 })),
    ];

    const deduped = new Map<string, { text: string; type: string; score: number }>();
    for (const suggestion of suggestions) {
      const key = suggestion.text.toLowerCase();
      const current = deduped.get(key);
      if (!current || suggestion.score > current.score) deduped.set(key, suggestion);
    }
    await this.recordInteraction(userId, AiInteractionType.SEARCH_SUGGESTION, {
      query,
      metadata: { count: deduped.size },
    });
    return [...deduped.values()]
      .sort((a, b) => b.score - a.score)
      .slice(0, dto.limit)
      .map((item) => ({ ...item, score: this.round(item.score) }));
  }

  async personalizedHomeFeed(userId: string | undefined) {
    const [forYou, sellers, trending] = await Promise.all([
      this.productRecommendations(userId, { limit: 12, include_explanations: true }),
      this.sellerRecommendations(userId, { limit: 8 }),
      this.prisma.product.findMany({
        where: availableWhere,
        include: productInclude,
        take: 12,
        orderBy: [{ ordersCount: 'desc' }, { viewsCount: 'desc' }],
      }),
    ]);
    await this.recordInteraction(userId, AiInteractionType.HOME_FEED, {
      metadata: { products: forYou.length, sellers: sellers.length },
    });
    return {
      for_you: forYou,
      recommended_sellers: sellers,
      trending: trending.map((product) => serializeProduct(product, { isLiked: false })),
    };
  }

  async behaviorAnalysis(userId: string) {
    const profile = await this.behaviorProfile(userId);
    await this.recordInteraction(userId, AiInteractionType.BEHAVIOR_ANALYSIS, {});
    const topCategories = [...profile.categories.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8)
      .map(([category, score]) => ({ category, score: this.round(score) }));
    const topSellers = [...profile.sellers.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8)
      .map(([seller_id, score]) => ({ seller_id, score: this.round(score) }));
    return {
      top_categories: topCategories,
      top_sellers: topSellers,
      recent_queries: profile.queries.slice(0, 10),
      viewed_products: profile.viewedProductIds.size,
      purchased_products: profile.purchasedProductIds.size,
      maturity:
        profile.purchasedProductIds.size > 5
          ? 'loyal_customer'
          : profile.viewedProductIds.size > 10
            ? 'active_researcher'
            : 'new_discovery',
    };
  }

  async generateProductDescription(userId: string, dto: GenerateProductDescriptionDto) {
    const attributes = this.normalizedAttributes(dto.attributes);
    const tone = dto.tone?.trim() || 'premium and helpful';
    const audience = dto.audience?.trim() || 'marketplace shoppers';
    const description = [
      `${dto.title.trim()} is designed for ${audience}, bringing ${attributes
        .slice(0, 3)
        .join(', ') || dto.category.toLowerCase()} into one polished piece.`,
      `Its ${dto.category.toLowerCase()} profile makes it easy to style, gift, and revisit across seasons.`,
      `The tone is ${tone}: clear enough for confident buying decisions, with enough detail to feel personal.`,
    ].join(' ');
    const bullets = [
      `Category: ${dto.category}`,
      ...attributes.slice(0, 5).map((attribute) => `Highlights ${attribute}`),
    ];
    const output = { description, bullets, tone, audience };
    await this.persistGeneration(userId, dto.product_id, AiGenerationType.PRODUCT_DESCRIPTION, dto.title, output);
    await this.recordInteraction(userId, AiInteractionType.PRODUCT_DESCRIPTION, {
      productId: dto.product_id,
      metadata: { category: dto.category },
    });
    return output;
  }

  async generateTags(userId: string, dto: GenerateTagsDto) {
    const tokens = [
      dto.category,
      ...this.tokens(`${dto.title} ${dto.description ?? ''}`),
      ...(dto.seed_tags ?? []),
    ]
      .map((tag) => this.slug(tag))
      .filter(Boolean);
    const unique = [...new Set(tokens)].slice(0, 16);
    const output = {
      tags: unique,
      seo_title: `${dto.title.trim()} | ${dto.category.trim()}`,
    };
    await this.persistGeneration(userId, dto.product_id, AiGenerationType.PRODUCT_TAGS, dto.title, output);
    await this.recordInteraction(userId, AiInteractionType.TAG_GENERATION, {
      productId: dto.product_id,
      metadata: { count: unique.length },
    });
    return output;
  }

  private async behaviorProfile(userId: string): Promise<BehaviorProfile> {
    const profile = this.emptyProfile();
    const [orders, favorites, searches, views] = await Promise.all([
      this.prisma.orderItem.findMany({
        where: { order: { userId } },
        include: { product: { select: { id: true, category: true, sellerId: true } } },
        take: 200,
        orderBy: { order: { createdAt: 'desc' } },
      }),
      this.prisma.favorite.findMany({
        where: { userId },
        include: { product: { select: { id: true, category: true, sellerId: true } } },
        take: 200,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.searchHistory.findMany({
        where: { userId },
        take: 40,
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.analyticsEvent.findMany({
        where: { userId, type: 'PRODUCT_VIEW' },
        include: { product: { select: { id: true, category: true, sellerId: true } } },
        take: 200,
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    for (const item of orders) {
      profile.purchasedProductIds.add(item.productId);
      this.bump(profile.categories, item.product.category, 4 * item.quantity);
      this.bump(profile.sellers, item.product.sellerId, 3 * item.quantity);
    }
    for (const favorite of favorites) {
      this.bump(profile.categories, favorite.product.category, 3);
      this.bump(profile.sellers, favorite.product.sellerId, 2);
    }
    for (const view of views) {
      if (!view.product) continue;
      profile.viewedProductIds.add(view.product.id);
      this.bump(profile.categories, view.product.category, 1);
      this.bump(profile.sellers, view.product.sellerId, 0.8);
    }
    profile.queries = [...new Set(searches.map((entry) => entry.query))];
    return profile;
  }

  private rankProducts(products: ProductRecord[], profile: BehaviorProfile) {
    return products
      .map((product) => {
        const categoryAffinity = profile.categories.get(product.category) ?? 0;
        const sellerAffinity = profile.sellers.get(product.sellerId) ?? 0;
        const score =
          product.rating * 12 +
          Math.log1p(product.ordersCount) * 8 +
          Math.log1p(product.favoritesCount) * 6 +
          categoryAffinity * 10 +
          sellerAffinity * 4 +
          (product.isFeatured ? 5 : 0);
        return { product, score };
      })
      .sort((a, b) => b.score - a.score);
  }

  private productReasons(product: ProductRecord, profile: BehaviorProfile) {
    const reasons = ['Strong marketplace performance'];
    if ((profile.categories.get(product.category) ?? 0) > 0) {
      reasons.push(`Matches your interest in ${product.category}`);
    }
    if ((profile.sellers.get(product.sellerId) ?? 0) > 0) {
      reasons.push(`From a seller you engage with`);
    }
    if (product.rating >= 4.5) reasons.push('Highly rated by customers');
    return reasons.slice(0, 4);
  }

  private async persistGeneration(
    userId: string,
    productId: string | undefined,
    type: AiGenerationType,
    prompt: string,
    output: unknown,
  ) {
    await this.prisma.aiGeneration.create({
      data: {
        userId,
        productId,
        type,
        prompt,
        output: output as Prisma.InputJsonValue,
      },
    });
  }

  private async recordInteraction(
    userId: string | undefined,
    type: AiInteractionType,
    input: {
      query?: string;
      productId?: string;
      sellerId?: string;
      metadata?: unknown;
      score?: number;
    },
  ) {
    await this.prisma.aiInteraction.create({
      data: {
        userId,
        type,
        query: input.query,
        productId: input.productId,
        sellerId: input.sellerId,
        metadata: input.metadata as Prisma.InputJsonValue,
        score: input.score,
      },
    });
  }

  private emptyProfile(): BehaviorProfile {
    return {
      categories: new Map(),
      sellers: new Map(),
      queries: [],
      viewedProductIds: new Set(),
      purchasedProductIds: new Set(),
    };
  }

  private normalizedAttributes(attributes?: string[]) {
    return (attributes ?? [])
      .map((attribute) => attribute.trim())
      .filter(Boolean)
      .slice(0, 12);
  }

  private tokens(value: string) {
    return value
      .toLowerCase()
      .split(/[^a-z0-9]+/i)
      .filter((token) => token.length > 2 && !['the', 'and', 'with'].includes(token))
      .slice(0, 30);
  }

  private tokenOverlap(left: string[], right: string[]) {
    const rightSet = new Set(right);
    return left.filter((token) => rightSet.has(token)).length;
  }

  private slug(value: string) {
    return value
      .toLowerCase()
      .trim()
      .replace(/[^a-z0-9]+/g, '-')
      .replace(/^-|-$/g, '');
  }

  private bump(map: Map<string, number>, key: string, value: number) {
    map.set(key, (map.get(key) ?? 0) + value);
  }

  private round(value: number) {
    return Math.round(value * 100) / 100;
  }
}
