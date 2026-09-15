-- GENERATED from backend/prisma/migrations/20260906190200_social_platform_tables/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: d2ff87d476b72a91110af5a9e361eb21cdb3ce28b6755ed94c6666b8bd18c865

SET search_path = public, extensions;


-- The social half of the content platform: the interaction rows a feed cannot
-- work without, the reshare edge behind "add to my page", and the attribution
-- projection a boutique reads to find the women promoting it.
--
-- Additive and fully reversible. Nothing here is read until the services that
-- own it ship.

-- CreateEnum
CREATE TYPE "CommerceContentReactionKind" AS ENUM ('LIKE', 'EMOJI');

-- CreateEnum
CREATE TYPE "CommerceContentCommentStatus" AS ENUM ('VISIBLE', 'REMOVED');

-- CreateEnum
CREATE TYPE "ContentTagBasis" AS ENUM ('SELLER_OFFER', 'PURCHASE', 'ADMIN');

-- CreateEnum
CREATE TYPE "CommerceAttributionSource" AS ENUM ('AUTHOR', 'PRODUCT_TAG', 'RESHARE');

-- AlterTable
ALTER TABLE "commerce_content_product_tags" ADD COLUMN     "basis" "ContentTagBasis" NOT NULL DEFAULT 'SELLER_OFFER',
ADD COLUMN     "source_order_item_id" UUID;

