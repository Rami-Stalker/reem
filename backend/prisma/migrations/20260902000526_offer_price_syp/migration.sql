-- AlterTable
ALTER TABLE "seller_offers" ADD COLUMN     "price_syp" DECIMAL(18,4);

-- CreateIndex
CREATE INDEX "seller_offers_product_id_status_price_syp_idx" ON "seller_offers"("product_id", "status", "price_syp");
