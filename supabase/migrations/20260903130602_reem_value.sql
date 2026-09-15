-- GENERATED from backend/prisma/migrations/20260903130602_reem_value/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 175f9fb661f284bbe32a4bedc0722250fae60b10f837e24f4474d0565c61350b

SET search_path = public, extensions;


-- ═══════════════════════════ Reem Value ═══════════════════════════
--
-- Seven tables and four enums: standing, and the benefits it opens.
--
-- Purely additive. Nothing is dropped and nothing is backfilled, which is
-- deliberate rather than convenient: the old `membership_tiers` /
-- `membership_accounts` rows stay untouched so the two programmes can run side
-- by side while the client decides how to retire the tier half of the old one.
-- `points_transactions` is not going anywhere at all — that is Q43's
-- ledger-backed credit, and Reem Value is standing rather than currency.
--
-- Every profile in `value_profiles` is a cache: the score, the pillars and the
-- rung are all recomputable from `value_events` plus the active row of
-- `value_policies`. Nothing here has to be got right on the first pass.

-- CreateEnum
CREATE TYPE "ValuePillar" AS ENUM ('COMMERCE', 'CRAFT', 'COMMUNITY', 'ADVOCACY', 'DISCOVERY', 'RELIABILITY');

-- CreateEnum
CREATE TYPE "ValueEventStatus" AS ENUM ('PENDING', 'CONFIRMED', 'REVERSED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "ValueBenefitKind" AS ENUM ('EARLY_ACCESS', 'EXCLUSIVE_PRODUCT', 'PRIORITY_SUPPORT', 'PRIORITY_DELIVERY', 'ENHANCED_RETURNS', 'GIFT', 'PERSONALISED_OFFER');

-- CreateEnum
CREATE TYPE "ValueGrantStatus" AS ENUM ('OFFERED', 'ACTIVE', 'USED', 'EXPIRED', 'REVOKED');

-- CreateTable
CREATE TABLE "value_tiers" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "name_ar" TEXT NOT NULL,
    "min_score" INTEGER NOT NULL,
    "rank" INTEGER NOT NULL,
    "demotion_buffer_score" INTEGER NOT NULL DEFAULT 40,
    "hold_days" INTEGER NOT NULL DEFAULT 90,
    "presentation" JSONB,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "value_tiers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "value_policies" (
    "id" UUID NOT NULL,
    "version" INTEGER NOT NULL,
    "is_active" BOOLEAN NOT NULL DEFAULT false,
    "pillar_weights" JSONB NOT NULL,
    "pillar_scales" JSONB NOT NULL,
    "event_weights" JSONB NOT NULL,
    "daily_pillar_caps" JSONB NOT NULL,
    "half_life_days" INTEGER NOT NULL DEFAULT 365,
    "horizon_days" INTEGER NOT NULL DEFAULT 1095,
    "commerce_ceiling_bps" INTEGER NOT NULL DEFAULT 3500,
    "reliability_baseline" INTEGER NOT NULL DEFAULT 70,
    "min_evidence_per_pillar" INTEGER NOT NULL DEFAULT 2,
    "note" TEXT,
    "created_by_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "activated_at" TIMESTAMP(3),

    CONSTRAINT "value_policies_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "value_profiles" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "score" INTEGER NOT NULL DEFAULT 0,
    "pillars" JSONB NOT NULL,
    "tier_id" UUID,
    "tier_key" TEXT,
    "tier_name" TEXT,
    "tier_achieved_at" TIMESTAMP(3),
    "tier_held_until" TIMESTAMP(3),
    "peak_score" INTEGER NOT NULL DEFAULT 0,
    "peak_achieved_at" TIMESTAMP(3),
    "momentum" INTEGER NOT NULL DEFAULT 0,
    "policy_id" UUID,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "frozen_at" TIMESTAMP(3),
    "frozen_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "value_profiles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "value_events" (
    "id" UUID NOT NULL,
    "profile_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "pillar" "ValuePillar" NOT NULL,
    "code" TEXT NOT NULL,
    "status" "ValueEventStatus" NOT NULL DEFAULT 'PENDING',
    "weight" INTEGER NOT NULL,
    "dedupe_key" TEXT NOT NULL,
    "subject_type" TEXT,
    "subject_id" UUID,
    "evidence" JSONB,
    "occurred_at" TIMESTAMP(3) NOT NULL,
    "confirmed_at" TIMESTAMP(3),
    "reversed_at" TIMESTAMP(3),
    "reversed_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "value_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "value_snapshots" (
    "id" UUID NOT NULL,
    "profile_id" UUID NOT NULL,
    "captured_on" DATE NOT NULL,
    "score" INTEGER NOT NULL,
    "pillars" JSONB NOT NULL,
    "tier_key" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "value_snapshots_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "value_benefits" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "kind" "ValueBenefitKind" NOT NULL,
    "title" TEXT NOT NULL,
    "title_ar" TEXT NOT NULL,
    "description" TEXT,
    "description_ar" TEXT,
    "min_tier_id" UUID,
    "config" JSONB,
    "per_user_quota" INTEGER,
    "quota_period_days" INTEGER,
    "total_budget" INTEGER,
    "granted_count" INTEGER NOT NULL DEFAULT 0,
    "unit_cost_syp" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "grant_ttl_days" INTEGER,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "starts_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "ends_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "value_benefits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "value_benefit_grants" (
    "id" UUID NOT NULL,
    "profile_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "benefit_id" UUID NOT NULL,
    "status" "ValueGrantStatus" NOT NULL DEFAULT 'OFFERED',
    "tier_key_at_grant" TEXT,
    "score_at_grant" INTEGER,
    "dedupe_key" TEXT NOT NULL,
    "used_on_type" TEXT,
    "used_on_id" UUID,
    "used_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3),
    "revoked_at" TIMESTAMP(3),
    "revoked_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "value_benefit_grants_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "value_tiers_key_key" ON "value_tiers"("key");

-- CreateIndex
CREATE INDEX "value_tiers_is_active_rank_idx" ON "value_tiers"("is_active", "rank");

-- CreateIndex
CREATE UNIQUE INDEX "value_policies_version_key" ON "value_policies"("version");

-- CreateIndex
CREATE INDEX "value_policies_is_active_idx" ON "value_policies"("is_active");

-- CreateIndex
CREATE UNIQUE INDEX "value_profiles_user_id_key" ON "value_profiles"("user_id");

-- CreateIndex
CREATE INDEX "value_profiles_tier_id_score_idx" ON "value_profiles"("tier_id", "score");

-- CreateIndex
CREATE INDEX "value_profiles_score_idx" ON "value_profiles"("score");

-- CreateIndex
CREATE INDEX "value_events_profile_id_status_occurred_at_idx" ON "value_events"("profile_id", "status", "occurred_at");

-- CreateIndex
CREATE INDEX "value_events_status_code_occurred_at_idx" ON "value_events"("status", "code", "occurred_at");

-- CreateIndex
CREATE INDEX "value_events_subject_type_subject_id_idx" ON "value_events"("subject_type", "subject_id");

-- CreateIndex
CREATE UNIQUE INDEX "value_events_user_id_dedupe_key_key" ON "value_events"("user_id", "dedupe_key");

-- CreateIndex
CREATE INDEX "value_snapshots_profile_id_captured_on_idx" ON "value_snapshots"("profile_id", "captured_on");

-- CreateIndex
CREATE UNIQUE INDEX "value_snapshots_profile_id_captured_on_key" ON "value_snapshots"("profile_id", "captured_on");

-- CreateIndex
CREATE UNIQUE INDEX "value_benefits_key_key" ON "value_benefits"("key");

-- CreateIndex
CREATE INDEX "value_benefits_is_active_kind_idx" ON "value_benefits"("is_active", "kind");

-- CreateIndex
CREATE INDEX "value_benefits_min_tier_id_is_active_idx" ON "value_benefits"("min_tier_id", "is_active");

-- CreateIndex
CREATE INDEX "value_benefit_grants_profile_id_status_idx" ON "value_benefit_grants"("profile_id", "status");

-- CreateIndex
CREATE INDEX "value_benefit_grants_benefit_id_status_idx" ON "value_benefit_grants"("benefit_id", "status");

-- CreateIndex
CREATE INDEX "value_benefit_grants_status_expires_at_idx" ON "value_benefit_grants"("status", "expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "value_benefit_grants_user_id_dedupe_key_key" ON "value_benefit_grants"("user_id", "dedupe_key");

-- AddForeignKey
ALTER TABLE "value_profiles" ADD CONSTRAINT "value_profiles_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "value_profiles" ADD CONSTRAINT "value_profiles_tier_id_fkey" FOREIGN KEY ("tier_id") REFERENCES "value_tiers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "value_profiles" ADD CONSTRAINT "value_profiles_policy_id_fkey" FOREIGN KEY ("policy_id") REFERENCES "value_policies"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "value_events" ADD CONSTRAINT "value_events_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "value_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "value_events" ADD CONSTRAINT "value_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "value_snapshots" ADD CONSTRAINT "value_snapshots_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "value_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "value_benefits" ADD CONSTRAINT "value_benefits_min_tier_id_fkey" FOREIGN KEY ("min_tier_id") REFERENCES "value_tiers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "value_benefit_grants" ADD CONSTRAINT "value_benefit_grants_profile_id_fkey" FOREIGN KEY ("profile_id") REFERENCES "value_profiles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "value_benefit_grants" ADD CONSTRAINT "value_benefit_grants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "value_benefit_grants" ADD CONSTRAINT "value_benefit_grants_benefit_id_fkey" FOREIGN KEY ("benefit_id") REFERENCES "value_benefits"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '175f9fb661f284bbe32a4bedc0722250fae60b10f837e24f4474d0565c61350b', now(), '20260903130602_reem_value', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260903130602_reem_value');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
