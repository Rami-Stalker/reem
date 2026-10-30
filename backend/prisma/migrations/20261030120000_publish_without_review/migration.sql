-- Posts, reels and stories now publish straight to the feed for sellers and
-- customers alike; moderation is reactive (reports, the word screen, takedowns
-- from the console). This releases what was still waiting on a moderator so
-- nobody's piece is stuck behind a gate that no longer exists.
--
-- Data only. Formats that are reviewed by definition (`moderation_required`
-- in the registry, e.g. live streams) are left untouched.

-- Waiting for review, still in date: onto the feed (or its schedule).
UPDATE "commerce_contents"
SET
  "status" = CASE
    WHEN "scheduled_at" IS NOT NULL AND "scheduled_at" > NOW()
      THEN 'SCHEDULED'::"CommerceContentStatus"
    ELSE 'PUBLISHED'::"CommerceContentStatus"
  END,
  "moderation_status" = 'APPROVED',
  "published_at" = CASE
    WHEN "scheduled_at" IS NOT NULL AND "scheduled_at" > NOW() THEN NULL
    ELSE COALESCE("published_at", NOW())
  END,
  "updated_at" = NOW()
WHERE "content_type" IN ('product_post', 'reel', 'story')
  AND "status" = 'IN_REVIEW'
  AND ("expires_at" IS NULL OR "expires_at" > NOW());

-- A story whose day ran out while it waited never reached the tray.
UPDATE "commerce_contents"
SET
  "status" = 'EXPIRED',
  "moderation_status" = 'APPROVED',
  "updated_at" = NOW()
WHERE "content_type" IN ('product_post', 'reel', 'story')
  AND "status" = 'IN_REVIEW'
  AND "expires_at" IS NOT NULL
  AND "expires_at" <= NOW();

-- Drafts and live pieces still marked pending would read «قيد المراجعة» to
-- their author for a review that will never come.
UPDATE "commerce_contents"
SET "moderation_status" = 'APPROVED', "updated_at" = NOW()
WHERE "content_type" IN ('product_post', 'reel', 'story')
  AND "moderation_status" IN ('PENDING', 'FLAGGED')
  AND "status" IN ('DRAFT', 'SCHEDULED', 'PUBLISHED');
