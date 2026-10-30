import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
  Optional,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  AdAudience,
  CommerceContentStatus,
  CommerceContentVisibility,
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  OfferStatus,
  Prisma,
  ProductStatus,
  PromotionPlacement,
  PromotionStatus,
  StoreAdTier,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { AppEvent, PromotionLaunchedPayload } from '../../common/events/app-events';
import { LedgerService } from '../ledger/ledger.service';
import { utcCast, utcParam, utcTimestamp } from '../../common/sql/utc-timestamp';
import {
  AD_PLANS,
  ATTRIBUTION_WINDOW_DAYS,
  AudienceSpec,
  DAILY_FREQUENCY_CAP,
  DEFAULT_DAILY_RATES_SYP,
  EVERYONE,
  FOLLOWER_NOTICE_INTERVAL_DAYS,
  hasInterestGroups,
  lowestPlanFor,
  planRefusal,
  priceCampaign,
  PriceBreakdown,
  RATE_CARD_SETTING,
  billedDays,
  weightedOrder,
} from './ad-plans';
import { AdTiersService } from './ad-tiers.service';
import { AdAudienceService } from './ad-audience.service';

/**
 * How many paid slots a page may carry.
 *
 * Three, and it is a hard ceiling rather than a default. The value of a
 * marketplace's results is that they answer the question; a page whose top
 * half is bought stops answering it, and the customers leave long before the
 * advertising revenue makes up for them.
 */
export const MAX_SLOTS = 3;

/** The community feed carries one pinned advert above the posts, never more. */
export const MAX_FEED_SLOTS = 1;

/** The longest window a single placement may be bought for. */
const MAX_WINDOW_DAYS = 30;

/** System setting holding the minimum price of one day of placement, in SYP. */
export const MIN_DAILY_FEE_SETTING = 'promotions.min_daily_fee_syp';

/** Placements a shopper is handed rather than searched for — capped per day. */
const CAPPED_PLACEMENTS: readonly PromotionPlacement[] = [
  PromotionPlacement.FEED_TOP,
  PromotionPlacement.HOME_SPOTLIGHT,
];

const NOT_A_PURCHASE = ['CANCELLED_BY_CUSTOMER', 'CANCELLED_BY_SELLER'];

/** One paid slot chosen for a page. */
export interface ServedSlot {
  promotionId: string;
  offerId: string;
  productId: string;
  sellerId: string;
  contentId: string | null;
  tier: StoreAdTier;
}

interface CandidateRow {
  id: string;
  offer_id: string;
  product_id: string;
  seller_id: string;
  category_id: string;
  content_id: string | null;
  fee_amount: Prisma.Decimal | string;
  starts_at: Date;
  ends_at: Date;
  audience: AdAudience;
  target_governorates: string[] | null;
  target_followers: boolean;
  target_past_buyers: boolean;
  target_interested: boolean;
  target_new_shoppers: boolean;
}

export interface CreatePromotionInput {
  offerId: string;
  placement: PromotionPlacement;
  /**
   * What she offers to pay. Optional: without it she pays the quoted price.
   * With it, it must reach the quote — paying more than the quote raises her
   * share of the slot, which is how a boutique outbids within her plan.
   */
  fee?: Money;
  startsAt: Date;
  endsAt: Date;
  audience?: AudienceSpec;
  /** FEED_TOP only: which of her posts to pin. Defaults to her latest one tagging the product. */
  contentId?: string;
  actorId: string;
  actorRole: UserRole;
}

