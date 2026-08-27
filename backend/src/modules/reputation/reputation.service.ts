import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  SellerOrderStatus,
  Prisma,
  ReviewStatus,
  ReviewTargetType,
  SellerBadgeType,
  SellerProgramTier,
  TrustVerificationStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { serializeUser } from '../../common/serializers';
import {
  AwardSellerBadgeDto,
  CreateReviewDto,
  ModerateReviewDto,
  RequestTrustedSellerVerificationDto,
  ReviewTrustedSellerVerificationDto,
} from './dto/reputation.dto';

const reviewUserSelect = {
  id: true,
  name: true,
  username: true,
  email: true,
  phone: true,
  bio: true,
  imageUrl: true,
  location: true,
  role: true,
  isVerified: true,
  mfaEnabled: true,
  deviceVerificationRequired: true,
  followersCount: true,
  followingCount: true,
  createdAt: true,
} satisfies Prisma.UserSelect;

@Injectable()
export class ReputationService {
  constructor(private readonly prisma: PrismaService) {}

  async productReviews(productId: string) {
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new NotFoundException('Product not found');

    const reviews = await this.prisma.productReview.findMany({
      where: { productId, status: ReviewStatus.APPROVED },
      include: { user: { select: reviewUserSelect } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return reviews.map((review) => this.serializeProductReview(review));
  }

  async sellerReviews(sellerId: string) {
    await this.ensureSeller(sellerId);
    const reviews = await this.prisma.sellerReview.findMany({
      where: { sellerId, status: ReviewStatus.APPROVED },
      include: { user: { select: reviewUserSelect } },
      orderBy: { createdAt: 'desc' },
      take: 100,
    });
    return reviews.map((review) => this.serializeSellerReview(review));
  }

  async createProductReview(userId: string, productId: string, dto: CreateReviewDto) {
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new NotFoundException('Product not found');
    await this.assertReviewIsUnique('product', {
      productId,
      userId,
      orderId: dto.order_id ?? null,
    });

    const verifiedPurchase = dto.order_id
      ? await this.hasPurchasedProduct(userId, productId, dto.order_id)
      : false;
    const review = await this.prisma.productReview.create({
      data: {
        productId,
        userId,
        orderId: dto.order_id ?? null,
        rating: dto.rating,
        title: dto.title?.trim() || null,
        body: dto.body?.trim() || null,
        verifiedPurchase,
        status: ReviewStatus.PENDING,
      },
      include: { user: { select: reviewUserSelect } },
    });
    return this.serializeProductReview(review);
  }

  async createSellerReview(userId: string, sellerId: string, dto: CreateReviewDto) {
    await this.ensureSeller(sellerId);
    if (userId === sellerId) {
      throw new BadRequestException('Sellers cannot review themselves');
    }
    await this.assertReviewIsUnique('seller', {
      sellerId,
      userId,
      orderId: dto.order_id ?? null,
    });

    const verifiedPurchase = dto.order_id
      ? await this.hasPurchasedFromSeller(userId, sellerId, dto.order_id)
      : false;
    const review = await this.prisma.sellerReview.create({
      data: {
        sellerId,
        userId,
        orderId: dto.order_id ?? null,
        rating: dto.rating,
        title: dto.title?.trim() || null,
        body: dto.body?.trim() || null,
        verifiedPurchase,
        status: ReviewStatus.PENDING,
      },
      include: { user: { select: reviewUserSelect } },
    });
    return this.serializeSellerReview(review);
  }

  async sellerReputation(sellerId: string) {
    await this.ensureSeller(sellerId);
    const reputation = await this.recalculateSeller(sellerId);
    const [seller, badges, verification] = await Promise.all([
      this.prisma.user.findUniqueOrThrow({
        where: { id: sellerId },
        select: reviewUserSelect,
      }),
      this.prisma.sellerBadge.findMany({
        where: {
          sellerId,
          OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
        },
        orderBy: { awardedAt: 'desc' },
      }),
      this.prisma.trustedSellerVerification.findUnique({
        where: { sellerId },
      }),
    ]);

    return {
      seller: serializeUser(seller),
      reputation: this.serializeReputation(reputation),
      badges: badges.map((badge) => this.serializeBadge(badge)),
      trusted_verification: verification
        ? this.serializeTrustedVerification(verification)
        : null,
    };
  }

  async moderateReview(moderatorId: string, dto: ModerateReviewDto) {
    if (dto.status === ReviewStatus.PENDING) {
      throw new BadRequestException('Moderation must choose a terminal status');
    }

    if (dto.target_type === ReviewTargetType.PRODUCT) {
      const current = await this.prisma.productReview.findUnique({
        where: { id: dto.review_id },
      });
      if (!current) throw new NotFoundException('Product review not found');

      const review = await this.prisma.$transaction(async (tx) => {
        const updated = await tx.productReview.update({
          where: { id: dto.review_id },
          data: { status: dto.status },
          include: { user: { select: reviewUserSelect } },
        });
        await tx.reviewModerationLog.create({
          data: {
            moderatorId,
            targetType: ReviewTargetType.PRODUCT,
            productReviewId: dto.review_id,
            fromStatus: current.status,
            toStatus: dto.status,
            reason: dto.reason?.trim() || null,
          },
        });
        return updated;
      });
      await this.recalculateProduct(review.productId);
      return this.serializeProductReview(review);
    }

    const current = await this.prisma.sellerReview.findUnique({
      where: { id: dto.review_id },
    });
    if (!current) throw new NotFoundException('Seller review not found');

    const review = await this.prisma.$transaction(async (tx) => {
      const updated = await tx.sellerReview.update({
        where: { id: dto.review_id },
        data: { status: dto.status },
        include: { user: { select: reviewUserSelect } },
      });
      await tx.reviewModerationLog.create({
        data: {
          moderatorId,
          targetType: ReviewTargetType.SELLER,
          sellerReviewId: dto.review_id,
          fromStatus: current.status,
          toStatus: dto.status,
          reason: dto.reason?.trim() || null,
        },
      });
      return updated;
    });
    await this.recalculateSeller(review.sellerId);
    return this.serializeSellerReview(review);
  }

  async awardBadge(dto: AwardSellerBadgeDto) {
    await this.ensureSeller(dto.seller_id);
    const badge = await this.prisma.sellerBadge.upsert({
      where: { sellerId_type: { sellerId: dto.seller_id, type: dto.type } },
      update: {
        label: dto.label?.trim() || this.defaultBadgeLabel(dto.type),
        reason: dto.reason?.trim() || null,
        expiresAt: dto.expires_at ? new Date(dto.expires_at) : null,
      },
      create: {
        sellerId: dto.seller_id,
        type: dto.type,
        label: dto.label?.trim() || this.defaultBadgeLabel(dto.type),
        reason: dto.reason?.trim() || null,
        expiresAt: dto.expires_at ? new Date(dto.expires_at) : null,
      },
    });
    return this.serializeBadge(badge);
  }

  async requestTrustedVerification(
    sellerId: string,
    dto: RequestTrustedSellerVerificationDto,
  ) {
    await this.ensureSeller(sellerId);
    const verification = await this.prisma.trustedSellerVerification.upsert({
      where: { sellerId },
      update: {
        status: TrustVerificationStatus.PENDING,
        evidence: (dto.evidence as Prisma.InputJsonValue) ?? Prisma.JsonNull,
        reviewedBy: null,
        reviewedAt: null,
      },
      create: {
        sellerId,
        status: TrustVerificationStatus.PENDING,
        evidence: (dto.evidence as Prisma.InputJsonValue) ?? Prisma.JsonNull,
      },
    });
    await this.recalculateSeller(sellerId);
    return this.serializeTrustedVerification(verification);
  }

  async reviewTrustedVerification(
    moderatorId: string,
    sellerId: string,
    dto: ReviewTrustedSellerVerificationDto,
  ) {
    await this.ensureSeller(sellerId);
    const verification = await this.prisma.trustedSellerVerification.upsert({
      where: { sellerId },
      update: {
        status: dto.status,
        reviewedBy: moderatorId,
        reviewedAt: new Date(),
      },
      create: {
        sellerId,
        status: dto.status,
        reviewedBy: moderatorId,
        reviewedAt: new Date(),
        evidence: dto.reason ? ({ note: dto.reason } as Prisma.InputJsonValue) : Prisma.JsonNull,
      },
    });
    const reputation = await this.recalculateSeller(sellerId);
    if (dto.status === TrustVerificationStatus.VERIFIED) {
      await this.upsertSystemBadge(
        sellerId,
        SellerBadgeType.TRUSTED,
        'Trusted seller',
        'Verified by the marketplace trust team',
      );
    }
    return {
      verification: this.serializeTrustedVerification(verification),
      reputation: this.serializeReputation(reputation),
    };
  }

  async moderationQueue() {
    const [products, sellers] = await Promise.all([
      this.prisma.productReview.findMany({
        where: { status: { in: [ReviewStatus.PENDING, ReviewStatus.FLAGGED] } },
        include: { user: { select: reviewUserSelect }, product: { select: { title: true } } },
        orderBy: { createdAt: 'asc' },
        take: 100,
      }),
      this.prisma.sellerReview.findMany({
        where: { status: { in: [ReviewStatus.PENDING, ReviewStatus.FLAGGED] } },
        include: { user: { select: reviewUserSelect }, seller: { select: reviewUserSelect } },
        orderBy: { createdAt: 'asc' },
        take: 100,
      }),
    ]);
    return {
      product_reviews: products.map((review) => ({
        ...this.serializeProductReview(review),
        product_title: review.product.title,
      })),
      seller_reviews: sellers.map((review) => ({
        ...this.serializeSellerReview(review),
        seller: serializeUser(review.seller),
      })),
    };
  }

  async recalculateProduct(productId: string) {
    const aggregate = await this.prisma.productReview.aggregate({
      where: { productId, status: ReviewStatus.APPROVED },
      _avg: { rating: true },
      _count: { _all: true },
    });
    await this.prisma.product.update({
      where: { id: productId },
      data: {
        rating: this.round(aggregate._avg.rating ?? 0),
        reviewsCount: aggregate._count._all,
      },
    });
  }

  private async recalculateSeller(sellerId: string) {
    const [reviews, verifiedReviews, orders, deliveredOrders, failedOrders, verification] =
      await Promise.all([
        this.prisma.sellerReview.aggregate({
          where: { sellerId, status: ReviewStatus.APPROVED },
          _avg: { rating: true },
          _count: { _all: true },
        }),
        this.prisma.sellerReview.count({
          where: {
            sellerId,
            status: ReviewStatus.APPROVED,
            verifiedPurchase: true,
          },
        }),
        // Counted per sub-order: the old query counted a whole multi-seller
        // order as delivered (or cancelled) for EVERY participating seller, so
        // one seller's cancellation damaged all their co-sellers' scores.
        this.prisma.sellerOrder.count({ where: { sellerId } }),
        this.prisma.sellerOrder.count({
          where: { sellerId, status: SellerOrderStatus.DELIVERED },
        }),
        this.prisma.sellerOrder.count({
          where: {
            sellerId,
            status: {
              in: [
                SellerOrderStatus.CANCELLED_BY_SELLER,
                SellerOrderStatus.CANCELLED_BY_CUSTOMER,
                SellerOrderStatus.REJECTED_ON_DELIVERY,
                SellerOrderStatus.REFUNDED,
              ],
            },
          },
        }),
        this.prisma.trustedSellerVerification.findUnique({
          where: { sellerId },
        }),
      ]);

    const averageRating = this.round(reviews._avg.rating ?? 0);
    const reviewScore = (averageRating / 5) * 70;
    const fulfillmentScore =
      orders === 0 ? 80 : Math.max(0, ((deliveredOrders - failedOrders) / orders) * 100);
    const responseScore = 90;
    const performanceScore = this.round(
      reviewScore + fulfillmentScore * 0.2 + responseScore * 0.1,
    );
    const customerSatisfactionScore = this.round(
      averageRating === 0 ? 0 : averageRating * 20,
    );
    const topSellerTier = this.programTier(
      performanceScore,
      reviews._count._all,
      deliveredOrders,
    );
    const trustedStatus = verification?.status ?? TrustVerificationStatus.PENDING;

    const reputation = await this.prisma.sellerReputation.upsert({
      where: { sellerId },
      update: {
        averageRating,
        reviewsCount: reviews._count._all,
        verifiedReviewsCount: verifiedReviews,
        performanceScore,
        customerSatisfactionScore,
        responseScore,
        fulfillmentScore: this.round(fulfillmentScore),
        topSellerTier,
        trustedStatus,
        calculatedAt: new Date(),
      },
      create: {
        sellerId,
        averageRating,
        reviewsCount: reviews._count._all,
        verifiedReviewsCount: verifiedReviews,
        performanceScore,
        customerSatisfactionScore,
        responseScore,
        fulfillmentScore: this.round(fulfillmentScore),
        topSellerTier,
        trustedStatus,
      },
    });

    if (
      topSellerTier === SellerProgramTier.TOP ||
      topSellerTier === SellerProgramTier.ELITE
    ) {
      await this.upsertSystemBadge(
        sellerId,
        SellerBadgeType.TOP_SELLER,
        topSellerTier === SellerProgramTier.ELITE ? 'Elite seller' : 'Top seller',
        'Awarded from performance and customer satisfaction signals',
      );
    }
    return reputation;
  }

  private async hasPurchasedProduct(
    userId: string,
    productId: string,
    orderId: string,
  ) {
    const order = await this.prisma.order.findFirst({
      where: {
        id: orderId,
        userId,
        sellerOrders: {
          some: {
            status: SellerOrderStatus.DELIVERED,
            items: { some: { productId } },
          },
        },
      },
      select: { id: true },
    });
    return Boolean(order);
  }

  private async hasPurchasedFromSeller(
    userId: string,
    sellerId: string,
    orderId: string,
  ) {
    const order = await this.prisma.order.findFirst({
      where: {
        id: orderId,
        userId,
        sellerOrders: {
          some: { sellerId, status: SellerOrderStatus.DELIVERED },
        },
      },
      select: { id: true },
    });
    return Boolean(order);
  }

  private async assertReviewIsUnique(
    type: 'product' | 'seller',
    input: {
      productId?: string;
      sellerId?: string;
      userId: string;
      orderId: string | null;
    },
  ) {
    const where =
      type === 'product'
        ? {
            productId: input.productId,
            userId: input.userId,
            orderId: input.orderId,
          }
        : {
            sellerId: input.sellerId,
            userId: input.userId,
            orderId: input.orderId,
          };
    const existing =
      type === 'product'
        ? await this.prisma.productReview.findFirst({ where })
        : await this.prisma.sellerReview.findFirst({ where });
    if (existing) {
      throw new BadRequestException('You have already reviewed this target');
    }
  }

  private async ensureSeller(sellerId: string) {
    const seller = await this.prisma.user.findUnique({
      where: { id: sellerId },
      select: { id: true, role: true },
    });
    if (!seller || seller.role !== UserRole.SELLER) {
      throw new NotFoundException('Seller not found');
    }
  }

  private async upsertSystemBadge(
    sellerId: string,
    type: SellerBadgeType,
    label: string,
    reason: string,
  ) {
    await this.prisma.sellerBadge.upsert({
      where: { sellerId_type: { sellerId, type } },
      update: { label, reason },
      create: { sellerId, type, label, reason },
    });
  }

  private programTier(score: number, reviews: number, deliveredOrders: number) {
    if (score >= 95 && reviews >= 100 && deliveredOrders >= 500) {
      return SellerProgramTier.ELITE;
    }
    if (score >= 88 && reviews >= 30 && deliveredOrders >= 100) {
      return SellerProgramTier.TOP;
    }
    if (score >= 75 && reviews >= 10) return SellerProgramTier.RISING;
    return SellerProgramTier.STANDARD;
  }

  private defaultBadgeLabel(type: SellerBadgeType) {
    const labels: Record<SellerBadgeType, string> = {
      TRUSTED: 'Trusted seller',
      TOP_SELLER: 'Top seller',
      FAST_SHIPPER: 'Fast shipper',
      CUSTOMER_LOVED: 'Customer loved',
      VERIFIED_BRAND: 'Verified brand',
    };
    return labels[type];
  }

  private serializeProductReview(
    review: Prisma.ProductReviewGetPayload<{
      include: { user: { select: typeof reviewUserSelect } };
    }>,
  ) {
    return {
      id: review.id,
      product_id: review.productId,
      order_id: review.orderId,
      user: serializeUser(review.user),
      rating: review.rating,
      title: review.title,
      body: review.body,
      verified_purchase: review.verifiedPurchase,
      status: review.status.toLowerCase(),
      helpful_count: review.helpfulCount,
      created_at: review.createdAt.toISOString(),
      updated_at: review.updatedAt.toISOString(),
    };
  }

  private serializeSellerReview(
    review: Prisma.SellerReviewGetPayload<{
      include: { user: { select: typeof reviewUserSelect } };
    }>,
  ) {
    return {
      id: review.id,
      seller_id: review.sellerId,
      order_id: review.orderId,
      user: serializeUser(review.user),
      rating: review.rating,
      title: review.title,
      body: review.body,
      verified_purchase: review.verifiedPurchase,
      status: review.status.toLowerCase(),
      created_at: review.createdAt.toISOString(),
      updated_at: review.updatedAt.toISOString(),
    };
  }

  private serializeReputation(
    reputation: Prisma.SellerReputationGetPayload<Record<string, never>>,
  ) {
    return {
      average_rating: reputation.averageRating,
      reviews_count: reputation.reviewsCount,
      verified_reviews_count: reputation.verifiedReviewsCount,
      performance_score: reputation.performanceScore,
      customer_satisfaction_score: reputation.customerSatisfactionScore,
      response_score: reputation.responseScore,
      fulfillment_score: reputation.fulfillmentScore,
      top_seller_tier: reputation.topSellerTier.toLowerCase(),
      trusted_status: reputation.trustedStatus.toLowerCase(),
      calculated_at: reputation.calculatedAt.toISOString(),
    };
  }

  private serializeBadge(badge: Prisma.SellerBadgeGetPayload<Record<string, never>>) {
    return {
      id: badge.id,
      seller_id: badge.sellerId,
      type: badge.type.toLowerCase(),
      label: badge.label,
      reason: badge.reason,
      awarded_at: badge.awardedAt.toISOString(),
      expires_at: badge.expiresAt?.toISOString() ?? null,
    };
  }

  private serializeTrustedVerification(
    verification: Prisma.TrustedSellerVerificationGetPayload<Record<string, never>>,
  ) {
    return {
      id: verification.id,
      seller_id: verification.sellerId,
      status: verification.status.toLowerCase(),
      evidence: verification.evidence,
      reviewed_by: verification.reviewedBy,
      reviewed_at: verification.reviewedAt?.toISOString() ?? null,
      created_at: verification.createdAt.toISOString(),
      updated_at: verification.updatedAt.toISOString(),
    };
  }

  private round(value: number) {
    return Math.round(value * 100) / 100;
  }
}
