import { BadRequestException, Injectable } from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { CouponType, PointsTransactionType } from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import { AppEvent } from '../../common/events/app-events';
import {
  serializeCoupon,
  serializePointsTransaction,
} from './rewards.serializer';

/** 100 points = 1 currency unit of discount. */
const POINTS_PER_UNIT = 100;
const MIN_REDEEM = 100;
const REDEEM_TTL_DAYS = 30;

@Injectable()
export class PointsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
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
      redeem_rate: POINTS_PER_UNIT,
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

  /** Converts points into a one-time, user-specific discount coupon. */
  async redeem(userId: string, points: number) {
    if (points < MIN_REDEEM || points % 100 !== 0) {
      throw new BadRequestException('Redeem points in multiples of 100');
    }
    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user || user.points < points) {
      throw new BadRequestException('Insufficient points balance');
    }

    const discount = points / POINTS_PER_UNIT;
    const code = `PTS-${randomUUID().split('-')[0].toUpperCase()}`;
    const expiresAt = new Date(Date.now() + REDEEM_TTL_DAYS * 24 * 60 * 60 * 1000);

    const coupon = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.user.update({
        where: { id: userId },
        data: { points: { decrement: points } },
      });
      await tx.pointsTransaction.create({
        data: {
          userId,
          type: PointsTransactionType.REDEEM,
          points: -points,
          reason: 'Redeemed for a discount coupon',
          balanceAfter: updated.points,
        },
      });
      return tx.coupon.create({
        data: {
          code,
          title: `$${discount} reward`,
          type: CouponType.FIXED,
          amountOff: discount,
          userId,
          maxUses: 1,
          perUserLimit: 1,
          expiresAt,
        },
      });
    });

    this.events.emit(AppEvent.CouponIssued, {
      userId,
      couponCode: coupon.code,
      title: coupon.title,
    });

    return {
      points_redeemed: points,
      discount,
      coupon: serializeCoupon(coupon),
    };
  }
}
