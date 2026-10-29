import { BadRequestException, Injectable } from '@nestjs/common';
import {
  Currency,
  Prisma,
  PromotionPlacement,
  PromotionStatus,
  StoreAdTier,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { utcTimestamp } from '../../common/sql/utc-timestamp';
import {
  AD_PLANS,
  AudienceSpec,
  billedDays,
  EVERYONE,
  lowestPlanFor,
  planRefusal,
  recommendPlan,
  TIER_ORDER,
} from './ad-plans';
import { AdAudienceService } from './ad-audience.service';
import { AdTiersService } from './ad-tiers.service';
import {
  MAX_FEED_SLOTS,
  MAX_SLOTS,
  normaliseAudience,
  PromotionsService,
} from './promotions.service';

const NOT_A_PURCHASE = ['CANCELLED_BY_CUSTOMER', 'CANCELLED_BY_SELLER'];
const LOOKBACK_DAYS = 30;
const HIDDEN_GEM_DAYS = 14;

export type SuggestionReason = 'loved_not_bought' | 'best_seller' | 'hidden_gem' | 'fresh_pick';

const lower = (value: string) => value.toLowerCase();

/**
 * «مركز الإعلانات» — everything a boutique sees before and after she pays.
 *
 * The smart parts are all arithmetic over what the platform already records,
 * never a guess dressed as a forecast: the reach is a count of real shoppers,
 * the share of voice is her weight against the campaigns live today, the
 * suggestions are her own views, favourites and sales, and the plan
 * recommendation is what last month's campaigns would have cost on each plan.
 */
@Injectable()
export class StoreAdsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly promotions: PromotionsService,
    private readonly tiers: AdTiersService,
    private readonly audiences: AdAudienceService,
  ) {}

  // ── Plans ────────────────────────────────────────────────────────────────

  async plans(sellerId: string) {
    const [current, liveCount, history, spend, prices] = await Promise.all([
      this.tiers.current(sellerId),
      this.liveCampaigns(sellerId),
      this.tiers.history(sellerId),
      this.recentSpend(sellerId),
      Promise.all(TIER_ORDER.map((tier) => this.tiers.priceOf(tier))),
    ]);
    const now = new Date();
    const queued = history.find((row) => row.startsAt > now) ?? null;

    // What she spent is after her plan's discount; compare plans on the list
    // price so each plan applies its own discount to the same campaigns.
    const discount = current.plan.discountBps / 10_000;
    const listSpend = discount < 1 ? Math.round(spend / (1 - discount)) : spend;
    const recommendation = recommendPlan(current.tier, listSpend);

    return {
      current: {
        tier: lower(current.tier),
        ends_at: current.endsAt?.toISOString() ?? null,
        credit_granted: current.creditGranted,
        credit_used: current.creditUsed,
        credit_remaining: current.creditRemaining,
        active_campaigns: liveCount,
        max_active_campaigns: current.plan.maxActiveCampaigns,
      },
      queued: queued ? { tier: lower(queued.tier), starts_at: queued.startsAt.toISOString() } : null,
      plans: TIER_ORDER.map((tier, index) => this.planView(tier, prices[index])),
      spend_last_30_days: spend,
      recommendation: recommendation
        ? {
            tier: lower(recommendation.tier),
            saving: recommendation.saving,
            reason: spend > 0 ? 'would_have_saved' : 'start',
          }
        : current.tier === StoreAdTier.FREE
          ? { tier: 'silver', saving: 0, reason: 'start' }
          : null,
    };
  }

  private planView(tier: StoreAdTier, price: number) {
    const plan = AD_PLANS[tier];
    return {
      tier: lower(tier),
      price,
      credit: plan.creditSyp,
      discount_percent: plan.discountBps / 100,
      max_active_campaigns: plan.maxActiveCampaigns,
      placements: plan.placements.map(lower),
      targeting: plan.targeting,
      serving_weight: plan.servingWeight,
      notifies_followers: plan.notifiesFollowers,
      featured_store: plan.featuredStore,
    };
  }

  async subscribe(sellerId: string, tier: StoreAdTier) {
    await this.tiers.subscribe(sellerId, tier);
    return this.plans(sellerId);
  }

  // ── Quote ────────────────────────────────────────────────────────────────

  /**
   * Everything she needs to decide, before paying: the price line by line,
   * whether her plan allows it (and which plan would), how many shoppers the
   * audience holds, and her expected share of the slot against what is live.
   */
  async quote(
    sellerId: string,
    input: {
      offerId: string;
      placement: PromotionPlacement;
      startsAt: Date;
      endsAt: Date;
      audience: AudienceSpec;
    },
  ) {
    if (!(input.endsAt > input.startsAt)) {
      throw new BadRequestException('A placement must end after it starts');
    }
    const offer = await this.prisma.sellerOffer.findFirst({
      where: { id: input.offerId, sellerId },
      select: { productId: true, product: { select: { categoryId: true } } },
    });
    if (!offer) throw new BadRequestException('That listing is not yours');

    const audience = normaliseAudience(input.audience);
    const [price, current, reach, competition, feedPost] = await Promise.all([
      this.promotions.quote(sellerId, input.placement, input.startsAt, input.endsAt, audience),
      this.tiers.current(sellerId),
      this.audiences.estimateReach(sellerId, offer.product.categoryId, audience),
      this.competition(input.placement, offer.product.categoryId),
      input.placement === PromotionPlacement.FEED_TOP
        ? this.latestPost(sellerId, offer.productId)
        : Promise.resolve(null),
    ]);

    const refusal = planRefusal(current.plan, input.placement, audience);
    const days = billedDays(input.startsAt, input.endsAt);
    const myWeight = current.plan.servingWeight * Math.max(price.total / days, 1);
    const slots =
      input.placement === PromotionPlacement.FEED_TOP ? MAX_FEED_SLOTS : MAX_SLOTS;
    const shareOfVoice =
      competition.weight <= 0
        ? 1
        : Math.min(1, (slots * myWeight) / (myWeight + competition.weight));

    return {
      tier: lower(price.tier),
      allowed: refusal === null,
      refusal,
      required_tier: refusal ? lower(lowestPlanFor(input.placement, audience)) : null,
      price: {
        days: price.days,
        daily_rate: price.dailyRate,
        list_price: price.listPrice,
        discount: price.discount,
        total: price.total,
        credit_applied: price.creditApplied,
        to_pay: price.toPay,
        currency: Currency.SYP,
      },
      reach,
      competing_campaigns: competition.count,
      share_of_voice: Number(shareOfVoice.toFixed(3)),
      feed_post:
        input.placement === PromotionPlacement.FEED_TOP
          ? feedPost
            ? { id: feedPost.id, title: feedPost.title, image_url: feedPost.image }
            : null
          : undefined,
    };
  }

  /** The live campaigns she would be competing with for this page. */
  private async competition(placement: PromotionPlacement, categoryId: string) {
    const slots = await this.promotions.serve(placement, {
      categoryIds: placement === PromotionPlacement.CATEGORY ? [categoryId] : undefined,
      limit: 50,
      random: () => 0.5,
    });
    if (slots.length === 0) return { count: 0, weight: 0 };
    const rows = await this.prisma.productPromotion.findMany({
      where: { id: { in: slots.map((slot) => slot.promotionId) } },
      select: { id: true, feeAmount: true, startsAt: true, endsAt: true },
    });
    const tierOf = new Map(slots.map((slot) => [slot.promotionId, slot.tier]));
    const weight = rows.reduce((sum, row) => {
      const perDay = Number(row.feeAmount) / billedDays(row.startsAt, row.endsAt);
      return sum + AD_PLANS[tierOf.get(row.id) ?? StoreAdTier.FREE].servingWeight * Math.max(perDay, 1);
    }, 0);
    return { count: rows.length, weight };
  }

  private async latestPost(sellerId: string, productId: string) {
    const post = await this.prisma.commerceContent.findFirst({
      where: {
        authorId: sellerId,
        status: 'PUBLISHED',
        visibility: 'PUBLIC',
        moderationStatus: { not: 'REJECTED' },
        productTags: { some: { productId } },
      },
      orderBy: { publishedAt: 'desc' },
      select: {
        id: true,
        title: true,
        media: { orderBy: { sortOrder: 'asc' }, take: 1, select: { url: true } },
      },
    });
    return post ? { id: post.id, title: post.title, image: post.media[0]?.url ?? null } : null;
  }

  // ── Suggestions ──────────────────────────────────────────────────────────

  /**
   * Which of her pieces to advertise, and why — read from her own numbers.
   *
   * - **loved_not_bought**: favourited and viewed, rarely ordered. The demand
   *   is there; an advert in front of the women who want it converts it.
   * - **best_seller**: already selling. Advertising what works compounds.
   * - **hidden_gem**: new and barely seen. Nobody can buy what nobody saw.
   * - **fresh_pick**: a new boutique with no numbers yet gets her newest.
   */
  async suggestions(sellerId: string) {
    const since = new Date(Date.now() - LOOKBACK_DAYS * 86_400_000);
    const rows = await this.prisma.$queryRaw<
      {
        offer_id: string;
        product_id: string;
        title: string;
        created_at: Date;
        image: string | null;
        price: Prisma.Decimal;
        currency: Currency;
        views: bigint;
        favorites: bigint;
        sold: bigint;
        promoted: boolean;
        has_post: boolean;
      }[]
    >`
      SELECT o.id AS offer_id, pr.id AS product_id, pr.title, pr.created_at,
             o.price, o.currency,
             (SELECT m.url FROM product_media m WHERE m.product_id = pr.id AND m.type = 'image'
               ORDER BY m.sort_order ASC LIMIT 1) AS image,
             (SELECT COUNT(*) FROM analytics_events e
               WHERE e.product_id = pr.id AND e.type = 'PRODUCT_VIEW'
                 AND e.occurred_at >= ${utcTimestamp(since)})::bigint AS views,
             (SELECT COUNT(*) FROM favorites f WHERE f.product_id = pr.id)::bigint AS favorites,
             (SELECT COALESCE(SUM(oi.quantity), 0) FROM order_items oi
                JOIN seller_orders so ON so.id = oi.seller_order_id
               WHERE oi.offer_id = o.id AND so.created_at >= ${utcTimestamp(since)}
                 AND so.status::text <> ALL(${NOT_A_PURCHASE}::text[]))::bigint AS sold,
             EXISTS (SELECT 1 FROM product_promotions p
                      WHERE p.offer_id = o.id AND p.status = 'ACTIVE' AND p.ends_at > now()) AS promoted,
             EXISTS (SELECT 1 FROM commerce_content_product_tags t
                       JOIN commerce_contents c ON c.id = t.content_id
                      WHERE t.product_id = pr.id AND c.author_id = o.seller_id
                        AND c.status = 'PUBLISHED' AND c.visibility = 'PUBLIC') AS has_post
        FROM seller_offers o
        JOIN products pr ON pr.id = o.product_id
       WHERE o.seller_id = ${sellerId}::uuid
         AND o.status = 'ACTIVE' AND o.is_active AND o.stock > 0
         AND pr.status = 'ACTIVE'
       ORDER BY pr.created_at DESC
       LIMIT 200`;

    const current = await this.tiers.current(sellerId);
    const allows = (placement: PromotionPlacement) => current.plan.placements.includes(placement);
    const fullTargeting = current.plan.targeting === 'full';
    const hiddenSince = Date.now() - HIDDEN_GEM_DAYS * 86_400_000;

    const scored = rows
      .filter((row) => !row.promoted)
      .map((row) => {
        const views = Number(row.views);
        const favorites = Number(row.favorites);
        const sold = Number(row.sold);
        const interest = favorites * 3 + views;
        let reason = null as SuggestionReason | null;
        let score = 0;
        if (sold <= 1 && interest >= 5) {
          reason = 'loved_not_bought';
          score = 1000 + interest;
        } else if (sold >= 2) {
          reason = 'best_seller';
          score = 800 + sold * 10;
        } else if (row.created_at.getTime() >= hiddenSince && views < 20) {
          reason = 'hidden_gem';
          score = 500 + (20 - views);
        }
        return { row, views, favorites, sold, reason, score };
      });

    // The best of each reason first, then the rest by score — six «loved but
    // not bought» cards say one thing six times.
    const ranked = scored.filter((s) => s.reason !== null).sort((a, b) => b.score - a.score);
    const leaders = new Map<SuggestionReason, (typeof ranked)[number]>();
    for (const s of ranked) if (!leaders.has(s.reason!)) leaders.set(s.reason!, s);
    const firsts = new Set(leaders.values());
    let picks = [...firsts, ...ranked.filter((s) => !firsts.has(s))];
    if (picks.length === 0) {
      picks = scored.slice(0, 3).map((s) => ({ ...s, reason: 'fresh_pick' as const, score: 0 }));
    }

    return picks.slice(0, 6).map(({ row, views, favorites, sold, reason }) => {
      const placement =
        reason === 'loved_not_bought'
          ? allows(PromotionPlacement.HOME_SPOTLIGHT)
            ? PromotionPlacement.HOME_SPOTLIGHT
            : row.has_post && allows(PromotionPlacement.FEED_TOP)
              ? PromotionPlacement.FEED_TOP
              : PromotionPlacement.SEARCH
          : reason === 'best_seller'
            ? PromotionPlacement.SEARCH
            : row.has_post && allows(PromotionPlacement.FEED_TOP)
              ? PromotionPlacement.FEED_TOP
              : PromotionPlacement.CATEGORY;
      const targetInterested = reason === 'loved_not_bought' && fullTargeting;
      return {
        offer_id: row.offer_id,
        product: {
          id: row.product_id,
          title: row.title,
          image_url: row.image,
          price: Money.of(row.price, row.currency).toJSON(),
        },
        reason,
        stats: { views_30d: views, favorites, sold_30d: sold },
        has_post: row.has_post,
        suggested: {
          placement: lower(placement),
          days: 7,
          audience: targetInterested ? 'interested' : 'everyone',
        },
      };
    });
  }

  // ── Overview ─────────────────────────────────────────────────────────────

  /** How her advertising is doing, in one card — and against the platform. */
  async overview(sellerId: string) {
    const promotions = await this.prisma.productPromotion.findMany({
      where: { sellerId },
      select: {
        id: true,
        placement: true,
        status: true,
        endsAt: true,
        feeAmount: true,
        creditApplied: true,
        chargedAt: true,
        impressions: true,
        clicks: true,
      },
    });
    const ids = promotions.map((p) => p.id);
    const [stats, reachRows, benchmarks] = await Promise.all([
      this.promotions.performance(ids),
      ids.length
        ? this.prisma.$queryRaw<{ n: bigint }[]>`
            SELECT COUNT(DISTINCT user_id)::bigint AS n FROM ad_exposures
             WHERE promotion_id = ANY(${ids}::uuid[])`
        : Promise.resolve([{ n: BigInt(0) }]),
      this.benchmarks(),
    ]);

    const charged = promotions.filter((p) => p.chargedAt);
    const spend = charged.reduce((sum, p) => sum + Number(p.feeAmount), 0);
    const creditUsed = charged.reduce((sum, p) => sum + Number(p.creditApplied), 0);
    const impressions = promotions.reduce((sum, p) => sum + p.impressions, 0);
    const clicks = promotions.reduce((sum, p) => sum + p.clicks, 0);
    let orders = 0;
    let revenue = 0;
    for (const s of stats.values()) {
      orders += s.attributed_orders;
      revenue += Number(s.attributed_revenue.amount);
    }
    const now = new Date();
    const ctr = impressions > 0 ? clicks / impressions : null;
    const platformCtr = benchmarks.overall;

    return {
      active_campaigns: promotions.filter(
        (p) => p.status === PromotionStatus.ACTIVE && p.endsAt > now,
      ).length,
      total_campaigns: promotions.length,
      spend,
      credit_used: creditUsed,
      impressions,
      clicks,
      reach: Number(reachRows[0]?.n ?? 0),
      click_through_rate: ctr === null ? null : Number(ctr.toFixed(4)),
      attributed_orders: orders,
      attributed_revenue: revenue,
      // Revenue per lira spent. Null before anything was spent — a return on
      // nothing is not infinite, it is unknown.
      return_on_ad_spend: spend > 0 ? Number((revenue / spend).toFixed(2)) : null,
      benchmark_ctr: platformCtr === null ? null : Number(platformCtr.toFixed(4)),
      benchmark_ctr_by_placement: benchmarks.byPlacement,
      insight:
        ctr === null || platformCtr === null
          ? 'not_enough_data'
          : ctr >= platformCtr * 1.2
            ? 'above_average'
            : ctr <= platformCtr * 0.8
              ? 'below_average'
              : 'average',
      currency: Currency.SYP,
    };
  }

  /** The platform's click-through rate, overall and per placement. */
  private async benchmarks() {
    const rows = await this.prisma.productPromotion.groupBy({
      by: ['placement'],
      _sum: { impressions: true, clicks: true },
    });
    let imp = 0;
    let clk = 0;
    const byPlacement: Record<string, number | null> = {};
    for (const row of rows) {
      const i = row._sum.impressions ?? 0;
      const c = row._sum.clicks ?? 0;
      imp += i;
      clk += c;
      byPlacement[lower(row.placement)] = i >= 100 ? Number((c / i).toFixed(4)) : null;
    }
    // Under a hundred impressions a rate is noise; say nothing rather than mislead.
    return { overall: imp >= 100 ? clk / imp : null, byPlacement };
  }

  async governorates() {
    return this.audiences.governorates();
  }

  // ── internals ────────────────────────────────────────────────────────────

  private liveCampaigns(sellerId: string) {
    return this.prisma.productPromotion.count({
      where: { sellerId, status: PromotionStatus.ACTIVE, endsAt: { gt: new Date() } },
    });
  }

  /** What her campaigns charged in the last month, in SYP. */
  private async recentSpend(sellerId: string): Promise<number> {
    const since = new Date(Date.now() - LOOKBACK_DAYS * 86_400_000);
    const agg = await this.prisma.productPromotion.aggregate({
      where: { sellerId, chargedAt: { gte: since }, feeCurrency: Currency.SYP },
      _sum: { feeAmount: true },
    });
    return Number(agg._sum.feeAmount ?? 0);
  }
}

