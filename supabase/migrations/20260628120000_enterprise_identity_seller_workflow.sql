-- GENERATED from backend/prisma/migrations/20260628120000_enterprise_identity_seller_workflow/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: d796320bf3f7a4d13407dbeafadcc2ca55398c3f13e5a2413dbcc90b3ca5b6d2

SET search_path = public, extensions;


-- Enterprise identity additions: verification timestamps, richer seller
-- applications, status history, and seller workflow states.

ALTER TYPE "SellerVerificationStatus" ADD VALUE IF NOT EXISTS 'UNDER_REVIEW';
ALTER TYPE "SellerVerificationStatus" ADD VALUE IF NOT EXISTS 'NEEDS_MORE_DOCUMENTS';
ALTER TYPE "SellerVerificationStatus" ADD VALUE IF NOT EXISTS 'SUSPENDED';

ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "phone_verified_at" TIMESTAMP(3);
ALTER TABLE "users" ADD COLUMN IF NOT EXISTS "email_verified_at" TIMESTAMP(3);

UPDATE "users"
SET "phone_verified_at" = COALESCE("phone_verified_at", "updated_at", "created_at")
WHERE "is_verified" = TRUE AND "phone_verified_at" IS NULL;

UPDATE "users"
SET "email_verified_at" = COALESCE("email_verified_at", "updated_at", "created_at")
WHERE "email" IS NOT NULL AND "email_verified_at" IS NULL;

ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "business_category" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "store_description" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "store_logo_url" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "contact_phone" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "contact_email" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "business_address" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "warehouse_address" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "commercial_registration" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "government_id_url" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "business_license_url" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "bank_name" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "account_holder" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "iban" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "payment_information" JSONB;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "shipping_methods" JSONB;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "return_policy" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "product_categories" JSONB;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "years_experience" INTEGER;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "website" TEXT;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "social_media_links" JSONB;
ALTER TABLE "seller_verifications" ADD COLUMN IF NOT EXISTS "review_reason" TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS "seller_verifications_commercial_registration_key"
ON "seller_verifications"("commercial_registration");

CREATE UNIQUE INDEX IF NOT EXISTS "seller_verifications_tax_id_key"
ON "seller_verifications"("tax_id");

CREATE TABLE IF NOT EXISTS "seller_verification_status_history" (
    "id" UUID NOT NULL,
    "verification_id" UUID NOT NULL,
    "status" "SellerVerificationStatus" NOT NULL,
    "reason" TEXT NOT NULL,
    "admin_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "seller_verification_status_history_pkey" PRIMARY KEY ("id")
);

CREATE INDEX IF NOT EXISTS "seller_verification_status_history_verification_id_created_at_idx"
ON "seller_verification_status_history"("verification_id", "created_at");

CREATE INDEX IF NOT EXISTS "seller_verification_status_history_admin_id_created_at_idx"
ON "seller_verification_status_history"("admin_id", "created_at");

ALTER TABLE "seller_verification_status_history"
ADD CONSTRAINT "seller_verification_status_history_verification_id_fkey"
FOREIGN KEY ("verification_id") REFERENCES "seller_verifications"("id")
ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "seller_verification_status_history"
ADD CONSTRAINT "seller_verification_status_history_admin_id_fkey"
FOREIGN KEY ("admin_id") REFERENCES "users"("id")
ON DELETE SET NULL ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'd796320bf3f7a4d13407dbeafadcc2ca55398c3f13e5a2413dbcc90b3ca5b6d2', now(), '20260628120000_enterprise_identity_seller_workflow', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260628120000_enterprise_identity_seller_workflow');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
