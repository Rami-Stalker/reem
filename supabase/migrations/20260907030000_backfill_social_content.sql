-- GENERATED from backend/prisma/migrations/20260907030000_backfill_social_content/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: e586c07f71468db4550f20deab149163fc8fb9a1753f3662ab087242759494c6

SET search_path = public, extensions;


-- Legacy `posts` and `stories` become `commerce_contents`.
--
-- **Every id is preserved.** A post's id becomes its content id, a like's id
-- becomes its reaction id, and so on. Two things follow, and both are the
-- reason for doing it this way:
--
--   1. `guest_saved_items.post_id` and `wishlist_collection_items.post_id` —
--      the only external references to `posts` — need no data movement at all.
--      Re-pointing them is a rename plus a foreign key.
--   2. Every statement below is re-runnable. `ON CONFLICT DO NOTHING` makes the
--      whole migration idempotent, so it runs again as a catch-up pass
--      immediately after the cutover release to pick up the likes and comments
--      written during the window. Without that, engagement in those minutes is
--      simply lost.
--
-- A uuid4 colliding with an existing content id is not a practical risk, and
-- the primary key would fail loudly rather than silently merge two rows.

-- ── Posts ───────────────────────────────────────────────────────────────────
-- `payload.legacy` is the marker that makes this migration reversible: the
-- rows it created are exactly those where it is set.
INSERT INTO "commerce_contents" (
  "id", "author_id", "author_kind", "author_is_public", "content_type",
  "body", "locale", "status", "visibility", "moderation_status", "payload",
  "publication_targets", "published_at",
  "reactions_count", "replies_count", "shares_count", "saves_count",
  "engagement_count", "created_at", "updated_at"
)
SELECT
  p."id",
  p."author_id",
  CASE u."role"
    WHEN 'CUSTOMER' THEN 'CUSTOMER'::"CommerceAuthorKind"
    WHEN 'SELLER'   THEN 'SELLER'::"CommerceAuthorKind"
    ELSE 'PLATFORM'::"CommerceAuthorKind"
  END,
  u."profile_is_public",
  'product_post',
  p."caption",
  'ar',
  'PUBLISHED'::"CommerceContentStatus",
  'PUBLIC'::"CommerceContentVisibility",
  'APPROVED'::"CommerceContentModerationStatus",
  jsonb_build_object('caption', p."caption", 'legacy', 'post'),
  ARRAY['HOME_FEED','STORE_FEED','FOLLOWING_FEED']::"CommerceContentPublicationChannel"[],
  p."created_at",
  p."likes_count",
  p."comments_count",
  p."shares_count",
  p."saves_count",
  p."likes_count" + p."comments_count" + p."saves_count",
  p."created_at",
  p."created_at"
FROM "posts" p
JOIN "users" u ON u."id" = p."author_id"
ON CONFLICT ("id") DO NOTHING;

-- The one tagged product becomes a product tag. A legacy post carries at most
-- one, so reusing the post id as the tag id is safe and keeps the statement
-- re-runnable.
INSERT INTO "commerce_content_product_tags"
  ("id", "content_id", "product_id", "role", "sort_order", "basis", "created_at")
SELECT p."id", p."id", p."product_id", 'featured', 0, 'SELLER_OFFER'::"ContentTagBasis", p."created_at"
FROM "posts" p
WHERE p."product_id" IS NOT NULL
ON CONFLICT ("id") DO NOTHING;

-- ── Stories ─────────────────────────────────────────────────────────────────
-- An expired story is migrated as EXPIRED rather than skipped: its views and
-- reactions are the boutique's analytics history, and dropping the parent to
-- save a row would orphan them.
INSERT INTO "commerce_contents" (
  "id", "author_id", "author_kind", "author_is_public", "content_type",
  "locale", "status", "visibility", "moderation_status", "payload",
  "publication_targets", "published_at", "expires_at", "created_at", "updated_at"
)
SELECT
  s."id",
  s."user_id",
  CASE u."role"
    WHEN 'CUSTOMER' THEN 'CUSTOMER'::"CommerceAuthorKind"
    WHEN 'SELLER'   THEN 'SELLER'::"CommerceAuthorKind"
    ELSE 'PLATFORM'::"CommerceAuthorKind"
  END,
  u."profile_is_public",
  'story',
  'ar',
  (CASE WHEN s."expires_at" > now() THEN 'PUBLISHED' ELSE 'EXPIRED' END)::"CommerceContentStatus",
  'PUBLIC'::"CommerceContentVisibility",
  'APPROVED'::"CommerceContentModerationStatus",
  jsonb_build_object(
    'frames', jsonb_build_array(
      jsonb_build_object('media_url', s."media_url", 'link', s."link")
    ),
    'legacy', 'story'
  ),
  ARRAY['STORY_FEED','STORE_FEED']::"CommerceContentPublicationChannel"[],
  s."created_at",
  s."expires_at",
  s."created_at",
  s."created_at"
FROM "stories" s
JOIN "users" u ON u."id" = s."user_id"
ON CONFLICT ("id") DO NOTHING;

INSERT INTO "commerce_content_media"
  ("id", "content_id", "url", "type", "sort_order", "created_at")
SELECT s."id", s."id", s."media_url", s."media_type", 0, s."created_at"
FROM "stories" s
ON CONFLICT ("id") DO NOTHING;

