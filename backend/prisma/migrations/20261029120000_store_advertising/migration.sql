-- «إعلانات المتاجر»: plans that rank boutiques by what they pay, two new
-- placements (the top of the community feed and the home spotlight), audience
-- targeting, and the per-shopper exposure rows behind the frequency cap, the
-- unique reach a seller is shown, and order attribution.
--
-- Every new column on product_promotions has a default that reproduces the
-- old behaviour exactly — shown to everyone, nothing paid from credit — so the
-- placements already sold keep serving as they did.

-- CreateEnum
CREATE TYPE "AdAudience" AS ENUM ('EVERYONE', 'TARGETED');

-- CreateEnum
CREATE TYPE "StoreAdTier" AS ENUM ('FREE', 'SILVER', 'GOLD', 'DIAMOND');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "PromotionPlacement" ADD VALUE 'FEED_TOP';
ALTER TYPE "PromotionPlacement" ADD VALUE 'HOME_SPOTLIGHT';

-- AlterTable
ALTER TABLE "product_promotions" ADD COLUMN     "audience" "AdAudience" NOT NULL DEFAULT 'EVERYONE',
ADD COLUMN     "content_id" UUID,
ADD COLUMN     "credit_applied" DECIMAL(18,4) NOT NULL DEFAULT 0,
ADD COLUMN     "followers_notified_at" TIMESTAMP(3),
ADD COLUMN     "target_followers" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "target_governorates" TEXT[] DEFAULT ARRAY[]::TEXT[],
ADD COLUMN     "target_interested" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "target_new_shoppers" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "target_past_buyers" BOOLEAN NOT NULL DEFAULT false;

-- CreateTable
CREATE TABLE "store_ad_subscriptions" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "tier" "StoreAdTier" NOT NULL,
    "price_amount" DECIMAL(18,4) NOT NULL,
    "price_currency" "Currency" NOT NULL DEFAULT 'SYP',
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3) NOT NULL,
    "credit_granted" DECIMAL(18,4) NOT NULL,
    "credit_used" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "charge_reference" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "store_ad_subscriptions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ad_exposures" (
    "id" UUID NOT NULL,
    "promotion_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "impressions" INTEGER NOT NULL DEFAULT 0,
    "clicks" INTEGER NOT NULL DEFAULT 0,
    "last_clicked_at" TIMESTAMP(3),

    CONSTRAINT "ad_exposures_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "store_ad_subscriptions_charge_reference_key" ON "store_ad_subscriptions"("charge_reference");

-- CreateIndex
CREATE INDEX "store_ad_subscriptions_seller_id_ends_at_idx" ON "store_ad_subscriptions"("seller_id", "ends_at");

-- CreateIndex
CREATE INDEX "ad_exposures_user_id_day_idx" ON "ad_exposures"("user_id", "day");

-- CreateIndex
CREATE UNIQUE INDEX "ad_exposures_promotion_id_user_id_day_key" ON "ad_exposures"("promotion_id", "user_id", "day");

-- CreateIndex
CREATE INDEX "product_promotions_placement_status_ends_at_idx" ON "product_promotions"("placement", "status", "ends_at");

-- AddForeignKey
ALTER TABLE "product_promotions" ADD CONSTRAINT "product_promotions_content_id_fkey" FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "store_ad_subscriptions" ADD CONSTRAINT "store_ad_subscriptions_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_exposures" ADD CONSTRAINT "ad_exposures_promotion_id_fkey" FOREIGN KEY ("promotion_id") REFERENCES "product_promotions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ad_exposures" ADD CONSTRAINT "ad_exposures_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

