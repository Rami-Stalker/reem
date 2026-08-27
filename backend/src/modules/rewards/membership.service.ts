import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CashbackStatus,
  Currency,
  CouponType,
  LoyaltyReward,
  LoyaltyRewardType,
  MembershipTier,
  MembershipTierStatus,
  PointsTransactionType,
  Prisma,
} from '@prisma/client';
import { randomUUID } from 'node:crypto';
import { PrismaService } from '../../prisma/prisma.service';
import {
  POINTS_PER_REDEMPTION,
  SYP_PER_REDEMPTION,
} from '../finance/loyalty.service';
import { Money } from '../../common/money';
import {
  CreateMembershipTierDto,
  RedeemCashbackDto,
  UpsertLoyaltyRewardDto,
} from './dto/rewards.dto';
import {
  serializeCashbackEntry,
  serializeCoupon,
  serializeLoyaltyReward,
  serializeMembershipTier,
} from './rewards.serializer';

/** Cashback and wallet credit are settled in SYP. */
const CASHBACK_CURRENCY = Currency.SYP;

const CASHBACK_TTL_DAYS = 180;

const round = (n: number) => Math.round(n * 100) / 100;

const DEFAULT_TIERS = [
  {
    key: 'bronze',
    name: 'Bronze',
    minLifetimePoints: 0,
    pointsMultiplier: 1,
    cashbackBps: 0,
    freeShipping: false,
    priority: 0,
    benefits: {
      highlights: ['Earn points on every order', 'Referral rewards'],
    },
  },
  {
    key: 'silver',
    name: 'Silver',
    minLifetimePoints: 1000,
    pointsMultiplier: 1.1,
    cashbackBps: 100,
    freeShipping: false,
    priority: 10,
    benefits: {
      highlights: ['10% bonus points', '1% cashback'],
    },
  },
  {
    key: 'gold',
    name: 'Gold',
    minLifetimePoints: 5000,
    pointsMultiplier: 1.25,
    cashbackBps: 200,
    freeShipping: false,
    priority: 20,
    benefits: {
      highlights: ['25% bonus points', '2% cashback', 'Early access offers'],
    },
  },
  {
    key: 'platinum',
    name: 'Platinum',
    minLifetimePoints: 15000,
    pointsMultiplier: 1.5,
    cashbackBps: 350,
    freeShipping: true,
    priority: 30,
    benefits: {
      highlights: ['50% bonus points', '3.5% cashback', 'Shipping perks'],
    },
  },
  {
    key: 'vip',
    name: 'VIP',
    minLifetimePoints: 50000,
    pointsMultiplier: 2,
    cashbackBps: 500,
    freeShipping: true,
    priority: 40,
    benefits: {
      highlights: ['Double points', '5% cashback', 'VIP-only offers'],
    },
  },
] as const;

@Injectable()
export class MembershipService {
  constructor(private readonly prisma: PrismaService) {}

