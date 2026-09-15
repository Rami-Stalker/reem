-- GENERATED from backend/prisma/migrations/20260909150000_coupon_scope/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 8e7aa2b3faa8b9c5e61b7f00af72a46347cc2611131866a2407dd12d60e56b13

SET search_path = public, extensions;


-- A coupon now says what it may be spent on.
--
-- `funded_by_seller` recorded that a seller paid for a discount, and nothing
-- recorded *which* seller's goods it applied to. Checkout evaluated every code
-- against the whole basket subtotal and then reduced the commission base of
-- every seller in it, weighted by their share -- so a code one boutique
-- created was paid for, in part, by every other boutique the customer happened
-- to buy from in the same order. They were never told, and there was nothing
-- in the data that would have let anyone notice.
--
-- All three columns null means "the whole basket", which is exactly what every
-- existing coupon meant, so nothing in flight changes behaviour.

ALTER TABLE "coupons" ADD COLUMN IF NOT EXISTS "seller_id" UUID;
ALTER TABLE "coupons" ADD COLUMN IF NOT EXISTS "category_id" UUID;
ALTER TABLE "coupons" ADD COLUMN IF NOT EXISTS "product_id" UUID;

DO $$ BEGIN
  ALTER TABLE "coupons" ADD CONSTRAINT "coupons_seller_id_fkey"
    FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "coupons" ADD CONSTRAINT "coupons_category_id_fkey"
    FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "coupons" ADD CONSTRAINT "coupons_product_id_fkey"
    FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS "coupons_seller_id_idx" ON "coupons" ("seller_id");
CREATE INDEX IF NOT EXISTS "coupons_category_id_idx" ON "coupons" ("category_id");
CREATE INDEX IF NOT EXISTS "coupons_product_id_idx" ON "coupons" ("product_id");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '8e7aa2b3faa8b9c5e61b7f00af72a46347cc2611131866a2407dd12d60e56b13', now(), '20260909150000_coupon_scope', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260909150000_coupon_scope');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
