-- GENERATED from backend/prisma/migrations/20260908140100_promotion_tables/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 6cc2b59cab73eec41963e640fda2691c6a6edbc3725c04273879fa4ba27fba32

SET search_path = public, extensions;


-- CreateEnum
CREATE TYPE "PromotionPlacement" AS ENUM ('SEARCH', 'CATEGORY');

-- CreateEnum
CREATE TYPE "PromotionStatus" AS ENUM ('PENDING', 'ACTIVE', 'PAUSED', 'ENDED', 'UNPAID');

-- CreateTable
CREATE TABLE "product_promotions" (
    "id" UUID NOT NULL,
    "offer_id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "placement" "PromotionPlacement" NOT NULL,
    "fee_amount" DECIMAL(18,4) NOT NULL,
    "fee_currency" "Currency" NOT NULL DEFAULT 'SYP',
    "status" "PromotionStatus" NOT NULL DEFAULT 'PENDING',
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3) NOT NULL,
    "charge_reference" TEXT,
    "charged_at" TIMESTAMP(3),
    "impressions" INTEGER NOT NULL DEFAULT 0,
    "clicks" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "product_promotions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "product_promotions_charge_reference_key" ON "product_promotions"("charge_reference");

-- CreateIndex
CREATE INDEX "product_promotions_status_starts_at_ends_at_idx" ON "product_promotions"("status", "starts_at", "ends_at");

-- CreateIndex
CREATE INDEX "product_promotions_seller_id_status_idx" ON "product_promotions"("seller_id", "status");

-- CreateIndex
CREATE INDEX "product_promotions_offer_id_idx" ON "product_promotions"("offer_id");

-- AddForeignKey
ALTER TABLE "product_promotions" ADD CONSTRAINT "product_promotions_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_promotions" ADD CONSTRAINT "product_promotions_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '6cc2b59cab73eec41963e640fda2691c6a6edbc3725c04273879fa4ba27fba32', now(), '20260908140100_promotion_tables', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908140100_promotion_tables');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
