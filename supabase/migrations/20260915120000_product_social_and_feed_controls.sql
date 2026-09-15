-- GENERATED from backend/prisma/migrations/20260915120000_product_social_and_feed_controls/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 787925fe5ed1a0287e69be3598b070f2b9935efebbd8195e118993930050203f

SET search_path = public, extensions;


-- Product social, and a feed she can tune.
--
-- The client asked for every product in the app to carry what a post carries:
-- a heart, a comment thread, a share count and «أضيفي إلى صفحتي». Until now a
-- product could only be favourited, which is a private shelf rather than a
-- public gesture. Counters live on `products` beside `favorites_count` and are
-- moved in the same transaction as the row that justifies them.
--
-- `content_hides` and `user_mutes` back the post menu: «غير مهتمة» removes one
-- piece from her feeds, «إخفاء منشورات هذا الحساب» removes an account's. Both
-- are private to her — nobody is notified and no moderation queue is touched.
--
-- Additive only: four defaulted columns and five new tables.

-- AlterTable
ALTER TABLE "products" ADD COLUMN     "comments_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "likes_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "picks_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "shares_count" INTEGER NOT NULL DEFAULT 0;

-- CreateTable
CREATE TABLE "product_likes" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_likes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_comments" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "body" TEXT NOT NULL,
    "status" "CommerceContentCommentStatus" NOT NULL DEFAULT 'VISIBLE',
    "removed_by_id" UUID,
    "removal_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "product_comments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_picks" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "note" VARCHAR(280),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_picks_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "content_hides" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "content_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "content_hides_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_mutes" (
    "id" UUID NOT NULL,
    "muter_id" UUID NOT NULL,
    "muted_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_mutes_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "product_likes_user_id_product_id_idx" ON "product_likes"("user_id", "product_id");

-- CreateIndex
CREATE UNIQUE INDEX "product_likes_product_id_user_id_key" ON "product_likes"("product_id", "user_id");

-- CreateIndex
CREATE INDEX "product_comments_product_id_status_created_at_idx" ON "product_comments"("product_id", "status", "created_at" DESC);

-- CreateIndex
CREATE INDEX "product_comments_user_id_idx" ON "product_comments"("user_id");

-- CreateIndex
CREATE INDEX "product_picks_user_id_created_at_idx" ON "product_picks"("user_id", "created_at" DESC);

-- CreateIndex
CREATE INDEX "product_picks_product_id_idx" ON "product_picks"("product_id");

-- CreateIndex
CREATE UNIQUE INDEX "product_picks_user_id_product_id_key" ON "product_picks"("user_id", "product_id");

-- CreateIndex
CREATE INDEX "content_hides_content_id_idx" ON "content_hides"("content_id");

-- CreateIndex
CREATE UNIQUE INDEX "content_hides_user_id_content_id_key" ON "content_hides"("user_id", "content_id");

-- CreateIndex
CREATE INDEX "user_mutes_muted_id_idx" ON "user_mutes"("muted_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_mutes_muter_id_muted_id_key" ON "user_mutes"("muter_id", "muted_id");

-- AddForeignKey
ALTER TABLE "product_likes" ADD CONSTRAINT "product_likes_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_likes" ADD CONSTRAINT "product_likes_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_comments" ADD CONSTRAINT "product_comments_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_comments" ADD CONSTRAINT "product_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_picks" ADD CONSTRAINT "product_picks_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_picks" ADD CONSTRAINT "product_picks_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "content_hides" ADD CONSTRAINT "content_hides_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "content_hides" ADD CONSTRAINT "content_hides_content_id_fkey" FOREIGN KEY ("content_id") REFERENCES "commerce_contents"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_mutes" ADD CONSTRAINT "user_mutes_muter_id_fkey" FOREIGN KEY ("muter_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_mutes" ADD CONSTRAINT "user_mutes_muted_id_fkey" FOREIGN KEY ("muted_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '787925fe5ed1a0287e69be3598b070f2b9935efebbd8195e118993930050203f', now(), '20260915120000_product_social_and_feed_controls', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260915120000_product_social_and_feed_controls');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
