-- Stock that is off the shelf now says why, and what will put it back.
--
-- Until now the only record that a unit had been sold was the decrement itself:
-- `claimStock` lowered `seller_offers.stock` inside the checkout transaction
-- and nothing said which order took it. Three problems came out of that, and
-- this table exists for all three.
--
-- **Releasing was not idempotent.** `restock` incremented the column with no
-- condition, so any path that ran twice — a retried cancellation, a refusal
-- recorded by the courier and again by the carrier's webhook — credited the
-- seller units she never got back, and the shelf drifted upward for ever. A
-- reservation can leave HELD/COMMITTED exactly once; the state is the guard,
-- checked in the same UPDATE that moves it.
--
-- **The release depended on the order lifecycle.** A sub-order stuck in a state
-- nobody could move it out of took its stock with it permanently. A
-- reservation carries its own deadline, so the shelf recovers even when the
-- order does not.
--
-- **A seller could not tell "sold" from "spoken for".**
--
-- `seller_offers.stock` deliberately keeps meaning *available* rather than
-- *physically present*: every catalogue read, product card and roll-up already
-- reads that column, and redefining it would have turned availability into a
-- join on the hottest path in the platform.

DO $$ BEGIN
  CREATE TYPE "InventoryReservationState" AS ENUM ('HELD', 'COMMITTED', 'CONSUMED', 'RELEASED');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS "inventory_reservations" (
  "id"                UUID PRIMARY KEY,
  "offer_id"          UUID NOT NULL,
  "offer_variant_id"  UUID,
  "order_id"          UUID NOT NULL,
  "seller_order_id"   UUID,
  "quantity"          INTEGER NOT NULL,
  "state"             "InventoryReservationState" NOT NULL DEFAULT 'HELD',
  "expires_at"        TIMESTAMP(3),
  "committed_at"      TIMESTAMP(3),
  "consumed_at"       TIMESTAMP(3),
  "released_at"       TIMESTAMP(3),
  "release_reason"    TEXT,
  "created_at"        TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at"        TIMESTAMP(3) NOT NULL,

  CONSTRAINT "inventory_reservations_offer_id_fkey"
    FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "inventory_reservations_offer_variant_id_fkey"
    FOREIGN KEY ("offer_variant_id") REFERENCES "seller_offer_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE,
  CONSTRAINT "inventory_reservations_order_id_fkey"
    FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE,
  CONSTRAINT "inventory_reservations_seller_order_id_fkey"
    FOREIGN KEY ("seller_order_id") REFERENCES "seller_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

-- The sweeper's only query: holds whose deadline has passed.
CREATE INDEX IF NOT EXISTS "inventory_reservations_state_expires_at_idx"
  ON "inventory_reservations" ("state", "expires_at");
CREATE INDEX IF NOT EXISTS "inventory_reservations_order_id_idx"
  ON "inventory_reservations" ("order_id");
CREATE INDEX IF NOT EXISTS "inventory_reservations_seller_order_id_idx"
  ON "inventory_reservations" ("seller_order_id");
-- "What is spoken for on this listing", for the seller's stock screen.
CREATE INDEX IF NOT EXISTS "inventory_reservations_offer_id_state_idx"
  ON "inventory_reservations" ("offer_id", "state");
