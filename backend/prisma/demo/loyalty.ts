import {
  Currency,
  LoyaltyRewardType,
  MembershipTierStatus,
  Prisma,
  ReferralParticipantType,
  ReferralRewardType,
  ReferralStatus,
} from '@prisma/client';
import { COUPONS } from './data';
import { DemoContext } from './context';

const D = Prisma.Decimal;

const TIERS = [
  {
    key: 'bronze',
    name: 'برونزية',
    minLifetimePoints: 0,
    pointsMultiplier: 1,
    cashbackBps: 0,
    freeShipping: false,
    priority: 1,
    benefits: ['نقاط على كل طلب', 'عروض المتابعات'],
  },
  {
    key: 'silver',
    name: 'فضية',
    minLifetimePoints: 1_000,
    pointsMultiplier: 1.25,
    cashbackBps: 100,
    freeShipping: false,
    priority: 2,
    benefits: ['نقاط مضاعفة ١.٢٥×', 'كاش باك ١٪', 'دعم أولوية'],
  },
  {
    key: 'gold',
    name: 'ذهبية',
    minLifetimePoints: 5_000,
    pointsMultiplier: 1.5,
    cashbackBps: 200,
    freeShipping: true,
    priority: 3,
    benefits: ['شحن مجاني فوق ٣٠٠ ألف', 'كاش باك ٢٪', 'وصول مبكر للعروض'],
  },
  {
    key: 'platinum',
    name: 'بلاتينية',
    minLifetimePoints: 15_000,
    pointsMultiplier: 2,
    cashbackBps: 300,
    freeShipping: true,
    priority: 4,
    benefits: [
      'شحن مجاني دائم',
      'كاش باك ٣٪',
      'عروض حصرية',
      'مديرة حساب خاصة',
    ],
  },
];

const TIER_BY_LABEL: Record<string, string> = {
  Bronze: 'bronze',
  Silver: 'silver',
  Gold: 'gold',
  Platinum: 'platinum',
};

/**
 * Coupons, membership tiers, loyalty rewards and referral codes.
 *
 * Runs **before** the orders, because an order may redeem a coupon and the
 * redemption row has to point at a coupon that already exists.
 */