  async summary(userId: string) {
    await this.ensureDefaults();
    const account = await this.refreshMembership(userId);
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { points: true, lifetimePoints: true, tier: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const tiers = await this.prisma.membershipTier.findMany({
      where: { status: MembershipTierStatus.ACTIVE },
      orderBy: { minLifetimePoints: 'asc' },
    });
    const nextTier = tiers.find(
      (tier) => tier.minLifetimePoints > user.lifetimePoints,
    );
    const cashback = await this.cashbackBalance(userId);
    const rewards = await this.availableRewards(userId);
    const currentMin = account.tier?.minLifetimePoints ?? 0;
    const nextMin = nextTier?.minLifetimePoints ?? currentMin;
    const span = Math.max(1, nextMin - currentMin);

    return {
      points: user.points,
      lifetime_points: user.lifetimePoints,
      tier: account.tierSnapshot,
      // Q43, from the service that owns the rate.
      redeem_step: POINTS_PER_REDEMPTION,
      redeem_value_syp: SYP_PER_REDEMPTION,
      membership: {
        tier: account.tier ? serializeMembershipTier(account.tier) : null,
        next_tier: nextTier ? serializeMembershipTier(nextTier) : null,
        vip: account.vip,
        points_multiplier: account.pointsMultiplier,
        cashback_bps: account.cashbackBps,
        cashback_rate: account.cashbackBps / 100,
        progress: {
          current: user.lifetimePoints,
          current_tier_min: currentMin,
          next_tier_min: nextTier?.minLifetimePoints ?? null,
          percentage: nextTier
            ? Math.min(1, Math.max(0, (user.lifetimePoints - currentMin) / span))
            : 1,
        },
      },
      cashback,
      rewards,
    };
  }

  async availableRewards(userId: string) {
    await this.ensureDefaults();
    const account = await this.refreshMembership(userId);
    const now = new Date();
    const rewards = await this.prisma.loyaltyReward.findMany({
      where: {
        isActive: true,
        startsAt: { lte: now },
        OR: [{ endsAt: null }, { endsAt: { gt: now } }],
      },
      include: { tier: true },
      orderBy: [{ exclusive: 'desc' }, { createdAt: 'desc' }],
    });
    const priority = account.tier?.priority ?? 0;
    return rewards
      .filter((reward) => !reward.tier || reward.tier.priority <= priority)
      .map(serializeLoyaltyReward);
  }

  async refreshMembership(userId: string) {
    await this.ensureDefaults();
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { id: true, lifetimePoints: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const tiers = await this.prisma.membershipTier.findMany({
      where: { status: MembershipTierStatus.ACTIVE },
      orderBy: { minLifetimePoints: 'desc' },
    });
    const tier = tiers.find((t) => user.lifetimePoints >= t.minLifetimePoints);
    if (!tier) throw new BadRequestException('Membership tiers are not configured');

    const existing = await this.prisma.membershipAccount.findUnique({
      where: { userId },
      select: { vip: true },
    });
    const vip = Boolean(existing?.vip || tier.key === 'vip');

    await this.prisma.user.update({
      where: { id: userId },
      data: { tier: tier.name },
    });

    return this.prisma.membershipAccount.upsert({
      where: { userId },
      create: {
        userId,
        tierId: tier.id,
        tierSnapshot: tier.name,
        vip,
        pointsMultiplier: tier.pointsMultiplier,
        cashbackBps: tier.cashbackBps,
      },
      update: {
        tierId: tier.id,
        tierSnapshot: tier.name,
        vip,
        pointsMultiplier: tier.pointsMultiplier,
        cashbackBps: tier.cashbackBps,
        tierUpdatedAt: new Date(),
      },
      include: { tier: true },
    });
  }

  async recordPurchase(userId: string, orderId: string, total: Money) {
    const account = await this.refreshMembership(userId);
    const bonusPoints = Math.floor(
      total.toUnsafeNumber() * Math.max(0, account.pointsMultiplier - 1),
    );
    const cashback = total.percentBps(account.cashbackBps);
    const expiresAt = new Date(
      Date.now() + CASHBACK_TTL_DAYS * 24 * 60 * 60 * 1000,
    );

    await this.prisma.$transaction(async (tx) => {
      await tx.membershipAccount.update({
        where: { userId },
        data: {
          spendCurrency: total.currency,
          currentPeriodSpend: { increment: total.toPrisma() },
        },
      });

      if (bonusPoints > 0) {
        const alreadyAwarded = await tx.pointsTransaction.count({
          where: { userId, orderId, reason: 'Tier bonus points' },
        });
        if (alreadyAwarded === 0) {
          await this.awardPoints(
            tx,
            userId,
            bonusPoints,
            'Tier bonus points',
            orderId,
          );
        }
      }

      if (!cashback.isZero()) {
        const existingCashback = await tx.cashbackLedger.findFirst({
          where: { userId, orderId, status: { not: CashbackStatus.REVERSED } },
        });
        if (!existingCashback) {
          await tx.cashbackLedger.create({
            data: {
              userId,
              orderId,
              currency: cashback.currency,
              amount: cashback.toPrisma(),
              status: CashbackStatus.EARNED,
              expiresAt,
            },
          });
        }
      }
    });
  }

  async redeemReward(userId: string, rewardId: string) {
    await this.ensureDefaults();
    const account = await this.refreshMembership(userId);
    const reward = await this.prisma.loyaltyReward.findUnique({
      where: { id: rewardId },
      include: { tier: true, coupon: true },
    });
    if (!reward || !this.rewardIsActive(reward)) {
      throw new NotFoundException('Reward is not available');
    }
    if (reward.tier && (account.tier?.priority ?? 0) < reward.tier.priority) {
      throw new BadRequestException('Your membership tier cannot redeem this reward');
    }

    const user = await this.prisma.user.findUnique({ where: { id: userId } });
    if (!user) throw new NotFoundException('User not found');
    if (reward.pointsCost && user.points < reward.pointsCost) {
      throw new BadRequestException('Insufficient points balance');
    }

    const result = await this.prisma.$transaction(async (tx) => {
      if (reward.pointsCost && reward.pointsCost > 0) {
        const updated = await tx.user.update({
          where: { id: userId },
          data: { points: { decrement: reward.pointsCost } },
        });
        await tx.pointsTransaction.create({
          data: {
            userId,
            type: PointsTransactionType.REDEEM,
            points: -reward.pointsCost,
            reason: `Redeemed ${reward.title}`,
            balanceAfter: updated.points,
          },
        });
      }

      if (reward.exclusive) {
        await tx.exclusiveOfferClaim.upsert({
          where: { userId_rewardId: { userId, rewardId } },
          create: { userId, rewardId },
          update: {},
        });
      }

      if (reward.type === LoyaltyRewardType.POINTS) {
        const points = this.metadataNumber(reward.metadata, 'points', 0);
        if (points > 0) {
          await this.awardPoints(tx, userId, points, reward.title);
        }
        return { reward: serializeLoyaltyReward(reward), points_awarded: points };
      }

      if (reward.type === LoyaltyRewardType.CASHBACK) {
        const amount = Money.of(
          reward.cashbackAmount ??
            this.metadataNumber(reward.metadata, 'amount', 0),
          reward.currency,
        );
        if (amount.isZero() || amount.isNegative()) {
          throw new BadRequestException('Cashback reward is misconfigured');
        }
        const entry = await tx.cashbackLedger.create({
          data: {
            userId,
            currency: amount.currency,
            amount: amount.toPrisma(),
            status: CashbackStatus.EARNED,
            expiresAt: new Date(Date.now() + CASHBACK_TTL_DAYS * 24 * 60 * 60 * 1000),
          },
        });
        return {
          reward: serializeLoyaltyReward(reward),
          cashback: serializeCashbackEntry(entry),
        };
      }

      const coupon = await this.issueRewardCoupon(tx, userId, reward);
      return {
        reward: serializeLoyaltyReward(reward),
        coupon: serializeCoupon(coupon),
      };
    });

    return result;
  }

  async cashbackBalance(userId: string) {
    const [available, pending, lifetime, entries] = await Promise.all([
      this.prisma.cashbackLedger.aggregate({
        where: { userId, status: CashbackStatus.EARNED },
        _sum: { amount: true },
      }),
      this.prisma.cashbackLedger.aggregate({
        where: { userId, status: CashbackStatus.PENDING },
        _sum: { amount: true },
      }),
      this.prisma.cashbackLedger.aggregate({
        where: {
          userId,
          status: { in: [CashbackStatus.EARNED, CashbackStatus.REDEEMED] },
        },
        _sum: { amount: true },
      }),
      this.prisma.cashbackLedger.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 10,
      }),
    ]);

    // Cashback is always held in the platform's settlement currency.
    return {
      available: Money.of(available._sum.amount ?? 0, CASHBACK_CURRENCY).toJSON(),
      pending: Money.of(pending._sum.amount ?? 0, CASHBACK_CURRENCY).toJSON(),
      lifetime_earned: Money.of(lifetime._sum.amount ?? 0, CASHBACK_CURRENCY).toJSON(),
      entries: entries.map(serializeCashbackEntry),
    };
  }

