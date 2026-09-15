-- GENERATED from backend/prisma/migrations/20260821203000_ledger_owner_key/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 5d522a181255fde6cb9851b35e94f7cb6b6c66b0b5ad0062f2de524248404a0e

SET search_path = public, extensions;


-- Uniqueness for ledger accounts moves off the nullable `owner_id`.
--
-- PostgreSQL treats NULLs as distinct in a unique index, so a unique on
-- (code, owner_id, currency) admits any number of platform-account rows —
-- every one of them NULL-owned and therefore "different". The balance for
-- PLATFORM_CASH would then split silently across duplicates.
--
-- `owner_key` is the same value with no NULLs: the owner's uuid, or the
-- literal 'platform'. `owner_id` stays as the foreign key.

DROP INDEX "ledger_accounts_code_owner_id_currency_key";

ALTER TABLE "ledger_accounts"
  ADD COLUMN "owner_key" TEXT NOT NULL DEFAULT 'platform';

-- Existing rows (none at the time of writing) take their owner or the sentinel.
UPDATE "ledger_accounts" SET "owner_key" = COALESCE("owner_id"::text, 'platform');

-- The default was only there to fill existing rows; the app always supplies it.
ALTER TABLE "ledger_accounts" ALTER COLUMN "owner_key" DROP DEFAULT;

CREATE UNIQUE INDEX "ledger_accounts_code_owner_key_currency_key"
  ON "ledger_accounts"("code", "owner_key", "currency");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '5d522a181255fde6cb9851b35e94f7cb6b6c66b0b5ad0062f2de524248404a0e', now(), '20260821203000_ledger_owner_key', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260821203000_ledger_owner_key');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
