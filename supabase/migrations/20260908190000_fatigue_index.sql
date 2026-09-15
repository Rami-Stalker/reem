-- GENERATED from backend/prisma/migrations/20260908190000_fatigue_index/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 594b25cd5514ad1ccd2bb19b9af64930ad16b66bc5fc149438c0b9e83a8487ee

SET search_path = public, extensions;


-- The frequency cap runs on every marketing send.
--
-- It asks one question — how much marketing has this woman had in the last day
-- and the last week — and the existing (user_id, status) index answers it by
-- reading every delivery she has ever had and filtering. Fine at a thousand
-- customers; not fine at the volume the cap exists to protect them from.
CREATE INDEX IF NOT EXISTS "notification_deliveries_user_id_category_sent_at_idx"
  ON "notification_deliveries" ("user_id", "category", "sent_at");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '594b25cd5514ad1ccd2bb19b9af64930ad16b66bc5fc149438c0b9e83a8487ee', now(), '20260908190000_fatigue_index', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908190000_fatigue_index');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
