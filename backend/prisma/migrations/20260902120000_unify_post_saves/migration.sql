-- One table for "she saved this post".
--
-- `post_favorites` and `post_saves` recorded the same gesture from two
-- different surfaces: the feed card wrote `post_saves` via /posts/:id/save,
-- the wishlist endpoints wrote `post_favorites`. Neither read the other, so a
-- post bookmarked in the feed never reached «منشورات محفوظة», and one saved
-- from the wishlist came back from the feed showing an empty bookmark.
--
-- Rows are moved rather than dropped, duplicates collapse on the unique pair,
-- and `saves_count` is recomputed from the surviving table — it had been
-- incremented by both writers, so a post saved through each route counted two.

INSERT INTO "post_saves" ("id", "post_id", "user_id", "created_at")
SELECT gen_random_uuid(), "post_id", "user_id", "created_at"
FROM "post_favorites"
ON CONFLICT ("post_id", "user_id") DO NOTHING;

UPDATE "posts" p
SET "saves_count" = (
  SELECT COUNT(*) FROM "post_saves" ps WHERE ps."post_id" = p."id"
);

DROP TABLE "post_favorites";
