-- GENERATED from backend/prisma/migrations/20260825115818_chat_attachment_media_link/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 21fae0d2ed1c3324fad9994bfacaad9a7001310365b43aa4618a5aaefc3039ab

SET search_path = public, extensions;


-- AlterTable
ALTER TABLE "message_attachments" ADD COLUMN     "media_asset_id" UUID;

-- CreateIndex
CREATE INDEX "message_attachments_media_asset_id_idx" ON "message_attachments"("media_asset_id");

-- AddForeignKey
ALTER TABLE "message_attachments" ADD CONSTRAINT "message_attachments_media_asset_id_fkey" FOREIGN KEY ("media_asset_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '21fae0d2ed1c3324fad9994bfacaad9a7001310365b43aa4618a5aaefc3039ab', now(), '20260825115818_chat_attachment_media_link', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260825115818_chat_attachment_media_link');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
