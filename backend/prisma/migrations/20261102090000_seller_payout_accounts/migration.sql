-- A boutique is paid to a Sham Cash wallet or a Visa card, and each payout
-- remembers where it was sent.
CREATE TYPE "PayoutMethod" AS ENUM ('SHAM_CASH', 'VISA');

CREATE TABLE "seller_payout_accounts" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "method" "PayoutMethod" NOT NULL,
    "holder_name" TEXT NOT NULL,
    "sham_cash_number" TEXT,
    "card_last4" TEXT,
    "card_sealed" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "seller_payout_accounts_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "seller_payout_accounts_seller_id_key" ON "seller_payout_accounts"("seller_id");

ALTER TABLE "seller_payout_accounts" ADD CONSTRAINT "seller_payout_accounts_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "seller_payouts" ADD COLUMN "method" "PayoutMethod",
ADD COLUMN "destination_label" TEXT,
ADD COLUMN "destination_sealed" TEXT;
