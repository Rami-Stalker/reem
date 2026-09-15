-- GENERATED from backend/prisma/migrations/20260908235222_delivery_provider_adapter/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 2debe272ed84fac784aca01a1a34cdff5a411b6743e119ef60741a73b2309d1a

SET search_path = public, extensions;


-- The adapter that serves an account, separate from the account's own code:
-- two delivery companies can share one adapter with different configuration.
ALTER TABLE "delivery_provider_accounts" ADD COLUMN "adapter" TEXT NOT NULL DEFAULT 'http_generic';

-- Accounts written before this column existed named their adapter in `code`.
UPDATE "delivery_provider_accounts" SET "adapter" = "code";


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '2debe272ed84fac784aca01a1a34cdff5a411b6743e119ef60741a73b2309d1a', now(), '20260908235222_delivery_provider_adapter', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908235222_delivery_provider_adapter');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
