-- GENERATED from backend/prisma/migrations/20260819004334_otp_delivery_subsystem/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: c9fa573a8abdc3368d87fd2c02ea0a4ec6d7127ad485f27c7bbfb311adbf151d

SET search_path = public, extensions;


-- CreateEnum
CREATE TYPE "OtpTransportKind" AS ENUM ('WHATSAPP_CLOUD', 'SMS_GATEWAY', 'VOICE', 'OPS_CONSOLE');

-- CreateEnum
CREATE TYPE "OtpDeliveryStatus" AS ENUM ('QUEUED', 'SENDING', 'SENT', 'DELIVERED', 'FAILED', 'SKIPPED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "OtpOutboxStatus" AS ENUM ('PENDING', 'IN_FLIGHT', 'AWAITING_RECEIPT', 'DELIVERED', 'EXHAUSTED', 'CANCELLED');

-- AlterTable
ALTER TABLE "otp_requests" ADD COLUMN     "client_nonce_hash" TEXT,
ADD COLUMN     "match_code" TEXT;

-- CreateTable
CREATE TABLE "otp_transport_routes" (
    "id" UUID NOT NULL,
    "transport" "OtpTransportKind" NOT NULL,
    "priority" INTEGER NOT NULL DEFAULT 100,
    "enabled" BOOLEAN NOT NULL DEFAULT true,
    "daily_budget_micros" BIGINT,
    "spent_today_micros" BIGINT NOT NULL DEFAULT 0,
    "spent_on" DATE,
    "breaker_tripped_at" TIMESTAMP(3),
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "otp_transport_routes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "otp_outbox" (
    "id" UUID NOT NULL,
    "challenge_id" UUID NOT NULL,
    "sealed_code" TEXT,
    "status" "OtpOutboxStatus" NOT NULL DEFAULT 'PENDING',
    "transport_index" INTEGER NOT NULL DEFAULT 0,
    "attempts" INTEGER NOT NULL DEFAULT 0,
    "next_attempt_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_error" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "otp_outbox_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "challenge_deliveries" (
    "id" UUID NOT NULL,
    "challenge_id" UUID NOT NULL,
    "transport" "OtpTransportKind" NOT NULL,
    "route_id" UUID,
    "status" "OtpDeliveryStatus" NOT NULL DEFAULT 'QUEUED',
    "provider_message_id" TEXT,
    "cost_micros" BIGINT NOT NULL DEFAULT 0,
    "sent_at" TIMESTAMP(3),
    "delivered_at" TIMESTAMP(3),
    "failed_at" TIMESTAMP(3),
    "failure_reason" TEXT,
    "metadata" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "challenge_deliveries_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "otp_transport_routes_transport_key" ON "otp_transport_routes"("transport");

-- CreateIndex
CREATE INDEX "otp_transport_routes_enabled_priority_idx" ON "otp_transport_routes"("enabled", "priority");

-- CreateIndex
CREATE UNIQUE INDEX "otp_outbox_challenge_id_key" ON "otp_outbox"("challenge_id");

-- CreateIndex
CREATE INDEX "otp_outbox_status_next_attempt_at_idx" ON "otp_outbox"("status", "next_attempt_at");

-- CreateIndex
CREATE INDEX "challenge_deliveries_challenge_id_created_at_idx" ON "challenge_deliveries"("challenge_id", "created_at");

-- CreateIndex
CREATE INDEX "challenge_deliveries_transport_created_at_idx" ON "challenge_deliveries"("transport", "created_at");

-- CreateIndex
CREATE INDEX "challenge_deliveries_status_sent_at_idx" ON "challenge_deliveries"("status", "sent_at");

-- CreateIndex
CREATE INDEX "challenge_deliveries_provider_message_id_idx" ON "challenge_deliveries"("provider_message_id");

-- AddForeignKey
ALTER TABLE "otp_outbox" ADD CONSTRAINT "otp_outbox_challenge_id_fkey" FOREIGN KEY ("challenge_id") REFERENCES "otp_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "challenge_deliveries" ADD CONSTRAINT "challenge_deliveries_challenge_id_fkey" FOREIGN KEY ("challenge_id") REFERENCES "otp_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "challenge_deliveries" ADD CONSTRAINT "challenge_deliveries_route_id_fkey" FOREIGN KEY ("route_id") REFERENCES "otp_transport_routes"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'c9fa573a8abdc3368d87fd2c02ea0a4ec6d7127ad485f27c7bbfb311adbf151d', now(), '20260819004334_otp_delivery_subsystem', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260819004334_otp_delivery_subsystem');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