-- The product a story pointed at was parsed out of a free-text `link` by a
-- regex in `stories.service.ts`. It becomes a real relation here, which is what
-- retires that regex.
INSERT INTO "commerce_content_product_tags"
  ("id", "content_id", "product_id", "role", "sort_order", "basis", "created_at")
SELECT gen_random_uuid(), s."id", pr."id", 'featured', 0, 'SELLER_OFFER'::"ContentTagBasis", s."created_at"
FROM "stories" s
JOIN LATERAL (
  SELECT (regexp_match(
    s."link",
    '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
  ))[1] AS uid
) m ON TRUE
JOIN "products" pr ON pr."id" = m.uid::uuid
WHERE s."link" IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM "commerce_content_product_tags" t
     WHERE t."content_id" = s."id" AND t."product_id" = pr."id"
  );

-- ── Engagement ──────────────────────────────────────────────────────────────
-- `post_likes` has NO `created_at` column, so the post's own timestamp stands
-- in. It is the closest true statement available: the like happened at or
-- after the post, and inventing `now()` would date every historical like to
-- the migration.
INSERT INTO "commerce_content_reactions"
  ("id", "content_id", "user_id", "kind", "emoji", "created_at")
SELECT pl."id", pl."post_id", pl."user_id", 'LIKE'::"CommerceContentReactionKind", NULL, p."created_at"
FROM "post_likes" pl
JOIN "posts" p ON p."id" = pl."post_id"
ON CONFLICT ("id") DO NOTHING;

INSERT INTO "commerce_content_reactions"
  ("id", "content_id", "user_id", "kind", "emoji", "created_at")
SELECT sr."id", sr."story_id", sr."user_id", 'EMOJI'::"CommerceContentReactionKind", sr."emoji", sr."created_at"
FROM "story_reactions" sr
ON CONFLICT ("id") DO NOTHING;

INSERT INTO "commerce_content_saves" ("id", "content_id", "user_id", "created_at")
SELECT ps."id", ps."post_id", ps."user_id", ps."created_at"
FROM "post_saves" ps
ON CONFLICT ("id") DO NOTHING;

-- Flat, because `comments` is flat. Nothing is invented: a legacy comment has
-- no parent because it never had one.
INSERT INTO "commerce_content_comments"
  ("id", "content_id", "user_id", "parent_id", "body", "replies_count", "status", "created_at", "updated_at")
SELECT c."id", c."post_id", c."user_id", NULL, c."content", 0,
       'VISIBLE'::"CommerceContentCommentStatus", c."created_at", c."created_at"
FROM "comments" c
ON CONFLICT ("id") DO NOTHING;

INSERT INTO "commerce_content_viewers"
  ("id", "content_id", "user_id", "views_count", "first_viewed_at", "last_viewed_at")
SELECT sv."id", sv."story_id", sv."user_id", 1, sv."viewed_at", sv."viewed_at"
FROM "story_views" sv
ON CONFLICT ("content_id", "user_id") DO NOTHING;

-- Stories carried their view and reaction counts in the child tables only.
UPDATE "commerce_contents" c
   SET "views_count" = counts.views,
       "unique_viewers_count" = counts.views,
       "reactions_count" = counts.reactions,
       "engagement_count" = counts.reactions
  FROM (
    SELECT s."id",
           (SELECT count(*) FROM "story_views" v WHERE v."story_id" = s."id") AS views,
           (SELECT count(*) FROM "story_reactions" r WHERE r."story_id" = s."id") AS reactions
      FROM "stories" s
  ) counts
 WHERE c."id" = counts."id";

-- ── Attribution ─────────────────────────────────────────────────────────────
-- The projection, for everything that now exists.
--
-- Note the shape: `gen_random_uuid()` sits OUTSIDE the DISTINCT. Written the
-- obvious way — `SELECT DISTINCT gen_random_uuid(), …` — every row is unique by
-- construction and the DISTINCT silently does nothing, which would double every
-- boutique's credit for a post tagging two of its products.
INSERT INTO "commerce_content_attributions"
  ("id", "content_id", "seller_id", "source", "product_id", "actor_id", "created_at")
SELECT gen_random_uuid(), x.content_id, x.seller_id, x.source, x.product_id, x.actor_id, x.created_at
FROM (
  SELECT c."id" AS content_id, c."author_id" AS seller_id,
         'AUTHOR'::"CommerceAttributionSource" AS source,
         NULL::uuid AS product_id, c."author_id" AS actor_id, c."created_at" AS created_at
    FROM "commerce_contents" c
   WHERE c."author_kind" = 'SELLER'
  UNION
  SELECT DISTINCT c."id", o."seller_id",
         'PRODUCT_TAG'::"CommerceAttributionSource",
         t."product_id", c."author_id", c."created_at"
    FROM "commerce_contents" c
    JOIN "commerce_content_product_tags" t ON t."content_id" = c."id"
    JOIN "seller_offers" o ON o."product_id" = t."product_id"
                          AND o."status" = 'ACTIVE' AND o."is_active"
   WHERE o."seller_id" <> c."author_id"
) x
WHERE NOT EXISTS (
  SELECT 1 FROM "commerce_content_attributions" a
   WHERE a."content_id" = x.content_id
     AND a."seller_id" = x.seller_id
     AND a."source" = x.source
     AND a."product_id" IS NOT DISTINCT FROM x.product_id
);


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'e586c07f71468db4550f20deab149163fc8fb9a1753f3662ab087242759494c6', now(), '20260907030000_backfill_social_content', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260907030000_backfill_social_content');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