  async redeemCashback(userId: string, dto: RedeemCashbackDto = {}) {
    const balance = await this.cashbackBalance(userId);
    const available = Money.of(balance.available.amount, CASHBACK_CURRENCY);
    const amount =
      dto.amount && dto.amount > 0
        ? Money.of(dto.amount, CASHBACK_CURRENCY)
        : available;
    if (amount.isZero() || amount.isNegative() || amount.greaterThan(available)) {
      throw new BadRequestException('Insufficient cashback balance');
    }

    const coupon = await this.prisma.$transaction(async (tx) => {
      let remaining = amount;
      const entries = await tx.cashbackLedger.findMany({
        where: { userId, status: CashbackStatus.EARNED },
        orderBy: { createdAt: 'asc' },
      });

      for (const entry of entries) {
        if (remaining.isZero() || remaining.isNegative()) break;
        const entryAmount = Money.of(entry.amount, entry.currency);
        if (!entryAmount.greaterThan(remaining)) {
          remaining = remaining.minus(entryAmount);
          await tx.cashbackLedger.update({
            where: { id: entry.id },
            data: { status: CashbackStatus.REDEEMED, redeemedAt: new Date() },
          });
        } else {
          const redeemed = remaining;
          const leftover = entryAmount.minus(remaining);
          remaining = Money.zero(CASHBACK_CURRENCY);
          await tx.cashbackLedger.update({
            where: { id: entry.id },
            data: {
              amount: redeemed.toPrisma(),
              status: CashbackStatus.REDEEMED,
              redeemedAt: new Date(),
            },
          });
          await tx.cashbackLedger.create({
            data: {
              userId,
              orderId: entry.orderId,
              currency: entry.currency,
              amount: leftover.toPrisma(),
              status: CashbackStatus.EARNED,
              expiresAt: entry.expiresAt,
            },
          });
        }
      }

      return tx.coupon.create({
        data: {
          code: `CASH-${randomUUID().split('-')[0].toUpperCase()}`,
          // The currency travels with the figure — the old template baked a
          // literal "$" into a row that holds SYP.
          title: `${amount.toString()} cashback reward`,
          type: CouponType.FIXED,
          currency: amount.currency,
          amountOff: amount.toPrisma(),
          userId,
          maxUses: 1,
          perUserLimit: 1,
          expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
        },
      });
    });

    return {
      amount_redeemed: amount.toJSON(),
      coupon: serializeCoupon(coupon),
      cashback: await this.cashbackBalance(userId),
    };
  }

