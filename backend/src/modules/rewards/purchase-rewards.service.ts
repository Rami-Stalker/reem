import { Injectable, Logger } from '@nestjs/common';
import { Prisma, SellerOrderStatus } from '@prisma/client';

import { CANCELLED_STATUSES, Money } from '../../common/money';
import { PrismaService } from '../../prisma/prisma.service';
import { keptGoodsOf } from '../finance/loyalty.service';
import { MembershipService } from './membership.service';
import { ReferralsService } from './referrals.service';

/** One sweep's worth; a backlog drains over consecutive runs. */
const SWEEP_BATCH = 200;

/**
 * Parcels that ended without a sale. They neither earn a reward nor hold one
 * back: an order is final when each of its parcels is either released (the
 * sale stands) or one of these (there was no sale).
 */
const ENDED_WITHOUT_SALE: readonly SellerOrderStatus[] = [
  ...CANCELLED_STATUSES,
  SellerOrderStatus.RETURNED,
  SellerOrderStatus.REFUND_PENDING,
  SellerOrderStatus.REFUNDED,
];

/**
 * The rewards a purchase earns — tier spend, tier bonus points and cashback,
 * and a referral's reward — granted once, when the sale is final.
 *
 * Checkout used to grant all of these the moment an order was placed: before
 * it was paid, before it shipped, and with nothing that took them back when
 * the order was cancelled or expired unpaid. Points convert into wallet
 * credit, so placing and cancelling an order was a way to mint spendable
 * money. Q43 had already said when a purchase counts — «بعد انتهاء مدة
 * الاسترجاع» — and the loyalty accrual followed it; these now do too.
 *
 * Exactly once per order, by claiming `rewardsGrantedAt` with a conditional
 * update before anything is granted. A grant that fails releases the claim so
 * the next sweep tries again.
 */
@Injectable()
export class PurchaseRewardsService {
  private readonly logger = new Logger(PurchaseRewardsService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly membership: MembershipService,
    private readonly referrals: ReferralsService,
  ) {}

  /**
   * Grants an order's rewards if every parcel in it has reached its end.
   * Returns true when this call granted them.
   */
  async grantIfFinal(orderId: string): Promise<boolean> {
    const order = await this.prisma.order.findUnique({
      where: { id: orderId },
      select: {
        id: true,
        userId: true,
        currency: true,
        placedAt: true,
        rewardsGrantedAt: true,
        sellerOrders: {
          select: {
            id: true,
            status: true,
            escrowReleased: true,
            currency: true,
            itemsSubtotal: true,
            discountTotal: true,
          },
        },
      },
    });
    // A guest has no account to reward (Q46 P1).
    if (!order || !order.userId || order.rewardsGrantedAt) return false;
    if (order.sellerOrders.length === 0) return false;

    const stillOpen = order.sellerOrders.some(
      (parcel) =>
        !parcel.escrowReleased && !ENDED_WITHOUT_SALE.includes(parcel.status),
    );
    if (stillOpen) return false;

    const kept = Money.sum(
      await Promise.all(
        order.sellerOrders
          .filter((parcel) => parcel.escrowReleased)
          .map((parcel) => keptGoodsOf(this.prisma, parcel)),
      ),
      order.currency,
    );

    const claimed = await this.prisma.order.updateMany({
      where: { id: orderId, rewardsGrantedAt: null },
      data: { rewardsGrantedAt: new Date() },
    });
    if (claimed.count === 0) return false;

    // Nothing was kept — every parcel was cancelled, refused or returned.
    // The claim stays: the order is final and there is nothing to grant.
    if (kept.isZero()) return false;

    try {
      await this.membership.recordPurchase(order.userId, order.id, kept);
      await this.referrals.qualifyReferralForOrder(
        order.userId,
        order.id,
        order.placedAt ?? undefined,
      );
    } catch (error) {
      await this.prisma.order
        .update({ where: { id: orderId }, data: { rewardsGrantedAt: null } })
        .catch(() => undefined);
      throw error;
    }
    return true;
  }

  /**
   * Catches the orders whose last parcel ended by something other than an
   * escrow release — a cancellation or a return after a sibling was released —
   * so no event was there to grant them.
   */
  async sweep(): Promise<{ granted: number; failed: number }> {
    const candidates = await this.prisma.order.findMany({
      where: {
        rewardsGrantedAt: null,
        userId: { not: null },
        // At least one sale stood, and nothing is still on its way: the
        // orders that are final. Anything else would sit at the front of
        // this oldest-first batch for ever and starve the ones behind it.
        AND: [
          { sellerOrders: { some: { escrowReleased: true } } },
          {
            sellerOrders: {
              none: {
                escrowReleased: false,
                status: { notIn: [...ENDED_WITHOUT_SALE] },
              },
            },
          },
        ],
      } satisfies Prisma.OrderWhereInput,
      select: { id: true },
      orderBy: { placedAt: 'asc' },
      take: SWEEP_BATCH,
    });

    let granted = 0;
    let failed = 0;
    for (const order of candidates) {
      try {
        if (await this.grantIfFinal(order.id)) granted += 1;
      } catch (error) {
        failed += 1;
        this.logger.error(
          `Purchase rewards for order ${order.id} failed; the next sweep ` +
            `retries: ${(error as Error).message}`,
        );
      }
    }
    return { granted, failed };
  }
}
