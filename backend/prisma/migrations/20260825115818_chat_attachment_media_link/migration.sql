-- AlterTable
ALTER TABLE "message_attachments" ADD COLUMN     "media_asset_id" UUID;

-- CreateIndex
CREATE INDEX "message_attachments_media_asset_id_idx" ON "message_attachments"("media_asset_id");

-- AddForeignKey
ALTER TABLE "message_attachments" ADD CONSTRAINT "message_attachments_media_asset_id_fkey" FOREIGN KEY ("media_asset_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;
