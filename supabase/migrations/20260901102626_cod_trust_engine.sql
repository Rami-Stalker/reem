-- GENERATED from backend/prisma/migrations/20260901102626_cod_trust_engine/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 3ba59856529645b5444928ba9bfb0d8e2d54e24c9fa735d6b4df4158908568c6

SET search_path = public, extensions;


-- CreateEnum
CREATE TYPE "CodRiskTier" AS ENUM ('TRUSTED', 'LOW', 'MEDIUM', 'HIGH');

-- CreateEnum
CREATE TYPE "CodAssurance" AS ENUM ('NONE', 'ORDER_CONFIRMATION', 'PREPAYMENT');

-- CreateEnum
CREATE TYPE "CodAssuranceState" AS ENUM ('NOT_REQUIRED', 'PENDING', 'SATISFIED', 'ABANDONED');

-- AlterEnum
ALTER TYPE "OtpPurpose" ADD VALUE 'ORDER_CONFIRMATION';

-- AlterTable
-- Pre-existing drift, not part of this feature: the column carries a database
-- default the schema never declared. Prisma folds it into the next migration
-- to run, and this happens to be it.
ALTER TABLE "addresses" ALTER COLUMN "updated_at" DROP DEFAULT;

-- CreateTable
CREATE TABLE "cod_risk_assessments" (
    "id" UUID NOT NULL,
    "order_id" UUID NOT NULL,
    "user_id" UUID,
    "score" DECIMAL(5,2) NOT NULL,
    "confidence" DECIMAL(4,2) NOT NULL,
    "tier" "CodRiskTier" NOT NULL,
    "assurance" "CodAssurance" NOT NULL,
    "state" "CodAssuranceState" NOT NULL DEFAULT 'NOT_REQUIRED',
    "factors" JSONB NOT NULL,
    "rule_codes" TEXT[],
    "exposure_usd" DECIMAL(18,4) NOT NULL,
    "otp_request_id" UUID,
    "satisfied_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3),
    "observed_outcome" TEXT,
    "observed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "cod_risk_assessments_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "cod_risk_assessments_order_id_key" ON "cod_risk_assessments"("order_id");

-- CreateIndex
CREATE INDEX "cod_risk_assessments_tier_created_at_idx" ON "cod_risk_assessments"("tier", "created_at");

-- CreateIndex
CREATE INDEX "cod_risk_assessments_state_expires_at_idx" ON "cod_risk_assessments"("state", "expires_at");

-- CreateIndex
CREATE INDEX "cod_risk_assessments_user_id_created_at_idx" ON "cod_risk_assessments"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "cod_risk_assessments_observed_outcome_created_at_idx" ON "cod_risk_assessments"("observed_outcome", "created_at");

-- AddForeignKey
ALTER TABLE "cod_risk_assessments" ADD CONSTRAINT "cod_risk_assessments_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cod_risk_assessments" ADD CONSTRAINT "cod_risk_assessments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '3ba59856529645b5444928ba9bfb0d8e2d54e24c9fa735d6b4df4158908568c6', now(), '20260901102626_cod_trust_engine', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260901102626_cod_trust_engine');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