export async function seedLoyaltyBase(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  const tierIds = new Map<string, string>();
  for (const tier of TIERS) {
    const row = await prisma.membershipTier.create({
      data: {
        key: tier.key,
        name: tier.name,
        minLifetimePoints: tier.minLifetimePoints,
        pointsMultiplier: tier.pointsMultiplier,
        cashbackBps: tier.cashbackBps,
        freeShipping: tier.freeShipping,
        priority: tier.priority,
        status: MembershipTierStatus.ACTIVE,
        benefits: tier.benefits as Prisma.InputJsonValue,
      },
    });
    tierIds.set(tier.key, row.id);
  }

  // ── Coupons: platform-wide, plus one personal code per shopper ───────
  const couponIds: string[] = [];
  for (const coupon of COUPONS) {
    const row = await prisma.coupon.create({
      data: {
        code: coupon.code,
        title: coupon.title,
        type: coupon.amountOff ? 'FIXED' : 'PERCENTAGE',
        currency: Currency.SYP,
        discountPercent: new D(coupon.percent),
        amountOff: coupon.amountOff ? new D(coupon.amountOff) : null,
        minOrderAmount: new D(1_500),
        maxUses: rng.int(100, 1000),
        perUserLimit: 1,
        expiresAt: rng.futureDate(coupon.days, Math.round(coupon.days / 3)),
        isActive: true,
      },
    });
    couponIds.push(row.id);
  }

  for (const customer of ctx.customers) {
    if (!rng.bool(0.5)) continue;
    await prisma.coupon.create({
      data: {
        code: `REEM-${customer.id.slice(0, 6).toUpperCase()}`,
        title: 'كوبون خاص بكِ',
        currency: Currency.SYP,
        discountPercent: new D(rng.pick([10, 15, 20])),
        minOrderAmount: new D(1_000),
        perUserLimit: 1,
        userId: customer.id,
        expiresAt: rng.futureDate(45, 7),
      },
    });
  }

  // ── Catalogue of redeemable rewards ─────────────────────────────────
  const rewards: Prisma.LoyaltyRewardCreateInput[] = [
    {
      tier: { connect: { id: tierIds.get('bronze')! } },
      type: LoyaltyRewardType.COUPON,
      title: 'كوبون خصم ١٠٪',
      description: 'استبدلي ٥٠٠ نقطة بكوبون خصم على طلبك القادم.',
      pointsCost: 500,
      coupon: { connect: { id: couponIds[0] } },
    },
    {
      tier: { connect: { id: tierIds.get('silver')! } },
      type: LoyaltyRewardType.FREE_SHIPPING,
      title: 'شحن مجاني لمرة واحدة',
      description: 'استبدلي ٣٠٠ نقطة بشحن مجاني داخل محافظتك.',
      pointsCost: 300,
    },
    {
      tier: { connect: { id: tierIds.get('gold')! } },
      type: LoyaltyRewardType.CASHBACK,
      title: 'كاش باك ٥٠ ألف ل.س',
      description: 'رصيد يُضاف لمحفظتك ويُخصم من طلبك القادم.',
      pointsCost: 1_200,
      currency: Currency.SYP,
      cashbackAmount: new D(500),
    },
    {
      tier: { connect: { id: tierIds.get('platinum')! } },
      type: LoyaltyRewardType.EXCLUSIVE_OFFER,
      title: 'وصول مبكر لتشكيلة المناسبات',
      description: 'تسوّقي التشكيلة الجديدة قبل الجميع بـ ٤٨ ساعة.',
      exclusive: true,
    },
    {
      type: LoyaltyRewardType.GIFT,
      title: 'هدية عيد ميلادك 🎁',
      description: 'هدية صغيرة مع طلبك في شهر ميلادك.',
      exclusive: false,
    },
    {
      type: LoyaltyRewardType.POINTS,
      title: '١٠٠ نقطة ترحيبية',
      description: 'تُمنح تلقائياً بعد أول طلب مكتمل.',
      pointsCost: null,
    },
  ];

  const rewardIds: string[] = [];
  for (const reward of rewards) {
    const row = await prisma.loyaltyReward.create({ data: reward });
    rewardIds.push(row.id);
  }

  // A few shoppers already grabbed the exclusive offers.
  for (const customer of rng.sample(ctx.customers, 4)) {
    await prisma.exclusiveOfferClaim.create({
      data: {
        userId: customer.id,
        rewardId: rng.pick(rewardIds),
        claimedAt: rng.pastDate(40),
      },
    });
  }

  // ── Referrals ───────────────────────────────────────────────────────
  const codes = new Map<string, string>();
  for (const customer of ctx.customers) {
    const code = await prisma.referralCode.create({
      data: {
        userId: customer.id,
        code: `REEM${customer.id.slice(0, 5).toUpperCase()}`,
        participantType: ReferralParticipantType.CUSTOMER,
        campaign: 'launch',
        maxUses: 20,
        expiresAt: rng.futureDate(180, 30),
        createdAt: rng.pastDate(200, 10),
      },
    });
    codes.set(customer.id, code.id);
  }

  for (const seller of ctx.sellers) {
    await prisma.referralCode.create({
      data: {
        userId: seller.id,
        code: `SELLER${seller.id.slice(0, 5).toUpperCase()}`,
        participantType: ReferralParticipantType.SELLER,
        campaign: 'seller-growth',
        maxUses: 50,
        expiresAt: rng.futureDate(365, 60),
      },
    });
  }

  // Each referred shopper can only be referred once (unique constraint), so
  // the pairs are drawn without replacement.
  const referrers = rng.shuffle(ctx.customers);
  for (let index = 0; index + 1 < referrers.length; index += 2) {
    const referrer = referrers[index];
    const invited = referrers[index + 1];
    const codeId = codes.get(referrer.id);
    if (!codeId) continue;

    const status = rng.weighted<ReferralStatus>([
      [ReferralStatus.REWARDED, 3],
      [ReferralStatus.QUALIFIED, 2],
      [ReferralStatus.PENDING, 2],
    ]);
    const createdAt = rng.pastDate(120, 5);

    const referral = await prisma.referral.create({
      data: {
        codeId,
        referrerId: referrer.id,
        referredUserId: invited.id,
        participantType: ReferralParticipantType.CUSTOMER,
        status,
        fraudScore: rng.float(0, 0.3, 2),
        qualifiedAt:
          status === ReferralStatus.PENDING ? null : new Date(createdAt),
        rewardedAt:
          status === ReferralStatus.REWARDED
            ? new Date(createdAt.getTime() + 3 * 864e5)
            : null,
        expiresAt: rng.futureDate(90, 10),
        createdAt,
      },
    });

    await prisma.referralCode.update({
      where: { id: codeId },
      data: { usedCount: { increment: 1 } },
    });

    if (status === ReferralStatus.REWARDED) {
      await prisma.referralReward.createMany({
        data: [
          {
            referralId: referral.id,
            userId: referrer.id,
            type: ReferralRewardType.POINTS,
            points: 250,
            status: 'issued',
            issuedAt: new Date(createdAt.getTime() + 3 * 864e5),
          },
          {
            referralId: referral.id,
            userId: invited.id,
            type: ReferralRewardType.CASHBACK,
            currency: Currency.SYP,
            cashbackAmount: new D(250),
            status: 'issued',
            issuedAt: new Date(createdAt.getTime() + 3 * 864e5),
          },
        ],
      });
    }
  }
}

