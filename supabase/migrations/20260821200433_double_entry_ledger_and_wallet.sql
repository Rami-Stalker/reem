-- GENERATED from backend/prisma/migrations/20260821200433_double_entry_ledger_and_wallet/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 5fbd2d3f874410664e84788c78cd80eedc8a254f4a4d71256947ccfbe63333b0

SET search_path = public, extensions;


-- CreateEnum
CREATE TYPE "LedgerAccountKind" AS ENUM ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE');

-- CreateEnum
CREATE TYPE "LedgerAccountCode" AS ENUM ('PLATFORM_CASH', 'COURIER_CASH_IN_TRANSIT', 'GATEWAY_RECEIVABLE', 'SELLER_ESCROW', 'SELLER_PAYABLE', 'CUSTOMER_WALLET', 'DISPUTE_HELD', 'COMMISSION_REVENUE', 'SHIPPING_REVENUE', 'SHIPPING_EXPENSE', 'PLATFORM_PROMOTION_EXPENSE', 'LOYALTY_LIABILITY', 'FX_ADJUSTMENT', 'ROUNDING_ADJUSTMENT', 'SUSPENSE');

-- CreateEnum
CREATE TYPE "LedgerDirection" AS ENUM ('DEBIT', 'CREDIT');

-- CreateEnum
CREATE TYPE "JournalEntryType" AS ENUM ('ORDER_PLACED', 'PAYMENT_CAPTURED', 'COURIER_CASH_SETTLED', 'COMMISSION_EARNED', 'ESCROW_RELEASED', 'PAYOUT_ACCRUED', 'PAYOUT_PAID', 'REFUND_ISSUED', 'RETURN_SETTLED', 'WALLET_TOPUP', 'WALLET_SPENT', 'LOYALTY_ACCRUED', 'LOYALTY_REDEEMED', 'DISPUTE_HELD', 'DISPUTE_RELEASED', 'FX_REVALUATION', 'MANUAL_ADJUSTMENT', 'REVERSAL');

-- CreateEnum
CREATE TYPE "WalletTransactionSource" AS ENUM ('RETURN_REFUND', 'POINTS_CONVERSION', 'ADMIN_COMPENSATION', 'CUSTOMER_TOPUP', 'CAMPAIGN_GIFT', 'PRICE_ADJUSTMENT', 'ORDER_PAYMENT', 'ORDER_REVERSAL');

-- CreateTable
CREATE TABLE "ledger_accounts" (
    "id" UUID NOT NULL,
    "code" "LedgerAccountCode" NOT NULL,
    "kind" "LedgerAccountKind" NOT NULL,
    "currency" "Currency" NOT NULL,
    "owner_id" UUID,
    "balance" DECIMAL(20,4) NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ledger_accounts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "journal_entries" (
    "id" UUID NOT NULL,
    "type" "JournalEntryType" NOT NULL,
    "reference" TEXT NOT NULL,
    "description" TEXT NOT NULL,
    "order_id" UUID,
    "seller_order_id" UUID,
    "reverses_id" UUID,
    "created_by_id" UUID,
    "metadata" JSONB,
    "occurred_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "journal_entries_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "journal_lines" (
    "id" UUID NOT NULL,
    "entry_id" UUID NOT NULL,
    "account_id" UUID NOT NULL,
    "direction" "LedgerDirection" NOT NULL,
    "amount" DECIMAL(20,4) NOT NULL,
    "currency" "Currency" NOT NULL,
    "memo" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "journal_lines_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wallets" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "balance" DECIMAL(20,4) NOT NULL DEFAULT 0,
    "frozen" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "wallets_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wallet_transactions" (
    "id" UUID NOT NULL,
    "wallet_id" UUID NOT NULL,
    "source" "WalletTransactionSource" NOT NULL,
    "amount" DECIMAL(20,4) NOT NULL,
    "currency" "Currency" NOT NULL,
    "balance_after" DECIMAL(20,4) NOT NULL,
    "reason" TEXT NOT NULL,
    "order_id" UUID,
    "journal_entry_id" UUID,
    "reference" TEXT,
    "created_by_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wallet_transactions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ledger_accounts_owner_id_code_idx" ON "ledger_accounts"("owner_id", "code");

-- CreateIndex
CREATE UNIQUE INDEX "ledger_accounts_code_owner_id_currency_key" ON "ledger_accounts"("code", "owner_id", "currency");

-- CreateIndex
CREATE UNIQUE INDEX "journal_entries_reference_key" ON "journal_entries"("reference");

-- CreateIndex
CREATE UNIQUE INDEX "journal_entries_reverses_id_key" ON "journal_entries"("reverses_id");

-- CreateIndex
CREATE INDEX "journal_entries_type_occurred_at_idx" ON "journal_entries"("type", "occurred_at");

-- CreateIndex
CREATE INDEX "journal_entries_order_id_idx" ON "journal_entries"("order_id");

-- CreateIndex
CREATE INDEX "journal_entries_seller_order_id_idx" ON "journal_entries"("seller_order_id");

-- CreateIndex
CREATE INDEX "journal_lines_account_id_created_at_idx" ON "journal_lines"("account_id", "created_at");

-- CreateIndex
CREATE INDEX "journal_lines_entry_id_idx" ON "journal_lines"("entry_id");

-- CreateIndex
CREATE UNIQUE INDEX "wallets_user_id_currency_key" ON "wallets"("user_id", "currency");

-- CreateIndex
CREATE UNIQUE INDEX "wallet_transactions_journal_entry_id_key" ON "wallet_transactions"("journal_entry_id");

-- CreateIndex
CREATE UNIQUE INDEX "wallet_transactions_reference_key" ON "wallet_transactions"("reference");

-- CreateIndex
CREATE INDEX "wallet_transactions_wallet_id_created_at_idx" ON "wallet_transactions"("wallet_id", "created_at");

-- CreateIndex
CREATE INDEX "wallet_transactions_order_id_idx" ON "wallet_transactions"("order_id");

-- AddForeignKey
ALTER TABLE "ledger_accounts" ADD CONSTRAINT "ledger_accounts_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "journal_entries" ADD CONSTRAINT "journal_entries_reverses_id_fkey" FOREIGN KEY ("reverses_id") REFERENCES "journal_entries"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "journal_lines" ADD CONSTRAINT "journal_lines_entry_id_fkey" FOREIGN KEY ("entry_id") REFERENCES "journal_entries"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "journal_lines" ADD CONSTRAINT "journal_lines_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "ledger_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallets" ADD CONSTRAINT "wallets_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wallet_transactions" ADD CONSTRAINT "wallet_transactions_wallet_id_fkey" FOREIGN KEY ("wallet_id") REFERENCES "wallets"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '5fbd2d3f874410664e84788c78cd80eedc8a254f4a4d71256947ccfbe63333b0', now(), '20260821200433_double_entry_ledger_and_wallet', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260821200433_double_entry_ledger_and_wallet');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
