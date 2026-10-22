import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  CommerceContentStatus,
  CommerceContentVisibility,
  Currency,
  MediaType,
  Prisma,
  ProductStatus,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { LIVE_OFFER_WHERE } from '../../common/catalog/product-include';
import { SharePreview } from './share-preview';
import { appRouteFor, buildPath, SHARE_PATHS, ShareLinkKind } from './share-links';

/**
 * Turns an id in a shared URL back into something worth looking at.
 *
 * ## Why these are their own queries
 *
 * Every one of these facts can be had from an existing service — `products
 * .detail`, `ContentFeedService`, the profile serializer. None of them is used
 * here, on purpose:
 *
 *  - They are written for a signed-in shopper and personalise accordingly.
 *    This runs for WhatsApp's crawler, which is nobody.
 *  - `products.detail` increments `views_count` and writes an analytics row. A
 *    link pasted into a group of forty would have counted forty views before
 *    anyone tapped it.
 *  - They return the whole object graph — every offer, every variant, twenty
 *    versions of the content row. A preview needs a title, a picture and a
 *    price, and this path is on the critical route of a cold Render instance.
 *
 * ## Visibility fails closed
 *
 * The viewer is always anonymous here, so every resolver applies the same rule
 * a signed-out visitor gets and returns `null` otherwise. Returning a redacted
 * preview instead would be worse than useless: a messenger's crawler caches
 * what it is given, and a cache is not something a privacy setting can reach
 * into afterwards.
 */
