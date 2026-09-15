-- GENERATED from backend/prisma/migrations/20260825124902_media_audio_kind/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 2ddafe9964816af94b94a6f37f51aedc6660e3d24c6aa003c6417676250cf068

SET search_path = public, extensions;


-- AlterEnum
ALTER TYPE "MediaType" ADD VALUE 'audio';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '2ddafe9964816af94b94a6f37f51aedc6660e3d24c6aa003c6417676250cf068', now(), '20260825124902_media_audio_kind', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260825124902_media_audio_kind');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
