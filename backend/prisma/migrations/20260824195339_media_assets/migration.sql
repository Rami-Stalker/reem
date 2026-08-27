-- CreateEnum
CREATE TYPE "MediaVisibility" AS ENUM ('PUBLIC', 'PRIVATE');

-- CreateEnum
CREATE TYPE "MediaAssetStatus" AS ENUM ('PENDING', 'ATTACHED');

-- CreateTable
CREATE TABLE "media_assets" (
    "id" UUID NOT NULL,
    "owner_id" UUID NOT NULL,
    "driver" TEXT NOT NULL,
    "storage_key" TEXT NOT NULL,
    "visibility" "MediaVisibility" NOT NULL DEFAULT 'PUBLIC',
    "status" "MediaAssetStatus" NOT NULL DEFAULT 'PENDING',
    "mime_type" TEXT NOT NULL,
    "kind" "MediaType" NOT NULL DEFAULT 'image',
    "byte_size" INTEGER NOT NULL,
    "width" INTEGER,
    "height" INTEGER,
    "checksum" TEXT NOT NULL,
    "original_name" TEXT,
    "purpose" TEXT,
    "attached_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "media_assets_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "media_assets_storage_key_key" ON "media_assets"("storage_key");

-- CreateIndex
CREATE INDEX "media_assets_owner_id_created_at_idx" ON "media_assets"("owner_id", "created_at");

-- CreateIndex
CREATE INDEX "media_assets_status_created_at_idx" ON "media_assets"("status", "created_at");

-- CreateIndex
CREATE INDEX "media_assets_owner_id_checksum_idx" ON "media_assets"("owner_id", "checksum");

-- AddForeignKey
ALTER TABLE "media_assets" ADD CONSTRAINT "media_assets_owner_id_fkey" FOREIGN KEY ("owner_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
