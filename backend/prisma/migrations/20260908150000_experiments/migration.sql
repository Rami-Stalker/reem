-- A/B testing: a change tried on some customers and not others.
--
-- Confirmed absent by the audit. Every ranking weight, every piece of copy and
-- every layout decision in the platform had been made by argument rather than
-- by measurement, because there was no way to measure one.
--
-- Assignment is computed from a hash rather than stored, so the same woman
-- sees the same variant on her phone and her sister's laptop with no lookup,
-- and a busy experiment costs nothing on the read path. What is stored is what
-- was *shown* and what happened after — a different question from what was
-- assigned. Counting assignments as exposures is the commonest way an
-- experiment reports a result it never measured: a variant behind a screen
-- nobody reached has no data, and averaging it in makes the other one look
-- worse than it is.
--
-- The unique key on (experiment, subject, kind, metric) makes both halves
-- idempotent. A screen that renders twice is one exposure; a customer who
-- reloads her confirmation page converts once.
-- CreateEnum
CREATE TYPE "ExperimentStatus" AS ENUM ('DRAFT', 'RUNNING', 'STOPPED');

-- CreateEnum
CREATE TYPE "ExperimentEventKind" AS ENUM ('EXPOSURE', 'CONVERSION');

-- CreateTable
CREATE TABLE "experiments" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "name" TEXT NOT NULL,
    "hypothesis" TEXT,
    "status" "ExperimentStatus" NOT NULL DEFAULT 'DRAFT',
    "variants" JSONB NOT NULL,
    "metric" TEXT NOT NULL,
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3),
    "created_by_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "experiments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "experiment_events" (
    "id" UUID NOT NULL,
    "experiment_id" UUID NOT NULL,
    "subject_key" TEXT NOT NULL,
    "variant" TEXT NOT NULL,
    "kind" "ExperimentEventKind" NOT NULL,
    "metric" TEXT,
    "value" DECIMAL(18,4),
    "currency" "Currency",
    "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "experiment_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "experiments_key_key" ON "experiments"("key");

-- CreateIndex
CREATE INDEX "experiments_status_starts_at_idx" ON "experiments"("status", "starts_at");

-- CreateIndex
CREATE INDEX "experiments_created_by_id_idx" ON "experiments"("created_by_id");

-- CreateIndex
CREATE INDEX "experiment_events_experiment_id_variant_kind_idx" ON "experiment_events"("experiment_id", "variant", "kind");

-- CreateIndex
CREATE UNIQUE INDEX "experiment_events_experiment_id_subject_key_kind_metric_key" ON "experiment_events"("experiment_id", "subject_key", "kind", "metric");

-- AddForeignKey
ALTER TABLE "experiments" ADD CONSTRAINT "experiments_created_by_id_fkey" FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "experiment_events" ADD CONSTRAINT "experiment_events_experiment_id_fkey" FOREIGN KEY ("experiment_id") REFERENCES "experiments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

