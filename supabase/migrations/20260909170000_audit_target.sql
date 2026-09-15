-- GENERATED from backend/prisma/migrations/20260909170000_audit_target/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 0ab4f08eb4c5fe4e29df20412a9eb2242b498b3a1af0ba18551711e4495eb3ad

SET search_path = public, extensions;


-- The audit trail can now be asked about a record rather than only about a
-- person.
--
-- `audit_logs` recorded the actor, the action and the time, and put the thing
-- acted upon inside an unindexed JSON blob -- if it recorded it at all. So the
-- question actually asked after an incident, "show me everything that happened
-- to this order", or to this seller, or to this payout, had no answer. Two
-- columns and one index make it a query.

ALTER TABLE "audit_logs" ADD COLUMN IF NOT EXISTS "target_type" TEXT;
ALTER TABLE "audit_logs" ADD COLUMN IF NOT EXISTS "target_id" TEXT;

CREATE INDEX IF NOT EXISTS "audit_logs_target_type_target_id_created_at_idx"
  ON "audit_logs" ("target_type", "target_id", "created_at");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '0ab4f08eb4c5fe4e29df20412a9eb2242b498b3a1af0ba18551711e4495eb3ad', now(), '20260909170000_audit_target', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260909170000_audit_target');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
