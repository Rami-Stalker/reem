-- GENERATED from backend/prisma/migrations/20260818173828_product_curation_flags/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: fb28649aee3abda9886a1967bd6a1c5c5a2d4de697c6b097cddcd599dd4dd247

SET search_path = public, extensions;


-- AlterTable
ALTER TABLE "products" ADD COLUMN     "is_featured" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "show_in_feed" BOOLEAN NOT NULL DEFAULT true;

-- AlterTable
ALTER TABLE "user_presence" ALTER COLUMN "updated_at" DROP DEFAULT;

-- CreateIndex
CREATE INDEX "products_status_is_featured_idx" ON "products"("status", "is_featured");

-- RenameIndex
ALTER INDEX "seller_verification_status_history_verification_id_created_at_i" RENAME TO "seller_verification_status_history_verification_id_created__idx";


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'fb28649aee3abda9886a1967bd6a1c5c5a2d4de697c6b097cddcd599dd4dd247', now(), '20260818173828_product_curation_flags', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260818173828_product_curation_flags');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
