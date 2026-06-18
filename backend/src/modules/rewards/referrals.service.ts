import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CashbackStatus,
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

const REWARD_MATRIX = {
  [ReferralParticipantType.CUSTOMER]: {
    referrerPoints: 500,
    referredPoints: 250,
    referrerCashback: 2.5,
  },
  [ReferralParticipantType.SELLER]: {
    referrerPoints: 1200,
    referredPoints: 500,
    referrerCashback: 10,
  },
} as const;

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
      return {
        already_applied: true,
        referral: serializeReferral(existing),
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

    return {
      accepted: status !== ReferralStatus.REJECTED,
      referral: serializeReferral(referral),
      code: serializeReferralCode(code),
      risk,
    };
  }

  async qualifyReferralForOrder(userId: string, orderId: string) {
    const referral = await this.prisma.referral.findFirst({
      where: {
        referredUserId: userId,
        status: ReferralStatus.PENDING,
        OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
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

    const existingRewards = await this.prisma.referralReward.count({
      where: { referralId: referral.id },
    });
    if (existingRewards > 0) {
      return this.prisma.referral.update({
        where: { id: referral.id },
        data: { status: ReferralStatus.REWARDED, rewardedAt: new Date() },
      });
    }

    const reward = REWARD_MATRIX[referral.participantType];
    const issuedAt = new Date();

    return this.prisma.$transaction(async (tx) => {
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
