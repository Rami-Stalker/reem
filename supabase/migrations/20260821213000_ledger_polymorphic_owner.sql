-- GENERATED from backend/prisma/migrations/20260821213000_ledger_polymorphic_owner/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: af7bc195aefa7df2e5beb40950f7197fd8c692b728610a41f9c9a33af6b67645

SET search_path = public, extensions;


-- Ledger account ownership is polymorphic.
--
-- Most per-owner accounts belong to a user — a seller's payable, a customer's
-- wallet. `COURIER_CASH_IN_TRANSIT` belongs to a courier, which is a separate
-- table, so pointing it at `owner_id` violated the users foreign key.
--
-- Each owner kind now gets its own nullable foreign key, and the chart of
-- accounts (`chart-of-accounts.ts`) declares which one a code uses. Uniqueness
-- still runs off `owner_key`, which carries whichever id applies.

ALTER TABLE "ledger_accounts" ADD COLUMN "courier_id" UUID;

CREATE INDEX "ledger_accounts_courier_id_code_idx"
  ON "ledger_accounts"("courier_id", "code");

ALTER TABLE "ledger_accounts"
  ADD CONSTRAINT "ledger_accounts_courier_id_fkey"
  FOREIGN KEY ("courier_id") REFERENCES "couriers"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'af7bc195aefa7df2e5beb40950f7197fd8c692b728610a41f9c9a33af6b67645', now(), '20260821213000_ledger_polymorphic_owner', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260821213000_ledger_polymorphic_owner');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
