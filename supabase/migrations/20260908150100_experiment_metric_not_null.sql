-- GENERATED from backend/prisma/migrations/20260908150100_experiment_metric_not_null/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 4b49be3ebd75b66ad944c837279f359f88ed441f075afb713241d7f6ea131c82

SET search_path = public, extensions;


-- The unique key on experiment events was not unique.
--
-- `metric` was nullable and null for every exposure, and PostgreSQL treats
-- NULLs as *distinct* in a unique index — so (experiment, subject, EXPOSURE,
-- NULL) matched nothing and three identical rows sat happily side by side. The
-- "one exposure per screen" guarantee the whole measurement rests on was not a
-- guarantee at all: a component that rendered twice doubled its arm's exposure
-- count and halved its conversion rate.
--
-- Exactly the trap `LedgerAccount.ownerKey` was built to avoid, met again.
-- Same answer: a non-null column with a sentinel, where there are no NULLs to
-- be distinct from each other.
UPDATE "experiment_events" SET "metric" = '' WHERE "metric" IS NULL;
ALTER TABLE "experiment_events" ALTER COLUMN "metric" SET DEFAULT '';
ALTER TABLE "experiment_events" ALTER COLUMN "metric" SET NOT NULL;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '4b49be3ebd75b66ad944c837279f359f88ed441f075afb713241d7f6ea131c82', now(), '20260908150100_experiment_metric_not_null', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908150100_experiment_metric_not_null');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
