-- GENERATED from backend/prisma/migrations/20260909160000_review_integrity/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 983f93909ba5dc7c14b63b7442177b1ec526fb3a332a5992c1eb57489ab8f620

SET search_path = public, extensions;


-- One voice per customer, enforced where it cannot be raced.
--
-- The unique key on reviews was `(product_id, user_id, order_id)`, and
-- PostgreSQL treats NULLs as *distinct* in a unique index. An unverified
-- review carries no order, so `order_id` was NULL, so the key never matched
-- itself: one account could write the same product any number of times. The
-- service checked for an existing row first, but a check followed by an insert
-- is two moments -- two concurrent requests both found nothing and both wrote.
--
-- The order comes out of the key entirely. A customer who bought the same
-- dress twice gets one review of it, which is the honest reading: her opinion
-- of the garment is one opinion, not one per receipt.
--
-- Verified safe before writing: zero duplicate (product_id, user_id) and zero
-- duplicate (seller_id, user_id) rows exist.

DROP INDEX IF EXISTS "product_reviews_product_id_user_id_order_id_key";
CREATE UNIQUE INDEX IF NOT EXISTS "product_reviews_product_id_user_id_key"
  ON "product_reviews" ("product_id", "user_id");

DROP INDEX IF EXISTS "seller_reviews_seller_id_user_id_order_id_key";
CREATE UNIQUE INDEX IF NOT EXISTS "seller_reviews_seller_id_user_id_key"
  ON "seller_reviews" ("seller_id", "user_id");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '983f93909ba5dc7c14b63b7442177b1ec526fb3a332a5992c1eb57489ab8f620', now(), '20260909160000_review_integrity', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260909160000_review_integrity');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
