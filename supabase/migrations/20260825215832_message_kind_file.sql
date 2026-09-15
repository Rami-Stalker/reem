-- GENERATED from backend/prisma/migrations/20260825215832_message_kind_file/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 1c1dc0c316390d3d4eb9d690c3797d8724f63852cb034d3551ebbdd15ec415c6

SET search_path = public, extensions;


-- AlterEnum
ALTER TYPE "MessageKind" ADD VALUE 'FILE';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '1c1dc0c316390d3d4eb9d690c3797d8724f63852cb034d3551ebbdd15ec415c6', now(), '20260825215832_message_kind_file', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260825215832_message_kind_file');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
