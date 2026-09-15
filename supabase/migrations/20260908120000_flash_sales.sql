-- GENERATED from backend/prisma/migrations/20260908120000_flash_sales/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 328b19c2ded3f0334de81c8290fb9ab09ea152797d614b57fd09be64928ccea9

SET search_path = public, extensions;


-- Flash sales: a window in which some listings are cheaper.
--
-- Confirmed absent by the audit. The only discount the platform could express
-- was a coupon, and a coupon is the wrong shape for this: it is something a
-- customer *has*, needing a code she types, invisible until she reaches a
-- basket. A flash sale is something a listing *is* — no code, everyone, and
-- shown on the card.
--
-- Two decisions worth stating, because both are places this goes wrong.
--
-- The sale price is absolute, not a percentage. A percentage recomputed at
-- checkout can disagree with the figure printed on the card if the seller
-- edited her price in between, and the figure on the card is the one the
-- customer agreed to.
--
-- `quantity_cap` is claimed the way stock is — conditionally, inside the
-- checkout transaction — for the same reason stock is. A doorbuster whose cap
-- is checked before the transaction and decremented inside it sells the whole
-- shelf at a loss to whoever arrives together, which is precisely the defect
-- this release fixed for stock, coupons and points.
-- CreateEnum
CREATE TYPE "FlashSaleStatus" AS ENUM ('DRAFT', 'ACTIVE', 'PAUSED', 'ENDED');

-- CreateTable
CREATE TABLE "flash_sales" (
    "id" UUID NOT NULL,
    "title" TEXT NOT NULL,
    "note" TEXT,
    "status" "FlashSaleStatus" NOT NULL DEFAULT 'DRAFT',
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3) NOT NULL,
    "seller_id" UUID,
    "created_by_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "flash_sales_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "flash_sale_items" (
    "id" UUID NOT NULL,
    "sale_id" UUID NOT NULL,
    "offer_id" UUID NOT NULL,
    "sale_price" DECIMAL(18,4) NOT NULL,
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "compare_at_price" DECIMAL(18,4) NOT NULL,
    "quantity_cap" INTEGER,
    "quantity_sold" INTEGER NOT NULL DEFAULT 0,
    "funded_by_seller" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "flash_sale_items_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "flash_sales_status_starts_at_ends_at_idx" ON "flash_sales"("status", "starts_at", "ends_at");

-- CreateIndex
CREATE INDEX "flash_sales_seller_id_status_idx" ON "flash_sales"("seller_id", "status");

-- CreateIndex
CREATE INDEX "flash_sales_created_by_id_idx" ON "flash_sales"("created_by_id");

-- CreateIndex
CREATE INDEX "flash_sale_items_offer_id_idx" ON "flash_sale_items"("offer_id");

-- CreateIndex
CREATE UNIQUE INDEX "flash_sale_items_sale_id_offer_id_key" ON "flash_sale_items"("sale_id", "offer_id");

-- AddForeignKey
ALTER TABLE "flash_sales" ADD CONSTRAINT "flash_sales_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "flash_sales" ADD CONSTRAINT "flash_sales_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "flash_sale_items" ADD CONSTRAINT "flash_sale_items_sale_id_fkey" FOREIGN KEY ("sale_id") REFERENCES "flash_sales"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "flash_sale_items" ADD CONSTRAINT "flash_sale_items_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '328b19c2ded3f0334de81c8290fb9ab09ea152797d614b57fd09be64928ccea9', now(), '20260908120000_flash_sales', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908120000_flash_sales');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
