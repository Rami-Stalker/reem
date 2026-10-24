import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CashbackStatus,
  Coupon,
  CouponType,
  PointsTransactionType,
  Prisma,
  ReferralParticipantType,
  ReferralRewardType,
  ReferralStatus,
} from '@prisma/client';
import { randomBytes } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service';
import {
  ApplyReferralCodeDto,
  CreateReferralCodeDto,
} from './dto/rewards.dto';
import {
  serializeReferral,
  serializeReferralCode,
  serializeReferralReward,
} from './rewards.serializer';

const REFERRAL_TTL_DAYS = 45;
const HIGH_RISK_THRESHOLD = 0.8;

/**
 * What each side of an invite is paid. Exported because the profile centre
 * quotes it to the shopper — a promise the screen makes has to be the same
 * number the ledger later honours.
 *
 * **The discount is the part that was missing.** Points and cashback are what
 * this paid before, and neither is what «كود الدعوة» means to the woman
 * holding it: she expects money off, on the purchase she is about to make.
 * `referredPercent` is her welcome discount, applied at her first checkout;
 * `referrerPercent` is what her friend gets once that purchase completes. Both
 * are issued as ordinary single-use coupons bound to one account, so they run
 * through the same race-safe redemption rail every other code does rather than
 * through a second, weaker one written for referrals.
 */
export const REWARD_MATRIX = {
  [ReferralParticipantType.CUSTOMER]: {
    referrerPoints: 500,
    referredPoints: 250,
    referrerCashback: 2.5,
    referredPercent: 15,
    referrerPercent: 10,
  },
  [ReferralParticipantType.SELLER]: {
    referrerPoints: 1200,
    referredPoints: 500,
    referrerCashback: 10,
    referredPercent: 15,
    referrerPercent: 10,
  },
} as const;

/** How long a referral coupon stands before it lapses. */
const REFERRAL_COUPON_TTL_DAYS = 60;

/**
 * Nothing a referral coupon may take off is unbounded.
 *
 * A percentage with no ceiling on a marketplace where a single order can be a
 * gold set is a discount nobody approved. The cap is in the platform's own
 * currency because that is the only one these coupons are ever minted in.
 */
const REFERRAL_COUPON_MAX_OFF_SYP = 150_000;

@Injectable()
export class ReferralsService {
  constructor(private readonly prisma: PrismaService) {}

