-- GENERATED from backend/prisma/migrations/20260826180000_delivery_shaped_addresses/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: bd58ea45acdceaad726bd01d26faccc0d6dd9f89beb316441d5a4bab7a21267f

SET search_path = public, extensions;


-- The address book is reshaped around what a delivery actually needs.
--
-- The old columns (street/country/postal_code) could not fill a single field
-- of the checkout form, so the book was unusable and every customer retyped
-- her address on every order. What exists is carried across rather than
-- dropped: `street` becomes the address line, and the governorate is seeded
-- from the city until she edits it.

ALTER TABLE "addresses"
  ADD COLUMN "recipient_name"  TEXT,
  ADD COLUMN "recipient_phone" TEXT,
  ADD COLUMN "governorate"     TEXT,
  ADD COLUMN "district"        TEXT,
  ADD COLUMN "address_line"    TEXT,
  ADD COLUMN "landmark"        TEXT,
  ADD COLUMN "is_rural"        BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN "delivery_instructions" TEXT,
  ADD COLUMN "created_at"      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ADD COLUMN "updated_at"      TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

UPDATE "addresses" a
SET "address_line"    = COALESCE(a."street", ''),
    "governorate"     = COALESCE(a."city", ''),
    "recipient_name"  = COALESCE(u."name", ''),
    "recipient_phone" = COALESCE(u."phone", '')
FROM "users" u
WHERE u."id" = a."user_id";

-- Anything with no user row left to borrow from still has to satisfy NOT NULL.
UPDATE "addresses"
SET "address_line"    = COALESCE("address_line", ''),
    "governorate"     = COALESCE("governorate", ''),
    "recipient_name"  = COALESCE("recipient_name", ''),
    "recipient_phone" = COALESCE("recipient_phone", '');

ALTER TABLE "addresses"
  ALTER COLUMN "recipient_name"  SET NOT NULL,
  ALTER COLUMN "recipient_phone" SET NOT NULL,
  ALTER COLUMN "governorate"     SET NOT NULL,
  ALTER COLUMN "address_line"    SET NOT NULL;

ALTER TABLE "addresses"
  DROP COLUMN "street",
  DROP COLUMN "country",
  DROP COLUMN "postal_code";

ALTER TABLE "addresses" ALTER COLUMN "label" SET DEFAULT 'المنزل';

CREATE INDEX "addresses_user_id_is_default_idx" ON "addresses"("user_id", "is_default");


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'bd58ea45acdceaad726bd01d26faccc0d6dd9f89beb316441d5a4bab7a21267f', now(), '20260826180000_delivery_shaped_addresses', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260826180000_delivery_shaped_addresses');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