  async upsertTier(dto: CreateMembershipTierDto) {
    const data = {
      name: dto.name,
      minLifetimePoints: dto.min_lifetime_points,
      pointsMultiplier: dto.points_multiplier ?? 1,
      cashbackBps: dto.cashback_bps ?? 0,
      freeShipping: dto.free_shipping ?? false,
      priority: dto.priority ?? 0,
      status: dto.status ?? MembershipTierStatus.ACTIVE,
      ...(dto.benefits !== undefined && {
        benefits: dto.benefits as Prisma.InputJsonValue,
      }),
    };
    const tier = await this.prisma.membershipTier.upsert({
      where: { key: dto.key.toLowerCase() },
      create: { key: dto.key.toLowerCase(), ...data },
      update: data,
    });
    return serializeMembershipTier(tier);
  }

  async upsertReward(dto: UpsertLoyaltyRewardDto) {
    const data = {
      tierId: dto.tier_id ?? null,
      type: dto.type,
      title: dto.title,
      description: dto.description ?? null,
      pointsCost: dto.points_cost ?? null,
      couponId: dto.coupon_id ?? null,
      cashbackAmount: dto.cashback_amount ?? null,
      exclusive: dto.exclusive ?? false,
      isActive: dto.is_active ?? true,
      startsAt: dto.starts_at ? new Date(dto.starts_at) : new Date(),
      endsAt: dto.ends_at ? new Date(dto.ends_at) : null,
      ...(dto.metadata !== undefined && {
        metadata: dto.metadata as Prisma.InputJsonValue,
      }),
    };

    const reward = dto.id
      ? await this.prisma.loyaltyReward.update({ where: { id: dto.id }, data })
      : await this.prisma.loyaltyReward.create({ data });
    return serializeLoyaltyReward(reward);
  }

