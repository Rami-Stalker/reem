import { Injectable } from '@nestjs/common';
import {
  DisputeStatus,
  OfferStatus,
  ProductStatus,
  ReturnStatus,
  ReviewStatus,
  SellerOrderStatus,
  TrustSignalStatus,
  TrustSubject,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { searchKey } from '../search/arabic';
import {
  IdentityFacts,
  RefundFacts,
  ReviewFacts,
  SellerConductFacts,
} from './kernel/trust-facts';

/**
 * How far back "recently" reaches when counting a reviewer's habits.
 *
 * Long enough that a campaign run over a fortnight is still one campaign,
 * short enough that a customer's behaviour two years ago is not held against
 * her.
 */
export const REVIEW_WINDOW_DAYS = 30;

/** The refund window. A season, so seasonal returns land inside one reading. */
export const REFUND_WINDOW_DAYS = 120;

const dayMs = 24 * 60 * 60 * 1000;

/**
 * Gathers what the kernel is allowed to know.
 *
 * Everything expensive lives here rather than in the scorer, and the scorer
 * gets counts. That division is the reason the rules can be tested in
 * milliseconds and read by somebody who does not know Prisma — and the reason
 * a "risk score" cannot quietly turn into a place where names and phone
 * numbers accumulate.
 */
@Injectable()
export class TrustFactsService {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * The facts behind one review.
   *
   * Reads eight things about a review that a moderator would otherwise have to
   * assemble by hand from six screens.
   */
  async forReview(reviewId: string): Promise<ReviewFacts | null> {
    const review = await this.prisma.productReview.findUnique({
      where: { id: reviewId },
      select: {
        id: true,
        rating: true,
        body: true,
        verifiedPurchase: true,
        createdAt: true,
        productId: true,
        userId: true,
        user: { select: { createdAt: true, phoneVerifiedAt: true } },
      },
    });
    if (!review) return null;

    const since = new Date(review.createdAt.getTime() - REVIEW_WINDOW_DAYS * dayMs);
    const dayStart = new Date(review.createdAt.getTime() - dayMs / 2);
    const dayEnd = new Date(review.createdAt.getTime() + dayMs / 2);

    const [
      hers,
      productTotal,
      productSameDay,
      productAgg,
      ordersPlaced,
      sellerIds,
    ] = await Promise.all([
      // Her own recent reviews, with the product each landed on so the
      // single-boutique count can be worked out without a second pass.
      this.prisma.productReview.findMany({
        where: { userId: review.userId, createdAt: { gte: since } },
        select: { id: true, rating: true, productId: true, body: true },
      }),
      this.prisma.productReview.count({
        where: { productId: review.productId, status: ReviewStatus.APPROVED },
      }),
      this.prisma.productReview.count({
        where: {
          productId: review.productId,
          createdAt: { gte: dayStart, lt: dayEnd },
        },
      }),
      // The product's mean *without* this review, so an outlying mark is not
      // measured against an average it is itself dragging.
      this.prisma.productReview.aggregate({
        where: {
          productId: review.productId,
          status: ReviewStatus.APPROVED,
          id: { not: review.id },
        },
        _avg: { rating: true },
        _count: { _all: true },
      }),
      this.prisma.order.count({ where: { userId: review.userId } }),
      this.sellersOf(review.productId),
    ]);

    const hersOnSameSellers = await this.countReviewsForSellers(
      hers.map((r) => r.productId),
      sellerIds,
    );

    const accountAgeDays = review.user?.createdAt
      ? Math.max(
          0,
          Math.floor(
            (review.createdAt.getTime() - review.user.createdAt.getTime()) / dayMs,
          ),
        )
      : null;

    return {
      rating: review.rating,
      verifiedPurchase: review.verifiedPurchase,
      accountAgeDays,
      phoneVerified: Boolean(review.user?.phoneVerifiedAt),
      reviewsInWindow: hers.length,
      fiveStarInWindow: hers.filter((r) => r.rating === 5).length,
      reviewsForSameSeller: hersOnSameSellers,
      ordersPlaced,
      productReviewsSameDay: productSameDay,
      productReviewsTotal: productTotal,
      productMeanWithout: productAgg._count._all > 0 ? productAgg._avg.rating : null,
      duplicateBodies: await this.countDuplicateBodies(review.id, review.body),
      bodyEmpty: !review.body || review.body.trim().length === 0,
    };
  }

  /** What a customer's returns look like, and what the platform's look like. */
  async forRefunds(userId: string): Promise<RefundFacts> {
    const since = new Date(Date.now() - REFUND_WINDOW_DAYS * dayMs);
    const window = { createdAt: { gte: since } };

    const [
      delivered,
      returnsRequested,
      refundsReceived,
      refused,
      disputesOpened,
      disputesLost,
      platformDelivered,
      platformRefunded,
    ] = await Promise.all([
      this.prisma.sellerOrder.count({
        where: {
          ...window,
          order: { userId },
          status: {
            in: [SellerOrderStatus.DELIVERED, SellerOrderStatus.EXCHANGED],
          },
        },
      }),
      this.prisma.returnRequest.count({
        where: { ...window, sellerOrder: { order: { userId } } },
      }),
      this.prisma.returnRequest.count({
        where: {
          ...window,
          sellerOrder: { order: { userId } },
          status: ReturnStatus.REFUNDED,
        },
      }),
      this.prisma.sellerOrder.count({
        where: {
          ...window,
          order: { userId },
          status: SellerOrderStatus.REJECTED_ON_DELIVERY,
        },
      }),
      this.prisma.dispute.count({
        where: { ...window, openedById: userId },
      }),
      this.prisma.dispute.count({
        where: {
          ...window,
          openedById: userId,
          status: DisputeStatus.RESOLVED_FOR_SELLER,
        },
      }),
      // The platform's own rate over the same window, so she is judged
      // against this catalogue rather than a number somebody typed.
      this.prisma.sellerOrder.count({
        where: {
          ...window,
          status: {
            in: [SellerOrderStatus.DELIVERED, SellerOrderStatus.EXCHANGED],
          },
        },
      }),
      this.prisma.returnRequest.count({
        where: { ...window, status: ReturnStatus.REFUNDED },
      }),
    ]);

    return {
      deliveredParcels: delivered,
      returnsRequested,
      refundsReceived,
      refusedParcels: refused,
      disputesOpened,
      disputesLost,
      platformRefundRate:
        platformDelivered > 0 ? platformRefunded / platformDelivered : 0,
    };
  }

  /** What ties one account to others. */
  async forIdentity(userId: string): Promise<IdentityFacts> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { createdAt: true, phoneVerifiedAt: true },
    });

    const [addresses, deviceKeys] = await Promise.all([
      this.prisma.address.findMany({
        where: { userId },
        select: { recipientPhone: true, addressLine: true },
      }),
      this.prisma.deviceKey.findMany({
        where: { userId },
        select: { publicKey: true },
      }),
    ]);

    const phones = [...new Set(addresses.map((a) => a.recipientPhone))];
    const lines = [...new Set(addresses.map((a) => a.addressLine))];

    const [sharingPhone, sharingAddress, sharingDevice] = await Promise.all([
      phones.length
        ? this.distinctOtherUsers({ recipientPhone: { in: phones } }, userId)
        : Promise.resolve([]),
      lines.length
        ? this.distinctOtherUsers({ addressLine: { in: lines } }, userId)
        : Promise.resolve([]),
      // A device key is unique per key, so "the same device" means the same
      // handset re-enrolled under another account. Matching on the key itself
      // rather than a fingerprint keeps this exact: no false links.
      deviceKeys.length
        ? this.prisma.deviceKey
            .findMany({
              where: {
                publicKey: { in: deviceKeys.map((k) => k.publicKey) },
                userId: { not: userId },
              },
              select: { userId: true },
              distinct: ['userId'],
            })
            .then((rows) => rows.map((r) => r.userId).filter((id): id is string => !!id))
        : Promise.resolve([]),
    ]);

    const linked = [
      ...new Set([...sharingPhone, ...sharingAddress, ...sharingDevice]),
    ];

    const linkedCouponRedemptions = linked.length
      ? await this.prisma.couponRedemption.count({
          where: { userId: { in: linked } },
        })
      : 0;

    return {
      accountAgeDays: user?.createdAt
        ? Math.max(
            0,
            Math.floor((Date.now() - user.createdAt.getTime()) / dayMs),
          )
        : null,
      phoneVerified: Boolean(user?.phoneVerifiedAt),
      accountsSharingPhone: sharingPhone.length,
      accountsSharingDevice: sharingDevice.length,
      accountsSharingAddress: sharingAddress.length,
      linkedCouponRedemptions,
    };
  }

  /**
   * What a boutique's conduct looks like, beside her own category's norm.
   *
   * The category rate is computed over the categories she actually sells in,
   * not the whole catalogue: comparing an occasionwear boutique against a
   * platform average dominated by perfume would flag her for selling
   * something that is simply harder to fit.
   */
  async forSellerConduct(sellerId: string): Promise<SellerConductFacts> {
    const since = new Date(Date.now() - REFUND_WINDOW_DAYS * dayMs);
    const window = { createdAt: { gte: since } };

    const categories = await this.prisma.sellerOffer.findMany({
      where: { sellerId },
      select: { product: { select: { categoryId: true } } },
      distinct: ['productId'],
      take: 500,
    });
    const categoryIds = [
      ...new Set(categories.map((row) => row.product.categoryId)),
    ];

    const [
      seller,
      delivered,
      refunded,
      cancelled,
      disputesAgainst,
      disputesLost,
      confirmedFakeReviews,
      liveListings,
      removedListings,
      categoryDelivered,
      categoryRefunded,
    ] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: sellerId },
        select: { createdAt: true },
      }),
      this.prisma.sellerOrder.count({
        where: {
          ...window,
          sellerId,
          status: {
            in: [SellerOrderStatus.DELIVERED, SellerOrderStatus.EXCHANGED],
          },
        },
      }),
      this.prisma.returnRequest.count({
        where: {
          ...window,
          status: ReturnStatus.REFUNDED,
          sellerOrder: { sellerId },
        },
      }),
      this.prisma.sellerOrder.count({
        where: {
          ...window,
          sellerId,
          status: SellerOrderStatus.CANCELLED_BY_SELLER,
        },
      }),
      this.prisma.dispute.count({
        where: { ...window, sellerOrder: { sellerId } },
      }),
      this.prisma.dispute.count({
        where: {
          ...window,
          sellerOrder: { sellerId },
          status: DisputeStatus.RESOLVED_FOR_CUSTOMER,
        },
      }),
      // Confirmed by a person, not merely flagged: a competitor can flag
      // anybody, and a suspicion is not evidence of her involvement.
      this.prisma.trustSignal.count({
        where: {
          subject: TrustSubject.REVIEW,
          status: TrustSignalStatus.CONFIRMED,
          subjectId: {
            in: (
              await this.prisma.productReview.findMany({
                where: {
                  createdAt: { gte: since },
                  product: { offers: { some: { sellerId } } },
                },
                select: { id: true },
                take: 2000,
              })
            ).map((review) => review.id),
          },
        },
      }),
      this.prisma.sellerOffer.count({
        where: { sellerId, status: OfferStatus.ACTIVE, isActive: true },
      }),
      this.prisma.product.count({
        where: {
          status: ProductStatus.ARCHIVED,
          offers: { some: { sellerId } },
        },
      }),
      categoryIds.length
        ? this.prisma.sellerOrder.count({
            where: {
              ...window,
              status: {
                in: [SellerOrderStatus.DELIVERED, SellerOrderStatus.EXCHANGED],
              },
              items: {
                some: { product: { categoryId: { in: categoryIds } } },
              },
            },
          })
        : Promise.resolve(0),
      categoryIds.length
        ? this.prisma.returnRequest.count({
            where: {
              ...window,
              status: ReturnStatus.REFUNDED,
              sellerOrder: {
                items: {
                  some: { product: { categoryId: { in: categoryIds } } },
                },
              },
            },
          })
        : Promise.resolve(0),
    ]);

    return {
      accountAgeDays: seller?.createdAt
        ? Math.max(
            0,
            Math.floor((Date.now() - seller.createdAt.getTime()) / dayMs),
          )
        : null,
      deliveredParcels: delivered,
      refundedParcels: refunded,
      categoryRefundRate:
        categoryDelivered > 0 ? categoryRefunded / categoryDelivered : 0,
      cancelledBySeller: cancelled,
      disputesAgainst,
      disputesLost,
      confirmedFakeReviews,
      liveListings,
      removedListings,
    };
  }

  // ── internals ────────────────────────────────────────────────────────────

  /** Other accounts whose address book matches on some field. */
  private async distinctOtherUsers(
    where: Record<string, unknown>,
    userId: string,
  ): Promise<string[]> {
    const rows = await this.prisma.address.findMany({
      where: { ...where, userId: { not: userId } },
      select: { userId: true },
      distinct: ['userId'],
    });
    return rows.map((row) => row.userId);
  }

  /** Which boutiques list the reviewed product. */
  private async sellersOf(productId: string): Promise<string[]> {
    const offers = await this.prisma.sellerOffer.findMany({
      where: { productId },
      select: { sellerId: true },
      distinct: ['sellerId'],
    });
    return offers.map((offer) => offer.sellerId);
  }

  /**
   * How many of her recent reviews landed on products these boutiques sell.
   *
   * Counted over the products she reviewed rather than per review, so a woman
   * with thirty reviews costs one query rather than thirty.
   */
  private async countReviewsForSellers(
    productIds: string[],
    sellerIds: string[],
  ): Promise<number> {
    if (productIds.length === 0 || sellerIds.length === 0) return 0;
    const offers = await this.prisma.sellerOffer.findMany({
      where: {
        productId: { in: [...new Set(productIds)] },
        sellerId: { in: sellerIds },
      },
      select: { productId: true },
      distinct: ['productId'],
    });
    const overlapping = new Set(offers.map((offer) => offer.productId));
    return productIds.filter((id) => overlapping.has(id)).length;
  }

  /**
   * Other reviews carrying the same words.
   *
   * Compared on the folded search key, which is what makes this worth doing at
   * all: a campaign that pastes the same sentence with different spacing, or
   * with the harakat a phone keyboard added, produces different raw strings
   * and one identical key. Very short bodies are skipped — «حلو» is not
   * plagiarism, it is Arabic.
   */
  private async countDuplicateBodies(
    reviewId: string,
    body: string | null,
  ): Promise<number> {
    const key = searchKey(body);
    if (key.length < 20) return 0;

    const rows = await this.prisma.$queryRaw<{ n: bigint }[]>`
      SELECT count(*) AS n
      FROM product_reviews r
      WHERE r.id <> ${reviewId}::uuid
        AND r.body IS NOT NULL
        AND reem_search_key(r.body) = ${key}
    `;
    return Number(rows[0]?.n ?? 0);
  }
}
