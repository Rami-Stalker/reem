-- GENERATED from backend/prisma/migrations/20260819013000_step_up_ladder_and_new_device_cooldown/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 41bae29bb06d24b6f54252baf52305acf32fc09af51519e8dcafc3d56748ea7c

SET search_path = public, extensions;


-- CreateEnum
CREATE TYPE "AssuranceLevel" AS ENUM ('AAL1', 'AAL2', 'AAL3');

-- CreateEnum
CREATE TYPE "StepUpMethod" AS ENUM ('OTP', 'TOTP', 'RECOVERY_CODE');

-- AlterTable
ALTER TABLE "sessions" ADD COLUMN     "assurance_level" "AssuranceLevel" NOT NULL DEFAULT 'AAL1',
ADD COLUMN     "elevated_until" TIMESTAMP(3),
ADD COLUMN     "new_device_cooldown_until" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "step_up_grants" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "session_id" UUID,
    "scope" TEXT NOT NULL,
    "method" "StepUpMethod" NOT NULL,
    "challenge_id" UUID,
    "issued_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "consumed_at" TIMESTAMP(3),
    "ip_address" TEXT,
    "user_agent" TEXT,

    CONSTRAINT "step_up_grants_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "step_up_grants_user_id_scope_consumed_at_idx" ON "step_up_grants"("user_id", "scope", "consumed_at");

-- CreateIndex
CREATE INDEX "step_up_grants_session_id_expires_at_idx" ON "step_up_grants"("session_id", "expires_at");

-- AddForeignKey
ALTER TABLE "step_up_grants" ADD CONSTRAINT "step_up_grants_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "step_up_grants" ADD CONSTRAINT "step_up_grants_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '41bae29bb06d24b6f54252baf52305acf32fc09af51519e8dcafc3d56748ea7c', now(), '20260819013000_step_up_ladder_and_new_device_cooldown', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260819013000_step_up_ladder_and_new_device_cooldown');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
