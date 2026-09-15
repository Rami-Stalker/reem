-- GENERATED from backend/prisma/migrations/20260906190300_content_type_reel_and_audiences/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 5fca4154892f840f13da6a5e12916937fa0a3392f0ffdc0eea309dd30eaf73b3

SET search_path = public, extensions;


-- Formats are registry rows, not code. This adds `reel` and says which
-- formats a customer may publish.
--
-- `audiences` is the gate the authoring service reads. Putting it in data
-- rather than in an `if (isSeller)` means enabling customer reels — or pausing
-- them after a bad week — is a row edit, not a deploy. It also means the
-- composer can build itself from the registry instead of hard-coding a list
-- the server would then have to agree with.

-- ── Reels ───────────────────────────────────────────────────────────────────
-- A content TYPE rather than a publication channel, deliberately. As a type it
-- is served by the (content_type, status, visibility, published_at, id) index
-- as a pure index scan; as a channel it would need array containment inside a
-- partial index, which is both slower and more fragile.
INSERT INTO "commerce_content_type_definitions"
  ("id", "key", "name", "description", "schema", "ui_schema", "capabilities", "lifecycle", "active", "version", "created_at", "updated_at")
VALUES (
  gen_random_uuid(),
  'reel',
  'Reel',
  'Short shoppable video — up to thirty seconds, tagged with what is in it.',
  '{
     "type": "object",
     "required": ["caption"],
     "properties": {
       "caption": { "type": "string" },
       "hashtags": { "type": "array", "items": { "type": "string" } },
       "cta": { "type": "string" }
     }
   }'::jsonb,
  '{ "layout": "reel_editor" }'::jsonb,
  '{
     "supports_product_tags": true,
     "supports_media": true,
     "supports_replies": true,
     "video_required": true,
     "max_duration_seconds": 30,
     "max_media": 1,
     "moderation_required": false,
     "audiences": ["seller", "customer"]
   }'::jsonb,
  '{ "default_channels": ["VIDEO_FEED", "HOME_FEED", "FOLLOWING_FEED", "STORE_FEED"] }'::jsonb,
  TRUE,
  1,
  now(),
  now()
)
ON CONFLICT ("key") DO NOTHING;

-- ── Who may publish which format ────────────────────────────────────────────
-- A shopper gets the three social formats. `flash_offer`, `collection` and
-- `live_stream` stay seller-only: each one makes a commercial claim — a price,
-- a curation, a scheduled event — that only the boutique behind it can honour.
UPDATE "commerce_content_type_definitions"
   SET "capabilities" = COALESCE("capabilities", '{}'::jsonb)
                        || '{"audiences": ["seller", "customer"]}'::jsonb,
       "updated_at" = now()
 WHERE "key" IN ('product_post', 'story', 'reel');

UPDATE "commerce_content_type_definitions"
   SET "capabilities" = COALESCE("capabilities", '{}'::jsonb)
                        || '{"audiences": ["seller"]}'::jsonb,
       "updated_at" = now()
 WHERE "key" IN ('flash_offer', 'collection', 'live_stream');

-- The seeded `product_post` is named for the seller's shoppable post, which is
-- now only half of what it carries. The key stays — it is on rows and in the
-- payloads that reference it — but the label a composer shows should not say
-- "product post" to a woman posting a photograph of herself.
UPDATE "commerce_content_type_definitions"
   SET "name" = 'Post',
       "description" = 'A photo post — a boutique''s look book, or hers.',
       "updated_at" = now()
 WHERE "key" = 'product_post';


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '5fca4154892f840f13da6a5e12916937fa0a3392f0ffdc0eea309dd30eaf73b3', now(), '20260906190300_content_type_reel_and_audiences', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260906190300_content_type_reel_and_audiences');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
