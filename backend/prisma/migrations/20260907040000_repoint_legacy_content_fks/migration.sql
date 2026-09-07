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
