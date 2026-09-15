-- GENERATED from backend/prisma/migrations/20260902000526_offer_price_syp/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: d8c0cd469ca1d1367de2f02b22d7a221e23ba67c5f0fda4a2b57872acfaa97c1

SET search_path = public, extensions;


-- AlterTable
ALTER TABLE "seller_offers" ADD COLUMN     "price_syp" DECIMAL(18,4);

-- CreateIndex
CREATE INDEX "seller_offers_product_id_status_price_syp_idx" ON "seller_offers"("product_id", "status", "price_syp");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'd8c0cd469ca1d1367de2f02b22d7a221e23ba67c5f0fda4a2b57872acfaa97c1', now(), '20260902000526_offer_price_syp', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260902000526_offer_price_syp');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