@Injectable()
export class SharePreviewService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly config: ConfigService,
  ) {}

  /**
   * [requestOrigin] is only ever a fallback for turning a stored relative media
   * path into the absolute URL Open Graph requires. Configuration wins, because
   * the canonical origin has to match what the apps declare — but in
   * development nobody has configured one and `MEDIA_DRIVER=local` stores paths,
   * so without this the developer testing this very feature is the one person
   * whose preview has no picture in it.
   */
  async resolve(
    kind: ShareLinkKind,
    params: Record<string, string>,
    requestOrigin = '',
  ): Promise<SharePreview | null> {
    const origin = this.publicOrigin() || requestOrigin.replace(/\/+$/, '');
    switch (kind) {
      case 'product':
        return this.product(params.id, origin);
      case 'content':
        return this.content(params.id, origin);
      case 'profile':
        return this.profile(params.id, 'profile', origin);
      case 'storefront':
        return this.profile(params.id, 'storefront', origin);
      case 'collection':
        return this.collection(params.key, origin);
      case 'room-invite':
        return this.roomInvite(params.slug, origin);
      case 'referral':
        return this.referral(params.code, origin);
      case 'salon':
        return this.salon(params.id, origin);
      default:
        return null;
    }
  }

  // ── Kinds ────────────────────────────────────────────────────────────────

  private async product(id: string, origin: string): Promise<SharePreview | null> {
    if (!isUuid(id)) return null;

    const product = await this.prisma.product.findFirst({
      where: { id, status: ProductStatus.ACTIVE },
      select: {
        id: true,
        title: true,
        description: true,
        rating: true,
        reviewsCount: true,
        media: {
          where: { type: MediaType.image },
          orderBy: { sortOrder: 'asc' },
          take: 1,
          select: { url: true },
        },
        brand: { select: { nameAr: true, nameEn: true } },
        offers: {
          where: LIVE_OFFER_WHERE,
          // The same ordering the catalogue uses, so the price in a WhatsApp
          // preview is the price on the card she taps through to. `priceSyp`
          // and not `price`: the raw column is a number in whichever currency
          // the seller chose, and sorting on it once made a $9.50 offer the
          // "cheapest" beside SYP ones.
          orderBy: [{ priceSyp: 'asc' }, { price: 'asc' }],
          take: 1,
          select: {
            price: true,
            compareAtPrice: true,
            currency: true,
            seller: { select: { name: true, imageUrl: true, isVerified: true } },
          },
        },
      },
    });
    if (!product) return null;

    const offer = product.offers[0] ?? null;
    const facts: { label: string; value: string }[] = [];
    if (product.reviewsCount > 0) {
      facts.push({
        label: 'التقييم',
        value: `${product.rating.toFixed(1)} ★ (${product.reviewsCount})`,
      });
    }
    const brand = product.brand?.nameAr || product.brand?.nameEn;
    if (brand) facts.push({ label: 'الماركة', value: brand });

    return {
      kind: 'product',
      path: buildPath(SHARE_PATHS.product, { id: product.id }),
      appRoute: appRouteFor('product', { id: product.id }),
      label: 'منتج على ريم',
      title: product.title,
      description: summarise(product.description, product.title),
      // The real description or nothing. Falling back to the title here would
      // print the headline again as a paragraph under itself.
      body: product.description.trim()
        ? truncate(product.description, 320)
        : null,
      imageUrl: this.absolutise(product.media[0]?.url, origin),
      price: offer ? formatMoney(offer.price, offer.currency) : null,
      compareAtPrice:
        offer && offer.compareAtPrice && offer.compareAtPrice.greaterThan(offer.price)
          ? formatMoney(offer.compareAtPrice, offer.currency)
          : null,
      priceAmount: offer ? offer.price.toFixed(2) : null,
      priceCurrency: offer ? offer.currency : null,
      byline: offer?.seller.name ?? null,
      bylineImageUrl: this.absolutise(offer?.seller.imageUrl ?? null, origin),
      facts,
      // The product row is live but no seller lists it in stock. Saying so is
      // better than a page that looks buyable and a button that is not.
      unavailableNote: offer ? null : 'غير متوفر حالياً لدى أي بائعة',
    };
  }

  private async content(id: string, origin: string): Promise<SharePreview | null> {
    if (!isUuid(id)) return null;

    const content = await this.prisma.commerceContent.findFirst({
      where: {
        id,
        status: CommerceContentStatus.PUBLISHED,
        moderationStatus: { not: 'REJECTED' },
        // The signed-out branch of `ContentFeedService.visibilityWhere`, and
        // only that branch: a followers-only piece has no public preview.
        visibility: CommerceContentVisibility.PUBLIC,
        authorIsPublic: true,
        // An expired story is gone, not merely marked as expired. Rendering a
        // page that says «انتهت صلاحية القصة» *above her photograph and her
        // caption* would leak exactly what the 24 hours were there to take
        // away — to anyone holding a forwarded link, indefinitely. The
        // not-found page names expiry as one of the reasons instead.
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
      select: {
        id: true,
        title: true,
        body: true,
        contentType: true,
        reactionsCount: true,
        repliesCount: true,
        author: { select: { name: true, username: true, imageUrl: true } },
        media: {
          orderBy: { sortOrder: 'asc' },
          take: 1,
          select: { url: true, thumbnailUrl: true, type: true, altText: true },
        },
        productTags: {
          orderBy: { sortOrder: 'asc' },
          take: 1,
          select: {
            product: {
              select: {
                title: true,
                media: {
                  where: { type: MediaType.image },
                  orderBy: { sortOrder: 'asc' },
                  take: 1,
                  select: { url: true },
                },
              },
            },
          },
        },
      },
    });
    if (!content) return null;

    const media = content.media[0] ?? null;
    // A reel's `url` is an MP4. A crawler asked to draw that as `og:image`
    // draws nothing, so the poster frame is what travels.
    const image =
      media?.type === MediaType.video ? media.thumbnailUrl : (media?.url ?? null);

    const label =
      content.contentType === 'reel'
        ? 'ريل على ريم'
        : content.contentType === 'story'
          ? 'قصة على ريم'
          : 'منشور على ريم';

    const caption = content.title?.trim() || content.body?.trim() || '';
    const taggedProduct = content.productTags[0]?.product ?? null;
    const tagged = taggedProduct?.title;

    const facts: { label: string; value: string }[] = [];
    if (content.reactionsCount > 0n) {
      facts.push({ label: 'إعجاب', value: formatCount(content.reactionsCount) });
    }
    if (content.repliesCount > 0n) {
      facts.push({ label: 'تعليق', value: formatCount(content.repliesCount) });
    }
    if (tagged) facts.push({ label: 'القطعة', value: tagged });

    return {
      kind: 'content',
      path: buildPath(SHARE_PATHS.content, { id: content.id }),
      appRoute: appRouteFor('content', { id: content.id }),
      label,
      title: caption ? truncate(caption, 70) : `${content.author.name} على ريم`,
      // The caption is already the headline, so repeating it as the description
      // gives a messenger two identical lines. This says who wrote it and what
      // it is about instead — which is the part the headline leaves out.
      description: summarise(
        caption && caption.length > 70 ? caption : null,
        tagged
          ? `${content.author.name} تنسّق ${tagged} — على ريم`
          : `شاهدي ما نشرته ${content.author.name} على ريم`,
      ),
      body: caption || null,
      // A post with no picture of its own is usually a post *about* a piece.
      // Showing that piece beats showing a 40-pixel avatar blown up to fill a
      // preview card, and beats showing nothing.
      imageUrl:
        this.absolutise(image, origin) ??
        this.absolutise(taggedProduct?.media[0]?.url, origin) ??
        this.absolutise(content.author.imageUrl, origin),
      // Reels and stories are shot vertically; declaring it stops a messenger
      // cropping the subject out of the middle of the frame.
      imageIsPortrait: content.contentType !== 'product_post',
      byline: content.author.name,
      bylineImageUrl: this.absolutise(content.author.imageUrl, origin),
      facts,
    };
  }

  private async profile(
    id: string,
    kind: 'profile' | 'storefront',
    origin: string,
  ): Promise<SharePreview | null> {
    if (!isUuid(id)) return null;

    const user = await this.prisma.user.findFirst({
      // A closed page has no public preview at all — Q15 is a choice she made,
      // and a link somebody else shared does not override it.
      where: { id, profileIsPublic: true, disabledAt: null },
      select: {
        id: true,
        name: true,
        username: true,
        bio: true,
        imageUrl: true,
        isVerified: true,
        role: true,
        followersCount: true,
        _count: { select: { sellerOffers: { where: LIVE_OFFER_WHERE } } },
      },
    });
    if (!user) return null;

    const isSeller = user.role === 'SELLER';
    const liveOffers = user._count.sellerOffers;
    const facts: { label: string; value: string }[] = [];
    if (user.followersCount > 0) {
      facts.push({ label: 'متابِعة', value: formatCount(user.followersCount) });
    }
    if (isSeller && liveOffers > 0) {
      facts.push({ label: 'قطعة معروضة', value: formatCount(liveOffers) });
    }

    const label = isSeller ? 'بائعة على ريم' : 'صفحة على ريم';

    return {
      kind,
      path: buildPath(SHARE_PATHS[kind], { id: user.id }),
      appRoute: appRouteFor(kind, { id: user.id }),
      label: kind === 'storefront' ? 'متجر على ريم' : label,
      title: user.name,
      description: summarise(
        user.bio,
        isSeller
          ? `تسوّقي من ${user.name} على ريم`
          : `تابعي ${user.name} على ريم`,
      ),
      body: user.bio?.trim() || null,
      imageUrl: this.absolutise(user.imageUrl, origin),
      byline: `@${user.username}`,
      bylineImageUrl: this.absolutise(user.imageUrl, origin),
      facts,
    };
  }

  private async collection(key: string, origin: string): Promise<SharePreview | null> {
    const title = COLLECTION_TITLES[key];
    if (!title) return null;

    // Just enough for a cover. The shelf itself is assembled by the app.
    const product = await this.prisma.product.findFirst({
      where: { status: ProductStatus.ACTIVE, offers: { some: LIVE_OFFER_WHERE } },
      orderBy: { rankScore: 'desc' },
      select: {
        media: {
          where: { type: MediaType.image },
          orderBy: { sortOrder: 'asc' },
          take: 1,
          select: { url: true },
        },
      },
    });

    return {
      kind: 'collection',
      path: buildPath(SHARE_PATHS.collection, { key }),
      appRoute: appRouteFor('collection', { key }),
      label: 'مجموعة على ريم',
      title,
      description: `تصفّحي «${title}» على ريم`,
      imageUrl: this.absolutise(product?.media[0]?.url, origin),
    };
  }

  private async roomInvite(slug: string, origin: string): Promise<SharePreview | null> {
    const room = await this.prisma.room.findFirst({
      where: { shareSlug: slug },
      select: {
        title: true,
        note: true,
        coverUrl: true,
        isSurprise: true,
        owner: { select: { name: true, imageUrl: true } },
      },
    });
    if (!room) return null;

    return {
      kind: 'room-invite',
      path: buildPath(SHARE_PATHS['room-invite'], { slug }),
      appRoute: appRouteFor('room-invite', { slug }),
      label: 'دعوة إلى غرفة تسوّق',
      title: room.title,
      description: summarise(
        room.note,
        `دعتكِ ${room.owner.name} لتساعديها في الاختيار`,
      ),
      body: room.note?.trim() || null,
      imageUrl: this.absolutise(room.coverUrl, origin) ?? this.absolutise(room.owner.imageUrl, origin),
      byline: room.owner.name,
      bylineImageUrl: this.absolutise(room.owner.imageUrl, origin),
    };
  }

  private async referral(code: string, origin: string): Promise<SharePreview | null> {
    const referral = await this.prisma.referralCode.findFirst({
      where: {
        code,
        isActive: true,
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
      },
      select: { code: true, user: { select: { name: true, imageUrl: true } } },
    });
    if (!referral) return null;

    return {
      kind: 'referral',
      path: buildPath(SHARE_PATHS.referral, { code: referral.code }),
      // Nothing in the app consumes a code yet, so the invitation opens the
      // catalogue rather than a screen that would silently drop it.
      appRoute: '/home',
      label: 'دعوة إلى ريم',
      title: `${referral.user.name} تدعوكِ إلى ريم`,
      description:
        'سوق نسائي للأزياء والجمال — استخدمي رمز الدعوة عند إنشاء حسابكِ.',
      imageUrl: this.absolutise(referral.user.imageUrl, origin),
      byline: referral.user.name,
      bylineImageUrl: this.absolutise(referral.user.imageUrl, origin),
      facts: [{ label: 'رمز الدعوة', value: referral.code }],
    };
  }

  /** الصالونات والجمال — by slug or by id, whichever the link carries. */
  private async salon(
    idOrSlug: string,
    origin: string,
  ): Promise<SharePreview | null> {
    const salon = await this.prisma.salon.findFirst({
      // Live only. A draft a woman is still filling in, and a salon an
      // operator has suspended, are both 404 to a stranger holding a link.
      where: {
        status: 'ACTIVE',
        ...(isUuid(idOrSlug) ? { id: idOrSlug } : { slug: idOrSlug }),
      },
      select: {
        id: true,
        slug: true,
        name: true,
        tagline: true,
        about: true,
        city: true,
        governorate: true,
        rating: true,
        reviewsCount: true,
        servicesCount: true,
        homeService: true,
        coverUrl: true,
        logoUrl: true,
        services: {
          where: { isActive: true },
          orderBy: [{ priceSyp: 'asc' }, { price: 'asc' }],
          take: 1,
          select: { price: true, currency: true },
        },
      },
    });
    if (!salon) return null;

    const cheapest = salon.services[0] ?? null;
    const facts: { label: string; value: string }[] = [];
    if (salon.reviewsCount > 0) {
      facts.push({
        label: 'التقييم',
        value: `${salon.rating.toFixed(1)} ★ (${salon.reviewsCount})`,
      });
    }
    if (salon.servicesCount > 0) {
      facts.push({ label: 'الخدمات', value: String(salon.servicesCount) });
    }
    if (salon.homeService) {
      facts.push({ label: 'خدمة منزلية', value: 'متاحة' });
    }

    return {
      kind: 'salon',
      // The canonical link is the slug's, whichever form was followed.
      path: buildPath(SHARE_PATHS.salon, { id: salon.slug }),
      appRoute: appRouteFor('salon', { id: salon.slug }),
      label: 'صالون على ريم',
      title: salon.name,
      description: summarise(
        salon.tagline ?? salon.about,
        `${salon.city} — احجزي موعدكِ على ريم`,
      ),
      body: salon.about?.trim() || null,
      imageUrl:
        this.absolutise(salon.coverUrl, origin) ??
        this.absolutise(salon.logoUrl, origin),
      price: cheapest ? formatMoney(cheapest.price, cheapest.currency) : null,
      byline: `${salon.governorate} · ${salon.city}`,
      facts,
    };
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /**
   * Media URLs are stored as the driver wrote them: absolute for Supabase
   * Storage, a path on this API for local disk. Open Graph accepts only the
   * first kind — a crawler has no origin to resolve a path against — so a
   * relative one is joined onto the public origin here.
   */
  private absolutise(
    url: string | null | undefined,
    origin: string,
  ): string | null {
    const value = url?.trim();
    if (!value) return null;
    if (/^https?:\/\//i.test(value)) return value;
    if (!origin) return null;
    return `${origin}${value.startsWith('/') ? '' : '/'}${value}`;
  }

  private publicOrigin(): string {
    return (
      this.config.get<string>('links.publicOrigin') ||
      this.config.get<string>('media.publicOrigin') ||
      ''
    ).replace(/\/+$/, '');
  }
}

// ── Pure helpers, exported for the tests ───────────────────────────────────

const UUID =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/**
 * Checked here rather than with `ParseUUIDPipe` on the route.
 *
 * The pipe throws, and a throw on these routes becomes the JSON error envelope
 * — which is exactly the "page" a woman was shown before this existed. A
 * malformed id is simply a link that resolves to nothing, and the not-found
 * page says so in Arabic.
 */
export function isUuid(value: string | undefined): boolean {
  return typeof value === 'string' && UUID.test(value);
}

export const COLLECTION_TITLES: Record<string, string> = {
  trending: 'الأكثر رواجاً',
  best_selling: 'الأكثر مبيعاً',
  new_arrivals: 'وصل حديثاً',
  featured: 'مختارات ريم',
  most_loved: 'الأكثر إعجاباً',
  top_rated: 'الأعلى تقييماً',
  recommended: 'مختارة لكِ',
  deals: 'كل العروض',
};

/**
 * `1,450,000 ل.س`.
 *
 * The same figure the app prints, deliberately: `Money.format` on the Flutter
 * side runs `NumberFormat.decimalPatternDigits(locale: 'ar')`, whose Arabic
 * symbols carry a Latin zero digit — so grouped Western numerals, then the
 * symbol. A preview that disagreed with the product page about the price would
 * be worse than no preview.
 */
export function formatMoney(
  amount: Prisma.Decimal,
  currency: Currency,
): string {
  const symbol = currency === Currency.USD ? '$' : 'ل.س';
  const digits = currency === Currency.USD ? 2 : 0;
  const value = new Intl.NumberFormat('en-US', {
    minimumFractionDigits: digits,
    maximumFractionDigits: digits,
  }).format(amount.toNumber());
  return currency === Currency.USD ? `${symbol}${value}` : `${value} ${symbol}`;
}

export function formatCount(value: number | bigint): string {
  const n = typeof value === 'bigint' ? Number(value) : value;
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}K`;
  return String(n);
}

/** Collapses whitespace and cuts on a word boundary, adding an ellipsis. */
export function truncate(value: string, max: number): string {
  const text = value.replace(/\s+/g, ' ').trim();
  if (text.length <= max) return text;
  const cut = text.slice(0, max);
  const lastSpace = cut.lastIndexOf(' ');
  return `${(lastSpace > max * 0.6 ? cut.slice(0, lastSpace) : cut).trimEnd()}…`;
}

/**
 * The `og:description`: the real text when there is one, the fallback when
 * there is not. Kept short — WhatsApp shows about two lines and Telegram
 * rather less.
 */
export function summarise(
  value: string | null | undefined,
  fallback: string,
  max = 160,
): string {
  const text = value?.replace(/\s+/g, ' ').trim();
  return text ? truncate(text, max) : truncate(fallback, max);
}
