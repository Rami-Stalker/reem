-- GENERATED from backend/prisma/migrations/20260908100000_trust_signals/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: e97ad905d93acb243c0bb151ba1a22e646221327086733219c0796d39c198d06

SET search_path = public, extensions;


-- Readings the trust engine took, and what a person did about them.
--
-- Fake reviews, rating manipulation, refund abuse and multiple accounts were
-- all confirmed absent by the phase-one audit — not partly wired, not behind a
-- flag: nothing anywhere looked for any of them. A marketplace whose review
-- score cannot be trusted is one whose ranking, whose seller reputation and
-- whose recommendation engine are all quietly reading a corrupted signal.
--
-- One table for all three subjects, because the console works them the same
-- way: a score, the evidence behind it, a decision. Three tables would mean
-- three queues, and nobody opens the third.
--
-- The unique key on (subject, subject_id) is what keeps this a queue rather
-- than a log: a nightly sweep updates the reading a subject already has
-- instead of stacking a fresh flag every night until the same twelve cases
-- fill ten thousand rows.
-- CreateEnum
CREATE TYPE "TrustSubject" AS ENUM ('REVIEW', 'CUSTOMER_REFUNDS', 'CUSTOMER_IDENTITY');

-- CreateEnum
CREATE TYPE "TrustBand" AS ENUM ('CLEAR', 'WATCH', 'SUSPECT');

-- CreateEnum
CREATE TYPE "TrustSignalStatus" AS ENUM ('OPEN', 'CONFIRMED', 'DISMISSED');

-- CreateTable
CREATE TABLE "trust_signals" (
    "id" UUID NOT NULL,
    "subject" "TrustSubject" NOT NULL,
    "subject_id" UUID NOT NULL,
    "score" DOUBLE PRECISION NOT NULL,
    "band" "TrustBand" NOT NULL,
    "reasons" JSONB NOT NULL,
    "status" "TrustSignalStatus" NOT NULL DEFAULT 'OPEN',
    "note" TEXT,
    "resolved_by_id" UUID,
    "resolved_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "trust_signals_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "trust_signals_status_band_score_idx" ON "trust_signals"("status", "band", "score");

-- CreateIndex
CREATE INDEX "trust_signals_subject_band_idx" ON "trust_signals"("subject", "band");

-- CreateIndex
CREATE INDEX "trust_signals_resolved_by_id_idx" ON "trust_signals"("resolved_by_id");

-- CreateIndex
CREATE UNIQUE INDEX "trust_signals_subject_subject_id_key" ON "trust_signals"("subject", "subject_id");

-- AddForeignKey
ALTER TABLE "trust_signals" ADD CONSTRAINT "trust_signals_resolved_by_id_fkey" FOREIGN KEY ("resolved_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'e97ad905d93acb243c0bb151ba1a22e646221327086733219c0796d39c198d06', now(), '20260908100000_trust_signals', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908100000_trust_signals');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
