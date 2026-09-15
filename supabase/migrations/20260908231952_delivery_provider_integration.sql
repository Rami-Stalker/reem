-- GENERATED from backend/prisma/migrations/20260908231952_delivery_provider_integration/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 3d1d23cdb4a1d14862a3a4ed1becc5999d0057b7e841c104297649d1745a02ca

SET search_path = public, extensions;


-- CreateEnum
CREATE TYPE "DeliveryProviderKind" AS ENUM ('INTERNAL', 'EXTERNAL_API', 'MANUAL');

-- CreateEnum
CREATE TYPE "WebhookAuthScheme" AS ENUM ('HMAC_SHA256', 'SHARED_SECRET', 'NONE');

-- CreateTable
CREATE TABLE "delivery_provider_accounts" (
    "id" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "display_name" TEXT NOT NULL,
    "kind" "DeliveryProviderKind" NOT NULL DEFAULT 'EXTERNAL_API',
    "is_enabled" BOOLEAN NOT NULL DEFAULT false,
    "is_default" BOOLEAN NOT NULL DEFAULT false,
    "priority" INTEGER NOT NULL DEFAULT 100,
    "governorates" TEXT[],
    "supports_quote" BOOLEAN NOT NULL DEFAULT false,
    "supports_cancel" BOOLEAN NOT NULL DEFAULT false,
    "supports_tracking" BOOLEAN NOT NULL DEFAULT false,
    "supports_webhook" BOOLEAN NOT NULL DEFAULT false,
    "webhook_auth" "WebhookAuthScheme" NOT NULL DEFAULT 'HMAC_SHA256',
    "webhook_signature_header" TEXT,
    "config" JSONB,
    "credential_env_keys" JSONB,
    "courier_id" UUID,
    "last_healthy_at" TIMESTAMP(3),
    "last_error_at" TIMESTAMP(3),
    "last_error" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "delivery_provider_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "delivery_dispatches" (
    "id" UUID NOT NULL,
    "shipment_id" UUID NOT NULL,
    "provider_id" UUID NOT NULL,
    "provider_code" TEXT NOT NULL,
    "status" "ShipmentStatus" NOT NULL DEFAULT 'CREATED',
    "provider_status" TEXT,
    "external_delivery_id" TEXT,
    "tracking_number" TEXT,
    "tracking_url" TEXT,
    "label_url" TEXT,
    "fee_amount" DECIMAL(18,4),
    "fee_currency" "Currency",
    "idempotency_key" TEXT NOT NULL,
    "requested_at" TIMESTAMP(3),
    "assigned_at" TIMESTAMP(3),
    "picked_up_at" TIMESTAMP(3),
    "delivered_at" TIMESTAMP(3),
    "cancelled_at" TIMESTAMP(3),
    "returned_at" TIMESTAMP(3),
    "failure_reason" "DeliveryFailureReason",
    "failure_note" TEXT,
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "cancel_reason" TEXT,
    "last_error" TEXT,
    "last_synced_at" TIMESTAMP(3),
    "last_request" JSONB,
    "last_response" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "delivery_dispatches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "delivery_webhook_events" (
    "id" UUID NOT NULL,
    "provider_code" TEXT NOT NULL,
    "external_event_id" TEXT,
    "dispatch_id" UUID,
    "external_delivery_id" TEXT,
    "signature_valid" BOOLEAN NOT NULL DEFAULT false,
    "status" "ShipmentStatus",
    "provider_status" TEXT,
    "payload" JSONB NOT NULL,
    "error" TEXT,
    "received_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "processed_at" TIMESTAMP(3),

    CONSTRAINT "delivery_webhook_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "delivery_provider_accounts_code_key" ON "delivery_provider_accounts"("code");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_provider_accounts_courier_id_key" ON "delivery_provider_accounts"("courier_id");

-- CreateIndex
CREATE INDEX "delivery_provider_accounts_is_enabled_priority_idx" ON "delivery_provider_accounts"("is_enabled", "priority");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_dispatches_shipment_id_key" ON "delivery_dispatches"("shipment_id");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_dispatches_idempotency_key_key" ON "delivery_dispatches"("idempotency_key");

-- CreateIndex
CREATE INDEX "delivery_dispatches_provider_code_status_idx" ON "delivery_dispatches"("provider_code", "status");

-- CreateIndex
CREATE INDEX "delivery_dispatches_tracking_number_idx" ON "delivery_dispatches"("tracking_number");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_dispatches_provider_id_external_delivery_id_key" ON "delivery_dispatches"("provider_id", "external_delivery_id");

-- CreateIndex
CREATE INDEX "delivery_webhook_events_dispatch_id_received_at_idx" ON "delivery_webhook_events"("dispatch_id", "received_at");

-- CreateIndex
CREATE UNIQUE INDEX "delivery_webhook_events_provider_code_external_event_id_key" ON "delivery_webhook_events"("provider_code", "external_event_id");

-- AddForeignKey
ALTER TABLE "delivery_provider_accounts" ADD CONSTRAINT "delivery_provider_accounts_courier_id_fkey" FOREIGN KEY ("courier_id") REFERENCES "couriers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "delivery_dispatches" ADD CONSTRAINT "delivery_dispatches_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "shipments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "delivery_dispatches" ADD CONSTRAINT "delivery_dispatches_provider_id_fkey" FOREIGN KEY ("provider_id") REFERENCES "delivery_provider_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "delivery_webhook_events" ADD CONSTRAINT "delivery_webhook_events_dispatch_id_fkey" FOREIGN KEY ("dispatch_id") REFERENCES "delivery_dispatches"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '3d1d23cdb4a1d14862a3a4ed1becc5999d0057b7e841c104297649d1745a02ca', now(), '20260908231952_delivery_provider_integration', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908231952_delivery_provider_integration');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
