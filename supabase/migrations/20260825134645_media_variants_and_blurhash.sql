-- GENERATED from backend/prisma/migrations/20260825134645_media_variants_and_blurhash/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 66d68064c083d6fbb801c586f27b957948d1fc89f44d79d3d9da2da8e49e7ff4

SET search_path = public, extensions;


-- AlterTable
ALTER TABLE "media_assets" ADD COLUMN     "blur_hash" TEXT,
ADD COLUMN     "variants" INTEGER[];


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '66d68064c083d6fbb801c586f27b957948d1fc89f44d79d3d9da2da8e49e7ff4', now(), '20260825134645_media_variants_and_blurhash', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260825134645_media_variants_and_blurhash');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
