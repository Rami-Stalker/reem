-- GENERATED from backend/prisma/migrations/20260824195339_media_assets/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: d024a3789dd5e67cb266052a42e5237c5e9a509daeffd14f0fed1d910be8f7a8

SET search_path = public, extensions;


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


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'd024a3789dd5e67cb266052a42e5237c5e9a509daeffd14f0fed1d910be8f7a8', now(), '20260824195339_media_assets', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260824195339_media_assets');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