@Injectable()
export class PromotionsService {
  private readonly logger = new Logger(PromotionsService.name);
  private readonly tiers: AdTiersService;
  private readonly audiences: AdAudienceService;

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
    @Optional() tiers?: AdTiersService,
    @Optional() audiences?: AdAudienceService,
    @Optional() private readonly events?: EventEmitter2,
  ) {
    this.tiers = tiers ?? new AdTiersService(prisma, ledger);
    this.audiences = audiences ?? new AdAudienceService(prisma);
  }

  // ── Serving ──────────────────────────────────────────────────────────────

  /**
   * The paid slots for a page, in the order they should appear.
   *
   * Returns offer ids only. The caller loads and labels them, because a
   * sponsored result must be *shown* as sponsored, and a service that returned
   * ready-made product cards would make it easy to forget.
   *
   * Only listings a customer could actually buy are served. Paying for a slot
   * does not buy the right to occupy it with something out of stock.
   */
  async slotsFor(
    placement: PromotionPlacement,
    options: {
      categoryId?: string;
      /**
       * The page's whole category subtree. A department page shows products
       * that hang off its leaves, so a slot bought on a dress must be able to
       * appear on «ملابس» as well as on «فساتين».
       */
      categoryIds?: readonly string[];
      limit?: number;
      viewerId?: string;
    } = {},
  ): Promise<string[]> {
    const limit = Math.min(options.limit ?? MAX_SLOTS, MAX_SLOTS);
    const rows = await this.serve(placement, { ...options, limit });
    return rows.map((row) => row.offerId);
  }

  /**
   * Every live paid slot for a page that this viewer may be shown, in serving
   * order, with the product each one advertises — up to `limit` (50 by
   * default).
   *
   * For callers that must still decide which slots *fit* the page, such as
   * search, where a slot is only shown when its product is one the search
   * itself would have returned. The caller takes at most [MAX_SLOTS].
   */
  async candidatesFor(
    placement: PromotionPlacement,
    options: {
      categoryId?: string;
      categoryIds?: readonly string[];
      limit?: number;
      viewerId?: string;
    } = {},
  ): Promise<ServedSlot[]> {
    return this.serve(placement, options);
  }

  /**
   * The heart of serving.
   *
   * 1. Every live, paid, in-stock placement for the page.
   * 2. Only those whose audience holds this viewer (a guest: only EVERYONE).
   * 3. For the feed and the home page, none she has already been shown
   *    [DAILY_FREQUENCY_CAP] times today.
   * 4. Ordered by weighted chance: plan weight × what was paid per day. A
   *    Diamond boutique that paid twice the rate is shown far more often than
   *    a Free one — and the Free one that paid is still shown sometimes.
   * 5. One slot per product.
   */
  async serve(
    placement: PromotionPlacement,
    options: {
      categoryId?: string;
      categoryIds?: readonly string[];
      limit?: number;
      viewerId?: string;
      random?: () => number;
    } = {},
  ): Promise<ServedSlot[]> {
    // An empty subtree means "nothing qualifies", not "no filter".
    if (options.categoryIds?.length === 0) return [];
    const limit = Math.max(1, Math.min(options.limit ?? 50, 50));
    const now = new Date();

    const contentGate =
      placement === PromotionPlacement.FEED_TOP
        ? `AND EXISTS (
             SELECT 1 FROM commerce_contents c
              WHERE c.id = p.content_id
                AND c.status = 'PUBLISHED'
                AND c.visibility = 'PUBLIC'
                AND c.author_is_public
                AND c.moderation_status <> 'REJECTED'
                AND (c.expires_at IS NULL OR c.expires_at > now()))`
        : '';

    const rows = await this.prisma.$queryRawUnsafe<CandidateRow[]>(
      `
      SELECT p.id, p.offer_id, pr.id AS product_id, p.seller_id, pr.category_id,
             p.content_id, p.fee_amount, p.starts_at, p.ends_at, p.audience,
             p.target_governorates, p.target_followers, p.target_past_buyers,
             p.target_interested, p.target_new_shoppers
      FROM product_promotions p
      JOIN seller_offers o ON o.id = p.offer_id
      JOIN products pr ON pr.id = o.product_id
      WHERE p.status = $1::"PromotionStatus"
        AND p.placement = $2::"PromotionPlacement"
        AND p.starts_at <= ${utcCast('$3')}
        AND p.ends_at   >  ${utcCast('$3')}
        AND o.status = $4::"OfferStatus"
        AND o.is_active
        AND o.stock > 0
        AND pr.status = $5::"ProductStatus"
        AND ($6::uuid IS NULL OR pr.category_id = $6::uuid)
        AND ($7::uuid[] IS NULL OR pr.category_id = ANY($7::uuid[]))
        ${contentGate}
      ORDER BY p.created_at ASC
      LIMIT 200
      `,
      PromotionStatus.ACTIVE,
      placement,
      utcParam(now),
      OfferStatus.ACTIVE,
      ProductStatus.ACTIVE,
      options.categoryId ?? null,
      options.categoryIds ? [...options.categoryIds] : null,
    );
    if (rows.length === 0) return [];

    const fits = await this.audiences.matches(
      options.viewerId,
      rows.map((row) => ({
        sellerId: row.seller_id,
        categoryId: row.category_id,
        audience: audienceOf(row),
      })),
    );
    let eligible = rows.filter((_, i) => fits[i]);

    if (options.viewerId && CAPPED_PLACEMENTS.includes(placement) && eligible.length) {
      const capped = await this.prisma.$queryRaw<{ promotion_id: string }[]>`
        SELECT promotion_id FROM ad_exposures
         WHERE user_id = ${options.viewerId}::uuid
           AND day = (now() AT TIME ZONE 'UTC')::date
           AND impressions >= ${DAILY_FREQUENCY_CAP}
           AND promotion_id = ANY(${eligible.map((row) => row.id)}::uuid[])`;
      const seen = new Set(capped.map((row) => row.promotion_id));
      eligible = eligible.filter((row) => !seen.has(row.id));
    }
    if (eligible.length === 0) return [];

    const tiers = await this.tiers.tiersOf(eligible.map((row) => row.seller_id));
    const ordered = weightedOrder(
      eligible,
      (row) => servingWeight(row, tiers.get(row.seller_id) ?? StoreAdTier.FREE),
      options.random,
    );

    // One slot per product: two sellers' offers on the same dress would
    // otherwise fill two of three slots with one picture.
    const seen = new Set<string>();
    const out: ServedSlot[] = [];
    for (const row of ordered) {
      if (seen.has(row.product_id)) continue;
      seen.add(row.product_id);
      out.push({
        promotionId: row.id,
        offerId: row.offer_id,
        productId: row.product_id,
        sellerId: row.seller_id,
        contentId: row.content_id,
        tier: tiers.get(row.seller_id) ?? StoreAdTier.FREE,
      });
      if (out.length >= limit) break;
    }
    return out;
  }

  /**
   * Records that paid slots were shown, and that one was tapped.
   *
   * Reporting only — nothing about the money reads these counters. That is
   * what makes it safe for them to be incremented from a client. For a
   * signed-in viewer it also writes her exposure row, which is what the
   * frequency cap, the unique reach and order attribution read.
   */
  async recordImpressions(
    offerIds: string[],
    placement?: PromotionPlacement,
    viewerId?: string,
  ): Promise<void> {
    if (offerIds.length === 0) return;
    await this.prisma.productPromotion.updateMany({
      where: this.liveWhere({ offerId: { in: offerIds } }, placement),
      data: { impressions: { increment: 1 } },
    });
    if (viewerId) await this.writeExposure(offerIds, placement, viewerId, 'impression');
  }

  async recordClick(
    offerId: string,
    placement?: PromotionPlacement,
    viewerId?: string,
  ): Promise<void> {
    await this.prisma.productPromotion.updateMany({
      where: this.liveWhere({ offerId }, placement),
      data: { clicks: { increment: 1 } },
    });
    if (viewerId) await this.writeExposure([offerId], placement, viewerId, 'click');
  }

  private async writeExposure(
    offerIds: string[],
    placement: PromotionPlacement | undefined,
    viewerId: string,
    kind: 'impression' | 'click',
  ): Promise<void> {
    const now = new Date();
    const imp = kind === 'impression' ? 1 : 0;
    const clk = kind === 'click' ? 1 : 0;
    const clickedAt = kind === 'click' ? utcTimestamp(now) : Prisma.sql`NULL::timestamp`;
    await this.prisma.$executeRaw`
      INSERT INTO ad_exposures (id, promotion_id, user_id, day, impressions, clicks, last_clicked_at)
      SELECT gen_random_uuid(), p.id, ${viewerId}::uuid, (now() AT TIME ZONE 'UTC')::date,
             ${imp}, ${clk}, ${clickedAt}
        FROM product_promotions p
       WHERE p.offer_id = ANY(${offerIds}::uuid[])
         AND p.status = 'ACTIVE'
         AND p.starts_at <= ${utcTimestamp(now)} AND p.ends_at > ${utcTimestamp(now)}
         AND (${placement ?? null}::"PromotionPlacement" IS NULL
              OR p.placement = ${placement ?? null}::"PromotionPlacement")
      ON CONFLICT (promotion_id, user_id, day) DO UPDATE
        SET impressions = ad_exposures.impressions + EXCLUDED.impressions,
            clicks = ad_exposures.clicks + EXCLUDED.clicks,
            last_clicked_at = COALESCE(EXCLUDED.last_clicked_at, ad_exposures.last_clicked_at)`;
  }

  /**
   * The placements a counter may touch: live now, and on the page that
   * actually showed the slot. Without the window and the placement, one
   * search impression also ticked a seller's paused category slot and last
   * month's expired one, and the click-through rate she paid for was fiction.
   */
  private liveWhere(
    where: { offerId: string | { in: string[] } },
    placement?: PromotionPlacement,
  ) {
    const now = new Date();
    return {
      ...where,
      status: PromotionStatus.ACTIVE,
      startsAt: { lte: now },
      endsAt: { gt: now },
      ...(placement ? { placement } : {}),
    };
  }

  // ── Pricing ──────────────────────────────────────────────────────────────

  /**
   * The daily price of a placement: the console's rate card, or the default,
   * and never below the legacy per-day floor.
   */
  async dailyRate(placement: PromotionPlacement): Promise<number> {
    const settings = await this.prisma.systemSetting.findMany({
      where: { key: { in: [RATE_CARD_SETTING, MIN_DAILY_FEE_SETTING] } },
      select: { key: true, value: true },
    });
    const card = settings.find((s) => s.key === RATE_CARD_SETTING)?.value as
      | Record<string, unknown>
      | undefined;
    const override = card && typeof card === 'object' ? Number(card[placement]) : NaN;
    const rate =
      Number.isFinite(override) && override > 0 ? override : DEFAULT_DAILY_RATES_SYP[placement];
    const floor = parseDaily(settings.find((s) => s.key === MIN_DAILY_FEE_SETTING)?.value);
    return Math.max(rate, floor ?? 0);
  }

  /** What a campaign would cost this boutique today, credit included. */
  async quote(
    sellerId: string,
    placement: PromotionPlacement,
    startsAt: Date,
    endsAt: Date,
    audience: AudienceSpec,
  ): Promise<PriceBreakdown & { tier: StoreAdTier }> {
    const [current, rate] = await Promise.all([
      this.tiers.current(sellerId),
      this.dailyRate(placement),
    ]);
    return {
      tier: current.tier,
      ...priceCampaign({
        dailyRate: rate,
        days: billedDays(startsAt, endsAt),
        targeted: audience.targeted,
        plan: current.plan,
        creditAvailable: current.creditRemaining,
      }),
    };
  }

  // ── Buying ───────────────────────────────────────────────────────────────

  async create(input: CreatePromotionInput) {
    if (!(input.endsAt > input.startsAt)) {
      throw new BadRequestException('A placement must end after it starts');
    }
    const days = (input.endsAt.getTime() - input.startsAt.getTime()) / 86_400_000;
    if (days > MAX_WINDOW_DAYS) {
      throw new BadRequestException(`A placement runs for at most ${MAX_WINDOW_DAYS} days`);
    }
    if (input.fee?.isZero()) {
      throw new BadRequestException('A placement with no fee is not a placement');
    }
    if (input.endsAt.getTime() <= Date.now()) {
      throw new BadRequestException('That window has already ended');
    }
    const audience = normaliseAudience(input.audience ?? EVERYONE);

    const offer = await this.prisma.sellerOffer.findUnique({
      where: { id: input.offerId },
      select: { id: true, sellerId: true, productId: true },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    if (input.actorRole === UserRole.SELLER && offer.sellerId !== input.actorId) {
      throw new ForbiddenException('That listing is not yours');
    }

    const current = await this.tiers.current(offer.sellerId);
    if (input.actorRole === UserRole.SELLER) {
      await this.tiers.assertCanAdvertise(offer.sellerId);
      const refusal = planRefusal(current.plan, input.placement, audience);
      if (refusal) {
        throw new ForbiddenException({
          message: `This campaign needs the ${lowestPlanFor(input.placement, audience)} plan`,
          code: refusal,
          required_tier: lowestPlanFor(input.placement, audience).toLowerCase(),
        });
      }
    }

    const contentId =
      input.placement === PromotionPlacement.FEED_TOP
        ? await this.resolveFeedPost(offer.sellerId, offer.productId, input.contentId)
        : null;

    // The seller is quoted the price; staff may set any non-zero fee.
    const quoted = priceCampaign({
      dailyRate: await this.dailyRate(input.placement),
      days: billedDays(input.startsAt, input.endsAt),
      targeted: audience.targeted,
      plan: current.plan,
      creditAvailable: 0,
    }).total;
    let fee = input.fee;
    if (input.actorRole === UserRole.SELLER) {
      if (fee && fee.toUnsafeNumber() < quoted) {
        throw new BadRequestException(
          `A placement of ${Math.ceil(days)} day(s) costs at least ${quoted} SYP`,
        );
      }
    }
    fee ??= Money.of(String(quoted), Currency.SYP);

    const promotion = await this.prisma.productPromotion.create({
      data: {
        offerId: offer.id,
        sellerId: offer.sellerId,
        placement: input.placement,
        feeAmount: fee.toPrisma(),
        feeCurrency: fee.currency,
        startsAt: input.startsAt,
        endsAt: input.endsAt,
        contentId,
        audience: audience.targeted ? AdAudience.TARGETED : AdAudience.EVERYONE,
        targetGovernorates: [...audience.governorates],
        targetFollowers: audience.followers,
        targetPastBuyers: audience.pastBuyers,
        targetInterested: audience.interested,
        targetNewShoppers: audience.newShoppers,
      },
    });

    return this.serialize(promotion);
  }

  /**
   * The post a feed placement pins: the one she named, or her latest public
   * post tagging the product. A feed advert has to *be* a post — the feed has
   * no other kind of card — and it has to be hers.
   */
  private async resolveFeedPost(
    sellerId: string,
    productId: string,
    contentId?: string,
  ): Promise<string> {
    const post = await this.prisma.commerceContent.findFirst({
      where: {
        authorId: sellerId,
        status: CommerceContentStatus.PUBLISHED,
        visibility: CommerceContentVisibility.PUBLIC,
        // A post nobody can see in a feed cannot be pinned above one.
        authorIsPublic: true,
        moderationStatus: { not: 'REJECTED' },
        ...(contentId ? { id: contentId } : { productTags: { some: { productId } } }),
      },
      orderBy: { publishedAt: 'desc' },
      select: { id: true },
    });
    if (!post) {
      throw new BadRequestException({
        message: 'Publish a public post featuring this product first',
        code: 'feed_post_required',
      });
    }
    return post.id;
  }

  /**
   * Takes the fee and turns the placement on.
   *
   * The charge and the status move in one transaction, so a promotion is never
   * live-but-unbilled or billed-but-dark. Her plan's ad credit is spent first;
   * whatever remains comes out of her earnings. A boutique whose earnings
   * cannot cover it is left `UNPAID` rather than shown for free — and told,
   * rather than left wondering why her slot never appeared.
   */
  async activate(promotionId: string, actorId: string, actorRole: UserRole) {
    const promotion = await this.requireOwned(promotionId, actorId, actorRole);

    if (promotion.status === PromotionStatus.ACTIVE) {
      return this.serialize(promotion);
    }
    // Charging for a window that has closed sells nothing, and resuming one
    // shows nothing. Either way the honest answer is no.
    if (promotion.endsAt.getTime() <= Date.now()) {
      throw new BadRequestException('That placement window has already ended');
    }

    if (actorRole === UserRole.SELLER) {
      const current = await this.tiers.current(promotion.sellerId);
      const live = await this.prisma.productPromotion.count({
        where: {
          sellerId: promotion.sellerId,
          status: PromotionStatus.ACTIVE,
          endsAt: { gt: new Date() },
          id: { not: promotion.id },
        },
      });
      if (live >= current.plan.maxActiveCampaigns) {
        throw new ForbiddenException({
          message: `Your plan runs ${current.plan.maxActiveCampaigns} campaign(s) at once`,
          code: 'campaign_limit',
          limit: current.plan.maxActiveCampaigns,
        });
      }
    }

    if (promotion.chargedAt) {
      // Already paid for — this is a restart after a pause, not a second sale.
      const resumed = await this.prisma.productPromotion.update({
        where: { id: promotion.id },
        data: { status: PromotionStatus.ACTIVE },
      });
      return this.serialize(resumed);
    }

    const fee = Money.of(promotion.feeAmount, promotion.feeCurrency);
    const reference = `promotion:${promotion.id}`;

    let charged;
    try {
      charged = await this.prisma.$transaction(async (tx) => {
        const credit =
          fee.currency === Currency.SYP
            ? await this.tiers.spendCredit(
                promotion.sellerId,
                Math.floor(fee.toUnsafeNumber()),
                tx,
              )
            : 0;
        const toPay = fee.minus(Money.of(String(credit), fee.currency));

        if (!toPay.isZero()) {
          await this.tiers.assertCanPay(promotion.sellerId, toPay, tx);
          // Her earnings pay for it: the platform owes her less, and books the
          // difference as promotion revenue. No new money moves, which is
          // exactly right — nothing has left anybody's hands. Credit needs no
          // entry: it was booked as revenue when she bought the plan.
          await this.ledger.post(
            {
              type: JournalEntryType.MANUAL_ADJUSTMENT,
              reference,
              description: `رسوم ترويج — ${promotion.placement}`,
              lines: [
                {
                  account: {
                    code: LedgerAccountCode.SELLER_PAYABLE,
                    ownerId: promotion.sellerId,
                  },
                  direction: LedgerDirection.DEBIT,
                  amount: toPay,
                },
                {
                  account: { code: LedgerAccountCode.PROMOTION_REVENUE },
                  direction: LedgerDirection.CREDIT,
                  amount: toPay,
                },
              ],
            },
            tx,
          );
        }

        return tx.productPromotion.update({
          where: { id: promotion.id },
          data: {
            status: PromotionStatus.ACTIVE,
            chargeReference: reference,
            chargedAt: new Date(),
            creditApplied: String(credit),
          },
        });
      });
    } catch (error) {
      this.logger.warn(`Promotion ${promotion.id} not charged: ${String(error)}`);
      await this.prisma.productPromotion.update({
        where: { id: promotion.id },
        data: { status: PromotionStatus.UNPAID },
      });
      throw new BadRequestException(
        `The placement fee of ${fee.toString()} could not be taken from your earnings`,
      );
    }

    await this.maybeNotifyFollowers(charged.id, charged.sellerId, charged.offerId).catch(
      (error) => this.logger.warn(`Follower notice skipped: ${String(error)}`),
    );
    return this.serialize(charged);
  }

  /**
   * GOLD and DIAMOND: her followers hear about the campaign — at most once a
   * week per boutique, however many campaigns she starts.
   */
  private async maybeNotifyFollowers(promotionId: string, sellerId: string, offerId: string) {
    if (!this.events) return;
    const current = await this.tiers.current(sellerId);
    if (!current.plan.notifiesFollowers) return;
    const since = new Date(Date.now() - FOLLOWER_NOTICE_INTERVAL_DAYS * 86_400_000);
    const recent = await this.prisma.productPromotion.findFirst({
      where: { sellerId, followersNotifiedAt: { gte: since } },
      select: { id: true },
    });
    if (recent) return;
    const offer = await this.prisma.sellerOffer.findUnique({
      where: { id: offerId },
      select: { product: { select: { id: true, title: true } } },
    });
    if (!offer) return;
    await this.prisma.productPromotion.update({
      where: { id: promotionId },
      data: { followersNotifiedAt: new Date() },
    });
    const payload: PromotionLaunchedPayload = {
      sellerId,
      promotionId,
      productId: offer.product.id,
      productTitle: offer.product.title,
    };
    this.events.emit(AppEvent.PromotionLaunched, payload);
  }

  async setStatus(
    promotionId: string,
    status: PromotionStatus,
    actorId: string,
    actorRole: UserRole,
  ) {
    if (status === PromotionStatus.ACTIVE) {
      return this.activate(promotionId, actorId, actorRole);
    }
    await this.requireOwned(promotionId, actorId, actorRole);
    const updated = await this.prisma.productPromotion.update({
      where: { id: promotionId },
      data: { status },
    });
    return this.serialize(updated);
  }

  /** What a boutique bought, and what it did. */
  async listForSeller(sellerId: string) {
    const rows = await this.prisma.productPromotion.findMany({
      where: { sellerId },
      orderBy: { createdAt: 'desc' },
      include: {
        offer: {
          select: {
            id: true,
            product: {
              select: {
                id: true,
                title: true,
                slug: true,
                media: {
                  where: { type: 'image' },
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
    const stats = await this.performance(rows.map((row) => row.id));
    return rows.map((row) => {
      const { media, ...product } = row.offer.product;
      return {
        ...this.serialize(row),
        product: { ...product, image_url: media[0]?.url ?? null },
        ...(stats.get(row.id) ?? EMPTY_STATS),
      };
    });
  }

  /**
   * Unique reach and attributed sales, per placement.
   *
   * An order counts when it is for the advertised offer, from this boutique,
   * not cancelled, and placed by a woman who tapped the advert in the
   * [ATTRIBUTION_WINDOW_DAYS] days before it. A tap that came after the order
   * did not cause it.
   */
  async performance(promotionIds: readonly string[]) {
    const out = new Map<string, typeof EMPTY_STATS>();
    if (promotionIds.length === 0) return out;
    const rows = await this.prisma.$queryRaw<
      { id: string; reach: bigint; orders: bigint; revenue: Prisma.Decimal | null }[]
    >`
      SELECT p.id,
             (SELECT COUNT(DISTINCT x.user_id) FROM ad_exposures x WHERE x.promotion_id = p.id)::bigint AS reach,
             COALESCE(att.orders, 0)::bigint AS orders,
             att.revenue
        FROM product_promotions p
        LEFT JOIN LATERAL (
          SELECT COUNT(DISTINCT so.id) AS orders, SUM(oi.line_total) AS revenue
            FROM order_items oi
            JOIN seller_orders so ON so.id = oi.seller_order_id
            JOIN orders o ON o.id = so.order_id
           WHERE oi.offer_id = p.offer_id
             AND so.seller_id = p.seller_id
             AND so.currency = 'SYP'
             AND so.status::text <> ALL(${NOT_A_PURCHASE}::text[])
             AND so.created_at >= p.starts_at
             AND so.created_at < p.ends_at + make_interval(days => ${ATTRIBUTION_WINDOW_DAYS}::int)
             AND EXISTS (
               SELECT 1 FROM ad_exposures x
                WHERE x.promotion_id = p.id AND x.user_id = o.user_id AND x.clicks > 0
                  AND x.last_clicked_at <= so.created_at
                  AND x.last_clicked_at >= so.created_at - make_interval(days => ${ATTRIBUTION_WINDOW_DAYS}::int))
        ) att ON true
       WHERE p.id = ANY(${[...promotionIds]}::uuid[])`;
    for (const row of rows) {
      out.set(row.id, {
        reach: Number(row.reach),
        attributed_orders: Number(row.orders),
        attributed_revenue: Money.of(row.revenue ?? '0', Currency.SYP).toJSON(),
      });
    }
    return out;
  }

  async listAll() {
    const rows = await this.prisma.productPromotion.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    return rows.map((row) => this.serialize(row));
  }

  // ── internals ────────────────────────────────────────────────────────────

  private async requireOwned(promotionId: string, actorId: string, actorRole: UserRole) {
    const promotion = await this.prisma.productPromotion.findUnique({
      where: { id: promotionId },
    });
    if (!promotion) throw new NotFoundException('Placement not found');
    if (actorRole === UserRole.SELLER && promotion.sellerId !== actorId) {
      throw new ForbiddenException('That placement is not yours');
    }
    return promotion;
  }

  serialize(promotion: {
    id: string;
    offerId: string;
    sellerId: string;
    placement: PromotionPlacement;
    feeAmount: unknown;
    feeCurrency: Currency;
    status: PromotionStatus;
    startsAt: Date;
    endsAt: Date;
    chargedAt: Date | null;
    impressions: number;
    clicks: number;
    contentId?: string | null;
    audience?: AdAudience;
    targetGovernorates?: string[];
    targetFollowers?: boolean;
    targetPastBuyers?: boolean;
    targetInterested?: boolean;
    targetNewShoppers?: boolean;
    creditApplied?: unknown;
  }) {
    const now = new Date();
    return {
      id: promotion.id,
      offer_id: promotion.offerId,
      seller_id: promotion.sellerId,
      placement: promotion.placement.toLowerCase(),
      fee: Money.of(promotion.feeAmount as never, promotion.feeCurrency).toJSON(),
      credit_applied: Money.of(
        (promotion.creditApplied ?? '0') as never,
        promotion.feeCurrency,
      ).toJSON(),
      status: promotion.status.toLowerCase(),
      starts_at: promotion.startsAt.toISOString(),
      ends_at: promotion.endsAt.toISOString(),
      charged_at: promotion.chargedAt?.toISOString() ?? null,
      is_live:
        promotion.status === PromotionStatus.ACTIVE &&
        promotion.startsAt <= now &&
        promotion.endsAt > now,
      content_id: promotion.contentId ?? null,
      audience: {
        type: (promotion.audience ?? AdAudience.EVERYONE).toLowerCase(),
        governorates: promotion.targetGovernorates ?? [],
        followers: promotion.targetFollowers ?? false,
        past_buyers: promotion.targetPastBuyers ?? false,
        interested: promotion.targetInterested ?? false,
        new_shoppers: promotion.targetNewShoppers ?? false,
      },
      impressions: promotion.impressions,
      clicks: promotion.clicks,
      // Null rather than 0 before anything has been shown: a click-through
      // rate over no impressions is not zero, it is unknown.
      click_through_rate:
        promotion.impressions > 0
          ? Number((promotion.clicks / promotion.impressions).toFixed(4))
          : null,
    };
  }
}

const EMPTY_STATS = {
  reach: 0,
  attributed_orders: 0,
  attributed_revenue: { amount: '0', currency: Currency.SYP } as {
    amount: string;
    currency: Currency;
  },
};

function audienceOf(row: CandidateRow): AudienceSpec {
  return {
    targeted: row.audience === AdAudience.TARGETED,
    governorates: row.target_governorates ?? [],
    followers: row.target_followers,
    pastBuyers: row.target_past_buyers,
    interested: row.target_interested,
    newShoppers: row.target_new_shoppers,
  };
}

/**
 * A TARGETED audience that names nobody is EVERYONE, and governorates are
 * trimmed and de-duplicated, so «دمشق » and «دمشق» are one place.
 */
export function normaliseAudience(a: AudienceSpec): AudienceSpec {
  const governorates = [...new Set(a.governorates.map((g) => g.trim()).filter(Boolean))];
  const spec = { ...a, governorates };
  if (spec.targeted && governorates.length === 0 && !hasInterestGroups(spec)) {
    return EVERYONE;
  }
  return spec.targeted ? spec : EVERYONE;
}

/** Plan weight × what was paid per day — the chance of being picked. */
function servingWeight(row: CandidateRow, tier: StoreAdTier): number {
  const days = billedDays(row.starts_at, row.ends_at);
  const perDay = Number(row.fee_amount) / days;
  return AD_PLANS[tier].servingWeight * Math.max(perDay, 1);
}

function parseDaily(raw: unknown): number | null {
  const daily =
    typeof raw === 'number'
      ? raw
      : typeof raw === 'string'
        ? Number(raw)
        : raw && typeof raw === 'object' && 'amount' in raw
          ? Number((raw as { amount: unknown }).amount)
          : NaN;
  return Number.isFinite(daily) && daily > 0 ? daily : null;
}
