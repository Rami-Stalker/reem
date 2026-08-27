-- Uniqueness for ledger accounts moves off the nullable `owner_id`.
--
-- PostgreSQL treats NULLs as distinct in a unique index, so a unique on
-- (code, owner_id, currency) admits any number of platform-account rows —
-- every one of them NULL-owned and therefore "different". The balance for
-- PLATFORM_CASH would then split silently across duplicates.
--
-- `owner_key` is the same value with no NULLs: the owner's uuid, or the
-- literal 'platform'. `owner_id` stays as the foreign key.

DROP INDEX "ledger_accounts_code_owner_id_currency_key";

ALTER TABLE "ledger_accounts"
  ADD COLUMN "owner_key" TEXT NOT NULL DEFAULT 'platform';

-- Existing rows (none at the time of writing) take their owner or the sentinel.
UPDATE "ledger_accounts" SET "owner_key" = COALESCE("owner_id"::text, 'platform');

-- The default was only there to fill existing rows; the app always supplies it.
ALTER TABLE "ledger_accounts" ALTER COLUMN "owner_key" DROP DEFAULT;

CREATE UNIQUE INDEX "ledger_accounts_code_owner_key_currency_key"
  ON "ledger_accounts"("code", "owner_key", "currency");
