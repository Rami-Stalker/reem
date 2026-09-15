-- GENERATED from backend/prisma/migrations/20260908110000_reengagement/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: af5c3dc1571f65820dcfa0e39cf5db38f9b860fca540bb6c15e9cb632049e8c1

SET search_path = public, extensions;


-- Abandoned baskets and win-back, and the row that stops them becoming spam.
--
-- Neither existed. The notification module could already pick an audience, but
-- only from four facts — a role, a points balance, a verification flag, days
-- since last login — none of which is a commerce fact. Nothing could address
-- "women who left something in a basket last night" or "women who bought twice
-- and then stopped", so neither campaign could be written at all.
--
-- `reengagement_touches` is what makes a reminder a reminder. Without a record
-- of having sent one, the abandoned-basket job re-sends on every run: same
-- woman, same dress, every hour, until she uninstalls. The unique key on
-- (user, kind, reference) is the guarantee, and `reference` is what "once"
-- means in each case — a basket fingerprint that changes when she edits the
-- basket, or the month for a win-back.
--
-- `converted_at` is left null rather than false. "She has not bought yet" and
-- "the message failed" are different claims, and a column that cannot tell
-- them apart makes the first week of any campaign unreadable.
-- CreateEnum
CREATE TYPE "ReengagementKind" AS ENUM ('ABANDONED_CART', 'WIN_BACK');

-- CreateTable
CREATE TABLE "reengagement_touches" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "kind" "ReengagementKind" NOT NULL,
    "reference" TEXT NOT NULL,
    "stage" TEXT,
    "sent_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "converted_at" TIMESTAMP(3),

    CONSTRAINT "reengagement_touches_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "reengagement_touches_kind_sent_at_idx" ON "reengagement_touches"("kind", "sent_at");

-- CreateIndex
CREATE UNIQUE INDEX "reengagement_touches_user_id_kind_reference_key" ON "reengagement_touches"("user_id", "kind", "reference");

-- AddForeignKey
ALTER TABLE "reengagement_touches" ADD CONSTRAINT "reengagement_touches_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'af5c3dc1571f65820dcfa0e39cf5db38f9b860fca540bb6c15e9cb632049e8c1', now(), '20260908110000_reengagement', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908110000_reengagement');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
