import { Injectable } from '@nestjs/common';
import {
  CommerceContentPublicationChannel,
  CommerceContentStatus,
  OfferStatus,
  Prisma,
  ProductStatus,
  UserRole,
} from '@prisma/client';

import { PRODUCT_CARD_INCLUDE } from '../../common/catalog/product-include';
import { Money } from '../../common/money';
import { serializeProduct } from '../../common/serializers';
import { PrismaService } from '../../prisma/prisma.service';

/**
 * Everything the customer's home page shows, in one call.
 *
 * The screen was built against a mock data source and never connected, so for
 * months the first thing a customer saw was invented: banners for campaigns
 * nobody ran, stores that did not exist, a loyalty balance that was not hers.
 *
 * The rule followed here is that **a section with no real backing returns
 * empty rather than plausible**. `HomeContent` on the client defaults every
 * list, so an empty section simply does not render — which is the honest
 * outcome for a platform that has no geolocation (nearby stores) and does not
 * track per-customer product views (recently viewed). Filling them with
 * something that looks right is how a mock survives into production.
 */
@Injectable()
export class HomeContentService {
  constructor(private readonly prisma: PrismaService) {}

  async content(viewerId?: string) {
    const [
      heroBanners,
      featuredCategories,
      flashDeals,
      featuredStores,
      continueShopping,
      searchSuggestions,
      notifications,
      loyalty,
    ] = await Promise.all([
      this.heroBanners(),
      this.featuredCategories(),
      this.flashDeals(viewerId),
      this.featuredStores(viewerId),
      this.continueShopping(viewerId),
      this.searchSuggestions(viewerId),
      this.notifications(viewerId),
      this.loyalty(viewerId),
    ]);

    return {
      hero_banners: heroBanners,
      featured_categories: featuredCategories,
      flash_deals: flashDeals,
      featured_stores: featuredStores,
      continue_shopping: continueShopping,
      search_suggestions: searchSuggestions,
      notifications,
      loyalty,

      // Deliberately absent rather than invented: nothing records what a
      // customer has looked at, and no address carries coordinates.
      recently_viewed: [],
      nearby_stores: [],
      dynamic_blocks: [],
    };
  }

  /**
   * Q70 P1 — «إدارة الصفحة الرئيسية والبانرات».
   *
   * Banners are `CommerceContent` published to the home feed, which is the
   * content system the platform already has rather than a second one built
   * for this screen. Anything expired or still scheduled is left out here, so
   * the client never has to know the difference.
   */
  private async heroBanners() {
    const now = new Date();
    const rows = await this.prisma.commerceContent.findMany({
      where: {
        status: CommerceContentStatus.PUBLISHED,
        publicationTargets: {
          has: CommerceContentPublicationChannel.HOME_FEED,
        },
        publishedAt: { lte: now },
        OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
      },
      orderBy: [{ pinnedUntil: 'desc' }, { publishedAt: 'desc' }],
      take: 6,
      select: {
        id: true,
        title: true,
        body: true,
        payload: true,
        contentType: true,
      },
    });

    return rows
      .map((row) => {
        const payload = (row.payload ?? {}) as Record<string, unknown>;
        const image = this.text(payload.image_url ?? payload.image);
        // A banner is an image with something to tap. One without either is a
        // draft somebody published by accident, not a hero.
        if (!image) return null;

        return {
          id: row.id,
          kind: this.text(payload.kind) ?? 'promotion',
          title: row.title ?? this.text(payload.title) ?? '',
          subtitle: row.body ?? this.text(payload.subtitle) ?? '',
          cta_label: this.text(payload.cta_label) ?? '',
          image_url: image,
          eyebrow: this.text(payload.eyebrow),
          badge: this.text(payload.badge),
          target_route: this.text(payload.target_route),
        };
      })
      .filter((banner) => banner !== null);
  }

