-- GENERATED from backend/prisma/migrations/20260825212220_product_media_blurhash/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: dd45f8b7f52540d8f8a87197ee56f7b498a221b65b05a91b72d35e922bbd7341

SET search_path = public, extensions;


-- AlterTable
ALTER TABLE "product_media" ADD COLUMN     "blur_hash" TEXT;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'dd45f8b7f52540d8f8a87197ee56f7b498a221b65b05a91b72d35e922bbd7341', now(), '20260825212220_product_media_blurhash', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260825212220_product_media_blurhash');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
