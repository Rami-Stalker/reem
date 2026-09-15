-- GENERATED from backend/prisma/migrations/20260909140000_request_idempotency/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 098aac8e01fe7043ebde39205cd25682b51768e84e588d474e2ce614edfbb05e

SET search_path = public, extensions;


-- A double tap stops being a second order.
--
-- Checkout is one HTTP request that creates an order, claims stock from every
-- seller in the basket, redeems a coupon and initiates a payment. On a Syrian
-- mobile connection that request can be in flight for several seconds, and a
-- woman who is not sure it registered taps again. Nothing stopped the second
-- tap: she got two orders, two stock claims, and a courier at her door with
-- two bills.
--
-- The client now sends an `Idempotency-Key` with unsafe requests, and the
-- second attempt with the same key is answered from this table rather than
-- executed. `(scope, key)` is unique -- the scope being the principal, so one
-- customer's key can never collide with another's and a guessed key reaches
-- nothing of hers.

DO $$ BEGIN
  CREATE TYPE "IdempotencyState" AS ENUM ('IN_FLIGHT', 'COMPLETED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS "idempotency_records" (
  "id"           UUID PRIMARY KEY,
  "key"          TEXT NOT NULL,
  "scope"        TEXT NOT NULL,
  "endpoint"     TEXT NOT NULL,
  "request_hash" TEXT NOT NULL,
  "state"        "IdempotencyState" NOT NULL DEFAULT 'IN_FLIGHT',
  "status_code"  INTEGER,
  "response"     JSONB,
  "expires_at"   TIMESTAMP(3) NOT NULL,
  "created_at"   TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "completed_at" TIMESTAMP(3)
);

-- The claim. Inserting is how a request wins the right to run: the loser gets
-- a unique violation and reads the winner's answer instead.
CREATE UNIQUE INDEX IF NOT EXISTS "idempotency_records_scope_key_key"
  ON "idempotency_records" ("scope", "key");

-- The sweeper's only query.
CREATE INDEX IF NOT EXISTS "idempotency_records_expires_at_idx"
  ON "idempotency_records" ("expires_at");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '098aac8e01fe7043ebde39205cd25682b51768e84e588d474e2ce614edfbb05e', now(), '20260909140000_request_idempotency', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260909140000_request_idempotency');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