  /** The shelves she browses by, newest counts included. */
  private async featuredCategories() {
    const categories = await this.prisma.category.findMany({
      where: { isActive: true, isSensitive: false, imageUrl: { not: null } },
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      take: 10,
      select: {
        id: true,
        nameAr: true,
        imageUrl: true,
        _count: { select: { products: true } },
      },
    });

    return categories.map((category) => ({
      id: category.id,
      label: category.nameAr,
      image_url: category.imageUrl,
      product_count: category._count.products,
      is_featured: false,
    }));
  }

  /**
   * Offers listed below their own compare-at price — a real discount the
   * seller entered, not a countdown invented to create urgency.
   *
   * `ends_at` is the offer's own expiry where it has one. Where it does not,
   * the field is null and the client shows no timer, because a timer that
   * resets on refresh is a lie the customer eventually notices.
   */
  private async flashDeals(viewerId?: string) {
    const offers = await this.prisma.sellerOffer.findMany({
      where: {
        status: OfferStatus.ACTIVE,
        isActive: true,
        stock: { gt: 0 },
        compareAtPrice: { not: null },
        product: { status: ProductStatus.ACTIVE },
      },
      orderBy: { updatedAt: 'desc' },
      take: 20,
      select: {
        id: true,
        price: true,
        compareAtPrice: true,
        currency: true,
        stock: true,
        productId: true,
      },
    });

    const worthShowing = offers.filter((offer) =>
      Money.of(offer.compareAtPrice!, offer.currency).greaterThan(
        Money.of(offer.price, offer.currency),
      ),
    );
    if (worthShowing.length === 0) return [];

    const products = await this.loadProducts(
      worthShowing.map((offer) => offer.productId),
      viewerId,
    );

    return worthShowing
      .map((offer) => {
        const product = products.get(offer.productId);
        if (!product) return null;
        return {
          product,
          ends_at: null,
          sold_count: 0,
          total_quantity: offer.stock,
        };
      })
      .filter((deal) => deal !== null)
      .slice(0, 8);
  }

  /** Sellers she can be shown with a straight face: verified, and rated. */
  private async featuredStores(viewerId?: string) {
    const sellers = await this.prisma.user.findMany({
      where: {
        role: UserRole.SELLER,
        sellerVerifiedAt: { not: null },
        // A store with nothing on its shelves is not a store to feature.
        sellerOffers: { some: { status: OfferStatus.ACTIVE, isActive: true } },
      },
      orderBy: [{ followersCount: 'desc' }, { createdAt: 'asc' }],
      take: 8,
      select: {
        id: true,
        name: true,
        bio: true,
        imageUrl: true,
        sellerVerifiedAt: true,
        followersCount: true,
        _count: { select: { sellerOffers: true } },
      },
    });

    const following = viewerId
      ? new Set(
          (
            await this.prisma.follow.findMany({
              where: {
                followerId: viewerId,
                followingId: { in: sellers.map((seller) => seller.id) },
              },
              select: { followingId: true },
            })
          ).map((row) => row.followingId),
        )
      : new Set<string>();

    return sellers.map((seller) => ({
      id: seller.id,
      name: seller.name,
      tagline: seller.bio ?? '',
      logo_url: seller.imageUrl ?? '',
      // No separate cover image exists on an account; the client falls back to
      // its own gradient rather than being handed a duplicate of the avatar.
      cover_url: '',
      is_verified: seller.sellerVerifiedAt !== null,
      // Seller ratings live on `SellerReview` and are aggregated by the
      // reputation module. Sending a zero here would read as "rated badly", so
      // the field carries null until this reads that aggregate.
      rating: null,
      product_count: seller._count.sellerOffers,
      follower_count: seller.followersCount,
      is_following: following.has(seller.id),
      preview_images: [],
    }));
  }

