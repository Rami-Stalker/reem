-- GENERATED from backend/prisma/migrations/20260902165900_rounding_policy_nearest_10/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: e42dcd0dde00c8f4e8d971fea4a26b54963c472bebb3daa1deef5c33f8823854

SET search_path = public, extensions;


-- The rounding step the new lira needs.
--
-- Postgres will not let a value be added to an enum and used by the same
-- transaction, and Prisma runs each migration in one — so the value arrives
-- here, on its own, and the redenomination that follows can use it.

ALTER TYPE "RoundingPolicy" ADD VALUE IF NOT EXISTS 'NEAREST_10' BEFORE 'NEAREST_100';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'e42dcd0dde00c8f4e8d971fea4a26b54963c472bebb3daa1deef5c33f8823854', now(), '20260902165900_rounding_policy_nearest_10', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260902165900_rounding_policy_nearest_10');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