/**
 * Membership accounts, written after the order history so the tier reflects the
 * points the shopper actually accumulated.
 */
export async function seedMemberships(ctx: DemoContext): Promise<void> {
  const { prisma } = ctx;

  const tiers = await prisma.membershipTier.findMany({
    orderBy: { minLifetimePoints: 'asc' },
  });

  for (const customer of ctx.customers) {
    const user = await prisma.user.findUnique({
      where: { id: customer.id },
      select: { lifetimePoints: true, tier: true },
    });
    if (!user) continue;

    // The declared tier wins when it is higher than the earned one — VIP
    // upgrades are granted manually by the admin, not derived.
    const earned = [...tiers]
      .reverse()
      .find((tier) => user.lifetimePoints >= tier.minLifetimePoints);
    const declaredKey = TIER_BY_LABEL[user.tier] ?? 'bronze';
    const declared = tiers.find((tier) => tier.key === declaredKey);
    const tier =
      declared && earned && declared.priority > earned.priority
        ? declared
        : (earned ?? tiers[0]);

    await prisma.membershipAccount.create({
      data: {
        userId: customer.id,
        tierId: tier.id,
        tierSnapshot: tier.name,
        vip: tier.key === 'platinum',
        pointsMultiplier: tier.pointsMultiplier,
        cashbackBps: tier.cashbackBps,
        spendCurrency: Currency.SYP,
        currentPeriodSpend: new D(0),
      },
    });
  }

  // Roll the customer's spend for the current period out of their orders.
  const spend = await prisma.order.groupBy({
    by: ['userId'],
    where: {
      placedAt: { gte: new Date(Date.now() - 90 * 864e5) },
      status: { notIn: ['CANCELLED', 'PENDING_PAYMENT'] },
    },
    _sum: { grandTotal: true },
  });

  for (const row of spend) {
    if (!row.userId) continue;
    await prisma.membershipAccount.updateMany({
      where: { userId: row.userId },
      data: { currentPeriodSpend: row._sum.grandTotal ?? new D(0) },
    });
  }
}
