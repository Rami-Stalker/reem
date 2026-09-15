-- GENERATED from backend/prisma/migrations/20260909100000_order_expiry/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 4093e33d01be5633472f38e661811d224445a4b9ac64c584a3176c142fc8a96f

SET search_path = public, extensions;


-- An unpaid order now has a deadline.
--
-- Stock comes off the seller's offer inside the checkout transaction, so an
-- order nobody ever pays for is a garment permanently withdrawn from sale.
-- Cash orders held for a confirmation code already expired through
-- `cod_risk_assessments.expires_at`; every other way an order could be left
-- PENDING_PAYMENT — a transfer never sent, a gateway page closed, a crash
-- between creating the order and confirming it — held its stock for ever, and
-- the seller was never told why her dress had stopped selling.
--
-- Nullable, and left NULL on the orders that already exist: back-filling a
-- deadline onto historical rows would hand the first sweep a pile of orders to
-- cancel that nobody is waiting on. Existing unpaid orders are for support to
-- close by hand; everything placed from now on carries its own deadline.

ALTER TABLE "orders" ADD COLUMN IF NOT EXISTS "expires_at" TIMESTAMP(3);

-- The sweep's only query. Without it, finding the handful of expired orders is
-- a sequential scan of every order the platform has ever taken.
CREATE INDEX IF NOT EXISTS "orders_status_expires_at_idx"
  ON "orders" ("status", "expires_at");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '4093e33d01be5633472f38e661811d224445a4b9ac64c584a3176c142fc8a96f', now(), '20260909100000_order_expiry', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260909100000_order_expiry');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
