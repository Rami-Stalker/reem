-- GENERATED from backend/prisma/migrations/20260617093000_realtime_chat_analytics_bi/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: b8f67ad87208991c953bfe5f59eb5a2ff3a19658fbb12a118d9733ebcd8106c0

SET search_path = public, extensions;


-- Enterprise realtime messaging and analytics/BI.

CREATE TYPE "ChatContextType" AS ENUM ('DIRECT', 'PRODUCT', 'ORDER', 'SUPPORT');
CREATE TYPE "ChatParticipantRole" AS ENUM ('BUYER', 'SELLER', 'SUPPORT');
CREATE TYPE "MessageKind" AS ENUM ('TEXT', 'IMAGE', 'VOICE', 'SYSTEM');
CREATE TYPE "MessageDeliveryStatus" AS ENUM ('SENT', 'DELIVERED', 'READ');
CREATE TYPE "PresenceStatus" AS ENUM ('ONLINE', 'AWAY', 'OFFLINE');
CREATE TYPE "ChatReportStatus" AS ENUM ('OPEN', 'REVIEWING', 'RESOLVED', 'DISMISSED');
CREATE TYPE "ChatReportReason" AS ENUM ('SPAM', 'HARASSMENT', 'FRAUD', 'ABUSE', 'OTHER');
CREATE TYPE "AnalyticsEventType" AS ENUM (
  'APP_OPEN',
  'PRODUCT_VIEW',
  'PRODUCT_SEARCH',
  'CART_ADD',
  'CHECKOUT_START',
  'ORDER_PLACED',
  'PAYMENT_SUCCESS',
  'SELLER_VIEW',
  'CAMPAIGN_OPEN',
  'CAMPAIGN_CLICK',
  'CUSTOM'
);
CREATE TYPE "AnalyticsExportFormat" AS ENUM ('PDF', 'EXCEL', 'CSV', 'JSON');

ALTER TABLE "chats"
  ADD COLUMN "type" "ChatContextType" NOT NULL DEFAULT 'DIRECT',
  ADD COLUMN "product_id" UUID,
  ADD COLUMN "order_id" UUID,
  ADD COLUMN "buyer_id" UUID,
  ADD COLUMN "seller_id" UUID,
  ADD COLUMN "title" TEXT,
  ADD COLUMN "metadata" JSONB,
  ADD COLUMN "closed_at" TIMESTAMP(3);

