import { Injectable } from '@nestjs/common';
import {
  CommerceAuthorKind,
  CommerceContentPublicationChannel,
  CommerceContentStatus,
  MediaType,
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
      nearbyStores,
    ] = await Promise.all([
      this.heroBanners(),
      this.featuredCategories(),
      this.flashDeals(viewerId),
      this.featuredStores(viewerId),
      this.continueShopping(viewerId),
      this.searchSuggestions(viewerId),
      this.notifications(viewerId),
      this.loyalty(viewerId),
      this.nearbyStores(viewerId),
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
      nearby_stores: nearbyStores,

      // Still deliberately absent rather than invented: nothing records what a
      // customer has looked at, and no admin has configured a block.
      recently_viewed: [],
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
        authorId: true,
        authorKind: true,
        // The artwork lives on the media relation — that is where the content
        // system, the composer and the seed all put it. Reading it out of
        // `payload.image_url` alone meant every real banner failed the "no
        // image" test below and the hero carousel was permanently empty.
        media: {
          where: { type: MediaType.image },
          orderBy: { sortOrder: 'asc' },
          take: 1,
          select: { url: true },
        },
        // What the banner is actually advertising. Without this the carousel
        // was scenery: an auto-advancing, tappable, gorgeous no-op.
        productTags: {
          orderBy: { sortOrder: 'asc' },
          take: 1,
          select: { productId: true },
        },
      },
    });

    return rows
      .map((row) => {
        const payload = (row.payload ?? {}) as Record<string, unknown>;
        const image =
          row.media[0]?.url ?? this.text(payload.image_url ?? payload.image);
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
          target_route: this.bannerRoute(row, payload),
        };
      })
      .filter((banner) => banner !== null);
  }

  /**
   * Where a banner takes her.
   *
   * An explicit `target_route` in the payload wins — that is the campaign
   * manager's own answer. Failing that the banner still has to lead somewhere,
   * because a full-bleed hero with a CTA button that does nothing is worse
   * than no hero at all: every one published so far carries tagged products
   * and no route, so the carousel was five beautiful dead ends.
   *
   * The tagged piece comes first (it is what the artwork is showing), then the
   * boutique that published it. Both are routes the client already answers —
   * `/product-details?id=…` and `/user/:id` — and the shapes are the client's,
   * so they are spelled exactly as `RoutePaths` builds them.
   */
  private bannerRoute(
    row: {
      authorId: string;
      authorKind: CommerceAuthorKind;
      productTags: { productId: string }[];
    },
    payload: Record<string, unknown>,
  ): string {
    const explicit = this.text(payload.target_route);
    if (explicit) return explicit;

    const tagged = row.productTags[0]?.productId;
    if (tagged) return `/product-details?id=${tagged}`;

    // The boutique that published it — but only if a boutique did. An
    // editorial banner is published by Reem itself, and sending a shopper to
    // the operations account's profile is a worse dead end than the one this
    // fallback exists to prevent, because it looks like a real destination.
    if (row.authorKind === CommerceAuthorKind.SELLER) {
      return `/user/${row.authorId}`;
    }
    return '/categories';
  }

  /** The shelves she browses by, newest counts included. */
  private async featuredCategories() {
    const categories = await this.prisma.category.findMany({
      where: { isActive: true, isSensitive: false, imageUrl: { not: null } },
      orderBy: [{ sortOrder: 'asc' }, { nameAr: 'asc' }],
      take: 10,
      select: { id: true, slug: true, nameAr: true, imageUrl: true },
    });
    if (categories.length === 0) return [];

    // The count has to cover the whole subtree, not the direct children.
    // Products hang off leaves ("فساتين"), while the tiles on this rail are
    // departments and roots — counting only the rows that point at the tile
    // itself made every tile read "0".
    const descendants = await this.descendantsOf(
      categories.map((category) => category.id),
    );
    const counts = await this.prisma.product.groupBy({
      by: ['categoryId'],
      where: {
        status: ProductStatus.ACTIVE,
        categoryId: { in: [...new Set([...descendants.values()].flat())] },
      },
      _count: { _all: true },
    });
    const byCategory = new Map(
      counts.map((row) => [row.categoryId, row._count._all]),
    );

    return categories.map((category) => ({
      id: category.id,
      // The tile has to be able to open the department. Without a slug the
      // client had only the Arabic name to route with, and pushed
      // `/category/أزياء` — a path nothing matches.
      slug: category.slug,
      label: category.nameAr,
      image_url: category.imageUrl,
      product_count: (descendants.get(category.id) ?? []).reduce(
        (sum, id) => sum + (byCategory.get(id) ?? 0),
        0,
      ),
      is_featured: false,
    }));
  }

  /**
   * Every category id at or beneath each of [roots], keyed by root. The tree
   * is three levels deep and tiny, so this walks it breadth-first rather than
   * reaching for a recursive CTE.
   */
  private async descendantsOf(roots: string[]): Promise<Map<string, string[]>> {
    const subtree = new Map(roots.map((id) => [id, [id]]));
    let frontier = roots.map((id) => ({ root: id, id }));

    while (frontier.length > 0) {
      const children = await this.prisma.category.findMany({
        where: {
          isActive: true,
          parentId: { in: frontier.map((node) => node.id) },
        },
        select: { id: true, parentId: true },
      });
      if (children.length === 0) break;

      const rootOf = new Map(frontier.map((node) => [node.id, node.root]));
      frontier = [];
      for (const child of children) {
        const root = child.parentId ? rootOf.get(child.parentId) : undefined;
        if (!root) continue;
        subtree.get(root)!.push(child.id);
        frontier.push({ root, id: child.id });
      }
    }

    return subtree;
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

    // One card per product, not per offer. Two sellers discounting the same
    // piece produced two identical tiles side by side in the rail — same
    // photograph, same title, same price, because the card renders the
    // product's best offer either way. The first offer wins, which is the
    // most recently updated one and so the freshest deal.
    const seen = new Set<string>();
    const worthShowing = offers.filter((offer) => {
      const isDeal = Money.of(offer.compareAtPrice!, offer.currency).greaterThan(
        Money.of(offer.price, offer.currency),
      );
      if (!isDeal || seen.has(offer.productId)) return false;
      seen.add(offer.productId);
      return true;
    });
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

    // The two things that made these cards look unfinished: no rating, and an
    // empty teaser strip. Both were available all along — the rating on
    // `SellerReputation`, the shots on the pieces each boutique is selling.
    const [reputations, previews] = await Promise.all([
      this.prisma.sellerReputation.findMany({
        where: { sellerId: { in: sellers.map((seller) => seller.id) } },
        select: { sellerId: true, averageRating: true, reviewsCount: true },
      }),
      this.storePreviews(sellers.map((seller) => seller.id)),
    ]);
    const ratingOf = new Map(
      reputations.map((row) => [
        row.sellerId,
        // A boutique nobody has reviewed yet has no rating — not a zero, which
        // on a five-star scale reads as "rated badly".
        row.reviewsCount > 0 ? row.averageRating : null,
      ]),
    );

    return sellers.map((seller) => ({
      id: seller.id,
      name: seller.name,
      tagline: seller.bio ?? '',
      logo_url: seller.imageUrl ?? '',
      // No separate cover image exists on an account; the client falls back to
      // its own gradient rather than being handed a duplicate of the avatar.
      cover_url: '',
      is_verified: seller.sellerVerifiedAt !== null,
      rating: ratingOf.get(seller.id) ?? null,
      product_count: seller._count.sellerOffers,
      follower_count: seller.followersCount,
      is_following: following.has(seller.id),
      preview_images: previews.get(seller.id) ?? [],
    }));
  }

  /**
   * A few shots from each boutique's shelves — the teaser strip on its card.
   *
   * One query for every store on the rail, bucketed here, rather than eight
   * round trips in a loop.
   */
  private async storePreviews(sellerIds: string[]): Promise<Map<string, string[]>> {
    const previews = new Map<string, string[]>();
    if (sellerIds.length === 0) return previews;

    const offers = await this.prisma.sellerOffer.findMany({
      where: {
        sellerId: { in: sellerIds },
        status: OfferStatus.ACTIVE,
        isActive: true,
        product: { status: ProductStatus.ACTIVE },
      },
      orderBy: { updatedAt: 'desc' },
      // Enough rows that every store on the rail reaches its three, even when
      // one boutique holds most of them.
      take: sellerIds.length * 12,
      select: {
        sellerId: true,
        product: {
          select: {
            media: {
              where: { type: MediaType.image },
              orderBy: { sortOrder: 'asc' },
              take: 1,
              select: { url: true },
            },
          },
        },
      },
    });

    for (const offer of offers) {
      const url = offer.product.media[0]?.url;
      if (!url) continue;
      const bucket = previews.get(offer.sellerId) ?? [];
      if (bucket.length >= 3 || bucket.includes(url)) continue;
      previews.set(offer.sellerId, [...bucket, url]);
    }

    return previews;
  }

  /**
   * Q?? — «بوتيكات قريبة منك».
   *
   * The platform has no coordinates: no address carries a lat/long and no
   * store has opening hours, so the rail that used to sit here asked for
   * "location", flipped a boolean nothing read, and then rendered an empty
   * list forever. What the platform *does* know is where she has her orders
   * delivered and where each boutique trades — and in Syria that is the
   * distinction a shopper actually cares about, because it decides whether a
   * piece arrives the same day (Q61/Q62).
   *
   * So "near you" means her governorate, with her own city first. No
   * kilometres, because a kilometre figure would have to be invented.
   */
  private async nearbyStores(viewerId?: string) {
    if (!viewerId) return [];

    const where = await this.viewerLocality(viewerId);
    if (!where) return [];

    const sellers = await this.prisma.user.findMany({
      where: {
        role: UserRole.SELLER,
        sellerVerifiedAt: { not: null },
        sellerOffers: { some: { status: OfferStatus.ACTIVE, isActive: true } },
      },
      orderBy: [{ followersCount: 'desc' }, { createdAt: 'asc' }],
      take: 60,
      select: {
        id: true,
        name: true,
        imageUrl: true,
        location: true,
        sellerVerification: {
          select: { businessAddress: true, warehouseAddress: true },
        },
      },
    });

    const matches = sellers
      .map((seller) => {
        const haystack = [
          seller.location,
          seller.sellerVerification?.businessAddress,
          seller.sellerVerification?.warehouseAddress,
        ]
          .filter((part): part is string => !!part)
          .join(' | ');

        const sameCity = where.city ? haystack.includes(where.city) : false;
        const sameGovernorate = where.governorate
          ? haystack.includes(where.governorate)
          : false;
        if (!sameCity && !sameGovernorate) return null;

        return {
          seller,
          sameCity,
          // Her own city reads first; the rest of the governorate follows.
          area: sameCity ? where.city! : where.governorate!,
        };
      })
      .filter((match) => match !== null)
      .sort((a, b) => Number(b.sameCity) - Number(a.sameCity))
      .slice(0, 10);

    if (matches.length === 0) return [];

    const reputations = await this.prisma.sellerReputation.findMany({
      where: { sellerId: { in: matches.map((match) => match.seller.id) } },
      select: { sellerId: true, averageRating: true, reviewsCount: true },
    });
    const ratingOf = new Map(
      reputations.map((row) => [
        row.sellerId,
        row.reviewsCount > 0 ? row.averageRating : null,
      ]),
    );

    return matches.map((match) => ({
      id: match.seller.id,
      name: match.seller.name,
      logo_url: match.seller.imageUrl ?? '',
      area: match.area,
      same_city: match.sameCity,
      rating: ratingOf.get(match.seller.id) ?? null,
    }));
  }

  /**
   * Where she is, as the platform actually knows it: the governorate and city
   * on her default delivery address, falling back to the free-text locality on
   * her profile («دمشق، سوريا») for a shopper who has not saved one yet.
   */
  private async viewerLocality(
    viewerId: string,
  ): Promise<{ governorate?: string; city?: string } | null> {
    const address = await this.prisma.address.findFirst({
      where: { userId: viewerId },
      orderBy: [{ isDefault: 'desc' }, { createdAt: 'desc' }],
      select: { governorate: true, city: true },
    });
    if (address) {
      return {
        governorate: address.governorate.trim() || undefined,
        city: address.city.trim() || undefined,
      };
    }

    const user = await this.prisma.user.findUnique({
      where: { id: viewerId },
      select: { location: true },
    });
    const city = user?.location?.split(/[,،]/)[0]?.trim();
    return city ? { city } : null;
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