-- CreateTable
CREATE TABLE "commerce_content_reactions" (
    "id" UUID NOT NULL,
    "content_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "kind" "CommerceContentReactionKind" NOT NULL DEFAULT 'LIKE',
    "emoji" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "commerce_content_reactions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "commerce_content_saves" (
    "id" UUID NOT NULL,
    "content_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "commerce_content_saves_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "commerce_content_comments" (
    "id" UUID NOT NULL,
    "content_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "parent_id" UUID,
    "body" TEXT NOT NULL,
    "replies_count" INTEGER NOT NULL DEFAULT 0,
    "status" "CommerceContentCommentStatus" NOT NULL DEFAULT 'VISIBLE',
    "removed_at" TIMESTAMP(3),
    "removed_by_id" UUID,
    "removal_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "commerce_content_comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "commerce_content_reshares" (
    "id" UUID NOT NULL,
    "source_content_id" UUID NOT NULL,
    "resharer_id" UUID NOT NULL,
    "source_author_id" UUID NOT NULL,
    "via_reshare_id" UUID,
    "note" TEXT,
    "visibility" "CommerceContentVisibility" NOT NULL DEFAULT 'PUBLIC',
    "resharer_is_public" BOOLEAN NOT NULL DEFAULT false,
    "campaign_key" TEXT,
    "coupon_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "commerce_content_reshares_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "commerce_content_attributions" (
    "id" UUID NOT NULL,
    "content_id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "source" "CommerceAttributionSource" NOT NULL,
    "product_id" UUID,
    "reshare_id" UUID,
    "actor_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "commerce_content_attributions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "commerce_content_reactions_user_id_content_id_idx" ON "commerce_content_reactions"("user_id", "content_id");

-- CreateIndex
CREATE INDEX "commerce_content_reactions_content_id_created_at_idx" ON "commerce_content_reactions"("content_id", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "commerce_content_reactions_content_id_user_id_key" ON "commerce_content_reactions"("content_id", "user_id");

-- CreateIndex
CREATE INDEX "commerce_content_saves_user_id_content_id_idx" ON "commerce_content_saves"("user_id", "content_id");

-- CreateIndex
CREATE INDEX "commerce_content_saves_user_id_created_at_idx" ON "commerce_content_saves"("user_id", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "commerce_content_saves_content_id_user_id_key" ON "commerce_content_saves"("content_id", "user_id");

-- CreateIndex
CREATE INDEX "commerce_content_comments_content_id_parent_id_created_at_idx" ON "commerce_content_comments"("content_id", "parent_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "commerce_content_comments_user_id_created_at_idx" ON "commerce_content_comments"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "commerce_content_reshares_resharer_id_created_at_id_idx" ON "commerce_content_reshares"("resharer_id", "created_at" DESC, "id" DESC);

-- CreateIndex
CREATE INDEX "commerce_content_reshares_source_author_id_created_at_idx" ON "commerce_content_reshares"("source_author_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "commerce_content_reshares_source_content_id_created_at_idx" ON "commerce_content_reshares"("source_content_id", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "commerce_content_reshares_source_content_id_resharer_id_key" ON "commerce_content_reshares"("source_content_id", "resharer_id");

-- CreateIndex
CREATE INDEX "commerce_content_attributions_seller_id_source_created_at_idx" ON "commerce_content_attributions"("seller_id", "source", "created_at" DESC);

-- CreateIndex
CREATE INDEX "commerce_content_attributions_seller_id_product_id_created__idx" ON "commerce_content_attributions"("seller_id", "product_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "commerce_content_attributions_seller_id_actor_id_idx" ON "commerce_content_attributions"("seller_id", "actor_id");

-- CreateIndex
CREATE INDEX "commerce_content_attributions_content_id_idx" ON "commerce_content_attributions"("content_id");

-- CreateIndex
CREATE INDEX "commerce_content_product_tags_product_id_created_at_idx" ON "commerce_content_product_tags"("product_id", "created_at" DESC);

-- CreateIndex
CREATE UNIQUE INDEX "commerce_content_product_tags_content_id_source_order_item__key" ON "commerce_content_product_tags"("content_id", "source_order_item_id");

-- CreateIndex
CREATE INDEX "commerce_content_viewers_user_id_content_id_idx" ON "commerce_content_viewers"("user_id", "content_id");

-- AddForeignKey
ALTER TABLE "commerce_content_product_tags" ADD CONSTRAINT "commerce_content_product_tags_source_order_item_id_fkey" FOREIGN KEY ("source_order_item_id") REFERENCES "order_items"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_reactions" ADD CONSTRAINT "commerce_content_reactions_content_id_fkey" FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_reactions" ADD CONSTRAINT "commerce_content_reactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_saves" ADD CONSTRAINT "commerce_content_saves_content_id_fkey" FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_saves" ADD CONSTRAINT "commerce_content_saves_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_comments" ADD CONSTRAINT "commerce_content_comments_content_id_fkey" FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_comments" ADD CONSTRAINT "commerce_content_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_comments" ADD CONSTRAINT "commerce_content_comments_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "commerce_content_comments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_comments" ADD CONSTRAINT "commerce_content_comments_removed_by_id_fkey" FOREIGN KEY ("removed_by_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_reshares" ADD CONSTRAINT "commerce_content_reshares_source_content_id_fkey" FOREIGN KEY ("source_content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_reshares" ADD CONSTRAINT "commerce_content_reshares_resharer_id_fkey" FOREIGN KEY ("resharer_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_reshares" ADD CONSTRAINT "commerce_content_reshares_source_author_id_fkey" FOREIGN KEY ("source_author_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_reshares" ADD CONSTRAINT "commerce_content_reshares_via_reshare_id_fkey" FOREIGN KEY ("via_reshare_id") REFERENCES "commerce_content_reshares"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_reshares" ADD CONSTRAINT "commerce_content_reshares_coupon_id_fkey" FOREIGN KEY ("coupon_id") REFERENCES "coupons"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_attributions" ADD CONSTRAINT "commerce_content_attributions_content_id_fkey" FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_attributions" ADD CONSTRAINT "commerce_content_attributions_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_attributions" ADD CONSTRAINT "commerce_content_attributions_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_attributions" ADD CONSTRAINT "commerce_content_attributions_reshare_id_fkey" FOREIGN KEY ("reshare_id") REFERENCES "commerce_content_reshares"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commerce_content_attributions" ADD CONSTRAINT "commerce_content_attributions_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- ── Two indexes Prisma cannot express, and one constraint ──────────────────
-- Both are annotated in `schema.prisma` beside the model. Do not "clean them
-- up" because they are absent from the Prisma index list: the schema language
-- has no syntax for either.

-- The public feed's driving index. Partial, so it holds only the rows any feed
-- can ever return — a small index that carries the entire ORDER BY, instead of
-- a large one that filters after the sort.
CREATE INDEX "commerce_contents_public_feed_idx"
  ON "commerce_contents"("published_at" DESC, "id" DESC)
  WHERE "status" = 'PUBLISHED' AND "visibility" = 'PUBLIC' AND "author_is_public";

-- For the narrow channels (offers, collections) where the array membership is
-- the selective term rather than the recency.
CREATE INDEX "commerce_contents_publication_targets_gin"
  ON "commerce_contents" USING GIN ("publication_targets");

-- A takedown must say why. Expressed as a CHECK rather than NOT NULL because
-- *approving* content genuinely has no reason to give, and a column that is
-- mandatory for three of four outcomes cannot be modelled by nullability.
-- NOT VALID so the rows written before the policy existed are not retro-judged.
ALTER TABLE "commerce_content_moderation_actions"
  ADD CONSTRAINT "commerce_content_moderation_actions_reason_required"
  CHECK ("to_status" = 'APPROVED' OR ("reason" IS NOT NULL AND length(btrim("reason")) >= 10))
  NOT VALID;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, 'd2ff87d476b72a91110af5a9e361eb21cdb3ce28b6755ed94c6666b8bd18c865', now(), '20260906190200_social_platform_tables', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260906190200_social_platform_tables');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
