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
