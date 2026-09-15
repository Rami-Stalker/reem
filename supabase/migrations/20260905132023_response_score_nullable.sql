-- GENERATED from backend/prisma/migrations/20260905132023_response_score_nullable/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 55015fc35a496d880e19f7a89c1832d1da0e1d11309fd4db13a3ed8ec213c88f

SET search_path = public, extensions;


-- AlterTable
ALTER TABLE "seller_reputations" ALTER COLUMN "response_score" DROP NOT NULL,
ALTER COLUMN "response_score" DROP DEFAULT;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '55015fc35a496d880e19f7a89c1832d1da0e1d11309fd4db13a3ed8ec213c88f', now(), '20260905132023_response_score_nullable', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260905132023_response_score_nullable');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
