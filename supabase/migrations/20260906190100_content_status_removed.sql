-- GENERATED from backend/prisma/migrations/20260906190100_content_status_removed/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 02e72d77a4023631e3ef7ecfd51e07f7a8035275e965a98ca2886c404e1f3d51

SET search_path = public, extensions;


-- `REMOVED` — a moderator took it down, as distinct from `DELETED`, which is
-- the author changing her mind. Only one of the two is reachable by her.
--
-- This migration does exactly one thing, and that is not tidiness. Postgres
-- will not let a newly added enum value be *used* in the transaction that adds
-- it, and Prisma wraps each migration in a transaction — so a migration that
-- both adds `REMOVED` and writes it fails at runtime with an error that reads
-- like a typo. Keeping it alone makes that impossible.
ALTER TYPE "CommerceContentStatus" ADD VALUE IF NOT EXISTS 'REMOVED';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '02e72d77a4023631e3ef7ecfd51e07f7a8035275e965a98ca2886c404e1f3d51', now(), '20260906190100_content_status_removed', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260906190100_content_status_removed');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
