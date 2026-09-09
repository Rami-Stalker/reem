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
