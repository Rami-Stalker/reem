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
