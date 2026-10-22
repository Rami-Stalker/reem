import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Coupon, CouponType, Prisma, UserRole } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { Money } from '../../common/money';
import { ScopedLine, eligibleSubtotal, scopeRefusal } from './coupon-scope';
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
    await this.assertScopeExists(dto);
    const coupon = await this.prisma.coupon.create({
      data: {
        code: dto.code.toUpperCase(),
        sellerId: dto.seller_id ?? null,
        categoryId: dto.category_id ?? null,
        productId: dto.product_id ?? null,
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
    await this.assertScopeExists(dto);
    const coupon = await this.prisma.coupon.update({
      where: { id },
      data: {
        // `null` is meaningful and distinct from absent: it *clears* a scope.
        // An operator who scoped a code to the wrong boutique needs a way back
        // without deleting a code customers may already be holding.
        ...(dto.seller_id !== undefined && { sellerId: dto.seller_id }),
        ...(dto.category_id !== undefined && { categoryId: dto.category_id }),
        ...(dto.product_id !== undefined && { productId: dto.product_id }),
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
    /**
     * The basket, when the caller has it.
     *
     * Checkout does; the coupon-preview screen may not. When lines are given,
     * the discount is computed on the part of the basket the code actually
     * covers — which is what stops a code for one dress taking its percentage
     * off a basket of five, and stops a seller-funded code being charged to
     * every seller in the order. Omitted, the code applies to the whole
     * subtotal, which is how every coupon behaved before scopes existed.
     */
    lines?: readonly ScopedLine[],
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
    // The scope is applied last, after every reason the *coupon* might be
    // refused, so "you have already used this" is never hidden behind "this is
    // not in your basket".
    const base = lines ? eligibleSubtotal(coupon, lines, subtotal) : subtotal;
    if (base.isZero() && this.isScoped(coupon)) {
      throw new BadRequestException({
        code: 'COUPON_NOT_APPLICABLE',
        message: scopeRefusal(coupon),
      });
    }

    return { coupon, discount: this.computeDiscount(coupon, base) };
  }

  /** True when the code names a seller, a category or a product. */
  private isScoped(coupon: Coupon): boolean {
    return Boolean(coupon.sellerId || coupon.categoryId || coupon.productId);
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
    const zero = Money.zero(subtotal.currency);
    if (coupon.type === CouponType.FIXED) {
      const off = Money.of(coupon.amountOff ?? 0, coupon.currency);
      // Never discount more than the basket is worth, and never less than
      // nothing: a negative amount on a mistyped coupon would be a surcharge.
      return off.currency === subtotal.currency
        ? off.clampMax(subtotal).clampMin(zero).quantize()
        : zero;
    }
    // Quantized here, where the figure is born: a percentage of an odd
    // subtotal runs past the four places a column keeps, and the order's
    // discount and its per-seller shares would then round apart on disk.
    return subtotal
      .times(coupon.discountPercent.dividedBy(100))
      .clampMax(subtotal)
      .clampMin(zero)
      .quantize()
      .clampMax(subtotal);
  }

  /**
   * Refuses a scope that names nothing.
   *
   * A mistyped id would otherwise create a code that silently covers no line
   * in any basket — it would validate, activate, sit in the console looking
   * live, and refuse every customer who typed it. The seller check also
   * insists the account *is* a seller: scoping a discount to a shopper's id is
   * a code nobody can ever spend.
   */
  private async assertScopeExists(scope: {
    seller_id?: string | null;
    category_id?: string | null;
    product_id?: string | null;
  }): Promise<void> {
    if (scope.seller_id) {
      const seller = await this.prisma.user.findUnique({
        where: { id: scope.seller_id },
        select: { role: true },
      });
      if (!seller || seller.role !== UserRole.SELLER) {
        throw new BadRequestException({
          code: 'COUPON_SCOPE_NOT_A_SELLER',
          message: 'That account is not a seller',
        });
      }
    }

    if (scope.category_id) {
      const category = await this.prisma.category.findUnique({
        where: { id: scope.category_id },
        select: { id: true },
      });
      if (!category) {
        throw new BadRequestException({
          code: 'COUPON_SCOPE_CATEGORY_NOT_FOUND',
          message: 'Category not found',
        });
      }
    }

    if (scope.product_id) {
      const product = await this.prisma.product.findUnique({
        where: { id: scope.product_id },
        select: { id: true },
      });
      if (!product) {
        throw new BadRequestException({
          code: 'COUPON_SCOPE_PRODUCT_NOT_FOUND',
          message: 'Product not found',
        });
      }
    }
  }

  private async requireCoupon(id: string): Promise<Coupon> {
    const coupon = await this.prisma.coupon.findUnique({ where: { id } });
    if (!coupon) throw new NotFoundException('Coupon not found');
    return coupon;
  }
}
