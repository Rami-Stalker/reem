-- AlterTable
ALTER TABLE "products" ADD COLUMN     "is_featured" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "show_in_feed" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "user_presence" ALTER COLUMN "updated_at" DROP DEFAULT;

-- CreateIndex
CREATE INDEX "products_status_is_featured_idx" ON "products"("status", "is_featured");

-- RenameIndex
ALTER INDEX "seller_verification_status_history_verification_id_created_at_i" RENAME TO "seller_verification_status_history_verification_id_created__idx";
