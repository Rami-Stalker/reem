-- GENERATED from backend/prisma/migrations/20260909110000_delivery_cost_accounting/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 192c269c9dd489099de98305b9c865ac207c3d704b2b368cafb76787793e4ecb

SET search_path = public, extensions;


-- The cost of carrying a parcel now reaches the books.
--
-- `SHIPPING_EXPENSE` has been in the chart of accounts since the ledger was
-- built, and `EconomicsService` reads it when it computes contribution margin
-- -- but nothing ever wrote to it. The platform booked the delivery fee it
-- charged the customer (`SHIPPING_REVENUE`) and never booked what it paid the
-- carrier, so every margin figure on the admin dashboard was overstated by the
-- entire cost of delivery. `DeliveryDispatch.fee_amount` -- what the carrier
-- told us the journey cost -- was stored, displayed, and posted nowhere.
--
-- Two additions make the entry possible and balanced:
--
--   COURIER_PAYABLE       a liability, one account per carrier. The platform
--                         bears the delivery cost in full (the seller's net is
--                         computed on goods alone), and a courier hands over
--                         the GROSS cash it collected rather than netting its
--                         own fee, so what it is owed has to accrue somewhere.
--
--   DELIVERY_COST_ACCRUED the entry type, kept separate from COMMISSION_EARNED
--                         so a carrier's bill can be posted in the carrier's
--                         own currency and reconciled on its own reference.

ALTER TYPE "LedgerAccountCode" ADD VALUE IF NOT EXISTS 'COURIER_PAYABLE';
ALTER TYPE "JournalEntryType" ADD VALUE IF NOT EXISTS 'DELIVERY_COST_ACCRUED';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '192c269c9dd489099de98305b9c865ac207c3d704b2b368cafb76787793e4ecb', now(), '20260909110000_delivery_cost_accounting', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260909110000_delivery_cost_accounting');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
