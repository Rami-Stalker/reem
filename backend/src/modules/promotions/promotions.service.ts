import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  Logger,
  NotFoundException,
} from '@nestjs/common';
import {
  Currency,
  JournalEntryType,
  LedgerAccountCode,
  LedgerDirection,
  OfferStatus,
  ProductStatus,
  PromotionPlacement,
  PromotionStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { LedgerService } from '../ledger/ledger.service';
import { utcCast, utcParam } from '../../common/sql/utc-timestamp';

/**
 * How many paid slots a page may carry.
 *
 * Three, and it is a hard ceiling rather than a default. The value of a
 * marketplace's results is that they answer the question; a page whose top
 * half is bought stops answering it, and the customers leave long before the
 * advertising revenue makes up for them.
 */
export const MAX_SLOTS = 3;

/** The longest window a single placement may be bought for. */
const MAX_WINDOW_DAYS = 30;

/** System setting holding the minimum price of one day of placement, in SYP. */
export const MIN_DAILY_FEE_SETTING = 'promotions.min_daily_fee_syp';

@Injectable()
export class PromotionsService {
  private readonly logger = new Logger(PromotionsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly ledger: LedgerService,
  ) {}

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
    } = {},
  ): Promise<string[]> {
    const limit = Math.min(options.limit ?? MAX_SLOTS, MAX_SLOTS);
    const rows = await this.candidatesFor(placement, { ...options, limit });
    return rows.map((row) => row.offerId);
  }

  /**
   * Every live paid slot for a page, in serving order, with the product each
   * one advertises — up to `limit` (50 by default).
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
    } = {},
  ): Promise<{ offerId: string; productId: string }[]> {
    // An empty subtree means "nothing qualifies", not "no filter".
    if (options.categoryIds?.length === 0) return [];
    const limit = Math.max(1, Math.min(options.limit ?? 50, 50));
    const now = new Date();

    const rows = await this.prisma.$queryRawUnsafe<
      { offer_id: string; product_id: string }[]
    >(
      `
      SELECT p.offer_id, pr.id AS product_id
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
        AND ($8::uuid[] IS NULL OR pr.category_id = ANY($8::uuid[]))
      -- Oldest purchase first. Not a ranking of who paid most: with a flat
      -- fee there is nothing to outbid, and rotating by recency would let a
      -- seller re-buy her way back to the top all day.
      ORDER BY p.created_at ASC
      LIMIT $7
      `,
      PromotionStatus.ACTIVE,
      placement,
      utcParam(now),
      OfferStatus.ACTIVE,
      ProductStatus.ACTIVE,
      options.categoryId ?? null,
      limit,
      options.categoryIds ? [...options.categoryIds] : null,
    );

    // One slot per product: two sellers' offers on the same dress would
    // otherwise fill two of three slots with one picture.
    const seen = new Set<string>();
    const out: { offerId: string; productId: string }[] = [];
    for (const row of rows) {
      if (seen.has(row.product_id)) continue;
      seen.add(row.product_id);
      out.push({ offerId: row.offer_id, productId: row.product_id });
    }
    return out;
  }

  /**
   * Records that paid slots were shown, and that one was tapped.
   *
   * Reporting only — nothing about the money reads these counters. That is
   * what makes it safe for them to be incremented from a client.
   */
  async recordImpressions(
    offerIds: string[],
    placement?: PromotionPlacement,
  ): Promise<void> {
    if (offerIds.length === 0) return;
    await this.prisma.productPromotion.updateMany({
      where: this.liveWhere({ offerId: { in: offerIds } }, placement),
      data: { impressions: { increment: 1 } },
    });
  }

  async recordClick(
    offerId: string,
    placement?: PromotionPlacement,
  ): Promise<void> {
    await this.prisma.productPromotion.updateMany({
      where: this.liveWhere({ offerId }, placement),
      data: { clicks: { increment: 1 } },
    });
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

  // ── Buying ───────────────────────────────────────────────────────────────

  async create(input: {
    offerId: string;
    placement: PromotionPlacement;
    fee: Money;
    startsAt: Date;
    endsAt: Date;
    actorId: string;
    actorRole: UserRole;
  }) {
    if (!(input.endsAt > input.startsAt)) {
      throw new BadRequestException('A placement must end after it starts');
    }
    const days =
      (input.endsAt.getTime() - input.startsAt.getTime()) / 86_400_000;
    if (days > MAX_WINDOW_DAYS) {
      throw new BadRequestException(
        `A placement runs for at most ${MAX_WINDOW_DAYS} days`,
      );
    }
    if (input.fee.isZero()) {
      throw new BadRequestException('A placement with no fee is not a placement');
    }
    if (input.endsAt.getTime() <= Date.now()) {
      throw new BadRequestException('That window has already ended');
    }
    if (input.actorRole === UserRole.SELLER) {
      // The seller names her fee, so the platform names the floor. Without
      // one, a slot meant to cost a week of revenue sold for one lira.
      const floor = await this.minimumFee(days);
      if (floor !== null && input.fee.toUnsafeNumber() < floor) {
        throw new BadRequestException(
          `A placement of ${Math.ceil(days)} day(s) costs at least ${floor} SYP`,
        );
      }
    }

    const offer = await this.prisma.sellerOffer.findUnique({
      where: { id: input.offerId },
      select: { id: true, sellerId: true },
    });
    if (!offer) throw new NotFoundException('Offer not found');
    if (input.actorRole === UserRole.SELLER && offer.sellerId !== input.actorId) {
      throw new ForbiddenException('That listing is not yours');
    }

    const promotion = await this.prisma.productPromotion.create({
      data: {
        offerId: offer.id,
        sellerId: offer.sellerId,
        placement: input.placement,
        feeAmount: input.fee.toPrisma(),
        feeCurrency: input.fee.currency,
        startsAt: input.startsAt,
        endsAt: input.endsAt,
      },
    });

    return this.serialize(promotion);
  }

  /**
   * Takes the fee and turns the placement on.
   *
   * The charge and the status move in one transaction, so a promotion is never
   * live-but-unbilled or billed-but-dark. A boutique whose payable cannot
   * cover it is left `UNPAID` rather than shown for free — and told, rather
   * than left wondering why her slot never appeared.
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

    try {
      const charged = await this.prisma.$transaction(async (tx) => {
        // Her earnings pay for it: the platform owes her less, and books the
        // difference as promotion revenue. No new money moves, which is
        // exactly right — nothing has left anybody's hands.
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
                amount: fee,
              },
              {
                account: { code: LedgerAccountCode.PROMOTION_REVENUE },
                direction: LedgerDirection.CREDIT,
                amount: fee,
              },
            ],
          },
          tx,
        );

        return tx.productPromotion.update({
          where: { id: promotion.id },
          data: {
            status: PromotionStatus.ACTIVE,
            chargeReference: reference,
            chargedAt: new Date(),
          },
        });
      });

      return this.serialize(charged);
    } catch (error) {
      this.logger.warn(
        `Promotion ${promotion.id} not charged: ${String(error)}`,
      );
      await this.prisma.productPromotion.update({
        where: { id: promotion.id },
        data: { status: PromotionStatus.UNPAID },
      });
      throw new BadRequestException(
        `The placement fee of ${fee.toString()} could not be taken from your earnings`,
      );
    }
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
            product: { select: { id: true, title: true, slug: true } },
          },
        },
      },
    });
    return rows.map((row) => ({
      ...this.serialize(row),
      product: row.offer.product,
    }));
  }

  async listAll() {
    const rows = await this.prisma.productPromotion.findMany({
      orderBy: { createdAt: 'desc' },
      take: 200,
    });
    return rows.map((row) => this.serialize(row));
  }

  // ── internals ────────────────────────────────────────────────────────────

  /**
   * The least a seller may pay for a window of `days`, in SYP, or null when
   * staff have not set a rate.
   *
   * Read from the `promotions.min_daily_fee_syp` system setting so the price
   * of advertising is an operator's decision, changed from the console, and
   * not a constant someone has to ship a build to move.
   */
  private async minimumFee(days: number): Promise<number | null> {
    const setting = await this.prisma.systemSetting.findUnique({
      where: { key: MIN_DAILY_FEE_SETTING },
      select: { value: true },
    });
    const raw = setting?.value;
    const daily =
      typeof raw === 'number'
        ? raw
        : typeof raw === 'string'
          ? Number(raw)
          : raw && typeof raw === 'object' && 'amount' in raw
            ? Number((raw as { amount: unknown }).amount)
            : NaN;
    if (!Number.isFinite(daily) || daily <= 0) return null;
    return Math.ceil(daily * Math.max(1, Math.ceil(days)));
  }

  private async requireOwned(
    promotionId: string,
    actorId: string,
    actorRole: UserRole,
  ) {
    const promotion = await this.prisma.productPromotion.findUnique({
      where: { id: promotionId },
    });
    if (!promotion) throw new NotFoundException('Placement not found');
    if (actorRole === UserRole.SELLER && promotion.sellerId !== actorId) {
      throw new ForbiddenException('That placement is not yours');
    }
    return promotion;
  }

  private serialize(promotion: {
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
  }) {
    const now = new Date();
    return {
      id: promotion.id,
      offer_id: promotion.offerId,
      seller_id: promotion.sellerId,
      placement: promotion.placement.toLowerCase(),
      fee: Money.of(promotion.feeAmount as never, promotion.feeCurrency).toJSON(),
      status: promotion.status.toLowerCase(),
      starts_at: promotion.startsAt.toISOString(),
      ends_at: promotion.endsAt.toISOString(),
      charged_at: promotion.chargedAt?.toISOString() ?? null,
      is_live:
        promotion.status === PromotionStatus.ACTIVE &&
        promotion.startsAt <= now &&
        promotion.endsAt > now,
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
