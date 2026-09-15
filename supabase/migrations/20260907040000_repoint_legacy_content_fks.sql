-- GENERATED from backend/prisma/migrations/20260907040000_repoint_legacy_content_fks/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 4639e84d07105f9ad0c10439212daabab473f1aecf5860e44141a06144822cb0

SET search_path = public, extensions;


-- The two external references to `posts` follow their rows onto the platform.
--
-- **No data moves.** The backfill preserved every id, so a `post_id` already
-- names a `commerce_contents` row — this is a rename and a new foreign key, and
-- that is the entire payoff for having preserved them.
--
-- `GuestSavedItemType.POST` and `WishlistItemType.POST` are deliberately left
-- alone. Those strings are on the wire, in the shipped client's request bodies
-- and in its parsing, and renaming a wire value to match an internal table is
-- how you break an app to tidy a schema.

-- ── Guest saved items ───────────────────────────────────────────────────────
ALTER TABLE "guest_saved_items"
  DROP CONSTRAINT "guest_saved_items_post_id_fkey";

ALTER TABLE "guest_saved_items"
  RENAME COLUMN "post_id" TO "content_id";

ALTER INDEX "guest_saved_items_post_id_idx"
  RENAME TO "guest_saved_items_content_id_idx";

ALTER TABLE "guest_saved_items"
  ADD CONSTRAINT "guest_saved_items_content_id_fkey"
  FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;

-- ── Wishlist collection items ───────────────────────────────────────────────
ALTER TABLE "wishlist_collection_items"
  DROP CONSTRAINT "wishlist_collection_items_post_id_fkey";

ALTER TABLE "wishlist_collection_items"
  RENAME COLUMN "post_id" TO "content_id";

ALTER INDEX "wishlist_collection_items_collection_id_post_id_key"
  RENAME TO "wishlist_collection_items_collection_id_content_id_key";

ALTER INDEX "wishlist_collection_items_post_id_idx"
  RENAME TO "wishlist_collection_items_content_id_idx";

ALTER TABLE "wishlist_collection_items"
  ADD CONSTRAINT "wishlist_collection_items_content_id_fkey"
  FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id")
  ON DELETE CASCADE ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '4639e84d07105f9ad0c10439212daabab473f1aecf5860e44141a06144822cb0', now(), '20260907040000_repoint_legacy_content_fks', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260907040000_repoint_legacy_content_fks');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