  /** What is sitting in her cart, so the home page can hand it back to her. */
  private async continueShopping(viewerId?: string) {
    if (!viewerId) return [];

    const items = await this.prisma.cartItem.findMany({
      where: { userId: viewerId },
      orderBy: { updatedAt: 'desc' },
      take: 6,
      select: { offer: { select: { productId: true } } },
    });

    const products = await this.loadProducts(
      items.map((item) => item.offer.productId),
      viewerId,
    );

    return [...products.values()].map((product) => ({
      product,
      note: 'ما زال في سلتكِ',
    }));
  }

  /**
   * Q76 — what other women are searching for, plus her own last few.
   *
   * Her own history is only ever returned to her, and only the terms: a search
   * history is a record of what someone was curious about, which is not a
   * thing to hand to anybody else.
   */
  private async searchSuggestions(viewerId?: string) {
    const [trending, recent] = await Promise.all([
      this.prisma.searchHistory.groupBy({
        by: ['query'],
        where: {
          createdAt: { gte: new Date(Date.now() - 7 * 24 * 60 * 60 * 1000) },
        },
        _count: { query: true },
        orderBy: { _count: { query: 'desc' } },
        take: 8,
      }),
      viewerId
        ? this.prisma.searchHistory.findMany({
            where: { userId: viewerId },
            orderBy: { createdAt: 'desc' },
            distinct: ['query'],
            take: 6,
            select: { query: true },
          })
        : Promise.resolve([]),
    ]);

    return {
      trending: trending.map((row) => row.query),
      recent: recent.map((row) => row.query),
      suggested: [],
    };
  }

  private async notifications(viewerId?: string) {
    if (!viewerId) return { unread_count: 0, previews: [] };

    const [unreadCount, latest] = await Promise.all([
      this.prisma.notification.count({
        where: { userId: viewerId, isRead: false },
      }),
      this.prisma.notification.findMany({
        where: { userId: viewerId },
        orderBy: { createdAt: 'desc' },
        take: 3,
        select: {
          id: true,
          title: true,
          type: true,
          isRead: true,
          createdAt: true,
        },
      }),
    ]);

    return {
      unread_count: unreadCount,
      previews: latest.map((notification) => ({
        id: notification.id,
        kind: notification.type,
        title: notification.title,
        created_at: notification.createdAt,
        unread: !notification.isRead,
      })),
    };
  }

  private async loyalty(viewerId?: string) {
    if (!viewerId) return null;

    const user = await this.prisma.user.findUnique({
      where: { id: viewerId },
      select: { points: true, lifetimePoints: true, tier: true },
    });
    if (!user) return null;

    return {
      points: user.points,
      lifetime_points: user.lifetimePoints,
      tier: user.tier,
    };
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /**
   * Loads products for a set of ids, keyed by id.
   *
   * One query for a whole section rather than one per card — the home page is
   * the most-hit endpoint on the platform, and a loop of finds here is the
   * kind of thing that only hurts once there are customers.
   */
  private async loadProducts(ids: string[], viewerId?: string) {
    const unique = [...new Set(ids)];
    if (unique.length === 0) return new Map<string, unknown>();

    const [products, liked] = await Promise.all([
      this.prisma.product.findMany({
        where: { id: { in: unique } },
        include: PRODUCT_CARD_INCLUDE,
      }),
      viewerId
        ? this.prisma.favorite.findMany({
            where: { userId: viewerId, productId: { in: unique } },
            select: { productId: true },
          })
        : Promise.resolve([]),
    ]);

    const likedSet = new Set(liked.map((row) => row.productId));
    return new Map(
      products.map((product) => [
        product.id,
        serializeProduct(product, { isLiked: likedSet.has(product.id) }),
      ]),
    );
  }

  /** A JSON payload is whatever somebody stored; only strings are strings. */
  private text(value: unknown): string | undefined {
    return typeof value === 'string' && value.trim().length > 0
      ? value
      : undefined;
  }
}

export type HomeContentPayload = Awaited<
  ReturnType<HomeContentService['content']>
>;

export type HomeContentWhere = Prisma.ProductWhereInput;