ALTER TABLE "chats"
  ADD CONSTRAINT "chats_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "chats_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "chats_buyer_id_fkey" FOREIGN KEY ("buyer_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "chats_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "chats_buyer_id_seller_id_idx" ON "chats"("buyer_id", "seller_id");
CREATE INDEX "chats_product_id_idx" ON "chats"("product_id");
CREATE INDEX "chats_order_id_idx" ON "chats"("order_id");
CREATE INDEX "chats_type_updated_at_idx" ON "chats"("type", "updated_at");

ALTER TABLE "chat_participants"
  ADD COLUMN "role" "ChatParticipantRole",
  ADD COLUMN "last_read_message_id" UUID,
  ADD COLUMN "last_read_at" TIMESTAMP(3),
  ADD COLUMN "muted_until" TIMESTAMP(3),
  ADD COLUMN "archived_at" TIMESTAMP(3),
  ADD COLUMN "joined_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

CREATE INDEX "chat_participants_user_id_archived_at_idx" ON "chat_participants"("user_id", "archived_at");

ALTER TABLE "messages"
  ADD COLUMN "client_id" TEXT,
  ADD COLUMN "kind" "MessageKind" NOT NULL DEFAULT 'TEXT',
  ADD COLUMN "metadata" JSONB,
  ADD COLUMN "status" "MessageDeliveryStatus" NOT NULL DEFAULT 'SENT',
  ADD COLUMN "delivered_at" TIMESTAMP(3),
  ADD COLUMN "read_at" TIMESTAMP(3),
  ADD COLUMN "edited_at" TIMESTAMP(3),
  ADD COLUMN "deleted_at" TIMESTAMP(3);

CREATE INDEX "messages_sender_id_created_at_idx" ON "messages"("sender_id", "created_at");
CREATE INDEX "messages_kind_idx" ON "messages"("kind");
CREATE INDEX "messages_content_idx" ON "messages"("content");

CREATE TABLE "message_attachments" (
  "id" UUID NOT NULL,
  "message_id" UUID NOT NULL,
  "kind" "MessageKind" NOT NULL,
  "url" TEXT NOT NULL,
  "mime_type" TEXT,
  "file_name" TEXT,
  "size_bytes" INTEGER,
  "width" INTEGER,
  "height" INTEGER,
  "duration_ms" INTEGER,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "message_attachments_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "message_attachments"
  ADD CONSTRAINT "message_attachments_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "message_attachments_message_id_idx" ON "message_attachments"("message_id");

CREATE TABLE "message_read_receipts" (
  "id" UUID NOT NULL,
  "message_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "delivered_at" TIMESTAMP(3),
  "read_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "message_read_receipts_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "message_read_receipts"
  ADD CONSTRAINT "message_read_receipts_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "messages"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "message_read_receipts_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE UNIQUE INDEX "message_read_receipts_message_id_user_id_key" ON "message_read_receipts"("message_id", "user_id");
CREATE INDEX "message_read_receipts_user_id_read_at_idx" ON "message_read_receipts"("user_id", "read_at");

CREATE TABLE "chat_blocks" (
  "id" UUID NOT NULL,
  "blocker_id" UUID NOT NULL,
  "blocked_id" UUID NOT NULL,
  "reason" TEXT,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "chat_blocks_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "chat_blocks"
  ADD CONSTRAINT "chat_blocks_blocker_id_fkey" FOREIGN KEY ("blocker_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "chat_blocks_blocked_id_fkey" FOREIGN KEY ("blocked_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE UNIQUE INDEX "chat_blocks_blocker_id_blocked_id_key" ON "chat_blocks"("blocker_id", "blocked_id");
CREATE INDEX "chat_blocks_blocked_id_idx" ON "chat_blocks"("blocked_id");

CREATE TABLE "chat_reports" (
  "id" UUID NOT NULL,
  "chat_id" UUID NOT NULL,
  "reporter_id" UUID NOT NULL,
  "reported_user_id" UUID NOT NULL,
  "message_id" UUID,
  "reason" "ChatReportReason" NOT NULL DEFAULT 'OTHER',
  "description" TEXT,
  "status" "ChatReportStatus" NOT NULL DEFAULT 'OPEN',
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "resolved_at" TIMESTAMP(3),

  CONSTRAINT "chat_reports_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "chat_reports"
  ADD CONSTRAINT "chat_reports_chat_id_fkey" FOREIGN KEY ("chat_id") REFERENCES "chats"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "chat_reports_reporter_id_fkey" FOREIGN KEY ("reporter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  ADD CONSTRAINT "chat_reports_reported_user_id_fkey" FOREIGN KEY ("reported_user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "chat_reports_chat_id_created_at_idx" ON "chat_reports"("chat_id", "created_at");
CREATE INDEX "chat_reports_reported_user_id_status_idx" ON "chat_reports"("reported_user_id", "status");

CREATE TABLE "user_presence" (
  "id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "status" "PresenceStatus" NOT NULL DEFAULT 'OFFLINE',
  "socket_count" INTEGER NOT NULL DEFAULT 0,
  "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "user_presence_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "user_presence"
  ADD CONSTRAINT "user_presence_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE UNIQUE INDEX "user_presence_user_id_key" ON "user_presence"("user_id");
CREATE INDEX "user_presence_status_last_seen_at_idx" ON "user_presence"("status", "last_seen_at");

CREATE TABLE "analytics_events" (
  "id" UUID NOT NULL,
  "type" "AnalyticsEventType" NOT NULL,
  "user_id" UUID,
  "session_id" TEXT,
  "product_id" UUID,
  "seller_id" UUID,
  "order_id" UUID,
  "source" TEXT,
  "metadata" JSONB,
  "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "analytics_events_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "analytics_events"
  ADD CONSTRAINT "analytics_events_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "analytics_events_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  ADD CONSTRAINT "analytics_events_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

CREATE INDEX "analytics_events_type_occurred_at_idx" ON "analytics_events"("type", "occurred_at");
CREATE INDEX "analytics_events_user_id_occurred_at_idx" ON "analytics_events"("user_id", "occurred_at");
CREATE INDEX "analytics_events_product_id_occurred_at_idx" ON "analytics_events"("product_id", "occurred_at");
CREATE INDEX "analytics_events_seller_id_occurred_at_idx" ON "analytics_events"("seller_id", "occurred_at");
CREATE INDEX "analytics_events_order_id_occurred_at_idx" ON "analytics_events"("order_id", "occurred_at");

CREATE TABLE "analytics_exports" (
  "id" UUID NOT NULL,
  "requested_by" UUID NOT NULL,
  "format" "AnalyticsExportFormat" NOT NULL,
  "report_type" TEXT NOT NULL,
  "filters" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "analytics_exports_pkey" PRIMARY KEY ("id")
);

ALTER TABLE "analytics_exports"
  ADD CONSTRAINT "analytics_exports_requested_by_fkey" FOREIGN KEY ("requested_by") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE INDEX "analytics_exports_requested_by_created_at_idx" ON "analytics_exports"("requested_by", "created_at");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'b8f67ad87208991c953bfe5f59eb5a2ff3a19658fbb12a118d9733ebcd8106c0', now(), '20260617093000_realtime_chat_analytics_bi', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260617093000_realtime_chat_analytics_bi');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
