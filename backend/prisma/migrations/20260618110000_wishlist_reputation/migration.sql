-- CreateEnum
CREATE TYPE "WishlistItemType" AS ENUM ('PRODUCT', 'SELLER', 'POST');

-- CreateEnum
CREATE TYPE "WishlistShareVisibility" AS ENUM ('PRIVATE', 'LINK', 'PUBLIC');

-- CreateEnum
CREATE TYPE "ReviewStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'FLAGGED');

-- CreateEnum
CREATE TYPE "ReviewTargetType" AS ENUM ('PRODUCT', 'SELLER');

-- CreateEnum
CREATE TYPE "SellerBadgeType" AS ENUM ('TRUSTED', 'TOP_SELLER', 'FAST_SHIPPER', 'CUSTOMER_LOVED', 'VERIFIED_BRAND');

-- CreateEnum
CREATE TYPE "SellerProgramTier" AS ENUM ('STANDARD', 'RISING', 'TOP', 'ELITE');

-- CreateEnum
CREATE TYPE "TrustVerificationStatus" AS ENUM ('PENDING', 'VERIFIED', 'REJECTED', 'SUSPENDED');

-- CreateTable
CREATE TABLE "seller_favorites" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "seller_favorites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "post_favorites" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "post_id" UUID NOT NULL,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "post_favorites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wishlist_collections" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "description" TEXT,
    "visibility" "WishlistShareVisibility" NOT NULL DEFAULT 'PRIVATE',
    "share_slug" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "wishlist_collections_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "wishlist_collection_items" (
    "id" UUID NOT NULL,
    "collection_id" UUID NOT NULL,
    "type" "WishlistItemType" NOT NULL,
    "product_id" UUID,
    "seller_id" UUID,
    "post_id" UUID,
    "price_when_saved" DOUBLE PRECISION,
    "notify_price_drop" BOOLEAN NOT NULL DEFAULT true,
    "notify_back_in_stock" BOOLEAN NOT NULL DEFAULT true,
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wishlist_collection_items_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "wishlist_collection_items_target_check" CHECK (
        ("type" = 'PRODUCT' AND "product_id" IS NOT NULL AND "seller_id" IS NULL AND "post_id" IS NULL) OR
        ("type" = 'SELLER' AND "product_id" IS NULL AND "seller_id" IS NOT NULL AND "post_id" IS NULL) OR
        ("type" = 'POST' AND "product_id" IS NULL AND "seller_id" IS NULL AND "post_id" IS NOT NULL)
    )
);

-- CreateTable
CREATE TABLE "wishlist_shares" (
    "id" UUID NOT NULL,
    "collection_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "token" TEXT NOT NULL,
    "expires_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "wishlist_shares_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_reviews" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "order_id" UUID,
    "rating" INTEGER NOT NULL,
    "title" TEXT,
    "body" TEXT,
    "verified_purchase" BOOLEAN NOT NULL DEFAULT false,
    "status" "ReviewStatus" NOT NULL DEFAULT 'PENDING',
    "helpful_count" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "product_reviews_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "product_reviews_rating_check" CHECK ("rating" BETWEEN 1 AND 5)
);

-- CreateTable
CREATE TABLE "seller_reviews" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "order_id" UUID,
    "rating" INTEGER NOT NULL,
    "title" TEXT,
    "body" TEXT,
    "verified_purchase" BOOLEAN NOT NULL DEFAULT false,
    "status" "ReviewStatus" NOT NULL DEFAULT 'PENDING',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "seller_reviews_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "seller_reviews_rating_check" CHECK ("rating" BETWEEN 1 AND 5)
);

-- CreateTable
CREATE TABLE "review_moderation_logs" (
    "id" UUID NOT NULL,
    "moderator_id" UUID NOT NULL,
    "target_type" "ReviewTargetType" NOT NULL,
    "product_review_id" UUID,
    "seller_review_id" UUID,
    "from_status" "ReviewStatus",
    "to_status" "ReviewStatus" NOT NULL,
    "reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "review_moderation_logs_pkey" PRIMARY KEY ("id"),
    CONSTRAINT "review_moderation_logs_target_check" CHECK (
        ("target_type" = 'PRODUCT' AND "product_review_id" IS NOT NULL AND "seller_review_id" IS NULL) OR
        ("target_type" = 'SELLER' AND "product_review_id" IS NULL AND "seller_review_id" IS NOT NULL)
    )
);

-- CreateTable
CREATE TABLE "seller_badges" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "type" "SellerBadgeType" NOT NULL,
    "label" TEXT NOT NULL,
    "reason" TEXT,
    "awarded_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "expires_at" TIMESTAMP(3),

    CONSTRAINT "seller_badges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "seller_reputations" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "average_rating" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "reviews_count" INTEGER NOT NULL DEFAULT 0,
    "verified_reviews_count" INTEGER NOT NULL DEFAULT 0,
    "performance_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "customer_satisfaction_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "response_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "fulfillment_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "top_seller_tier" "SellerProgramTier" NOT NULL DEFAULT 'STANDARD',
    "trusted_status" "TrustVerificationStatus" NOT NULL DEFAULT 'PENDING',
    "calculated_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "seller_reputations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trusted_seller_verifications" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "status" "TrustVerificationStatus" NOT NULL DEFAULT 'PENDING',
    "evidence" JSONB,
    "reviewed_by" UUID,
    "reviewed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "trusted_seller_verifications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "seller_favorites_user_id_seller_id_key" ON "seller_favorites"("user_id", "seller_id");

-- CreateIndex
CREATE INDEX "seller_favorites_seller_id_idx" ON "seller_favorites"("seller_id");

