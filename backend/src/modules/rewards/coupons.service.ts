import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Coupon, CouponType, Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import { serializeCoupon } from './rewards.serializer';
import { CreateCouponDto, UpdateCouponDto } from './dto/rewards.dto';

const round = (n: number) => Math.round(n * 100) / 100;

export interface CouponEvaluation {
  coupon: Coupon;
  discount: Money;
}

@Injectable()
export class CouponsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Admin CRUD ───────────────────────────────────────────────────────────

  async create(dto: CreateCouponDto) {
    const coupon = await this.prisma.coupon.create({
      data: {
        code: dto.code.toUpperCase(),
        title: dto.title,
        type: dto.type,
        discountPercent: dto.discount_percent ?? 0,
        amountOff: dto.amount_off ?? null,
        minOrderAmount: dto.min_order_amount ?? null,
        maxUses: dto.max_uses ?? null,
        perUserLimit: dto.per_user_limit ?? null,
        userId: dto.user_id ?? null,
        expiresAt: new Date(dto.expires_at),
        isActive: dto.is_active ?? true,
      },
    });
    return serializeCoupon(coupon);
  }

  async update(id: string, dto: UpdateCouponDto) {
    await this.requireCoupon(id);
    const coupon = await this.prisma.coupon.update({
      where: { id },
      data: {
        ...(dto.title !== undefined && { title: dto.title }),
        ...(dto.type !== undefined && { type: dto.type }),
        ...(dto.discount_percent !== undefined && {
          discountPercent: dto.discount_percent,
        }),
        ...(dto.amount_off !== undefined && { amountOff: dto.amount_off }),
        ...(dto.min_order_amount !== undefined && {
          minOrderAmount: dto.min_order_amount,
        }),
        ...(dto.max_uses !== undefined && { maxUses: dto.max_uses }),
        ...(dto.per_user_limit !== undefined && {
          perUserLimit: dto.per_user_limit,
        }),
        ...(dto.expires_at !== undefined && {
          expiresAt: new Date(dto.expires_at),
        }),
        ...(dto.is_active !== undefined && { isActive: dto.is_active }),
      },
    });
    return serializeCoupon(coupon);
  }

  async setActive(id: string, isActive: boolean) {
    await this.requireCoupon(id);
    return serializeCoupon(
      await this.prisma.coupon.update({ where: { id }, data: { isActive } }),
    );
  }

  async remove(id: string) {
    await this.requireCoupon(id);
    await this.prisma.coupon.delete({ where: { id } });
    return { message: 'Coupon deleted' };
  }

  async listAll(page: PaginationDto) {
    const [coupons, total] = await Promise.all([
      this.prisma.coupon.findMany({
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
      }),
      this.prisma.coupon.count(),
    ]);
    return {
      data: coupons.map(serializeCoupon),
      pagination: buildMeta(page.page, page.limit, total, coupons.length),
    };
  }

  // ── Customer ─────────────────────────────────────────────────────────────

  async listAvailable(userId: string) {
    const coupons = await this.prisma.coupon.findMany({
      where: {
        isActive: true,
        expiresAt: { gt: new Date() },
        OR: [{ userId: null }, { userId }],
      },
      orderBy: { createdAt: 'desc' },
    });
    return coupons.map(serializeCoupon);
  }

  async validate(code: string, userId: string, subtotal: Money) {
    const { coupon, discount } = await this.evaluate(code, userId, subtotal);
    return {
      valid: true,
      code: coupon.code,
      type: coupon.type.toLowerCase(),
      discount: discount.toJSON(),
    };
  }

  /**
   * Full eligibility check. Throws a 400 with the specific reason, or returns
   * the coupon + computed discount. Reused by the checkout flow.
   */
  async evaluate(
    code: string,
    userId: string,
    subtotal: Money,
  ): Promise<CouponEvaluation> {
    const coupon = await this.prisma.coupon.findUnique({ where: { code } });
    if (!coupon || !coupon.isActive || coupon.expiresAt < new Date()) {
      throw new BadRequestException('Invalid or expired coupon');
    }
    if (coupon.userId && coupon.userId !== userId) {
      throw new BadRequestException('This coupon is not available for your account');
    }
    if (coupon.maxUses != null && coupon.usedCount >= coupon.maxUses) {
      throw new BadRequestException('This coupon has reached its usage limit');
    }
    if (coupon.minOrderAmount != null) {
      const minimum = Money.of(coupon.minOrderAmount, coupon.currency);
      // A minimum stated in another currency cannot be compared, so the
      // coupon simply does not apply rather than silently passing.
      if (minimum.currency !== subtotal.currency) {
        throw new BadRequestException(
          `This coupon applies to ${minimum.currency} orders only`,
        );
      }
      if (subtotal.lessThan(minimum)) {
        throw new BadRequestException(
          `Minimum order of ${minimum.toString()} required for this coupon`,
        );
      }
    }
    if (coupon.perUserLimit != null) {
      const used = await this.prisma.couponRedemption.count({
        where: { couponId: coupon.id, userId },
      });
      if (used >= coupon.perUserLimit) {
        throw new BadRequestException('You have already used this coupon');
      }
    }
    return { coupon, discount: this.computeDiscount(coupon, subtotal) };
  }

  /**
   * Claims one use of a coupon, inside the caller's transaction.
   *
   * Two things were wrong with recording this afterwards, and both of them
   * are ways a coupon gets spent more times than it was issued for.
   *
   * The first is atomicity. The redemption used to be written in its own
   * transaction after checkout had already committed, so a process that died
   * in the gap left an order that carried the discount and a coupon that had
   * never heard of it. Re-run often enough, a `max_uses: 1` code funds a
   * hundred baskets. The write now commits with the order or not at all.
   *
   * The second is the race. `evaluate` reads `usedCount` and counts this
   * woman's past redemptions, and both figures are already stale by the time
   * the increment lands — ten concurrent checkouts of the same code all read
   * zero and all pass. The row lock below is what makes the limits mean
   * anything: redeemers of one coupon queue behind each other, so the count
   * each of them re-reads includes everyone ahead in the queue. Different
   * coupons never contend.
   */
  async redeemInTransaction(
    tx: Prisma.TransactionClient,
    couponId: string,
    userId: string,
    orderId: string,
    amount: Money,
  ): Promise<void> {
    await tx.$queryRaw`SELECT id FROM coupons WHERE id = ${couponId}::uuid FOR UPDATE`;

    const coupon = await tx.coupon.findUnique({ where: { id: couponId } });
    if (!coupon) throw new NotFoundException('Coupon not found');

    if (coupon.maxUses != null && coupon.usedCount >= coupon.maxUses) {
      throw new BadRequestException('This coupon has reached its usage limit');
    }
    if (coupon.perUserLimit != null) {
      const used = await tx.couponRedemption.count({
        where: { couponId, userId },
      });
      if (used >= coupon.perUserLimit) {
        throw new BadRequestException('You have already used this coupon');
      }
    }

    await tx.couponRedemption.create({
      data: {
        couponId,
        userId,
        orderId,
        currency: amount.currency,
        amount: amount.toPrisma(),
      },
    });
    await tx.coupon.update({
      where: { id: couponId },
      data: { usedCount: { increment: 1 } },
    });
  }

  private computeDiscount(coupon: Coupon, subtotal: Money): Money {
    if (coupon.type === CouponType.FIXED) {
      const off = Money.of(coupon.amountOff ?? 0, coupon.currency);
      // Never discount more than the basket is worth.
      return off.currency === subtotal.currency ? off.clampMax(subtotal) : Money.zero(subtotal.currency);
    }
    return subtotal
      .times(coupon.discountPercent.dividedBy(100))
      .clampMax(subtotal);
  }

  private async requireCoupon(id: string): Promise<Coupon> {
    const coupon = await this.prisma.coupon.findUnique({ where: { id } });
    if (!coupon) throw new NotFoundException('Coupon not found');
    return coupon;
  }
}
