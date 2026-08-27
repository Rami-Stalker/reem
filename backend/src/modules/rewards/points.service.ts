import { BadRequestException, Injectable } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { CouponType, PointsTransactionType } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service';
import {
  LoyaltyService,
  POINTS_PER_REDEMPTION,
  SYP_PER_REDEMPTION,
} from '../finance/loyalty.service';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import { AppEvent } from '../../common/events/app-events';
import {
  serializeCoupon,
  serializePointsTransaction,
} from './rewards.serializer';

/**
 * What a point is worth lives in one place: `LoyaltyService`, which carries
 * the client's own answer (Q43 — «كل 10 نقاط = 5000 ل.س رصيد»).
 *
 * This service used to hold a second rate of its own — 100 points to one
 * currency unit, minted as a coupon denominated in dollars — which predated
 * that answer and disagreed with it by orders of magnitude. Two instruments
 * for the same points at two rates is not a feature with a preference; it is
 * a bug with a screen in front of it.
 */

@Injectable()
export class PointsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
    private readonly loyalty: LoyaltyService,
  ) {}

  async balance(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { points: true, lifetimePoints: true, tier: true },
    });
    return {
      points: user?.points ?? 0,
      lifetime_points: user?.lifetimePoints ?? 0,
      tier: user?.tier ?? 'Bronze',
      // Q43's own numbers, read from the service that owns them.
      redeem_step: POINTS_PER_REDEMPTION,
      redeem_value_syp: SYP_PER_REDEMPTION,
    };
  }

  async history(userId: string, page: PaginationDto) {
    const [items, total] = await Promise.all([
      this.prisma.pointsTransaction.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
      }),
      this.prisma.pointsTransaction.count({ where: { userId } }),
    ]);
    return {
      data: items.map(serializePointsTransaction),
      pagination: buildMeta(page.page, page.limit, total, items.length),
    };
  }

  /** Award points (e.g. after a successful purchase). Idempotency is the caller's job. */
  async earn(
    userId: string,
    points: number,
    reason: string,
    orderId?: string,
  ): Promise<void> {
    if (points <= 0) return;
    await this.prisma.$transaction(async (tx) => {
      const user = await tx.user.update({
        where: { id: userId },
        data: {
          points: { increment: points },
          lifetimePoints: { increment: points },
        },
      });
      await tx.pointsTransaction.create({
        data: {
          userId,
          type: PointsTransactionType.EARN,
          points,
          reason,
          orderId: orderId ?? null,
          balanceAfter: user.points,
        },
      });
    });
  }

  /**
   * Q43 — converts points into wallet credit.
   *
   * Delegates to `LoyaltyService`, which owns the rate, posts the ledger entry
   * and carries the liability. What she receives changed with this: spendable
   * credit (Q41/Q42) instead of a single-use coupon at a different rate.
   */
  async redeem(userId: string, points: number) {
    // The shape comes back from the loyalty service unchanged: one service
    // describes a conversion, and a second wording of the same event is how
    // two screens end up quoting different figures.
    return this.loyalty.convertToWallet(userId, points);
  }
}