-- CreateIndex
CREATE UNIQUE INDEX "post_favorites_user_id_post_id_key" ON "post_favorites"("user_id", "post_id");

-- CreateIndex
CREATE INDEX "post_favorites_post_id_idx" ON "post_favorites"("post_id");

-- CreateIndex
CREATE UNIQUE INDEX "wishlist_collections_share_slug_key" ON "wishlist_collections"("share_slug");

-- CreateIndex
CREATE INDEX "wishlist_collections_user_id_updated_at_idx" ON "wishlist_collections"("user_id", "updated_at");

-- CreateIndex
CREATE UNIQUE INDEX "wishlist_collection_items_collection_id_product_id_key" ON "wishlist_collection_items"("collection_id", "product_id");

-- CreateIndex
CREATE UNIQUE INDEX "wishlist_collection_items_collection_id_seller_id_key" ON "wishlist_collection_items"("collection_id", "seller_id");

-- CreateIndex
CREATE UNIQUE INDEX "wishlist_collection_items_collection_id_post_id_key" ON "wishlist_collection_items"("collection_id", "post_id");

-- CreateIndex
CREATE INDEX "wishlist_collection_items_product_id_idx" ON "wishlist_collection_items"("product_id");

-- CreateIndex
CREATE INDEX "wishlist_collection_items_seller_id_idx" ON "wishlist_collection_items"("seller_id");

-- CreateIndex
CREATE INDEX "wishlist_collection_items_post_id_idx" ON "wishlist_collection_items"("post_id");

-- CreateIndex
CREATE UNIQUE INDEX "wishlist_shares_token_key" ON "wishlist_shares"("token");

-- CreateIndex
CREATE INDEX "wishlist_shares_collection_id_idx" ON "wishlist_shares"("collection_id");

-- CreateIndex
CREATE INDEX "wishlist_shares_user_id_created_at_idx" ON "wishlist_shares"("user_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "product_reviews_product_id_user_id_order_id_key" ON "product_reviews"("product_id", "user_id", "order_id");

-- CreateIndex
CREATE INDEX "product_reviews_product_id_status_created_at_idx" ON "product_reviews"("product_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "product_reviews_user_id_created_at_idx" ON "product_reviews"("user_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "seller_reviews_seller_id_user_id_order_id_key" ON "seller_reviews"("seller_id", "user_id", "order_id");

-- CreateIndex
CREATE INDEX "seller_reviews_seller_id_status_created_at_idx" ON "seller_reviews"("seller_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "seller_reviews_user_id_created_at_idx" ON "seller_reviews"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "review_moderation_logs_moderator_id_created_at_idx" ON "review_moderation_logs"("moderator_id", "created_at");

-- CreateIndex
CREATE INDEX "review_moderation_logs_target_type_created_at_idx" ON "review_moderation_logs"("target_type", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "seller_badges_seller_id_type_key" ON "seller_badges"("seller_id", "type");

-- CreateIndex
CREATE INDEX "seller_badges_seller_id_idx" ON "seller_badges"("seller_id");

-- CreateIndex
CREATE UNIQUE INDEX "seller_reputations_seller_id_key" ON "seller_reputations"("seller_id");

-- CreateIndex
CREATE INDEX "seller_reputations_top_seller_tier_performance_score_idx" ON "seller_reputations"("top_seller_tier", "performance_score");

-- CreateIndex
CREATE UNIQUE INDEX "trusted_seller_verifications_seller_id_key" ON "trusted_seller_verifications"("seller_id");

-- CreateIndex
CREATE INDEX "trusted_seller_verifications_status_created_at_idx" ON "trusted_seller_verifications"("status", "created_at");

-- AddForeignKey
ALTER TABLE "seller_favorites" ADD CONSTRAINT "seller_favorites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_favorites" ADD CONSTRAINT "seller_favorites_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_favorites" ADD CONSTRAINT "post_favorites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "post_favorites" ADD CONSTRAINT "post_favorites_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wishlist_collections" ADD CONSTRAINT "wishlist_collections_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wishlist_collection_items" ADD CONSTRAINT "wishlist_collection_items_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "wishlist_collections"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wishlist_collection_items" ADD CONSTRAINT "wishlist_collection_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wishlist_collection_items" ADD CONSTRAINT "wishlist_collection_items_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wishlist_collection_items" ADD CONSTRAINT "wishlist_collection_items_post_id_fkey" FOREIGN KEY ("post_id") REFERENCES "posts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wishlist_shares" ADD CONSTRAINT "wishlist_shares_collection_id_fkey" FOREIGN KEY ("collection_id") REFERENCES "wishlist_collections"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "wishlist_shares" ADD CONSTRAINT "wishlist_shares_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_reviews" ADD CONSTRAINT "product_reviews_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_reviews" ADD CONSTRAINT "product_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_reviews" ADD CONSTRAINT "seller_reviews_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_reviews" ADD CONSTRAINT "seller_reviews_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "review_moderation_logs" ADD CONSTRAINT "review_moderation_logs_moderator_id_fkey" FOREIGN KEY ("moderator_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "review_moderation_logs" ADD CONSTRAINT "review_moderation_logs_product_review_id_fkey" FOREIGN KEY ("product_review_id") REFERENCES "product_reviews"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "review_moderation_logs" ADD CONSTRAINT "review_moderation_logs_seller_review_id_fkey" FOREIGN KEY ("seller_review_id") REFERENCES "seller_reviews"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_badges" ADD CONSTRAINT "seller_badges_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_reputations" ADD CONSTRAINT "seller_reputations_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trusted_seller_verifications" ADD CONSTRAINT "trusted_seller_verifications_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
