-- GENERATED from backend/prisma/migrations/20260908170000_notification_category/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 769d1bd993e7ac9a03bc81a3bfee911fab5ce55524f423e299a79dbc410bbe07

SET search_path = public, extensions;


-- Telling the messages she is waiting for from the ones the platform wants.
--
-- Frequency capping is impossible without this distinction, and getting it
-- wrong is worse than not capping: a cap that cannot tell an order update from
-- an offer either throttles the notification she has been refreshing the app
-- for, or fails to throttle the third promotion this week. Both lose her.
--
-- Existing rows default to TRANSACTIONAL, which is what nearly all of them
-- are — order status, payments, returns. Marketing is set explicitly at the
-- one place it originates.
-- CreateEnum
CREATE TYPE "NotificationCategory" AS ENUM ('TRANSACTIONAL', 'MARKETING');

-- AlterTable
ALTER TABLE "notification_deliveries" ADD COLUMN     "category" "NotificationCategory" NOT NULL DEFAULT 'TRANSACTIONAL';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '769d1bd993e7ac9a03bc81a3bfee911fab5ce55524f423e299a79dbc410bbe07', now(), '20260908170000_notification_category', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908170000_notification_category');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
