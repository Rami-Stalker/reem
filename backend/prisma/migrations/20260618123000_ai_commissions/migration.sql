-- CreateEnum
CREATE TYPE "AiInteractionType" AS ENUM ('RECOMMENDATION_VIEW', 'SEARCH_SUGGESTION', 'PRODUCT_DESCRIPTION', 'TAG_GENERATION', 'HOME_FEED', 'SIMILAR_PRODUCTS', 'SELLER_RECOMMENDATION', 'BEHAVIOR_ANALYSIS');

-- CreateEnum
CREATE TYPE "AiGenerationType" AS ENUM ('PRODUCT_DESCRIPTION', 'PRODUCT_TAGS', 'SEARCH_COPY');

-- CreateEnum
CREATE TYPE "AiGenerationStatus" AS ENUM ('PENDING', 'COMPLETED', 'FAILED');

-- CreateEnum
CREATE TYPE "PayoutStatus" AS ENUM ('PENDING', 'APPROVED', 'PAID', 'FAILED', 'CANCELLED');

-- AlterTable
ALTER TABLE "commission_rules"
ADD COLUMN "platform_fee_bps" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "fixed_fee" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN "min_commission" DOUBLE PRECISION,
ADD COLUMN "max_commission" DOUBLE PRECISION,
ADD COLUMN "priority" INTEGER NOT NULL DEFAULT 100;

-- AlterTable
ALTER TABLE "commission_ledgers"
ADD COLUMN "platform_fee" DOUBLE PRECISION NOT NULL DEFAULT 0,
ADD COLUMN "metadata" JSONB;

-- Backfill existing rows so net includes the new platform fee dimension.
UPDATE "commission_ledgers"
SET "platform_fee" = 0
WHERE "platform_fee" IS NULL;

-- CreateTable
CREATE TABLE "seller_payouts" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "period_start" TIMESTAMP(3) NOT NULL,
    "period_end" TIMESTAMP(3) NOT NULL,
    "gross" DOUBLE PRECISION NOT NULL,
    "commission" DOUBLE PRECISION NOT NULL,
    "platform_fees" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "adjustments" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "net" DOUBLE PRECISION NOT NULL,
    "currency" TEXT NOT NULL DEFAULT 'USD',
    "status" "PayoutStatus" NOT NULL DEFAULT 'PENDING',
    "reference" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "approved_at" TIMESTAMP(3),
    "paid_at" TIMESTAMP(3),

    CONSTRAINT "seller_payouts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "seller_payout_ledgers" (
    "id" UUID NOT NULL,
    "payout_id" UUID NOT NULL,
    "ledger_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "seller_payout_ledgers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_interactions" (
    "id" UUID NOT NULL,
    "user_id" UUID,
    "type" "AiInteractionType" NOT NULL,
    "query" TEXT,
    "product_id" UUID,
    "seller_id" UUID,
    "metadata" JSONB,
    "score" DOUBLE PRECISION,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_interactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_generations" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "product_id" UUID,
    "type" "AiGenerationType" NOT NULL,
    "prompt" TEXT NOT NULL,
    "output" JSONB NOT NULL,
    "model" TEXT NOT NULL DEFAULT 'reem-rules-v1',
    "status" "AiGenerationStatus" NOT NULL DEFAULT 'COMPLETED',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_generations_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "commission_ledgers_order_id_seller_id_key" ON "commission_ledgers"("order_id", "seller_id");

-- CreateIndex
CREATE INDEX "seller_payouts_seller_id_status_idx" ON "seller_payouts"("seller_id", "status");

-- CreateIndex
CREATE INDEX "seller_payouts_period_start_period_end_idx" ON "seller_payouts"("period_start", "period_end");

-- CreateIndex
CREATE UNIQUE INDEX "seller_payout_ledgers_payout_id_ledger_id_key" ON "seller_payout_ledgers"("payout_id", "ledger_id");

-- CreateIndex
CREATE INDEX "seller_payout_ledgers_ledger_id_idx" ON "seller_payout_ledgers"("ledger_id");

-- CreateIndex
CREATE INDEX "ai_interactions_user_id_type_created_at_idx" ON "ai_interactions"("user_id", "type", "created_at");

-- CreateIndex
CREATE INDEX "ai_interactions_product_id_idx" ON "ai_interactions"("product_id");

-- CreateIndex
CREATE INDEX "ai_interactions_seller_id_idx" ON "ai_interactions"("seller_id");

-- CreateIndex
CREATE INDEX "ai_generations_user_id_type_created_at_idx" ON "ai_generations"("user_id", "type", "created_at");

-- CreateIndex
CREATE INDEX "ai_generations_product_id_idx" ON "ai_generations"("product_id");

-- AddForeignKey
ALTER TABLE "commission_ledgers" ADD CONSTRAINT "commission_ledgers_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commission_ledgers" ADD CONSTRAINT "commission_ledgers_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_payouts" ADD CONSTRAINT "seller_payouts_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_payout_ledgers" ADD CONSTRAINT "seller_payout_ledgers_payout_id_fkey" FOREIGN KEY ("payout_id") REFERENCES "seller_payouts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_payout_ledgers" ADD CONSTRAINT "seller_payout_ledgers_ledger_id_fkey" FOREIGN KEY ("ledger_id") REFERENCES "commission_ledgers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_interactions" ADD CONSTRAINT "ai_interactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_interactions" ADD CONSTRAINT "ai_interactions_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_generations" ADD CONSTRAINT "ai_generations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_generations" ADD CONSTRAINT "ai_generations_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;