  async adminAnalytics() {
    await this.ensureDefaults();
    const [tiers, accountsByTier, cashback, rewards, vipCustomers] =
      await Promise.all([
        this.prisma.membershipTier.findMany({
          orderBy: { minLifetimePoints: 'asc' },
        }),
        this.prisma.membershipAccount.groupBy({
          by: ['tierSnapshot'],
          _count: { _all: true },
        }),
        this.prisma.cashbackLedger.aggregate({
          _sum: { amount: true },
          _count: { _all: true },
        }),
        this.prisma.loyaltyReward.count({ where: { isActive: true } }),
        this.prisma.membershipAccount.count({ where: { vip: true } }),
      ]);

    return {
      tiers: tiers.map(serializeMembershipTier),
      accounts_by_tier: Object.fromEntries(
        accountsByTier.map((row) => [row.tierSnapshot, row._count._all]),
      ),
      cashback: {
        entries: cashback._count._all,
        total: Money.of(cashback._sum.amount ?? 0, CASHBACK_CURRENCY).toJSON(),
      },
      active_rewards: rewards,
      vip_customers: vipCustomers,
    };
  }

  private async ensureDefaults() {
    const existingTiers = await this.prisma.membershipTier.findMany({
      where: { key: { in: DEFAULT_TIERS.map((tier) => tier.key) } },
      select: { key: true },
    });
    const existingKeys = new Set(existingTiers.map((tier) => tier.key));

    for (const tier of DEFAULT_TIERS) {
      if (!existingKeys.has(tier.key)) {
        await this.prisma.membershipTier.create({
          data: {
            ...tier,
            benefits: tier.benefits as Prisma.InputJsonValue,
            status: MembershipTierStatus.ACTIVE,
          },
        });
      }
    }

    const rewardCount = await this.prisma.loyaltyReward.count();
    if (rewardCount === 0) {
      const bronze = await this.prisma.membershipTier.findUnique({
        where: { key: 'bronze' },
        select: { id: true },
      });
      await this.prisma.loyaltyReward.createMany({
        data: [
          {
            tierId: bronze?.id,
            type: LoyaltyRewardType.COUPON,
            title: '$5 reward coupon',
            description: 'Convert 500 points into a one-time discount.',
            pointsCost: 500,
            metadata: { amount_off: 5 },
          },
          {
            tierId: bronze?.id,
            type: LoyaltyRewardType.FREE_SHIPPING,
            title: 'Free shipping perk',
            description: 'A shipping credit for loyal customers.',
            pointsCost: 1000,
            metadata: { amount_off: 7 },
          },
          {
            type: LoyaltyRewardType.EXCLUSIVE_OFFER,
            title: 'VIP early access',
            description: 'Claim access to private drops and exclusive offers.',
            exclusive: true,
            metadata: { amount_off: 15 },
          },
        ],
      });
    }
  }

  private async awardPoints(
    tx: Prisma.TransactionClient,
    userId: string,
    points: number,
    reason: string,
    orderId?: string,
  ) {
    const updated = await tx.user.update({
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
        balanceAfter: updated.points,
      },
    });
  }

  private async issueRewardCoupon(
    tx: Prisma.TransactionClient,
    userId: string,
    reward: LoyaltyReward,
  ) {
    const amountOff =
      reward.cashbackAmount ??
      this.metadataNumber(reward.metadata, 'amount_off', 0);
    return tx.coupon.create({
      data: {
        code: `LOYAL-${randomUUID().split('-')[0].toUpperCase()}`,
        title: reward.title,
        type: CouponType.FIXED,
        amountOff,
        userId,
        maxUses: 1,
        perUserLimit: 1,
        expiresAt: new Date(Date.now() + 45 * 24 * 60 * 60 * 1000),
      },
    });
  }

  private rewardIsActive(reward: LoyaltyReward) {
    const now = new Date();
    return (
      reward.isActive &&
      reward.startsAt <= now &&
      (!reward.endsAt || reward.endsAt > now)
    );
  }

  private metadataNumber(
    metadata: Prisma.JsonValue | null,
    key: string,
    fallback: number,
  ) {
    if (!metadata || Array.isArray(metadata) || typeof metadata !== 'object') {
      return fallback;
    }
    const value = (metadata as Record<string, unknown>)[key];
    return typeof value === 'number' && Number.isFinite(value)
      ? value
      : fallback;
  }
}
