-- The adapter that serves an account, separate from the account's own code:
-- two delivery companies can share one adapter with different configuration.
ALTER TABLE "delivery_provider_accounts" ADD COLUMN "adapter" TEXT NOT NULL DEFAULT 'http_generic';

-- Accounts written before this column existed named their adapter in `code`.
UPDATE "delivery_provider_accounts" SET "adapter" = "code";
