import { Injectable, NotFoundException } from '@nestjs/common';
import { OrderStatus, ReferralParticipantType, UserRole } from '@prisma/client';

import { REWARD_MATRIX } from '../rewards/referrals.service';

import { PrismaService } from '../../prisma/prisma.service';
import { ORDER_BUCKETS } from '../orders/orders.service';

/**
 * The customer's profile centre, in one call.
 *
 * Like the home page, this screen was built against a mock and never
 * connected: the orders counts, the followed stores, the referral code and the
 * points balance were all invented client-side. Everything here is now read
 * from her own rows.
 *
 * Two fields the mock had are deliberately not returned. Achievements were a
 * list of badges with icons chosen in the UI and no backing anywhere, and
 * recently-viewed needs a per-customer view log the platform does not keep.
 * Both come back empty, which renders as nothing rather than as a fiction.
 */
@Injectable()
export class ProfileOverviewService {
  constructor(private readonly prisma: PrismaService) {}

  async forUser(userId: string) {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: {
        id: true,
        name: true,
        username: true,
        phone: true,
        email: true,
        bio: true,
        imageUrl: true,
        points: true,
        lifetimePoints: true,
        tier: true,
        phoneVerifiedAt: true,
        createdAt: true,
      },
    });
    if (!user) throw new NotFoundException('User not found');

    const [orders, followedStores, reviews, referral] = await Promise.all([
      this.orders(userId),
      this.followedStores(userId),
      this.reviews(userId),
      this.referral(userId),
    ]);

    return {
      profile: {
        id: user.id,
        name: user.name,
        username: user.username,
        phone: user.phone,
        image_url: user.imageUrl,
        bio: user.bio,
        member_since: user.createdAt,
      },
      completion_steps: this.completionSteps(user),
      orders,
      followed_stores: followedStores,
      reviews_count: reviews.count,
      average_rating: reviews.average,
      referral,
      loyalty: {
        points: user.points,
        lifetime_points: user.lifetimePoints,
        tier: user.tier,
      },
      achievements: [],
      recently_viewed: [],
    };
  }

  /**
   * The four piles her orders screen is split into.
   *
   * Counted from the parent order, which is what she thinks of as "an order" —
   * a basket across three sellers is one thing she bought, not three.
   */
  private async orders(userId: string) {
    const rows = await this.prisma.order.groupBy({
      by: ['status'],
      where: { userId },
      _count: { _all: true },
    });

    // The buckets come from `ORDER_BUCKETS`, which is also what
    // `GET /orders?bucket=` filters by — so the tile she taps and the list she
    // lands on are counting the same thing.
    const count = (statuses: readonly OrderStatus[]) =>
      rows
        .filter((row) => statuses.includes(row.status))
        .reduce((total, row) => total + row._count._all, 0);

    return {
      pending: count(ORDER_BUCKETS.pending),
      processing: count(ORDER_BUCKETS.processing),
      delivered: count(ORDER_BUCKETS.delivered),
      cancelled: count(ORDER_BUCKETS.cancelled),
    };
  }

  private async followedStores(userId: string) {
    const follows = await this.prisma.follow.findMany({
      where: { followerId: userId, following: { role: UserRole.SELLER } },
      orderBy: { createdAt: 'desc' },
      take: 12,
      select: {
        following: {
          select: {
            id: true,
            name: true,
            imageUrl: true,
            sellerVerifiedAt: true,
          },
        },
      },
    });

    return follows.map((follow) => ({
      id: follow.following.id,
      name: follow.following.name,
      logo_url: follow.following.imageUrl ?? '',
      is_verified: follow.following.sellerVerifiedAt !== null,
    }));
  }

  /** What she has written, not what has been written about her. */
  private async reviews(userId: string) {
    const [products, sellers] = await Promise.all([
      this.prisma.productReview.aggregate({
        where: { userId },
        _count: { _all: true },
        _avg: { rating: true },
      }),
      this.prisma.sellerReview.aggregate({
        where: { userId },
        _count: { _all: true },
        _avg: { rating: true },
      }),
    ]);

    const count = products._count._all + sellers._count._all;
    if (count === 0) return { count: 0, average: 0 };

    // A weighted mean, so twenty product reviews are not outvoted by one
    // review of a shop.
    const total =
      (products._avg.rating ?? 0) * products._count._all +
      (sellers._avg.rating ?? 0) * sellers._count._all;

    return { count, average: Number((total / count).toFixed(2)) };
  }

  /**
   * Her invite code and what it has earned her.
   *
   * The code lives on `ReferralCode` and the accepted invites on `Referral`,
   * so "invited" counts rows that actually became accounts — not links she
   * shared and nobody used.
   */
  private async referral(userId: string) {
    const code = await this.prisma.referralCode.findFirst({
      where: { userId, isActive: true },
      orderBy: { createdAt: 'desc' },
      select: { id: true, code: true },
    });
    if (!code) return null;

    const [invited, rewards] = await Promise.all([
      this.prisma.referral.count({ where: { codeId: code.id } }),
      this.prisma.referralReward.aggregate({
        where: { referral: { codeId: code.id } },
        _sum: { points: true },
      }),
    ]);

    return {
      code: code.code,
      invited,
      earned_points: rewards._sum.points ?? 0,
      // What the programme pays, from the table that pays it. The client has
      // rendered a `reward_hint` since the card was built and the server never
      // sent one, so the line under «ادعي صديقاتك» was blank on every account.
      reward_hint: `لكِ ${REWARD_MATRIX[ReferralParticipantType.CUSTOMER].referrerPoints} نقطة ولها ${REWARD_MATRIX[ReferralParticipantType.CUSTOMER].referredPoints} عند أول طلب لها`,
    };
  }

  /**
   * Q34 — the nudges towards a complete profile.
   *
   * Each step is a fact about her account rather than a checklist somebody
   * ticks, so it cannot drift out of step with what she has actually done.
   */
  private completionSteps(user: {
    name: string;
    phone: string | null;
    email: string | null;
    bio: string | null;
    imageUrl: string | null;
    phoneVerifiedAt: Date | null;
  }) {
    return [
      { key: 'name', label: 'اسمكِ', done: user.name.trim().length > 0 },
      {
        key: 'phone_verified',
        label: 'تأكيد رقم الهاتف',
        done: user.phoneVerifiedAt !== null,
      },
      {
        key: 'photo',
        label: 'صورة الحساب',
        done: (user.imageUrl ?? '').trim().length > 0,
      },
      {
        key: 'bio',
        label: 'نبذة عنكِ',
        done: (user.bio ?? '').trim().length > 0,
      },
      {
        key: 'email',
        label: 'بريد إلكتروني للاستعادة',
        done: (user.email ?? '').trim().length > 0,
      },
    ];
  }
}
