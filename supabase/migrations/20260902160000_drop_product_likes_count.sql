-- GENERATED from backend/prisma/migrations/20260902160000_drop_product_likes_count/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 8b287038d8d2985d9921e19d0ad1459d8b83fec5b44b6a2ddee022356043ff00

SET search_path = public, extensions;


-- A product cannot be "liked" on this platform.
--
-- `products.likes_count` had no writer anywhere in the codebase: the heart on
-- a product is a favourite, which is `favorites_count` and has the `favorites`
-- table behind it. The column was seeded with an invented figure and shown on
-- the product page beside two real counters, which is how a shopper ends up
-- doubting all three.

ALTER TABLE "products" DROP COLUMN "likes_count";


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '8b287038d8d2985d9921e19d0ad1459d8b83fec5b44b6a2ddee022356043ff00', now(), '20260902160000_drop_product_likes_count', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260902160000_drop_product_likes_count');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
