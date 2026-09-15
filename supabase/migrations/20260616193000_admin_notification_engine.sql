-- GENERATED from backend/prisma/migrations/20260616193000_admin_notification_engine/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 9d144cc78a4ccda795cf989c6f86073a523284b0f077a8bd1bb522ab16f46348

SET search_path = public, extensions;


DO $$ BEGIN CREATE TYPE "NotificationChannel" AS ENUM ('IN_APP', 'PUSH', 'EMAIL', 'SMS'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "NotificationDeliveryStatus" AS ENUM ('QUEUED', 'SENT', 'FAILED', 'SKIPPED', 'CANCELLED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "NotificationCampaignStatus" AS ENUM ('DRAFT', 'SCHEDULED', 'RUNNING', 'COMPLETED', 'CANCELLED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "SupportTicketStatus" AS ENUM ('OPEN', 'PENDING', 'RESOLVED', 'CLOSED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "SupportPriority" AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "ModerationStatus" AS ENUM ('OPEN', 'APPROVED', 'REJECTED', 'ESCALATED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "FinancialLedgerType" AS ENUM ('ORDER_REVENUE', 'COMMISSION', 'REFUND', 'PAYOUT', 'ADJUSTMENT'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "CommissionStatus" AS ENUM ('PENDING', 'EARNED', 'PAID', 'REVERSED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE TYPE "ReportStatus" AS ENUM ('OPEN', 'REVIEWING', 'RESOLVED', 'DISMISSED'); EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS "push_tokens" (
  "id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "token_hash" TEXT NOT NULL,
  "provider" TEXT NOT NULL,
  "platform" TEXT,
  "enabled" BOOLEAN NOT NULL DEFAULT true,
  "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "push_tokens_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "notification_templates" (
  "id" UUID NOT NULL,
  "key" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "channel" "NotificationChannel" NOT NULL,
  "subject" TEXT,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "locale" TEXT NOT NULL DEFAULT 'en',
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "notification_templates_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "notification_campaigns" (
  "id" UUID NOT NULL,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "status" "NotificationCampaignStatus" NOT NULL DEFAULT 'DRAFT',
  "channels" "NotificationChannel"[],
  "segment" JSONB NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "deep_link" TEXT,
  "scheduled_at" TIMESTAMP(3),
  "started_at" TIMESTAMP(3),
  "completed_at" TIMESTAMP(3),
  "created_by" UUID,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "notification_campaigns_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "notification_deliveries" (
  "id" UUID NOT NULL,
  "campaign_id" UUID,
  "notification_id" UUID,
  "user_id" UUID NOT NULL,
  "channel" "NotificationChannel" NOT NULL,
  "status" "NotificationDeliveryStatus" NOT NULL DEFAULT 'QUEUED',
  "provider" TEXT,
  "provider_message_id" TEXT,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "payload" JSONB,
  "scheduled_at" TIMESTAMP(3),
  "sent_at" TIMESTAMP(3),
  "failed_at" TIMESTAMP(3),
  "failure_reason" TEXT,
  "opened_at" TIMESTAMP(3),
  "clicked_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "notification_deliveries_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "notification_events" (
  "id" UUID NOT NULL,
  "delivery_id" UUID NOT NULL,
  "event" TEXT NOT NULL,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "notification_events_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "support_tickets" (
  "id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "subject" TEXT NOT NULL,
  "status" "SupportTicketStatus" NOT NULL DEFAULT 'OPEN',
  "priority" "SupportPriority" NOT NULL DEFAULT 'NORMAL',
  "category" TEXT NOT NULL DEFAULT 'general',
  "assigned_to" UUID,
  "last_message_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "support_tickets_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "support_messages" (
  "id" UUID NOT NULL,
  "ticket_id" UUID NOT NULL,
  "author_id" UUID NOT NULL,
  "body" TEXT NOT NULL,
  "internal" BOOLEAN NOT NULL DEFAULT false,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "support_messages_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "moderation_cases" (
  "id" UUID NOT NULL,
  "target_type" TEXT NOT NULL,
  "target_id" UUID NOT NULL,
  "reporter_id" UUID,
  "reason" TEXT NOT NULL,
  "status" "ModerationStatus" NOT NULL DEFAULT 'OPEN',
  "assigned_to" UUID,
  "resolution" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "moderation_cases_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "financial_ledger_entries" (
  "id" UUID NOT NULL,
  "type" "FinancialLedgerType" NOT NULL,
  "order_id" UUID,
  "seller_id" UUID,
  "user_id" UUID,
  "amount" DOUBLE PRECISION NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'USD',
  "description" TEXT NOT NULL,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "financial_ledger_entries_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "commission_rules" (
  "id" UUID NOT NULL,
  "name" TEXT NOT NULL,
  "rate_bps" INTEGER NOT NULL,
  "category" TEXT,
  "seller_tier" TEXT,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "starts_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "ends_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "commission_rules_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "commission_ledgers" (
  "id" UUID NOT NULL,
  "rule_id" UUID,
  "order_id" UUID,
  "seller_id" UUID NOT NULL,
  "gross" DOUBLE PRECISION NOT NULL,
  "commission" DOUBLE PRECISION NOT NULL,
  "net" DOUBLE PRECISION NOT NULL,
  "status" "CommissionStatus" NOT NULL DEFAULT 'PENDING',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "paid_at" TIMESTAMP(3),
  CONSTRAINT "commission_ledgers_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "admin_reports" (
  "id" UUID NOT NULL,
  "type" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "status" "ReportStatus" NOT NULL DEFAULT 'OPEN',
  "payload" JSONB NOT NULL,
  "created_by" UUID,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "resolved_at" TIMESTAMP(3),
  CONSTRAINT "admin_reports_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "system_settings" (
  "id" UUID NOT NULL,
  "key" TEXT NOT NULL,
  "value" JSONB NOT NULL,
  "sensitive" BOOLEAN NOT NULL DEFAULT false,
  "updated_by" UUID,
  "updated_at" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "system_settings_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "push_tokens_token_hash_key" ON "push_tokens"("token_hash");
CREATE INDEX IF NOT EXISTS "push_tokens_user_id_enabled_idx" ON "push_tokens"("user_id", "enabled");
CREATE UNIQUE INDEX IF NOT EXISTS "notification_templates_key_key" ON "notification_templates"("key");
CREATE INDEX IF NOT EXISTS "notification_templates_channel_idx" ON "notification_templates"("channel");
CREATE INDEX IF NOT EXISTS "notification_campaigns_status_scheduled_at_idx" ON "notification_campaigns"("status", "scheduled_at");
CREATE INDEX IF NOT EXISTS "notification_deliveries_user_id_status_idx" ON "notification_deliveries"("user_id", "status");
CREATE INDEX IF NOT EXISTS "notification_deliveries_campaign_id_idx" ON "notification_deliveries"("campaign_id");
CREATE INDEX IF NOT EXISTS "notification_deliveries_channel_status_idx" ON "notification_deliveries"("channel", "status");
CREATE INDEX IF NOT EXISTS "notification_deliveries_scheduled_at_status_idx" ON "notification_deliveries"("scheduled_at", "status");
CREATE INDEX IF NOT EXISTS "notification_events_delivery_id_event_idx" ON "notification_events"("delivery_id", "event");
CREATE INDEX IF NOT EXISTS "support_tickets_status_priority_idx" ON "support_tickets"("status", "priority");
CREATE INDEX IF NOT EXISTS "support_tickets_user_id_idx" ON "support_tickets"("user_id");
CREATE INDEX IF NOT EXISTS "support_messages_ticket_id_created_at_idx" ON "support_messages"("ticket_id", "created_at");
CREATE INDEX IF NOT EXISTS "moderation_cases_status_target_type_idx" ON "moderation_cases"("status", "target_type");
CREATE INDEX IF NOT EXISTS "financial_ledger_entries_type_created_at_idx" ON "financial_ledger_entries"("type", "created_at");
CREATE INDEX IF NOT EXISTS "financial_ledger_entries_seller_id_idx" ON "financial_ledger_entries"("seller_id");
CREATE INDEX IF NOT EXISTS "commission_rules_active_category_idx" ON "commission_rules"("active", "category");
CREATE INDEX IF NOT EXISTS "commission_ledgers_seller_id_status_idx" ON "commission_ledgers"("seller_id", "status");
CREATE INDEX IF NOT EXISTS "commission_ledgers_order_id_idx" ON "commission_ledgers"("order_id");
CREATE INDEX IF NOT EXISTS "admin_reports_type_status_idx" ON "admin_reports"("type", "status");
CREATE UNIQUE INDEX IF NOT EXISTS "system_settings_key_key" ON "system_settings"("key");

ALTER TABLE "push_tokens" ADD CONSTRAINT "push_tokens_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "notification_deliveries" ADD CONSTRAINT "notification_deliveries_campaign_id_fkey" FOREIGN KEY ("campaign_id") REFERENCES "notification_campaigns"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "notification_deliveries" ADD CONSTRAINT "notification_deliveries_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "notification_events" ADD CONSTRAINT "notification_events_delivery_id_fkey" FOREIGN KEY ("delivery_id") REFERENCES "notification_deliveries"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "support_tickets" ADD CONSTRAINT "support_tickets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "support_messages" ADD CONSTRAINT "support_messages_ticket_id_fkey" FOREIGN KEY ("ticket_id") REFERENCES "support_tickets"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "support_messages" ADD CONSTRAINT "support_messages_author_id_fkey" FOREIGN KEY ("author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "commission_ledgers" ADD CONSTRAINT "commission_ledgers_rule_id_fkey" FOREIGN KEY ("rule_id") REFERENCES "commission_rules"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '9d144cc78a4ccda795cf989c6f86073a523284b0f077a8bd1bb522ab16f46348', now(), '20260616193000_admin_notification_engine', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260616193000_admin_notification_engine');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
