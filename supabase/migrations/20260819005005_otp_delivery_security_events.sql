-- GENERATED from backend/prisma/migrations/20260819005005_otp_delivery_security_events/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: c10aad26ac667e041b0eaabe5bc844a1d8a34b2b8474328a3679fa2a1bef55c5

SET search_path = public, extensions;


-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "SecurityEventType" ADD VALUE 'OTP_ROUTE_CHANGED';
ALTER TYPE "SecurityEventType" ADD VALUE 'OTP_CODE_REVEALED';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'c10aad26ac667e041b0eaabe5bc844a1d8a34b2b8474328a3679fa2a1bef55c5', now(), '20260819005005_otp_delivery_security_events', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260819005005_otp_delivery_security_events');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
