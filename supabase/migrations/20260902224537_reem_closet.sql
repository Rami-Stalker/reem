-- GENERATED from backend/prisma/migrations/20260902224537_reem_closet/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: d5c9ba710a56234c7c4e09f6aee5aa623f7aa1fe2ff1016f0479682490b1cd89

SET search_path = public, extensions;


-- ═══════════════════════════ Reem Closet ═══════════════════════════
--
-- Seven tables and five enums: the wardrobe layer. `closet_items` is the one
-- that matters — a garment she bought here and one she already owned are the
-- same row, distinguished only by which optional columns are filled in. See the
-- section comment in schema.prisma.
--
-- Purely additive. Nothing existing is dropped, renamed or backfilled, so this
-- deploys against a live database without a window.

-- CreateEnum
CREATE TYPE "ClosetItemSource" AS ENUM ('CATALOG', 'PURCHASE', 'PERSONAL');

-- CreateEnum
CREATE TYPE "ClosetItemStatus" AS ENUM ('ACTIVE', 'ARCHIVED', 'RELEASED');

-- CreateEnum
CREATE TYPE "ClosetSeason" AS ENUM ('ALL', 'SUMMER', 'WINTER', 'TRANSITIONAL');

-- CreateEnum
CREATE TYPE "ClosetGapKind" AS ENUM ('LOOK_SLOT', 'OCCASION', 'COVERAGE', 'SEASON', 'REPLACEMENT');

-- CreateEnum
CREATE TYPE "ClosetGapStatus" AS ENUM ('OPEN', 'FILLED', 'DISMISSED', 'STALE');

-- AlterTable
--
-- Nothing to do with the closet. `20260902165900_rounding_policy_nearest_10`
-- changed the default in schema.prisma without emitting the DDL for it, so the
-- column default has been drifting from the declared schema ever since and
-- Prisma folded the correction into the next migration to be generated — this
-- one. Kept rather than deleted: removing it leaves the drift in place and hands
-- the same stray statement to whoever writes the next migration.
ALTER TABLE "orders" ALTER COLUMN "rounding_policy" SET DEFAULT 'NEAREST_10';

