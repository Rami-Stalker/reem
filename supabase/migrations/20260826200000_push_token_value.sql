-- GENERATED from backend/prisma/migrations/20260826200000_push_token_value/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 7fa02b23854ab965d481db56e2a591247bacf9e00291a7519127ca6bd5ee2d9e

SET search_path = public, extensions;


-- A device token is an address, not a secret. Only its hash was kept, which
-- made every push unsendable — the platform could recognise a handset it had
-- seen before and had no way to write to it.
--
-- Existing rows keep their hash and get an empty token; those devices are
-- unreachable until the app registers again, which it does on next launch.
ALTER TABLE "push_tokens" ADD COLUMN "token" TEXT NOT NULL DEFAULT '';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '7fa02b23854ab965d481db56e2a591247bacf9e00291a7519127ca6bd5ee2d9e', now(), '20260826200000_push_token_value', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260826200000_push_token_value');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
