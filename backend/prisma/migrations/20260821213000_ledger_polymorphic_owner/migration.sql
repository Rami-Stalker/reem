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
