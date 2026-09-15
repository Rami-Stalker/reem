-- GENERATED from backend/prisma/migrations/20260822230245_identity_v2_recovery_phone_change/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 4fdf1adc0de36720914956d34755a23cffeeae3a019b7fc52586cc6284745e47

SET search_path = public, extensions;


-- CreateEnum
CREATE TYPE "PhoneChangeStatus" AS ENUM ('AWAITING_CURRENT', 'AWAITING_NEW', 'COMPLETED', 'CANCELLED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "AccountRecoveryStatus" AS ENUM ('SUBMITTED', 'UNDER_REVIEW', 'AWAITING_SECOND_APPROVAL', 'COOLING_OFF', 'COMPLETED', 'REJECTED', 'CANCELLED', 'EXPIRED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "OtpPurpose" ADD VALUE 'LOGIN';
ALTER TYPE "OtpPurpose" ADD VALUE 'PHONE_CHANGE';
ALTER TYPE "OtpPurpose" ADD VALUE 'ACCOUNT_RECOVERY';

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "SecurityEventType" ADD VALUE 'PASSWORD_ENABLED';
ALTER TYPE "SecurityEventType" ADD VALUE 'PASSWORD_DISABLED';
ALTER TYPE "SecurityEventType" ADD VALUE 'PHONE_CHANGED';
ALTER TYPE "SecurityEventType" ADD VALUE 'PASSWORD_NEW_DEVICE_BLOCKED';
ALTER TYPE "SecurityEventType" ADD VALUE 'RECOVERY_CASE_OPENED';
ALTER TYPE "SecurityEventType" ADD VALUE 'RECOVERY_CASE_APPROVED';
ALTER TYPE "SecurityEventType" ADD VALUE 'RECOVERY_CASE_REJECTED';
ALTER TYPE "SecurityEventType" ADD VALUE 'RECOVERY_CASE_CANCELLED';
ALTER TYPE "SecurityEventType" ADD VALUE 'RECOVERY_CASE_COMPLETED';
ALTER TYPE "SecurityEventType" ADD VALUE 'PAYOUT_FROZEN';

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "password_set_at" TIMESTAMP(3),
ADD COLUMN     "payout_freeze_reason" TEXT,
ADD COLUMN     "payout_frozen_until" TIMESTAMP(3);

-- CreateTable
CREATE TABLE "phone_change_requests" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "current_phone" TEXT NOT NULL,
    "new_phone" TEXT NOT NULL,
    "status" "PhoneChangeStatus" NOT NULL DEFAULT 'AWAITING_CURRENT',
    "current_verified_at" TIMESTAMP(3),
    "new_verified_at" TIMESTAMP(3),
    "session_id" UUID,
    "device_key_id" UUID,
    "ip_address" TEXT,
    "user_agent" TEXT,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "completed_at" TIMESTAMP(3),
    "cancelled_at" TIMESTAMP(3),
    "cancelled_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "phone_change_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "account_recovery_cases" (
    "id" UUID NOT NULL,
    "user_id" UUID,
    "claimed_phone" TEXT NOT NULL,
    "contact_phone" TEXT NOT NULL,
    "status" "AccountRecoveryStatus" NOT NULL DEFAULT 'SUBMITTED',
    "evidence" JSONB,
    "score" INTEGER NOT NULL DEFAULT 0,
    "risk_notes" TEXT,
    "first_approver_id" UUID,
    "first_approved_at" TIMESTAMP(3),
    "second_approver_id" UUID,
    "second_approved_at" TIMESTAMP(3),
    "cool_off_until" TIMESTAMP(3),
    "completed_at" TIMESTAMP(3),
    "rejected_at" TIMESTAMP(3),
    "rejected_reason" TEXT,
    "cancelled_at" TIMESTAMP(3),
    "new_phone" TEXT,
    "claim_secret_hash" TEXT,
    "ip_address" TEXT,
    "user_agent" TEXT,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "account_recovery_cases_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "account_recovery_events" (
    "id" UUID NOT NULL,
    "case_id" UUID NOT NULL,
    "actor_id" UUID,
    "action" TEXT NOT NULL,
    "note" TEXT,
    "metadata" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "account_recovery_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "phone_change_requests_user_id_status_idx" ON "phone_change_requests"("user_id", "status");

-- CreateIndex
CREATE INDEX "phone_change_requests_status_expires_at_idx" ON "phone_change_requests"("status", "expires_at");

-- CreateIndex
CREATE INDEX "account_recovery_cases_status_created_at_idx" ON "account_recovery_cases"("status", "created_at");

-- CreateIndex
CREATE INDEX "account_recovery_cases_user_id_status_idx" ON "account_recovery_cases"("user_id", "status");

-- CreateIndex
CREATE INDEX "account_recovery_cases_claimed_phone_created_at_idx" ON "account_recovery_cases"("claimed_phone", "created_at");

-- CreateIndex
CREATE INDEX "account_recovery_cases_status_cool_off_until_idx" ON "account_recovery_cases"("status", "cool_off_until");

-- CreateIndex
CREATE INDEX "account_recovery_events_case_id_created_at_idx" ON "account_recovery_events"("case_id", "created_at");

-- AddForeignKey
ALTER TABLE "phone_change_requests" ADD CONSTRAINT "phone_change_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "account_recovery_cases" ADD CONSTRAINT "account_recovery_cases_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "account_recovery_events" ADD CONSTRAINT "account_recovery_events_case_id_fkey" FOREIGN KEY ("case_id") REFERENCES "account_recovery_cases"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "account_recovery_events" ADD CONSTRAINT "account_recovery_events_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Backfill: every account that already carries a password had one set at some
-- point we did not record. Dating it from `created_at` is the honest floor —
-- it says "since at least then" rather than inventing a moment — and it keeps
-- `password_set_at IS NULL` meaning exactly one thing: no password.
UPDATE "users"
SET "password_set_at" = "created_at"
WHERE "password_hash" IS NOT NULL AND "password_set_at" IS NULL;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '4fdf1adc0de36720914956d34755a23cffeeae3a019b7fc52586cc6284745e47', now(), '20260822230245_identity_v2_recovery_phone_change', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260822230245_identity_v2_recovery_phone_change');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
