-- GENERATED from backend/prisma/migrations/20260909180000_backfill_reservations/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: ee842fb6ffeafe37e2f851131d2ce974c9083a87dd0a00faf5290a4ee16b6033

SET search_path = public, extensions;


-- Orders already in flight keep the right to give their stock back.
--
-- `inventory_reservations` made releasing stock idempotent by making it a state
-- change on a reservation row rather than a bare `increment`. Checkout writes
-- one per line from now on -- but every order placed *before* this deploy has
-- none, and `restock` correctly refuses to invent units it has no record of.
-- Without this backfill, an order in a seller's queue at the moment of the
-- deploy would be cancellable and would silently fail to return its garments
-- to the shelf. The seller would never be told; her dress would simply have
-- stopped selling.
--
-- Only sub-orders whose stock is genuinely still held are covered. A delivered
-- parcel's units are gone, and a cancelled or returned one has already had its
-- increment under the old code -- giving either a reservation would hand back
-- units a second time, which is the exact bug the table was added to prevent.
--
-- Written as COMMITTED, with no deadline: these are live orders a seller may
-- be packing right now, and a sweep must not release them underneath her.

INSERT INTO "inventory_reservations" (
  "id", "offer_id", "offer_variant_id", "order_id", "seller_order_id",
  "quantity", "state", "committed_at", "created_at", "updated_at"
)
SELECT
  gen_random_uuid(),
  oi."offer_id",
  -- `order_items.variant_id` names a ProductVariant; a reservation names the
  -- *offer's* variant, which is the row that carries stock. Resolved by the
  -- pair, exactly as the old restock looked it up.
  sov."id",
  so."order_id",
  so."id",
  oi."quantity",
  'COMMITTED',
  now(),
  now(),
  now()
FROM "order_items" oi
JOIN "seller_orders" so ON so."id" = oi."seller_order_id"
LEFT JOIN "seller_offer_variants" sov
  ON sov."offer_id" = oi."offer_id"
 AND sov."variant_id" = oi."variant_id"
WHERE oi."offer_id" IS NOT NULL
  AND so."status" IN (
    'NEW',
    'AWAITING_SELLER_CONFIRMATION',
    'PREPARING',
    'READY_TO_SHIP',
    'HANDED_TO_COURIER',
    'IN_TRANSIT',
    'DELIVERY_FAILED'
  )
  -- Idempotent: re-running this migration, or running it after some orders
  -- have already been reserved by the new checkout, adds nothing.
  AND NOT EXISTS (
    SELECT 1 FROM "inventory_reservations" r
    WHERE r."seller_order_id" = so."id"
      AND r."offer_id" = oi."offer_id"
  );


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'ee842fb6ffeafe37e2f851131d2ce974c9083a87dd0a00faf5290a4ee16b6033', now(), '20260909180000_backfill_reservations', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260909180000_backfill_reservations');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
