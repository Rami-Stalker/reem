import {
  BadRequestException,
  ForbiddenException,
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
import { serializePublicUser } from '../../common/serializers';
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

  /**
   * What everyone can read about this product — plus, for the woman asking,
   * her own review while it is still in moderation.
   *
   * Reviews are published only once a moderator approves them, which is right
   * for everybody else's screen and wrong for hers: she wrote a review, the
   * app said «تم إرسال تقييمك», the list reloaded without it and she
   * reasonably concluded it had been lost. Her own row now comes back with its
   * `status`, so the client can show it marked as under review. This is the
   * same rule `myReviews` already follows.
   */
  async productReviews(productId: string, viewerId?: string) {
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new NotFoundException('Product not found');

    const reviews = await this.prisma.productReview.findMany({
      where: {
        productId,
        OR: [
          { status: ReviewStatus.APPROVED },
          // Never a rejected one: telling her it was refused belongs in a
          // notification with a reason, not in the public list.
          ...(viewerId
            ? [{ userId: viewerId, status: ReviewStatus.PENDING }]
            : []),
        ],
      },
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

  /**
   * Every review of her goods and of her shop, in one list.
   *
   * A seller does not think in terms of two tables — she thinks about what
   * people are saying — so product reviews and shop reviews are merged and
   * sorted together, each tagged with which it is. `unanswered` is the filter
   * she actually works: an unanswered one-star review is the thing worth her
   * afternoon.
   *
   * Only APPROVED reviews appear. A review still in moderation is not public,
   * and answering one that may never be published would be answering nobody.
   */
  async reviewsForSeller(sellerId: string, filter: 'all' | 'unanswered' = 'all') {
    await this.ensureSeller(sellerId);

    const unanswered = filter === 'unanswered' ? { sellerReply: null } : {};

    const [productReviews, sellerReviews] = await Promise.all([
      this.prisma.productReview.findMany({
        where: {
          status: ReviewStatus.APPROVED,
          ...unanswered,
          // Hers is any product she lists — the catalogue entry is shared, so
          // ownership runs through the offer, not the product.
          product: { offers: { some: { sellerId } } },
        },
        include: {
          user: { select: reviewUserSelect },
          product: { select: { id: true, title: true, media: { take: 1, orderBy: { sortOrder: 'asc' } } } },
        },
        orderBy: { createdAt: 'desc' },
        take: 100,
      }),
      this.prisma.sellerReview.findMany({
        where: { sellerId, status: ReviewStatus.APPROVED, ...unanswered },
        include: { user: { select: reviewUserSelect } },
        orderBy: { createdAt: 'desc' },
        take: 100,
      }),
    ]);

    const merged = [
      ...productReviews.map((review) => ({
        ...this.serializeProductReview(review),
        target_type: ReviewTargetType.PRODUCT,
        product: {
          id: review.product.id,
          title: review.product.title,
          image: review.product.media[0]?.url ?? null,
        },
      })),
      ...sellerReviews.map((review) => ({
        ...this.serializeSellerReview(review),
        target_type: ReviewTargetType.SELLER,
        product: null,
      })),
    ];

    merged.sort((a, b) => b.created_at.localeCompare(a.created_at));

    return {
      data: merged,
      unanswered: merged.filter((review) => !review.seller_reply).length,
    };
  }

  /**
   * Everything *she* has written, product reviews and shop reviews together.
   *
   * The profile already showed her a count and an average — the aggregate was
   * computed and displayed — while the row that offered to open them was a
   * "coming soon" sheet, because nothing could list them.
   *
   * Unlike every other read here this one is **not** filtered to APPROVED. A
   * review of her own still in moderation is hers to see; hiding it would look
   * like the app had lost it, and she would write it again.
   */
  async reviewsByAuthor(userId: string) {
    const [productReviews, sellerReviews] = await Promise.all([
      this.prisma.productReview.findMany({
        where: { userId },
        include: {
          user: { select: reviewUserSelect },
          product: {
            select: {
              id: true,
              title: true,
              media: { take: 1, orderBy: { sortOrder: 'asc' } },
            },
          },
        },
        orderBy: { createdAt: 'desc' },
        take: 100,
      }),
      this.prisma.sellerReview.findMany({
        where: { userId },
        include: {
          user: { select: reviewUserSelect },
          seller: { select: { id: true, name: true, imageUrl: true } },
        },
        orderBy: { createdAt: 'desc' },
        take: 100,
      }),
    ]);

    const merged = [
      ...productReviews.map((review) => ({
        ...this.serializeProductReview(review),
        target_type: ReviewTargetType.PRODUCT,
        // What she reviewed, named — a list of bare star ratings tells her
        // nothing about which one she is looking at.
        subject: {
          id: review.product.id,
          title: review.product.title,
          image: review.product.media[0]?.url ?? null,
        },
      })),
      ...sellerReviews.map((review) => ({
        ...this.serializeSellerReview(review),
        target_type: ReviewTargetType.SELLER,
        subject: {
          id: review.seller.id,
          title: review.seller.name,
          image: review.seller.imageUrl ?? null,
        },
      })),
    ];

    merged.sort((a, b) => b.created_at.localeCompare(a.created_at));

    const count = merged.length;
    const average =
      count === 0
        ? 0
        : Number(
            (
              merged.reduce((sum, review) => sum + review.rating, 0) / count
            ).toFixed(2),
          );

    return { data: merged, count, average };
  }

  /**
   * The seller answers a review, publicly.
   *
   * Ownership is checked against the thing being reviewed, not against the
   * review row: for a product review that means she must actually list the
   * product. Writing an empty reply removes it, which is the only way back for
   * a sentence written in anger.
   */
  async replyToReview(
    sellerId: string,
    reviewId: string,
    targetType: ReviewTargetType,
    reply: string,
  ) {
    await this.ensureSeller(sellerId);
    const trimmed = reply.trim();
    const data = {
      sellerReply: trimmed.length === 0 ? null : trimmed,
      sellerRepliedAt: trimmed.length === 0 ? null : new Date(),
    };

    if (targetType === ReviewTargetType.SELLER) {
      const review = await this.prisma.sellerReview.findUnique({
        where: { id: reviewId },
        select: { sellerId: true, status: true },
      });
      if (!review || review.sellerId !== sellerId) {
        throw new NotFoundException('Review not found');
      }
      this.assertAnswerable(review.status);

      const updated = await this.prisma.sellerReview.update({
        where: { id: reviewId },
        data,
        include: { user: { select: reviewUserSelect } },
      });
      return this.serializeSellerReview(updated);
    }

    const review = await this.prisma.productReview.findUnique({
      where: { id: reviewId },
      select: {
        status: true,
        product: { select: { offers: { where: { sellerId }, take: 1 } } },
      },
    });
    if (!review || review.product.offers.length === 0) {
      throw new NotFoundException('Review not found');
    }
    this.assertAnswerable(review.status);

    const updated = await this.prisma.productReview.update({
      where: { id: reviewId },
      data,
      include: { user: { select: reviewUserSelect } },
    });
    return this.serializeProductReview(updated);
  }

  /**
   * A review nobody can read is a review nobody can be answered in front of.
   * Refusing here rather than silently accepting keeps a seller from writing a
   * careful reply to something that is never published.
   */
  private assertAnswerable(status: ReviewStatus) {
    if (status !== ReviewStatus.APPROVED) {
      throw new BadRequestException(
        'This review is not published, so there is nobody to answer yet',
      );
    }
  }

  async createProductReview(userId: string, productId: string, dto: CreateReviewDto) {
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new NotFoundException('Product not found');

    // The purchase is the credential.
    //
    // `order_id` used to be optional and, when absent, the review was written
    // anyway with `verifiedPurchase: false`. So any account could review any
    // product it had never bought — and any seller — with moderation as the
    // only thing standing between the catalogue and a competitor with a
    // scripted client. The order is now **resolved here** rather than taken
    // from the request: the client's hint is honoured when it names one of her
    // own delivered orders, and ignored otherwise, so no id in a request body
    // can make a purchase that did not happen.
    const orderId = await this.requireDeliveredProductPurchase(
      userId,
      productId,
      dto.order_id ?? null,
    );

    await this.assertReviewIsUnique('product', { productId, userId });

    const verifiedPurchase = true;
    const review = await this.prisma.productReview.create({
      data: {
        productId,
        userId,
        orderId,
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
    // Same rule as a product review: only a woman this boutique has actually
    // delivered to may rate it. See `createProductReview`.
    const orderId = await this.requireDeliveredSellerPurchase(
      userId,
      sellerId,
      dto.order_id ?? null,
    );

    await this.assertReviewIsUnique('seller', { sellerId, userId });

    const verifiedPurchase = true;
    const review = await this.prisma.sellerReview.create({
      data: {
        sellerId,
        userId,
        orderId,
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
      seller: serializePublicUser(seller),
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
        seller: serializePublicUser(review.seller),
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

    // Response time is measured, not assumed.
    //
    // This used to be `const responseScore = 90` — a literal that every seller
    // on the platform carried identically, whether she answered in ten minutes
    // or never. Seller Intelligence measures it from the actual gap between a
    // buyer's first message and the seller's first reply, and writes it onto
    // this same row.
    //
    // So the existing value is read back rather than overwritten. `null` is
    // the honest answer for a shop nobody has messaged yet, and the composite
    // below renormalises without it rather than substituting a number.
    const existing = await this.prisma.sellerReputation.findUnique({
      where: { sellerId },
      select: { responseScore: true },
    });
    const responseScore = existing?.responseScore ?? null;

    const performanceScore = this.round(
      responseScore === null
        ? // Without a measured response score the remaining components carry
          // the whole weight, scaled up so a shop is not silently docked ten
          // points for a conversation that never happened.
          (reviewScore + fulfillmentScore * 0.2) / 0.9
        : reviewScore + fulfillmentScore * 0.2 + responseScore * 0.1,
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
        // Only written when it was measured. Writing a null through as a zero
        // would put a fabricated number back on the row by another route.
        ...(responseScore === null ? {} : { responseScore }),
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

  /**
   * The delivered order behind a product review, or a refusal.
   *
   * `DELIVERED` and not merely paid: a woman who has not received the garment
   * has nothing to say about it yet, and a review written from the payment
   * screen is the easiest kind to manufacture.
   *
   * A hint that does not check out is treated as absent rather than as an
   * error — she may be reviewing from an old screen — and the search then
   * finds any delivered order of hers containing the product. What she cannot
   * do is name somebody else's order: every query here is scoped to `userId`.
   */
  private async requireDeliveredProductPurchase(
    userId: string,
    productId: string,
    hint: string | null,
  ): Promise<string> {
    if (hint && (await this.hasPurchasedProduct(userId, productId, hint))) {
      return hint;
    }

    const order = await this.prisma.order.findFirst({
      where: {
        userId,
        sellerOrders: {
          some: {
            status: SellerOrderStatus.DELIVERED,
            items: { some: { productId } },
          },
        },
      },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    });
    if (!order) {
      throw new ForbiddenException({
        code: 'REVIEW_REQUIRES_PURCHASE',
        message: 'يمكنكِ تقييم المنتجات التي استلمتِها فقط',
      });
    }
    return order.id;
  }

  /** The same rule for a boutique: she must have received something from it. */
  private async requireDeliveredSellerPurchase(
    userId: string,
    sellerId: string,
    hint: string | null,
  ): Promise<string> {
    if (hint && (await this.hasPurchasedFromSeller(userId, sellerId, hint))) {
      return hint;
    }

    const order = await this.prisma.order.findFirst({
      where: {
        userId,
        sellerOrders: {
          some: { sellerId, status: SellerOrderStatus.DELIVERED },
        },
      },
      orderBy: { createdAt: 'desc' },
      select: { id: true },
    });
    if (!order) {
      throw new ForbiddenException({
        code: 'REVIEW_REQUIRES_PURCHASE',
        message: 'يمكنكِ تقييم المتاجر التي اشتريتِ منها فقط',
      });
    }
    return order.id;
  }

  /**
   * One voice per customer, checked here for the message and enforced by the
   * database for the truth.
   *
   * This check alone was the whole defence, and it is a read followed by a
   * write: two requests arriving together both found nothing and both wrote.
   * The unique index added alongside this refuses the loser. This stays
   * because "you have already reviewed this" is a better answer than a
   * constraint violation.
   */
  private async assertReviewIsUnique(
    type: 'product' | 'seller',
    input: {
      productId?: string;
      sellerId?: string;
      userId: string;
    },
  ) {
    const where =
      type === 'product'
        ? { productId: input.productId, userId: input.userId }
        : { sellerId: input.sellerId, userId: input.userId };
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
      user: serializePublicUser(review.user),
      rating: review.rating,
      title: review.title,
      body: review.body,
      verified_purchase: review.verifiedPurchase,
      status: review.status.toLowerCase(),
      helpful_count: review.helpfulCount,
      seller_reply: review.sellerReply,
      seller_replied_at: review.sellerRepliedAt?.toISOString() ?? null,
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
      user: serializePublicUser(review.user),
      rating: review.rating,
      title: review.title,
      body: review.body,
      verified_purchase: review.verifiedPurchase,
      status: review.status.toLowerCase(),
      seller_reply: review.sellerReply,
      seller_replied_at: review.sellerRepliedAt?.toISOString() ?? null,
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
