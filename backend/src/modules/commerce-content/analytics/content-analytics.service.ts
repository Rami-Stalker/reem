import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common';
import { CommerceAttributionSource, Prisma } from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuthUser } from '../../../common/decorators/current-user.decorator';
import { assertCanManage } from '../../../common/authz';
import { buildMeta, PaginationDto } from '../../../common/dto/pagination.dto';
import { serializePromoter } from '../../../common/serializers/social.serializer';

/**
 * What a boutique can find out about its own content, and about the women
 * carrying it around.
 *
 * Every read here is one index scan on `commerce_content_attributions`. That
 * table exists precisely so this screen does not become a three-way join
 * through `seller_offers` that runs on every dashboard load and gets slower
 * every week the platform works.
 */
@Injectable()
export class ContentAnalyticsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Her own content ───────────────────────────────────────────────────────

  /** Posts against reels against stories — what is worth making more of. */
  async overview(user: AuthUser, sellerId?: string) {
    const authorId = this.subjectOrThrow(user, sellerId);

    const byType = await this.prisma.commerceContent.groupBy({
      by: ['contentType'],
      where: { authorId },
      _count: { _all: true },
      _sum: {
        viewsCount: true,
        uniqueViewersCount: true,
        reactionsCount: true,
        repliesCount: true,
        savesCount: true,
        sharesCount: true,
        productClicksCount: true,
        ordersCount: true,
        watchTimeMs: true,
      },
    });

    const byStatus = await this.prisma.commerceContent.groupBy({
      by: ['status'],
      where: { authorId },
      _count: { _all: true },
    });

    return {
      formats: byType.map((row) => ({
        content_type: row.contentType,
        published: row._count._all,
        views: Number(row._sum.viewsCount ?? 0),
        unique_viewers: Number(row._sum.uniqueViewersCount ?? 0),
        likes: Number(row._sum.reactionsCount ?? 0),
        comments: Number(row._sum.repliesCount ?? 0),
        saves: Number(row._sum.savesCount ?? 0),
        shares: Number(row._sum.sharesCount ?? 0),
        product_clicks: Number(row._sum.productClicksCount ?? 0),
        orders: Number(row._sum.ordersCount ?? 0),
        watch_time_ms: Number(row._sum.watchTimeMs ?? 0),
      })),
      statuses: Object.fromEntries(
        byStatus.map((row) => [row.status.toLowerCase(), row._count._all]),
      ),
    };
  }

  // ── «مين نشر منتجاتي» ─────────────────────────────────────────────────────

  /**
   * How far her content has travelled onto other women's pages.
   *
   * Counted from attributions rather than from `commerce_content_reshares`
   * alone, because the interesting case is the one the reshare table cannot
   * see on its own: a shopper's *original* look that tags a product this
   * boutique sells, and the reshares of that.
   */
  async reshareSummary(user: AuthUser, sellerId?: string) {
    const seller = this.subjectOrThrow(user, sellerId);

    const [totals, topContent, topProducts] = await Promise.all([
      this.prisma.commerceContentAttribution.aggregate({
        where: { sellerId: seller, source: CommerceAttributionSource.RESHARE },
        _count: { _all: true },
      }),
      this.prisma.commerceContentAttribution.groupBy({
        by: ['contentId'],
        where: { sellerId: seller, source: CommerceAttributionSource.RESHARE },
        _count: { _all: true },
        orderBy: { _count: { contentId: 'desc' } },
        take: 10,
      }),
      this.prisma.commerceContentAttribution.groupBy({
        by: ['productId'],
        where: {
          sellerId: seller,
          source: CommerceAttributionSource.RESHARE,
          productId: { not: null },
        },
        _count: { _all: true },
        orderBy: { _count: { productId: 'desc' } },
        take: 10,
      }),
    ]);

    // Distinct women, which `groupBy` cannot give and a COUNT(DISTINCT) can.
    const [{ promoters }] = await this.prisma.$queryRaw<
      { promoters: bigint }[]
    >`SELECT count(DISTINCT "actor_id") AS promoters
        FROM "commerce_content_attributions"
       WHERE "seller_id" = ${seller}::uuid AND "source" = 'RESHARE'`;

    const contentIds = topContent.map((row) => row.contentId);
    const productIds = topProducts
      .map((row) => row.productId)
      .filter((id): id is string => id !== null);

    const [contents, products] = await Promise.all([
      contentIds.length
        ? this.prisma.commerceContent.findMany({
            where: { id: { in: contentIds } },
            select: {
              id: true,
              title: true,
              body: true,
              contentType: true,
              media: { orderBy: { sortOrder: 'asc' }, take: 1, select: { url: true } },
            },
          })
        : Promise.resolve([]),
      productIds.length
        ? this.prisma.product.findMany({
            where: { id: { in: productIds } },
            select: {
              id: true,
              title: true,
              media: { orderBy: { sortOrder: 'asc' }, take: 1, select: { url: true } },
            },
          })
        : Promise.resolve([]),
    ]);

    const contentById = new Map(contents.map((row) => [row.id, row]));
    const productById = new Map(products.map((row) => [row.id, row]));

    return {
      total_reshares: totals._count._all,
      promoters: Number(promoters),
      top_content: topContent.map((row) => {
        const content = contentById.get(row.contentId);
        return {
          content_id: row.contentId,
          reshares: row._count._all,
          content_type: content?.contentType ?? null,
          title: content?.title ?? content?.body?.slice(0, 80) ?? null,
          image_url: content?.media[0]?.url ?? null,
        };
      }),
      top_products: topProducts.map((row) => {
        const product = row.productId ? productById.get(row.productId) : null;
        return {
          product_id: row.productId,
          reshares: row._count._all,
          title: product?.title ?? null,
          image_url: product?.media[0]?.url ?? null,
        };
      }),
    };
  }

  /**
   * The women themselves.
   *
   * Named only where her page is open — see `serializePromoter`, which is the
   * single place that decision is made so no route can leak past it. This is
   * also the list a future ambassador programme reads: the columns it needs
   * (`campaign_key`, `coupon_id`) already exist on the reshare row, so the
   * programme is a write path and a join, not a migration.
   */
  async promoters(user: AuthUser, page: PaginationDto, sellerId?: string) {
    const seller = this.subjectOrThrow(user, sellerId);

    const grouped = await this.prisma.commerceContentAttribution.groupBy({
      by: ['actorId'],
      where: { sellerId: seller, source: CommerceAttributionSource.RESHARE },
      _count: { _all: true },
      _max: { createdAt: true },
      orderBy: { _count: { actorId: 'desc' } },
      skip: page.skip,
      take: page.limit,
    });

    const distinct = await this.prisma.commerceContentAttribution.findMany({
      where: { sellerId: seller, source: CommerceAttributionSource.RESHARE },
      select: { actorId: true },
      distinct: ['actorId'],
    });

    if (grouped.length === 0) {
      return {
        // `data`, not `items`: this is a customer-style paged read and every
        // one of those speaks the same envelope. `items`/`has_more` is the
        // *admin* envelope, and mixing the two is how a client ends up with
        // two pagers.
        data: [],
        pagination: buildMeta(page.page, page.limit, distinct.length, 0),
      };
    }

    const actorIds = grouped.map((row) => row.actorId);
    const [actors, productCounts] = await Promise.all([
      this.prisma.user.findMany({
        where: { id: { in: actorIds } },
        select: {
          id: true,
          name: true,
          username: true,
          imageUrl: true,
          profileIsPublic: true,
        },
      }),
      this.prisma.commerceContentAttribution.groupBy({
        by: ['actorId', 'productId'],
        where: {
          sellerId: seller,
          source: CommerceAttributionSource.RESHARE,
          actorId: { in: actorIds },
          productId: { not: null },
        },
      }),
    ]);

    const actorById = new Map(actors.map((actor) => [actor.id, actor]));
    const productsPerActor = new Map<string, number>();
    for (const row of productCounts) {
      productsPerActor.set(
        row.actorId,
        (productsPerActor.get(row.actorId) ?? 0) + 1,
      );
    }

    return {
      data: grouped
        .map((row) => {
          const actor = actorById.get(row.actorId);
          if (!actor) return null;
          return serializePromoter({
            actor,
            reshares: row._count._all,
            products: productsPerActor.get(row.actorId) ?? 0,
            lastAt: row._max.createdAt ?? new Date(0),
          });
        })
        .filter((row): row is NonNullable<typeof row> => row !== null),
      pagination: buildMeta(
        page.page,
        page.limit,
        distinct.length,
        grouped.length,
      ),
    };
  }

  /** Everything about one piece, for its author. */
  async forContent(user: AuthUser, contentId: string) {
    const content = await this.prisma.commerceContent.findUnique({
      where: { id: contentId },
      select: {
        id: true,
        authorId: true,
        contentType: true,
        impressionsCount: true,
        viewsCount: true,
        uniqueViewersCount: true,
        reactionsCount: true,
        repliesCount: true,
        savesCount: true,
        sharesCount: true,
        productClicksCount: true,
        ordersCount: true,
        watchTimeMs: true,
        revenueGenerated: true,
        revenueCurrency: true,
        _count: { select: { reshares: true } },
      },
    });
    if (!content) throw new NotFoundException('Content not found');
    assertCanManage(content.authorId, user);

    const clicksByProduct = await this.prisma.commerceContentEvent.groupBy({
      by: ['productId'],
      where: { contentId, type: 'PRODUCT_CLICK', productId: { not: null } },
      _count: { _all: true },
    });

    return {
      content_id: content.id,
      content_type: content.contentType,
      impressions: Number(content.impressionsCount),
      views: Number(content.viewsCount),
      unique_viewers: Number(content.uniqueViewersCount),
      likes: Number(content.reactionsCount),
      comments: Number(content.repliesCount),
      saves: Number(content.savesCount),
      shares: Number(content.sharesCount),
      reshares: content._count.reshares,
      product_clicks: Number(content.productClicksCount),
      orders: Number(content.ordersCount),
      watch_time_ms: Number(content.watchTimeMs),
      revenue: {
        amount: content.revenueGenerated.toString(),
        currency: content.revenueCurrency,
      },
      product_clicks_by_product: clicksByProduct.map((row) => ({
        product_id: row.productId,
        clicks: row._count._all,
      })),
    };
  }

  /**
   * Whose numbers are being asked for.
   *
   * A seller asks about herself and needs no argument. Staff may name a seller;
   * nobody else may, which is the check that stops one boutique reading
   * another's promoter list by guessing a uuid.
   */
  private subjectOrThrow(user: AuthUser, sellerId?: string): string {
    if (!sellerId || sellerId === user.id) return user.id;
    try {
      assertCanManage(sellerId, user);
    } catch {
      throw new ForbiddenException('You can only read your own analytics');
    }
    return sellerId;
  }
}
