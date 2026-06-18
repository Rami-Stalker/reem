-- CreateEnum
CREATE TYPE "ReferralStatus" AS ENUM ('PENDING', 'QUALIFIED', 'REWARDED', 'REJECTED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "ReferralParticipantType" AS ENUM ('CUSTOMER', 'SELLER');

-- CreateEnum
CREATE TYPE "ReferralRewardType" AS ENUM ('POINTS', 'COUPON', 'CASHBACK');

-- CreateEnum
CREATE TYPE "MembershipTierStatus" AS ENUM ('ACTIVE', 'PAUSED', 'RETIRED');

-- CreateEnum
CREATE TYPE "LoyaltyRewardType" AS ENUM ('POINTS', 'COUPON', 'CASHBACK', 'EXCLUSIVE_OFFER', 'FREE_SHIPPING', 'GIFT');

-- CreateEnum
CREATE TYPE "CashbackStatus" AS ENUM ('PENDING', 'EARNED', 'REDEEMED', 'EXPIRED', 'REVERSED');

-- CreateTable
CREATE TABLE "referral_codes" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "participant_type" "ReferralParticipantType" NOT NULL DEFAULT 'CUSTOMER',
    "campaign" TEXT,
    "max_uses" INTEGER,
    "used_count" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "expires_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "referral_codes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "referrals" (
    "id" UUID NOT NULL,
    "code_id" UUID NOT NULL,
    "referrer_id" UUID NOT NULL,
    "referred_user_id" UUID NOT NULL,
    "participant_type" "ReferralParticipantType" NOT NULL DEFAULT 'CUSTOMER',
    "status" "ReferralStatus" NOT NULL DEFAULT 'PENDING',
    "fraud_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "fraud_flags" JSONB,
    "first_order_id" UUID,
    "qualified_at" TIMESTAMP(3),
    "rewarded_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "referrals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "referral_rewards" (
    "id" UUID NOT NULL,
    "referral_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "type" "ReferralRewardType" NOT NULL,
    "points" INTEGER,
    "coupon_id" UUID,
    "cashback_amount" DOUBLE PRECISION,
    "status" TEXT NOT NULL DEFAULT 'issued',
    "issued_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "referral_rewards_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "membership_tiers" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "min_lifetime_points" INTEGER NOT NULL DEFAULT 0,
    "points_multiplier" DOUBLE PRECISION NOT NULL DEFAULT 1,
    "cashback_bps" INTEGER NOT NULL DEFAULT 0,
    "free_shipping" BOOLEAN NOT NULL DEFAULT false,
    "priority" INTEGER NOT NULL DEFAULT 0,
    "status" "MembershipTierStatus" NOT NULL DEFAULT 'ACTIVE',
    "benefits" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "membership_tiers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "membership_accounts" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "tier_id" UUID,
    "tier_snapshot" TEXT NOT NULL DEFAULT 'Bronze',
    "vip" BOOLEAN NOT NULL DEFAULT false,
    "points_multiplier" DOUBLE PRECISION NOT NULL DEFAULT 1,
    "cashback_bps" INTEGER NOT NULL DEFAULT 0,
    "current_period_spend" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "tier_updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "membership_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "loyalty_rewards" (
    "id" UUID NOT NULL,
    "tier_id" UUID,
    "type" "LoyaltyRewardType" NOT NULL,
    "title" TEXT NOT NULL,
    "description" TEXT,
    "points_cost" INTEGER,
    "coupon_id" UUID,
    "cashback_amount" DOUBLE PRECISION,
    "exclusive" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "starts_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ends_at" TIMESTAMP(3),
    "metadata" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "loyalty_rewards_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cashback_ledger" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "order_id" UUID,
    "amount" DOUBLE PRECISION NOT NULL,
    "status" "CashbackStatus" NOT NULL DEFAULT 'EARNED',
    "expires_at" TIMESTAMP(3),
    "redeemed_at" TIMESTAMP(3),
    "reversed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cashback_ledger_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "exclusive_offer_claims" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "reward_id" UUID NOT NULL,
    "claimed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "metadata" JSONB,

    CONSTRAINT "exclusive_offer_claims_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "referral_codes_code_key" ON "referral_codes"("code");

-- CreateIndex
CREATE INDEX "referral_codes_user_id_participant_type_is_active_idx" ON "referral_codes"("user_id", "participant_type", "is_active");

-- CreateIndex
CREATE INDEX "referral_codes_campaign_idx" ON "referral_codes"("campaign");

-- CreateIndex
CREATE UNIQUE INDEX "referrals_referred_user_id_key" ON "referrals"("referred_user_id");

-- CreateIndex
CREATE UNIQUE INDEX "referrals_referrer_id_referred_user_id_key" ON "referrals"("referrer_id", "referred_user_id");

-- CreateIndex
CREATE INDEX "referrals_referrer_id_status_idx" ON "referrals"("referrer_id", "status");

-- CreateIndex
CREATE INDEX "referrals_participant_type_status_idx" ON "referrals"("participant_type", "status");

-- CreateIndex
CREATE INDEX "referrals_created_at_idx" ON "referrals"("created_at");

-- CreateIndex
CREATE INDEX "referral_rewards_referral_id_idx" ON "referral_rewards"("referral_id");

-- CreateIndex
CREATE INDEX "referral_rewards_user_id_idx" ON "referral_rewards"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "membership_tiers_key_key" ON "membership_tiers"("key");

-- CreateIndex
CREATE INDEX "membership_tiers_status_min_lifetime_points_idx" ON "membership_tiers"("status", "min_lifetime_points");

-- CreateIndex
CREATE UNIQUE INDEX "membership_accounts_user_id_key" ON "membership_accounts"("user_id");

-- CreateIndex
CREATE INDEX "membership_accounts_tier_id_idx" ON "membership_accounts"("tier_id");

-- CreateIndex
CREATE INDEX "membership_accounts_vip_idx" ON "membership_accounts"("vip");

-- CreateIndex
CREATE INDEX "loyalty_rewards_tier_id_is_active_idx" ON "loyalty_rewards"("tier_id", "is_active");

-- CreateIndex
CREATE INDEX "loyalty_rewards_type_is_active_idx" ON "loyalty_rewards"("type", "is_active");

-- CreateIndex
CREATE INDEX "cashback_ledger_user_id_status_idx" ON "cashback_ledger"("user_id", "status");

-- CreateIndex
CREATE INDEX "cashback_ledger_order_id_idx" ON "cashback_ledger"("order_id");

-- CreateIndex
CREATE UNIQUE INDEX "exclusive_offer_claims_user_id_reward_id_key" ON "exclusive_offer_claims"("user_id", "reward_id");

-- CreateIndex
CREATE INDEX "exclusive_offer_claims_reward_id_idx" ON "exclusive_offer_claims"("reward_id");

-- AddForeignKey
ALTER TABLE "referral_codes" ADD CONSTRAINT "referral_codes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_code_id_fkey" FOREIGN KEY ("code_id") REFERENCES "referral_codes"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_referrer_id_fkey" FOREIGN KEY ("referrer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "referrals" ADD CONSTRAINT "referrals_referred_user_id_fkey" FOREIGN KEY ("referred_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "referral_rewards" ADD CONSTRAINT "referral_rewards_referral_id_fkey" FOREIGN KEY ("referral_id") REFERENCES "referrals"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "referral_rewards" ADD CONSTRAINT "referral_rewards_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "referral_rewards" ADD CONSTRAINT "referral_rewards_coupon_id_fkey" FOREIGN KEY ("coupon_id") REFERENCES "coupons"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "membership_accounts" ADD CONSTRAINT "membership_accounts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "membership_accounts" ADD CONSTRAINT "membership_accounts_tier_id_fkey" FOREIGN KEY ("tier_id") REFERENCES "membership_tiers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "loyalty_rewards" ADD CONSTRAINT "loyalty_rewards_tier_id_fkey" FOREIGN KEY ("tier_id") REFERENCES "membership_tiers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "loyalty_rewards" ADD CONSTRAINT "loyalty_rewards_coupon_id_fkey" FOREIGN KEY ("coupon_id") REFERENCES "coupons"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cashback_ledger" ADD CONSTRAINT "cashback_ledger_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cashback_ledger" ADD CONSTRAINT "cashback_ledger_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "exclusive_offer_claims" ADD CONSTRAINT "exclusive_offer_claims_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "exclusive_offer_claims" ADD CONSTRAINT "exclusive_offer_claims_reward_id_fkey" FOREIGN KEY ("reward_id") REFERENCES "loyalty_rewards"("id") ON DELETE CASCADE ON UPDATE CASCADE;
