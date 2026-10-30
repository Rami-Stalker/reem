-- Paying for an advertising plan by Sham Cash, Syriatel Cash, MTN Cash, bank
-- transfer or hawala, with finance matching the reference. A boutique with no
-- earnings yet could otherwise not buy a plan at all.

-- CreateEnum
CREATE TYPE "AdPlanPurchaseStatus" AS ENUM ('AWAITING_PAYMENT', 'AWAITING_REVIEW', 'CONFIRMED', 'REJECTED', 'CANCELLED');

-- CreateTable
CREATE TABLE "ad_plan_purchases" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "tier" "StoreAdTier" NOT NULL,
    "method" "PaymentMethodType" NOT NULL,
    "amount" DECIMAL(18,4) NOT NULL,
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "status" "AdPlanPurchaseStatus" NOT NULL DEFAULT 'AWAITING_PAYMENT',
    "reference" TEXT,
    "reference_submitted_at" TIMESTAMP(3),
    "rejection_reason" TEXT,
    "decided_by_id" UUID,
    "decided_at" TIMESTAMP(3),
    "subscription_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ad_plan_purchases_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ad_plan_purchases_subscription_id_key" ON "ad_plan_purchases"("subscription_id");

-- CreateIndex
CREATE INDEX "ad_plan_purchases_status_created_at_idx" ON "ad_plan_purchases"("status", "created_at");

-- CreateIndex
CREATE INDEX "ad_plan_purchases_seller_id_created_at_idx" ON "ad_plan_purchases"("seller_id", "created_at");

-- AddForeignKey
ALTER TABLE "ad_plan_purchases" ADD CONSTRAINT "ad_plan_purchases_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Each plan reminder and campaign result is sent once.
-- AlterTable
ALTER TABLE "product_promotions" ADD COLUMN     "ended_notice_sent_at" TIMESTAMP(3);

-- AlterTable
ALTER TABLE "store_ad_subscriptions" ADD COLUMN     "ended_notice_sent_at" TIMESTAMP(3),
ADD COLUMN     "reminder_sent_at" TIMESTAMP(3);