-- CreateTable
CREATE TABLE "closets" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "auto_add_purchases" BOOLEAN NOT NULL DEFAULT true,
    "suggestions_enabled" BOOLEAN NOT NULL DEFAULT true,
    "items_count" INTEGER NOT NULL DEFAULT 0,
    "looks_count" INTEGER NOT NULL DEFAULT 0,
    "gaps_computed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "closets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "closet_items" (
    "id" UUID NOT NULL,
    "closet_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "source" "ClosetItemSource" NOT NULL,
    "status" "ClosetItemStatus" NOT NULL DEFAULT 'ACTIVE',
    "product_id" UUID,
    "offer_id" UUID,
    "variant_id" UUID,
    "order_item_id" UUID,
    "title" TEXT NOT NULL,
    "image_url" TEXT,
    "blur_hash" TEXT,
    "slot" "OutfitSlot" NOT NULL,
    "colours" TEXT[],
    "materials" TEXT[],
    "modesty" "ModestyLevel" NOT NULL DEFAULT 'UNSPECIFIED',
    "seasons" "ClosetSeason"[],
    "occasions" TEXT[],
    "size" TEXT,
    "brand_id" UUID,
    "brand_name" TEXT,
    "purchase_price_syp" DECIMAL(18,4),
    "acquired_at" TIMESTAMP(3),
    "wear_count" INTEGER NOT NULL DEFAULT 0,
    "last_worn_at" TIMESTAMP(3),
    "is_favourite" BOOLEAN NOT NULL DEFAULT false,
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "closet_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "closet_item_wears" (
    "id" UUID NOT NULL,
    "item_id" UUID NOT NULL,
    "look_wear_id" UUID,
    "worn_on" DATE NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "closet_item_wears_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "closet_looks" (
    "id" UUID NOT NULL,
    "closet_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "note" TEXT,
    "occasion" TEXT,
    "seasons" "ClosetSeason"[],
    "palette" TEXT[],
    "source_outfit_id" UUID,
    "is_complete" BOOLEAN NOT NULL DEFAULT false,
    "is_favourite" BOOLEAN NOT NULL DEFAULT false,
    "is_archived" BOOLEAN NOT NULL DEFAULT false,
    "wear_count" INTEGER NOT NULL DEFAULT 0,
    "last_worn_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "closet_looks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "closet_look_items" (
    "id" UUID NOT NULL,
    "look_id" UUID NOT NULL,
    "slot" "OutfitSlot" NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "closet_item_id" UUID,
    "product_id" UUID,
    "offer_id" UUID,
    "variant_id" UUID,
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "closet_look_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "closet_look_wears" (
    "id" UUID NOT NULL,
    "look_id" UUID NOT NULL,
    "worn_on" DATE NOT NULL,
    "occasion_note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "closet_look_wears_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "closet_gaps" (
    "id" UUID NOT NULL,
    "closet_id" UUID NOT NULL,
    "kind" "ClosetGapKind" NOT NULL,
    "status" "ClosetGapStatus" NOT NULL DEFAULT 'OPEN',
    "fingerprint" TEXT NOT NULL,
    "slot" "OutfitSlot" NOT NULL,
    "occasion" TEXT,
    "season" "ClosetSeason",
    "look_id" UUID,
    "priority" DOUBLE PRECISION NOT NULL,
    "components" JSONB,
    "suggested_colours" TEXT[],
    "suggested_size" TEXT,
    "suggested_budget_min_syp" DECIMAL(18,4),
    "suggested_budget_max_syp" DECIMAL(18,4),
    "filled_by_item_id" UUID,
    "filled_at" TIMESTAMP(3),
    "dismissed_at" TIMESTAMP(3),
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "closet_gaps_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "closets_user_id_key" ON "closets"("user_id");

-- CreateIndex
CREATE UNIQUE INDEX "closet_items_order_item_id_key" ON "closet_items"("order_item_id");

-- CreateIndex
CREATE INDEX "closet_items_closet_id_status_slot_created_at_idx" ON "closet_items"("closet_id", "status", "slot", "created_at");

-- CreateIndex
CREATE INDEX "closet_items_user_id_status_slot_idx" ON "closet_items"("user_id", "status", "slot");

-- CreateIndex
CREATE INDEX "closet_items_product_id_idx" ON "closet_items"("product_id");

-- CreateIndex
CREATE INDEX "closet_items_closet_id_last_worn_at_idx" ON "closet_items"("closet_id", "last_worn_at");

-- CreateIndex
CREATE INDEX "closet_item_wears_item_id_worn_on_idx" ON "closet_item_wears"("item_id", "worn_on");

-- CreateIndex
CREATE UNIQUE INDEX "closet_item_wears_item_id_worn_on_key" ON "closet_item_wears"("item_id", "worn_on");

-- CreateIndex
CREATE INDEX "closet_looks_closet_id_is_archived_updated_at_idx" ON "closet_looks"("closet_id", "is_archived", "updated_at");

-- CreateIndex
CREATE INDEX "closet_looks_closet_id_occasion_is_complete_idx" ON "closet_looks"("closet_id", "occasion", "is_complete");

-- CreateIndex
CREATE INDEX "closet_looks_user_id_last_worn_at_idx" ON "closet_looks"("user_id", "last_worn_at");

-- CreateIndex
CREATE INDEX "closet_look_items_closet_item_id_idx" ON "closet_look_items"("closet_item_id");

-- CreateIndex
CREATE INDEX "closet_look_items_product_id_idx" ON "closet_look_items"("product_id");

-- CreateIndex
CREATE UNIQUE INDEX "closet_look_items_look_id_slot_key" ON "closet_look_items"("look_id", "slot");

-- CreateIndex
CREATE INDEX "closet_look_wears_look_id_worn_on_idx" ON "closet_look_wears"("look_id", "worn_on");

-- CreateIndex
CREATE UNIQUE INDEX "closet_look_wears_look_id_worn_on_key" ON "closet_look_wears"("look_id", "worn_on");

-- CreateIndex
CREATE INDEX "closet_gaps_closet_id_status_priority_idx" ON "closet_gaps"("closet_id", "status", "priority");

-- CreateIndex
CREATE INDEX "closet_gaps_look_id_idx" ON "closet_gaps"("look_id");

-- CreateIndex
CREATE UNIQUE INDEX "closet_gaps_closet_id_fingerprint_key" ON "closet_gaps"("closet_id", "fingerprint");

-- AddForeignKey
ALTER TABLE "closets" ADD CONSTRAINT "closets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_items" ADD CONSTRAINT "closet_items_closet_id_fkey" FOREIGN KEY ("closet_id") REFERENCES "closets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_items" ADD CONSTRAINT "closet_items_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_items" ADD CONSTRAINT "closet_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_items" ADD CONSTRAINT "closet_items_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_items" ADD CONSTRAINT "closet_items_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "product_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_items" ADD CONSTRAINT "closet_items_order_item_id_fkey" FOREIGN KEY ("order_item_id") REFERENCES "order_items"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_items" ADD CONSTRAINT "closet_items_brand_id_fkey" FOREIGN KEY ("brand_id") REFERENCES "brands"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_item_wears" ADD CONSTRAINT "closet_item_wears_item_id_fkey" FOREIGN KEY ("item_id") REFERENCES "closet_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_item_wears" ADD CONSTRAINT "closet_item_wears_look_wear_id_fkey" FOREIGN KEY ("look_wear_id") REFERENCES "closet_look_wears"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_looks" ADD CONSTRAINT "closet_looks_closet_id_fkey" FOREIGN KEY ("closet_id") REFERENCES "closets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_looks" ADD CONSTRAINT "closet_looks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_looks" ADD CONSTRAINT "closet_looks_source_outfit_id_fkey" FOREIGN KEY ("source_outfit_id") REFERENCES "ai_stylist_outfits"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_look_items" ADD CONSTRAINT "closet_look_items_look_id_fkey" FOREIGN KEY ("look_id") REFERENCES "closet_looks"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_look_items" ADD CONSTRAINT "closet_look_items_closet_item_id_fkey" FOREIGN KEY ("closet_item_id") REFERENCES "closet_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_look_items" ADD CONSTRAINT "closet_look_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_look_wears" ADD CONSTRAINT "closet_look_wears_look_id_fkey" FOREIGN KEY ("look_id") REFERENCES "closet_looks"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_gaps" ADD CONSTRAINT "closet_gaps_closet_id_fkey" FOREIGN KEY ("closet_id") REFERENCES "closets"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_gaps" ADD CONSTRAINT "closet_gaps_look_id_fkey" FOREIGN KEY ("look_id") REFERENCES "closet_looks"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "closet_gaps" ADD CONSTRAINT "closet_gaps_filled_by_item_id_fkey" FOREIGN KEY ("filled_by_item_id") REFERENCES "closet_items"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'd5c9ba710a56234c7c4e09f6aee5aa623f7aa1fe2ff1016f0479682490b1cd89', now(), '20260902224537_reem_closet', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260902224537_reem_closet');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
