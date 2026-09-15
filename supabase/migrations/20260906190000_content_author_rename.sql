-- GENERATED from backend/prisma/migrations/20260906190000_content_author_rename/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: af6ae4204c196ff1d9a231457bc5242ce63de57c276f2a62c5f3605e74c41410

SET search_path = public, extensions;


-- The content platform becomes author-owned rather than seller-owned.
--
-- `commerce_contents.seller_id` is RENAMED, not dropped and re-added. Prisma's
-- own diff proposes the latter, which would discard the author of all 26 live
-- rows — including the home hero banners.
--
-- This migration is NOT backward compatible: code selecting `seller_id` fails
-- the instant it lands. That is deliberate and the reason it ships in the same
-- release as its readers (`commerce-content.repository`, `home-content.service`,
-- `seller-commerce.service`) rather than as a dual-write dance across four
-- migrations for a table this size.

-- ── The author ──────────────────────────────────────────────────────────────
ALTER TABLE "commerce_contents" RENAME COLUMN "seller_id" TO "author_id";

ALTER TABLE "commerce_contents"
  RENAME CONSTRAINT "commerce_contents_seller_id_fkey" TO "commerce_contents_author_id_fkey";

-- Two of the three indexes on the old column are replaced outright below,
-- because their column order changes as well as their name.
DROP INDEX "commerce_contents_seller_id_status_created_at_idx";
DROP INDEX "commerce_contents_content_type_status_published_at_idx";
-- Subsumed by the keyset feed indexes; nothing drove off `published_at` alone.
DROP INDEX "commerce_contents_published_at_idx";

CREATE TYPE "CommerceAuthorKind" AS ENUM ('SELLER', 'CUSTOMER', 'PLATFORM');

-- A temporary default so the column can be added NOT NULL to a populated
-- table. It is dropped once the backfill below has given every row a real
-- value, because the value is a historical fact recorded at write time, not
-- something a later INSERT should be allowed to guess.
ALTER TABLE "commerce_contents"
  ADD COLUMN "author_kind" "CommerceAuthorKind" NOT NULL DEFAULT 'SELLER',
  ADD COLUMN "author_is_public" BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN "removed_at" TIMESTAMP(3),
  ADD COLUMN "removed_by_id" UUID,
  ADD COLUMN "removal_reason" TEXT,
  ADD COLUMN "reports_count" INTEGER NOT NULL DEFAULT 0;

-- ── The public account ──────────────────────────────────────────────────────
-- Off by default: her page is hers until she says otherwise. Every existing
-- non-customer account is public, because a storefront nobody may look at is
-- not a storefront.
ALTER TABLE "users"
  ADD COLUMN "profile_is_public" BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN "profile_public_since" TIMESTAMP(3);

UPDATE "users"
   SET "profile_is_public" = TRUE,
       "profile_public_since" = "created_at"
 WHERE "role" <> 'CUSTOMER';

-- ── Backfill the author facts ───────────────────────────────────────────────
UPDATE "commerce_contents" c
   SET "author_kind" = CASE u."role"
         WHEN 'CUSTOMER' THEN 'CUSTOMER'::"CommerceAuthorKind"
         WHEN 'SELLER'   THEN 'SELLER'::"CommerceAuthorKind"
         ELSE 'PLATFORM'::"CommerceAuthorKind"
       END,
       "author_is_public" = u."profile_is_public"
  FROM "users" u
 WHERE u."id" = c."author_id";

ALTER TABLE "commerce_contents" ALTER COLUMN "author_kind" DROP DEFAULT;

-- ── Indexes the feeds actually drive off ────────────────────────────────────
-- Her authoring workspace.
CREATE INDEX "commerce_contents_author_id_status_updated_at_idx"
  ON "commerce_contents"("author_id", "status", "updated_at" DESC);

-- Her page timeline, and branch A of the following feed. Keyset-ordered, so
-- the index carries the whole ORDER BY rather than feeding a sort.
CREATE INDEX "commerce_contents_author_id_status_published_at_id_idx"
  ON "commerce_contents"("author_id", "status", "published_at" DESC, "id" DESC);

-- One index for every format-scoped feed — reels today, whatever the registry
-- grows tomorrow.
CREATE INDEX "commerce_contents_content_type_status_visibility_published__idx"
  ON "commerce_contents"("content_type", "status", "visibility", "published_at" DESC, "id" DESC);

-- The stories tray: one format, still live.
CREATE INDEX "commerce_contents_content_type_status_expires_at_idx"
  ON "commerce_contents"("content_type", "status", "expires_at");

ALTER TABLE "commerce_contents"
  ADD CONSTRAINT "commerce_contents_removed_by_id_fkey"
  FOREIGN KEY ("removed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'af6ae4204c196ff1d9a231457bc5242ce63de57c276f2a62c5f3605e74c41410', now(), '20260906190000_content_author_rename', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260906190000_content_author_rename');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
