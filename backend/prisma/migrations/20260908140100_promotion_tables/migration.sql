-- CreateEnum
CREATE TYPE "PromotionPlacement" AS ENUM ('SEARCH', 'CATEGORY');

-- CreateEnum
CREATE TYPE "PromotionStatus" AS ENUM ('PENDING', 'ACTIVE', 'PAUSED', 'ENDED', 'UNPAID');

-- CreateTable
CREATE TABLE "product_promotions" (
    "id" UUID NOT NULL,
    "offer_id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "placement" "PromotionPlacement" NOT NULL,
    "fee_amount" DECIMAL(18,4) NOT NULL,
    "fee_currency" "Currency" NOT NULL DEFAULT 'SYP',
    "status" "PromotionStatus" NOT NULL DEFAULT 'PENDING',
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3) NOT NULL,
    "charge_reference" TEXT,
    "charged_at" TIMESTAMP(3),
    "impressions" INTEGER NOT NULL DEFAULT 0,
    "clicks" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "product_promotions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "product_promotions_charge_reference_key" ON "product_promotions"("charge_reference");

-- CreateIndex
CREATE INDEX "product_promotions_status_starts_at_ends_at_idx" ON "product_promotions"("status", "starts_at", "ends_at");

-- CreateIndex
CREATE INDEX "product_promotions_seller_id_status_idx" ON "product_promotions"("seller_id", "status");

-- CreateIndex
CREATE INDEX "product_promotions_offer_id_idx" ON "product_promotions"("offer_id");

-- AddForeignKey
ALTER TABLE "product_promotions" ADD CONSTRAINT "product_promotions_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_promotions" ADD CONSTRAINT "product_promotions_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

