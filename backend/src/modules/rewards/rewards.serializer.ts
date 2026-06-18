import {
  CashbackLedger,
  Coupon,
  LoyaltyReward,
  MembershipTier,
  PointsTransaction,
  Referral,
  ReferralCode,
  ReferralReward,
} from '@prisma/client';

export function serializeCoupon(c: Coupon) {
  return {
    id: c.id,
    code: c.code,
    title: c.title,
    type: c.type.toLowerCase(),
    discount_percent: c.discountPercent,
    amount_off: c.amountOff,
    min_order_amount: c.minOrderAmount,
    max_uses: c.maxUses,
    used_count: c.usedCount,
    per_user_limit: c.perUserLimit,
    is_user_specific: c.userId != null,
    expires_at: c.expiresAt.toISOString(),
    is_active: c.isActive,
    created_at: c.createdAt.toISOString(),
  };
}

export function serializePointsTransaction(t: PointsTransaction) {
  return {
    id: t.id,
    type: t.type.toLowerCase(),
    points: t.points,
    reason: t.reason,
    order_id: t.orderId,
    balance_after: t.balanceAfter,
    expires_at: t.expiresAt?.toISOString() ?? null,
    created_at: t.createdAt.toISOString(),
  };
}

export function serializeReferralCode(c: ReferralCode) {
  return {
    id: c.id,
    code: c.code,
    participant_type: c.participantType.toLowerCase(),
    campaign: c.campaign,
    max_uses: c.maxUses,
    used_count: c.usedCount,
    is_active: c.isActive,
    expires_at: c.expiresAt?.toISOString() ?? null,
    created_at: c.createdAt.toISOString(),
  };
}

export function serializeReferral(r: Referral) {
  return {
    id: r.id,
    code_id: r.codeId,
    referrer_id: r.referrerId,
    referred_user_id: r.referredUserId,
    participant_type: r.participantType.toLowerCase(),
    status: r.status.toLowerCase(),
    fraud_score: r.fraudScore,
    fraud_flags: r.fraudFlags,
    first_order_id: r.firstOrderId,
    qualified_at: r.qualifiedAt?.toISOString() ?? null,
    rewarded_at: r.rewardedAt?.toISOString() ?? null,
    expires_at: r.expiresAt?.toISOString() ?? null,
    created_at: r.createdAt.toISOString(),
  };
}

export function serializeReferralReward(r: ReferralReward) {
  return {
    id: r.id,
    referral_id: r.referralId,
    user_id: r.userId,
    type: r.type.toLowerCase(),
    points: r.points,
    coupon_id: r.couponId,
    cashback_amount: r.cashbackAmount,
    status: r.status,
    issued_at: r.issuedAt?.toISOString() ?? null,
    created_at: r.createdAt.toISOString(),
  };
}

export function serializeMembershipTier(t: MembershipTier) {
  return {
    id: t.id,
    key: t.key,
    name: t.name,
    min_lifetime_points: t.minLifetimePoints,
    points_multiplier: t.pointsMultiplier,
    cashback_bps: t.cashbackBps,
    cashback_rate: t.cashbackBps / 100,
    free_shipping: t.freeShipping,
    priority: t.priority,
    status: t.status.toLowerCase(),
    benefits: t.benefits,
  };
}

export function serializeLoyaltyReward(r: LoyaltyReward) {
  return {
    id: r.id,
    tier_id: r.tierId,
    type: r.type.toLowerCase(),
    title: r.title,
    description: r.description,
    points_cost: r.pointsCost,
    coupon_id: r.couponId,
    cashback_amount: r.cashbackAmount,
    exclusive: r.exclusive,
    is_active: r.isActive,
    starts_at: r.startsAt.toISOString(),
    ends_at: r.endsAt?.toISOString() ?? null,
    metadata: r.metadata,
    created_at: r.createdAt.toISOString(),
  };
}

export function serializeCashbackEntry(c: CashbackLedger) {
  return {
    id: c.id,
    user_id: c.userId,
    order_id: c.orderId,
    amount: c.amount,
    status: c.status.toLowerCase(),
    expires_at: c.expiresAt?.toISOString() ?? null,
    redeemed_at: c.redeemedAt?.toISOString() ?? null,
    reversed_at: c.reversedAt?.toISOString() ?? null,
    created_at: c.createdAt.toISOString(),
  };
}
