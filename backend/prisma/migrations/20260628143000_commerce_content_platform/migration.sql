-- Universal commerce content platform foundation.
-- Content types are data-driven rows; lifecycle, analytics, media, product tags,
-- and versioning are handled by one extensible content object model.

DO $$ BEGIN
  CREATE TYPE "CommerceContentStatus" AS ENUM (
    'DRAFT',
    'IN_REVIEW',
    'SCHEDULED',
    'PUBLISHED',
    'EXPIRED',
    'ARCHIVED',
    'REJECTED',
    'DELETED'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "CommerceContentVisibility" AS ENUM (
    'PUBLIC',
    'FOLLOWERS',
    'UNLISTED',
    'PRIVATE',
    'CUSTOM'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "CommerceContentModerationStatus" AS ENUM (
    'PENDING',
    'APPROVED',
    'REJECTED',
    'FLAGGED'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "CommerceContentPublicationChannel" AS ENUM (
    'HOME_FEED',
    'FOLLOWING_FEED',
    'TRENDING_FEED',
    'NEARBY_FEED',
    'STORE_FEED',
    'CATEGORY_FEED',
    'PERSONALIZED_FEED',
    'SPONSORED_FEED',
    'VIDEO_FEED',
    'STORY_FEED',
    'COLLECTION_FEED',
    'OFFER_FEED'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE TYPE "CommerceContentAnalyticsEventType" AS ENUM (
    'IMPRESSION',
    'VIEW',
    'WATCH_TIME',
    'ENGAGEMENT',
    'PRODUCT_CLICK',
    'ADD_TO_CART',
    'PURCHASE',
    'SHARE',
    'SAVE',
    'REPLY',
    'REACTION'
  );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS "commerce_content_type_definitions" (
  "id" UUID NOT NULL,
  "key" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "description" TEXT,
  "schema" JSONB NOT NULL,
  "ui_schema" JSONB,
  "capabilities" JSONB,
  "lifecycle" JSONB,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "version" INTEGER NOT NULL DEFAULT 1,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "commerce_content_type_definitions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "commerce_contents" (
  "id" UUID NOT NULL,
  "seller_id" UUID NOT NULL,
  "content_type" TEXT NOT NULL,
  "title" TEXT,
  "body" TEXT,
  "locale" TEXT NOT NULL DEFAULT 'en',
  "status" "CommerceContentStatus" NOT NULL DEFAULT 'DRAFT',
  "visibility" "CommerceContentVisibility" NOT NULL DEFAULT 'PUBLIC',
  "moderation_status" "CommerceContentModerationStatus" NOT NULL DEFAULT 'PENDING',
  "payload" JSONB NOT NULL,
  "metadata" JSONB,
  "publication_targets" "CommerceContentPublicationChannel"[] NOT NULL DEFAULT ARRAY['HOME_FEED']::"CommerceContentPublicationChannel"[],
  "scheduled_at" TIMESTAMP(3),
  "published_at" TIMESTAMP(3),
  "expires_at" TIMESTAMP(3),
  "archived_at" TIMESTAMP(3),
  "pinned_until" TIMESTAMP(3),
  "impressions_count" BIGINT NOT NULL DEFAULT 0,
  "views_count" BIGINT NOT NULL DEFAULT 0,
  "unique_viewers_count" BIGINT NOT NULL DEFAULT 0,
  "engagement_count" BIGINT NOT NULL DEFAULT 0,
  "product_clicks_count" BIGINT NOT NULL DEFAULT 0,
  "orders_count" BIGINT NOT NULL DEFAULT 0,
  "shares_count" BIGINT NOT NULL DEFAULT 0,
  "saves_count" BIGINT NOT NULL DEFAULT 0,
  "replies_count" BIGINT NOT NULL DEFAULT 0,
  "reactions_count" BIGINT NOT NULL DEFAULT 0,
  "watch_time_ms" BIGINT NOT NULL DEFAULT 0,
  "revenue_generated" DOUBLE PRECISION NOT NULL DEFAULT 0,
  "last_engagement_at" TIMESTAMP(3),
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updated_at" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "commerce_contents_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "commerce_content_media" (
  "id" UUID NOT NULL,
  "content_id" UUID NOT NULL,
  "url" TEXT NOT NULL,
  "type" "MediaType" NOT NULL DEFAULT 'image',
  "thumbnail_url" TEXT,
  "streaming_url" TEXT,
  "alt_text" TEXT,
  "blur_hash" TEXT,
  "duration_ms" INTEGER,
  "metadata" JSONB,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "commerce_content_media_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "commerce_content_product_tags" (
  "id" UUID NOT NULL,
  "content_id" UUID NOT NULL,
  "product_id" UUID NOT NULL,
  "variant_id" UUID,
  "role" TEXT NOT NULL DEFAULT 'featured',
  "display_label" TEXT,
  "x" DOUBLE PRECISION,
  "y" DOUBLE PRECISION,
  "target_url" TEXT,
  "metadata" JSONB,
  "sort_order" INTEGER NOT NULL DEFAULT 0,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "commerce_content_product_tags_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "commerce_content_versions" (
  "id" UUID NOT NULL,
  "content_id" UUID NOT NULL,
  "version" INTEGER NOT NULL,
  "snapshot" JSONB NOT NULL,
  "change_note" TEXT,
  "created_by_id" UUID NOT NULL,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "commerce_content_versions_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "commerce_content_events" (
  "id" UUID NOT NULL,
  "content_id" UUID NOT NULL,
  "actor_id" UUID,
  "type" "CommerceContentAnalyticsEventType" NOT NULL,
  "product_id" UUID,
  "value" DOUBLE PRECISION,
  "watch_time_ms" INTEGER,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "commerce_content_events_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "commerce_content_viewers" (
  "id" UUID NOT NULL,
  "content_id" UUID NOT NULL,
  "user_id" UUID NOT NULL,
  "views_count" INTEGER NOT NULL DEFAULT 1,
  "first_viewed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "last_viewed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "commerce_content_viewers_pkey" PRIMARY KEY ("id")
);

CREATE TABLE IF NOT EXISTS "commerce_content_moderation_actions" (
  "id" UUID NOT NULL,
  "content_id" UUID NOT NULL,
  "moderator_id" UUID NOT NULL,
  "from_status" "CommerceContentModerationStatus",
  "to_status" "CommerceContentModerationStatus" NOT NULL,
  "reason" TEXT,
  "metadata" JSONB,
  "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "commerce_content_moderation_actions_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX IF NOT EXISTS "commerce_content_type_definitions_key_key"
ON "commerce_content_type_definitions"("key");
CREATE INDEX IF NOT EXISTS "commerce_content_type_definitions_active_idx"
ON "commerce_content_type_definitions"("active");

CREATE INDEX IF NOT EXISTS "commerce_contents_seller_id_status_created_at_idx"
ON "commerce_contents"("seller_id", "status", "created_at");
CREATE INDEX IF NOT EXISTS "commerce_contents_content_type_status_published_at_idx"
ON "commerce_contents"("content_type", "status", "published_at");
CREATE INDEX IF NOT EXISTS "commerce_contents_status_scheduled_at_idx"
ON "commerce_contents"("status", "scheduled_at");
CREATE INDEX IF NOT EXISTS "commerce_contents_status_expires_at_idx"
ON "commerce_contents"("status", "expires_at");
CREATE INDEX IF NOT EXISTS "commerce_contents_published_at_idx"
ON "commerce_contents"("published_at");

CREATE INDEX IF NOT EXISTS "commerce_content_media_content_id_sort_order_idx"
ON "commerce_content_media"("content_id", "sort_order");

CREATE INDEX IF NOT EXISTS "commerce_content_product_tags_content_id_sort_order_idx"
ON "commerce_content_product_tags"("content_id", "sort_order");
CREATE INDEX IF NOT EXISTS "commerce_content_product_tags_product_id_idx"
ON "commerce_content_product_tags"("product_id");
CREATE INDEX IF NOT EXISTS "commerce_content_product_tags_variant_id_idx"
ON "commerce_content_product_tags"("variant_id");

CREATE UNIQUE INDEX IF NOT EXISTS "commerce_content_versions_content_id_version_key"
ON "commerce_content_versions"("content_id", "version");
CREATE INDEX IF NOT EXISTS "commerce_content_versions_content_id_created_at_idx"
ON "commerce_content_versions"("content_id", "created_at");

CREATE INDEX IF NOT EXISTS "commerce_content_events_content_id_type_created_at_idx"
ON "commerce_content_events"("content_id", "type", "created_at");
CREATE INDEX IF NOT EXISTS "commerce_content_events_actor_id_created_at_idx"
ON "commerce_content_events"("actor_id", "created_at");
CREATE INDEX IF NOT EXISTS "commerce_content_events_product_id_idx"
ON "commerce_content_events"("product_id");

CREATE UNIQUE INDEX IF NOT EXISTS "commerce_content_viewers_content_id_user_id_key"
ON "commerce_content_viewers"("content_id", "user_id");
CREATE INDEX IF NOT EXISTS "commerce_content_viewers_content_id_last_viewed_at_idx"
ON "commerce_content_viewers"("content_id", "last_viewed_at");

CREATE INDEX IF NOT EXISTS "commerce_content_moderation_actions_content_id_created_at_idx"
ON "commerce_content_moderation_actions"("content_id", "created_at");
CREATE INDEX IF NOT EXISTS "commerce_content_moderation_actions_moderator_id_created_at_idx"
ON "commerce_content_moderation_actions"("moderator_id", "created_at");

ALTER TABLE "commerce_contents"
ADD CONSTRAINT "commerce_contents_seller_id_fkey"
FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "commerce_contents"
ADD CONSTRAINT "commerce_contents_content_type_fkey"
FOREIGN KEY ("content_type") REFERENCES "commerce_content_type_definitions"("key") ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "commerce_content_media"
ADD CONSTRAINT "commerce_content_media_content_id_fkey"
FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "commerce_content_product_tags"
ADD CONSTRAINT "commerce_content_product_tags_content_id_fkey"
FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "commerce_content_product_tags"
ADD CONSTRAINT "commerce_content_product_tags_product_id_fkey"
FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "commerce_content_product_tags"
ADD CONSTRAINT "commerce_content_product_tags_variant_id_fkey"
FOREIGN KEY ("variant_id") REFERENCES "product_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "commerce_content_versions"
ADD CONSTRAINT "commerce_content_versions_content_id_fkey"
FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "commerce_content_versions"
ADD CONSTRAINT "commerce_content_versions_created_by_id_fkey"
FOREIGN KEY ("created_by_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "commerce_content_events"
ADD CONSTRAINT "commerce_content_events_content_id_fkey"
FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "commerce_content_events"
ADD CONSTRAINT "commerce_content_events_actor_id_fkey"
FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "commerce_content_events"
ADD CONSTRAINT "commerce_content_events_product_id_fkey"
FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "commerce_content_viewers"
ADD CONSTRAINT "commerce_content_viewers_content_id_fkey"
FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "commerce_content_moderation_actions"
ADD CONSTRAINT "commerce_content_moderation_actions_content_id_fkey"
FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "commerce_content_moderation_actions"
ADD CONSTRAINT "commerce_content_moderation_actions_moderator_id_fkey"
FOREIGN KEY ("moderator_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

INSERT INTO "permissions" ("id", "key", "description", "created_at")
VALUES
  ('10000000-0000-4000-8000-000000000001', 'content:manage', 'Create and manage commerce content objects', CURRENT_TIMESTAMP),
  ('10000000-0000-4000-8000-000000000002', 'content_type:manage', 'Configure universal commerce content types', CURRENT_TIMESTAMP)
ON CONFLICT ("key") DO NOTHING;

WITH pairs AS (
  SELECT
    r."id" AS role_id,
    p."id" AS permission_id,
    md5(r."id"::text || ':' || p."id"::text) AS h
  FROM "roles" r
  JOIN "permissions" p ON p."key" = 'content:manage'
  WHERE r."name" IN ('SUPER_ADMIN', 'OPERATIONS_ADMIN', 'CONTENT_MODERATOR', 'ADMIN', 'SELLER')
)
INSERT INTO "role_permissions" ("id", "role_id", "permission_id")
SELECT
  (
    substr(h, 1, 8) || '-' ||
    substr(h, 9, 4) || '-' ||
    substr(h, 13, 4) || '-' ||
    substr(h, 17, 4) || '-' ||
    substr(h, 21, 12)
  )::uuid,
  role_id,
  permission_id
FROM pairs
ON CONFLICT ("role_id", "permission_id") DO NOTHING;

WITH pairs AS (
  SELECT
    r."id" AS role_id,
    p."id" AS permission_id,
    md5(r."id"::text || ':' || p."id"::text) AS h
  FROM "roles" r
  JOIN "permissions" p ON p."key" = 'content_type:manage'
  WHERE r."name" IN ('SUPER_ADMIN', 'OPERATIONS_ADMIN', 'ADMIN')
)
INSERT INTO "role_permissions" ("id", "role_id", "permission_id")
SELECT
  (
    substr(h, 1, 8) || '-' ||
    substr(h, 9, 4) || '-' ||
    substr(h, 13, 4) || '-' ||
    substr(h, 17, 4) || '-' ||
    substr(h, 21, 12)
  )::uuid,
  role_id,
  permission_id
FROM pairs
ON CONFLICT ("role_id", "permission_id") DO NOTHING;

INSERT INTO "commerce_content_type_definitions" (
  "id",
  "key",
  "name",
  "description",
  "schema",
  "ui_schema",
  "capabilities",
  "lifecycle",
  "active",
  "version",
  "created_at",
  "updated_at"
)
VALUES
  (
    '20000000-0000-4000-8000-000000000001',
    'product_post',
    'Product post',
    'A shoppable seller post centered on one or more products.',
    '{"type":"object","required":["caption"],"properties":{"caption":{"type":"string"},"cta":{"type":"string"},"hashtags":{"type":"array","items":{"type":"string"}}}}'::jsonb,
    '{"layout":"post_editor"}'::jsonb,
    '{"supports_product_tags":true,"supports_media":true,"supports_ai_generation":true,"moderation_required":false}'::jsonb,
    '{"default_channels":["HOME_FEED","STORE_FEED","FOLLOWING_FEED"]}'::jsonb,
    true,
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  ),
  (
    '20000000-0000-4000-8000-000000000002',
    'story',
    'Story',
    'Ephemeral, shoppable story content with product tags and expiry.',
    '{"type":"object","required":["frames"],"properties":{"frames":{"type":"array","items":{"type":"object"}},"template":{"type":"string"},"caption":{"type":"string"}}}'::jsonb,
    '{"layout":"story_editor"}'::jsonb,
    '{"supports_product_tags":true,"supports_media":true,"supports_replies":true,"supports_ai_generation":true,"moderation_required":false}'::jsonb,
    '{"expires_after_hours":24,"default_channels":["STORY_FEED","STORE_FEED"]}'::jsonb,
    true,
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  ),
  (
    '20000000-0000-4000-8000-000000000003',
    'flash_offer',
    'Flash offer',
    'Time-limited promotion with shoppable products and offer-feed ranking.',
    '{"type":"object","required":["headline","discount_label"],"properties":{"headline":{"type":"string"},"discount_label":{"type":"string"},"terms":{"type":"string"},"coupon_code":{"type":"string"}}}'::jsonb,
    '{"layout":"offer_editor"}'::jsonb,
    '{"supports_product_tags":true,"supports_media":true,"supports_scheduling":true,"supports_ai_generation":true,"moderation_required":false}'::jsonb,
    '{"default_channels":["OFFER_FEED","HOME_FEED","STORE_FEED"]}'::jsonb,
    true,
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  ),
  (
    '20000000-0000-4000-8000-000000000004',
    'collection',
    'Collection',
    'Curated product collection for seasonal, category, or campaign moments.',
    '{"type":"object","required":["name"],"properties":{"name":{"type":"string"},"description":{"type":"string"},"theme":{"type":"string"}}}'::jsonb,
    '{"layout":"collection_editor"}'::jsonb,
    '{"supports_product_tags":true,"supports_media":true,"supports_localization":true,"supports_ai_generation":true,"moderation_required":false}'::jsonb,
    '{"default_channels":["COLLECTION_FEED","STORE_FEED","HOME_FEED"]}'::jsonb,
    true,
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  ),
  (
    '20000000-0000-4000-8000-000000000005',
    'live_stream',
    'Live stream',
    'Live commerce event shell with shoppable products and scheduled launch.',
    '{"type":"object","required":["title","starts_at"],"properties":{"title":{"type":"string"},"starts_at":{"type":"string"},"stream_url":{"type":"string"},"description":{"type":"string"}}}'::jsonb,
    '{"layout":"live_editor"}'::jsonb,
    '{"supports_product_tags":true,"supports_scheduling":true,"supports_notifications":true,"moderation_required":true}'::jsonb,
    '{"default_channels":["VIDEO_FEED","HOME_FEED","STORE_FEED"]}'::jsonb,
    true,
    1,
    CURRENT_TIMESTAMP,
    CURRENT_TIMESTAMP
  )
ON CONFLICT ("key") DO NOTHING;
