-- GENERATED from backend/prisma/migrations/20260906021453_drop_messages_content_index/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 31c991fbf45becc95140f36c26aab109ceba076774377d5896c19f14fd96a0ad

SET search_path = public, extensions;


-- DropIndex
DROP INDEX "messages_content_idx";


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '31c991fbf45becc95140f36c26aab109ceba076774377d5896c19f14fd96a0ad', now(), '20260906021453_drop_messages_content_index', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260906021453_drop_messages_content_index');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
