-- GENERATED from backend/prisma/migrations/20260907010000_social_notification_preferences/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: cb87d5270a04903d4843e961999cd9efd9d539520b0985aaf8f42ec56b41525c

SET search_path = public, extensions;


-- Two preference columns for the social feed.
--
-- `in_app_social` covers likes, comments, reshares and new followers — the
-- feedback loop that makes publishing worth doing.
--
-- `in_app_moderation` names the softer half of moderation news (a report
-- resolved in her favour, a reinstatement). The removal notice itself
-- deliberately ignores it: a woman who muted likes has muted likes, not the
-- news that her page has changed.
ALTER TABLE "notification_preferences"
  ADD COLUMN "in_app_social" BOOLEAN NOT NULL DEFAULT TRUE,
  ADD COLUMN "in_app_moderation" BOOLEAN NOT NULL DEFAULT TRUE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'cb87d5270a04903d4843e961999cd9efd9d539520b0985aaf8f42ec56b41525c', now(), '20260907010000_social_notification_preferences', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260907010000_social_notification_preferences');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
