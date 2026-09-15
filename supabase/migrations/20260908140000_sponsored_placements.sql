-- GENERATED from backend/prisma/migrations/20260908140000_sponsored_placements/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 8c21fdfb6c47f7d829acb9d9960cb1470db5a525781afc30d4efcfd46ee503fe

SET search_path = public, extensions;


-- Sponsored placements: a boutique paying to be surfaced.
--
-- A flat fee for a window, deliberately, rather than an auction or a
-- cost-per-click. An auction needs a bidding engine nobody can tune on a
-- catalogue this size; cost-per-click needs click-fraud defences, and charging
-- real money against a counter a phone can inflate by tapping is how an ad
-- product becomes a liability. A fixed price for a fixed window is billable on
-- the day it starts and auditable afterwards.
--
-- `PROMOTION_REVENUE` is its own account rather than being folded into
-- commission. They are different businesses — one scales with what the
-- marketplace sells, the other with what sellers will pay to be seen — and a
-- take rate that silently mixes them stops answering the question it exists
-- for. The economics report reads both, and says which is which.
--
-- `charge_reference` is unique and null until charged, which is what makes
-- billing idempotent: a promotion that already carries a reference cannot be
-- charged a second time by a retry.
ALTER TYPE "LedgerAccountCode" ADD VALUE IF NOT EXISTS 'PROMOTION_REVENUE';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '8c21fdfb6c47f7d829acb9d9960cb1470db5a525781afc30d4efcfd46ee503fe', now(), '20260908140000_sponsored_placements', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260908140000_sponsored_placements');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
