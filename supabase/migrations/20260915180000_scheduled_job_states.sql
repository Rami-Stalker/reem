-- GENERATED from backend/prisma/migrations/20260915180000_scheduled_job_states/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 291191b778b1459ef2045bb4f34b64b5a0d71542567e9bd5dfa46f730f0244b5

SET search_path = public, extensions;


-- Scheduled job leases and run records.
--
-- Every scheduled job used to rely on "run exactly one API process": two
-- instances — including the old and new container that overlap for a few
-- seconds during every zero-downtime deploy — each ran every sweep. This table
-- is the lease that lets exactly one instance run a job at a time, plus the
-- record the health check reads to say when a job has stopped running.
--
-- Additive only: one new table, nothing existing is touched.

-- CreateTable
CREATE TABLE "scheduled_job_states" (
    "name" VARCHAR(160) NOT NULL,
    "locked_by" VARCHAR(200),
    "locked_until" TIMESTAMP(3),
    "last_started_at" TIMESTAMP(3),
    "last_finished_at" TIMESTAMP(3),
    "last_succeeded_at" TIMESTAMP(3),
    "last_status" VARCHAR(20),
    "last_error" TEXT,
    "last_duration_ms" INTEGER,
    "last_trigger" VARCHAR(20),
    "run_count" INTEGER NOT NULL DEFAULT 0,
    "consecutive_failures" INTEGER NOT NULL DEFAULT 0,
    "updated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "scheduled_job_states_pkey" PRIMARY KEY ("name")
);


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '291191b778b1459ef2045bb4f34b64b5a0d71542567e9bd5dfa46f730f0244b5', now(), '20260915180000_scheduled_job_states', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260915180000_scheduled_job_states');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