  async getOrCreateCode(userId: string, dto: CreateReferralCodeDto = {}) {
    const participantType =
      dto.participant_type ?? ReferralParticipantType.CUSTOMER;
    const now = new Date();

    if (!dto.campaign && !dto.max_uses && !dto.expires_at) {
      const existing = await this.prisma.referralCode.findFirst({
        where: {
          userId,
          participantType,
          isActive: true,
          OR: [{ expiresAt: null }, { expiresAt: { gt: now } }],
        },
        orderBy: { createdAt: 'desc' },
      });
      if (existing) return serializeReferralCode(existing);
    }

    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { username: true, name: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const code = await this.createUniqueCode(user.username || user.name);
    const referralCode = await this.prisma.referralCode.create({
      data: {
        userId,
        code,
        participantType,
        campaign: dto.campaign ?? null,
        maxUses: dto.max_uses ?? null,
        expiresAt: dto.expires_at ? new Date(dto.expires_at) : null,
      },
    });

    return serializeReferralCode(referralCode);
  }

  async overview(userId: string) {
    const [customerCode, sellerCode] = await Promise.all([
      this.getOrCreateCode(userId, {
        participant_type: ReferralParticipantType.CUSTOMER,
      }),
      this.getOrCreateCode(userId, {
        participant_type: ReferralParticipantType.SELLER,
      }),
    ]);

    const [
      referralsMade,
      referralsReceived,
      rewards,
      totalMade,
      qualified,
      rewarded,
      sellerReferrals,
      customerReferrals,
      suspicious,
    ] = await Promise.all([
      this.prisma.referral.findMany({
        where: { referrerId: userId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      this.prisma.referral.findMany({
        where: { referredUserId: userId },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
      this.prisma.referralReward.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 20,
      }),
      this.prisma.referral.count({ where: { referrerId: userId } }),
      this.prisma.referral.count({
        where: { referrerId: userId, status: ReferralStatus.QUALIFIED },
      }),
      this.prisma.referral.count({
        where: { referrerId: userId, status: ReferralStatus.REWARDED },
      }),
      this.prisma.referral.count({
        where: {
          referrerId: userId,
          participantType: ReferralParticipantType.SELLER,
        },
      }),
      this.prisma.referral.count({
        where: {
          referrerId: userId,
          participantType: ReferralParticipantType.CUSTOMER,
        },
      }),
      this.prisma.referral.count({
        where: { referrerId: userId, fraudScore: { gte: 0.5 } },
      }),
    ]);

    const rewardTotals = await this.prisma.referralReward.aggregate({
      where: { userId },
      _sum: { points: true, cashbackAmount: true },
    });

    return {
      customer_code: customerCode,
      seller_code: sellerCode,
      stats: {
        total: totalMade,
        qualified,
        rewarded,
        seller_referrals: sellerReferrals,
        customer_referrals: customerReferrals,
        suspicious,
        points_earned: rewardTotals._sum.points ?? 0,
        cashback_earned: rewardTotals._sum.cashbackAmount ?? 0,
      },
      referrals_made: referralsMade.map(serializeReferral),
      referrals_received: referralsReceived.map(serializeReferral),
      rewards: rewards.map(serializeReferralReward),
    };
  }

  async applyCode(userId: string, dto: ApplyReferralCodeDto) {
    const normalized = this.normalize(dto.code);
    const code = await this.prisma.referralCode.findUnique({
      where: { code: normalized },
    });
    if (!code || !code.isActive) {
      throw new BadRequestException('Referral code is not valid');
    }
    if (code.expiresAt && code.expiresAt < new Date()) {
      throw new BadRequestException('Referral code has expired');
    }
    if (code.maxUses != null && code.usedCount >= code.maxUses) {
      throw new BadRequestException('Referral code has reached its limit');
    }
    if (code.userId === userId) {
      throw new BadRequestException('You cannot use your own referral code');
    }

    const existing = await this.prisma.referral.findUnique({
      where: { referredUserId: userId },
    });
    if (existing) {
      // She applied a code before. Hand back the welcome coupon that went with
      // it rather than nothing: typing the code again at checkout is the same
      // woman asking for the same discount, and it is still hers to spend
      // until it is spent or lapses. `issueCoupon` is idempotent, so this
      // returns the existing row and never mints a second.
      const welcome =
        existing.status === ReferralStatus.REJECTED
          ? null
          : await this.issueCoupon({
              referralId: existing.id,
              userId,
              side: 'welcome',
              percent: REWARD_MATRIX[existing.participantType].referredPercent,
              title: 'خصم الترحيب من دعوة صديقة',
            });
      return {
        already_applied: true,
        accepted: existing.status !== ReferralStatus.REJECTED,
        referral: serializeReferral(existing),
        code: serializeReferralCode(code),
        welcome_coupon: this.serializeWelcome(welcome),
        risk: null,
      };
    }

    const participantType = dto.participant_type ?? code.participantType;
    const risk = await this.assessFraudRisk(code.userId, userId);
    const status =
      risk.score >= HIGH_RISK_THRESHOLD
        ? ReferralStatus.REJECTED
        : ReferralStatus.PENDING;
    const expiresAt = new Date(
      Date.now() + REFERRAL_TTL_DAYS * 24 * 60 * 60 * 1000,
    );

    const referral = await this.prisma.$transaction(async (tx) => {
      const created = await tx.referral.create({
        data: {
          codeId: code.id,
          referrerId: code.userId,
          referredUserId: userId,
          participantType,
          status,
          fraudScore: risk.score,
          fraudFlags: risk.flags,
          expiresAt,
        },
      });
      if (status !== ReferralStatus.REJECTED) {
        await tx.referralCode.update({
          where: { id: code.id },
          data: { usedCount: { increment: 1 } },
        });
      }
      return created;
    });

    // Her welcome discount, ready for the first checkout. This is what the
    // whole gesture means to her — «استخدمي الكود واحصلي على خصم» — and it did
    // not exist: applying a code recorded a relationship and paid points at
    // some later date, so the woman who typed it in got nothing she could see.
    const welcome =
      status === ReferralStatus.REJECTED
        ? null
        : await this.issueCoupon({
            referralId: referral.id,
            userId,
            side: 'welcome',
            percent: REWARD_MATRIX[participantType].referredPercent,
            title: 'خصم الترحيب من دعوة صديقة',
          });

    return {
      already_applied: false,
      accepted: status !== ReferralStatus.REJECTED,
      referral: serializeReferral(referral),
      code: serializeReferralCode(code),
      welcome_coupon: this.serializeWelcome(welcome),
      risk,
    };
  }

  /** The discount she can spend, as the client needs it. */
  private serializeWelcome(coupon: Coupon | null) {
    if (!coupon) return null;
    return {
      code: coupon.code,
      discount_percent: Number(coupon.discountPercent),
      expires_at: coupon.expiresAt.toISOString(),
    };
  }

  /**
   * Whether [code] names a live invite, and whose.
   *
   * Checkout asks this when the code a woman typed is not a coupon: «كود
   * الدعوة» and «الكوبون» are one field on her screen and she should not have
   * to know which kind she is holding.
   */
  async findLiveCode(rawCode: string) {
    const normalized = this.normalize(rawCode);
    if (!normalized) return null;
    const code = await this.prisma.referralCode.findUnique({
      where: { code: normalized },
    });
    if (!code || !code.isActive) return null;
    if (code.expiresAt && code.expiresAt < new Date()) return null;
    if (code.maxUses != null && code.usedCount >= code.maxUses) return null;
    return code;
  }

  /**
   * Issues one side's coupon, once.
   *
   * Idempotent by construction: the code is derived from the referral id and
   * which side it is for, so a retry — a double tap, a replayed request, a
   * qualification that runs twice — collides with the unique index on
   * `coupons.code` and is answered with the row that already exists. That is
   * the whole of «منع التكرار في الاستفادة», and it is enforced by the
   * database rather than by a check that could be raced.
   */
  private async issueCoupon(input: {
    referralId: string;
    userId: string;
    side: 'welcome' | 'thanks';
    percent: number;
    title: string;
  }) {
    const code = this.couponCodeFor(input.referralId, input.side);
    const existing = await this.prisma.coupon.findUnique({ where: { code } });
    if (existing) return existing;

    const expiresAt = new Date(
      Date.now() + REFERRAL_COUPON_TTL_DAYS * 24 * 60 * 60 * 1000,
    );

    try {
      const coupon = await this.prisma.coupon.create({
        data: {
          code,
          title: input.title,
          type: CouponType.PERCENTAGE,
          discountPercent: input.percent,
          // Never more than this off one order, however large the basket.
          maxDiscountAmount: REFERRAL_COUPON_MAX_OFF_SYP,
          // Bound to one account, spendable once. Both matter: `userId` is
          // what stops the code being passed on, and the two limits together
          // are what the redemption rail locks the row against.
          userId: input.userId,
          maxUses: 1,
          perUserLimit: 1,
          expiresAt,
          // Ohara funds an invite, not the boutique she happens to buy from.
          fundedBySeller: false,
        },
      });

      await this.prisma.referralReward.create({
        data: {
          referralId: input.referralId,
          userId: input.userId,
          type: ReferralRewardType.COUPON,
          couponId: coupon.id,
          status: 'issued',
          issuedAt: new Date(),
        },
      });
      return coupon;
    } catch (error) {
      // Somebody else won the race; their row is the answer.
      if (
        error instanceof Prisma.PrismaClientKnownRequestError &&
        error.code === 'P2002'
      ) {
        return this.prisma.coupon.findUnique({ where: { code } });
      }
      throw error;
    }
  }

  /**
   * `REEM-<referral>-W` / `-T`.
   *
   * Derived rather than random on purpose: the derivation *is* the idempotency
   * key. Uppercase and stripped of punctuation so it survives `normalize` and
   * reads the same way she will type it.
   */
  private couponCodeFor(referralId: string, side: 'welcome' | 'thanks') {
    const stem = referralId.replace(/-/g, '').slice(0, 12).toUpperCase();
    return `REEM${stem}${side === 'welcome' ? 'W' : 'T'}`;
  }

  /**
   * [placedAt] is when she placed the qualifying order. The reward is granted
   * once that order's sale is final — after its return window — and a
   * referral that was live when she bought must not lapse in the week the
   * platform spent making sure the sale would stand.
   */
  async qualifyReferralForOrder(
    userId: string,
    orderId: string,
    placedAt: Date = new Date(),
  ) {
    const referral = await this.prisma.referral.findFirst({
      where: {
        referredUserId: userId,
        status: ReferralStatus.PENDING,
        OR: [{ expiresAt: null }, { expiresAt: { gt: placedAt } }],
      },
    });
    if (!referral) return null;

    if (referral.fraudScore >= HIGH_RISK_THRESHOLD) {
      await this.prisma.referral.update({
        where: { id: referral.id },
        data: { status: ReferralStatus.REJECTED },
      });
      return null;
    }

    // Has *the referrer* already been paid for this invite?
    //
    // Scoped to her deliberately. The invitee holds a reward row of her own
    // from the moment she applied the code — her welcome coupon — so a check
    // that counted every row on this referral would see it, conclude the
    // invite had already paid out, and silently skip the referrer's half. The
    // question this guard exists to ask is about one side, so it names that
    // side.
    const alreadyPaid = await this.prisma.referralReward.count({
      where: { referralId: referral.id, userId: referral.referrerId },
    });
    if (alreadyPaid > 0) {
      return this.prisma.referral.update({
        where: { id: referral.id },
        data: { status: ReferralStatus.REWARDED, rewardedAt: new Date() },
      });
    }

    const reward = REWARD_MATRIX[referral.participantType];
    const issuedAt = new Date();

    const rewarded = await this.prisma.$transaction(async (tx) => {
      await tx.referral.update({
        where: { id: referral.id },
        data: {
          status: ReferralStatus.QUALIFIED,
          firstOrderId: orderId,
          qualifiedAt: issuedAt,
        },
      });

      await this.awardPoints(
        tx,
        referral.referrerId,
        reward.referrerPoints,
        'Referral reward',
        orderId,
      );
      await this.awardPoints(
        tx,
        referral.referredUserId,
        reward.referredPoints,
        'Referral welcome reward',
        orderId,
      );

      await tx.referralReward.createMany({
        data: [
          {
            referralId: referral.id,
            userId: referral.referrerId,
            type: ReferralRewardType.POINTS,
            points: reward.referrerPoints,
            status: 'issued',
            issuedAt,
          },
          {
            referralId: referral.id,
            userId: referral.referredUserId,
            type: ReferralRewardType.POINTS,
            points: reward.referredPoints,
            status: 'issued',
            issuedAt,
          },
          {
            referralId: referral.id,
            userId: referral.referrerId,
            type: ReferralRewardType.CASHBACK,
            cashbackAmount: reward.referrerCashback,
            status: 'issued',
            issuedAt,
          },
        ],
      });

      await tx.cashbackLedger.create({
        data: {
          userId: referral.referrerId,
          orderId,
          amount: reward.referrerCashback,
          status: CashbackStatus.EARNED,
          expiresAt: new Date(Date.now() + 90 * 24 * 60 * 60 * 1000),
        },
      });

      return tx.referral.update({
        where: { id: referral.id },
        data: { status: ReferralStatus.REWARDED, rewardedAt: issuedAt },
      });
    });

    // The other side of the promise: her friend's own discount, now that the
    // invite has actually produced a purchase. Issued after the transaction
    // rather than inside it — a coupon that failed to mint must not undo a
    // completed order, and `issueCoupon` is idempotent, so the next
    // qualification attempt or the profile screen's read mints it instead.
    await this.issueCoupon({
      referralId: referral.id,
      userId: referral.referrerId,
      side: 'thanks',
      percent: reward.referrerPercent,
      title: 'خصم دعوة صديقة',
    });

    return rewarded;
  }

  async analytics() {
    const [byStatus, byType, rewards, suspicious, topReferrers] =
      await Promise.all([
        this.prisma.referral.groupBy({
          by: ['status'],
          _count: { _all: true },
        }),
        this.prisma.referral.groupBy({
          by: ['participantType'],
          _count: { _all: true },
        }),
        this.prisma.referralReward.aggregate({
          _sum: { points: true, cashbackAmount: true },
          _count: { _all: true },
        }),
        this.prisma.referral.count({ where: { fraudScore: { gte: 0.5 } } }),
        this.prisma.referral.groupBy({
          by: ['referrerId'],
          _count: { referrerId: true },
          orderBy: { _count: { referrerId: 'desc' } },
          take: 10,
        }),
      ]);

    const referrerIds = topReferrers.map((r) => r.referrerId);
    const users = await this.prisma.user.findMany({
      where: { id: { in: referrerIds } },
      select: { id: true, name: true, username: true },
    });
    const userById = new Map(users.map((u) => [u.id, u]));

    return {
      status_breakdown: Object.fromEntries(
        byStatus.map((row) => [row.status.toLowerCase(), row._count._all]),
      ),
      participant_breakdown: Object.fromEntries(
        byType.map((row) => [
          row.participantType.toLowerCase(),
          row._count._all,
        ]),
      ),
      rewards: {
        count: rewards._count._all,
        points: rewards._sum.points ?? 0,
        cashback: rewards._sum.cashbackAmount ?? 0,
      },
      suspicious_referrals: suspicious,
      top_referrers: topReferrers.map((row) => ({
        user: userById.get(row.referrerId) ?? { id: row.referrerId },
        referrals: row._count.referrerId,
      })),
    };
  }

  private async assessFraudRisk(referrerId: string, referredUserId: string) {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);
    const [referrer, referred, recentReferrals, previousOrders] =
      await Promise.all([
        this.prisma.user.findUnique({
          where: { id: referrerId },
          select: {
            email: true,
            phone: true,
            devices: {
              select: { fingerprintHash: true, ipAddress: true },
              where: { revokedAt: null },
            },
          },
        }),
        this.prisma.user.findUnique({
          where: { id: referredUserId },
          select: {
            email: true,
            phone: true,
            devices: {
              select: { fingerprintHash: true, ipAddress: true },
              where: { revokedAt: null },
            },
          },
        }),
        this.prisma.referral.count({
          where: { referrerId, createdAt: { gte: since } },
        }),
        this.prisma.order.count({ where: { userId: referredUserId } }),
      ]);

    const reasons: string[] = [];
    let score = 0;

    if (!referrer || !referred) {
      reasons.push('missing_identity');
      score += 0.2;
    }
    if (previousOrders > 0) {
      reasons.push('existing_customer');
      score += 0.45;
    }
    if (recentReferrals >= 25) {
      reasons.push('referral_velocity_24h');
      score += 0.35;
    }
    if (referrer?.phone && referred?.phone && referrer.phone === referred.phone) {
      reasons.push('shared_phone');
      score += 0.7;
    }
    if (referrer?.email && referred?.email) {
      const refDomain = referrer.email.split('@')[1];
      const newDomain = referred.email.split('@')[1];
      if (refDomain && refDomain === newDomain && !this.isCommonEmailDomain(refDomain)) {
        reasons.push('shared_private_email_domain');
        score += 0.1;
      }
    }

    const refDevices = new Set(
      referrer?.devices.map((d) => d.fingerprintHash).filter(Boolean) ?? [],
    );
    const refIps = new Set(
      referrer?.devices.map((d) => d.ipAddress).filter(Boolean) ?? [],
    );
    const sharedDevice = referred?.devices.some((d) =>
      refDevices.has(d.fingerprintHash),
    );
    const sharedIp = referred?.devices.some((d) =>
      d.ipAddress ? refIps.has(d.ipAddress) : false,
    );
    if (sharedDevice) {
      reasons.push('shared_device');
      score += 0.65;
    }
    if (sharedIp) {
      reasons.push('shared_ip');
      score += 0.2;
    }

    const capped = Math.min(1, Math.round(score * 100) / 100);
    return {
      score: capped,
      flags: { reasons, recent_referrals_24h: recentReferrals, previous_orders: previousOrders },
    };
  }

  private async awardPoints(
    tx: Prisma.TransactionClient,
    userId: string,
    points: number,
    reason: string,
    orderId: string,
  ) {
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
        orderId,
        balanceAfter: user.points,
      },
    });
  }

  private normalize(code: string) {
    return code.trim().replace(/[^a-z0-9]/gi, '').toUpperCase();
  }

  private async createUniqueCode(seed: string) {
    const prefix =
      seed
        .normalize('NFKD')
        .replace(/[^a-z0-9]/gi, '')
        .slice(0, 6)
        .toUpperCase() || 'REEM';
    for (let attempt = 0; attempt < 8; attempt += 1) {
      const code = `${prefix}${randomBytes(3).toString('hex').toUpperCase()}`;
      const existing = await this.prisma.referralCode.findUnique({
        where: { code },
        select: { id: true },
      });
      if (!existing) return code;
    }
    return `REEM${randomBytes(5).toString('hex').toUpperCase()}`;
  }

  private isCommonEmailDomain(domain: string) {
    return [
      'gmail.com',
      'icloud.com',
      'outlook.com',
      'hotmail.com',
      'yahoo.com',
      'proton.me',
    ].includes(domain.toLowerCase());
  }
}
