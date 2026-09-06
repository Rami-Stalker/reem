-- CreateEnum
CREATE TYPE "MarketSubject" AS ENUM ('PRODUCT', 'CATEGORY', 'SLOT');

-- CreateEnum
CREATE TYPE "MarketFinding" AS ENUM ('SUPPLY_GAP', 'OVERSUPPLIED', 'RISING', 'COOLING', 'WEAK_CONVERSION', 'CROWDED', 'STOCKED_OUT');

-- CreateEnum
CREATE TYPE "DropStatus" AS ENUM ('DRAFT', 'SCHEDULED', 'LIVE', 'ENDED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "DropAudience" AS ENUM ('EVERYONE', 'EARLY_ACCESS', 'INVITE_ONLY');

-- CreateEnum
CREATE TYPE "BundleStatus" AS ENUM ('GENERATED', 'CURATED', 'RETIRED');

-- CreateEnum
CREATE TYPE "ResaleStatus" AS ENUM ('DRAFT', 'LISTED', 'RESERVED', 'SOLD', 'WITHDRAWN');

-- CreateEnum
CREATE TYPE "ResaleCondition" AS ENUM ('NEW_WITH_TAGS', 'EXCELLENT', 'GOOD', 'FAIR');

-- CreateEnum
CREATE TYPE "MissionKind" AS ENUM ('DISCOVER', 'CONTRIBUTE', 'COMPLETE', 'SHARE');

-- CreateEnum
CREATE TYPE "MissionStatus" AS ENUM ('OFFERED', 'ACTIVE', 'COMPLETED', 'EXPIRED');

-- CreateTable
CREATE TABLE "market_signals" (
    "id" UUID NOT NULL,
    "subject_type" "MarketSubject" NOT NULL,
    "subject_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "demand_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "supply_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "conversion_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "competition" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "tension" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "price_index_bps" INTEGER,
    "components" JSONB NOT NULL,
    "findings" JSONB NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "market_signals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "drops" (
    "id" UUID NOT NULL,
    "seller_id" UUID,
    "title" TEXT NOT NULL,
    "note" TEXT,
    "status" "DropStatus" NOT NULL DEFAULT 'DRAFT',
    "audience" "DropAudience" NOT NULL DEFAULT 'EVERYONE',
    "early_access_at" TIMESTAMP(3),
    "starts_at" TIMESTAMP(3) NOT NULL,
    "ends_at" TIMESTAMP(3),
    "rationale" JSONB,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "drops_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "drop_products" (
    "id" UUID NOT NULL,
    "drop_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "reason" JSONB,

    CONSTRAINT "drop_products_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "drop_invites" (
    "id" UUID NOT NULL,
    "drop_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "reason" JSONB NOT NULL,
    "affinity" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "notified_at" TIMESTAMP(3),
    "opened_at" TIMESTAMP(3),
    "converted_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "drop_invites_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bundles" (
    "id" UUID NOT NULL,
    "fingerprint" TEXT NOT NULL,
    "title" TEXT NOT NULL,
    "occasion" TEXT,
    "status" "BundleStatus" NOT NULL DEFAULT 'GENERATED',
    "total_syp" DECIMAL(18,4) NOT NULL,
    "seller_count" INTEGER NOT NULL DEFAULT 1,
    "score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "slots" TEXT[],
    "basis" JSONB,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "bundles_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "bundle_items" (
    "id" UUID NOT NULL,
    "bundle_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "offer_id" UUID,
    "slot" TEXT,
    "position" INTEGER NOT NULL DEFAULT 0,
    "reason" TEXT,

    CONSTRAINT "bundle_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "resale_listings" (
    "id" UUID NOT NULL,
    "closet_item_id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "product_id" UUID,
    "title" TEXT NOT NULL,
    "note" TEXT,
    "condition" "ResaleCondition" NOT NULL,
    "status" "ResaleStatus" NOT NULL DEFAULT 'DRAFT',
    "price_syp" DECIMAL(18,4) NOT NULL,
    "original_price_syp" DECIMAL(18,4),
    "listed_at" TIMESTAMP(3),
    "sold_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "resale_listings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "missions" (
    "id" UUID NOT NULL,
    "key" TEXT NOT NULL,
    "kind" "MissionKind" NOT NULL,
    "title_ar" TEXT NOT NULL,
    "body_ar" TEXT NOT NULL,
    "criteria" JSONB NOT NULL,
    "value_points" INTEGER NOT NULL DEFAULT 0,
    "ttl_days" INTEGER NOT NULL DEFAULT 14,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "missions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "mission_progress" (
    "id" UUID NOT NULL,
    "mission_id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "MissionStatus" NOT NULL DEFAULT 'OFFERED',
    "progress" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "evidence" JSONB,
    "offered_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completed_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3),

    CONSTRAINT "mission_progress_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "market_signals_subject_type_day_tension_idx" ON "market_signals"("subject_type", "day", "tension");

-- CreateIndex
CREATE INDEX "market_signals_subject_id_day_idx" ON "market_signals"("subject_id", "day");

-- CreateIndex
CREATE UNIQUE INDEX "market_signals_subject_type_subject_id_day_key" ON "market_signals"("subject_type", "subject_id", "day");

-- CreateIndex
CREATE INDEX "drops_status_starts_at_idx" ON "drops"("status", "starts_at");

-- CreateIndex
CREATE INDEX "drops_seller_id_status_idx" ON "drops"("seller_id", "status");

-- CreateIndex
CREATE INDEX "drop_products_drop_id_position_idx" ON "drop_products"("drop_id", "position");

-- CreateIndex
CREATE UNIQUE INDEX "drop_products_drop_id_product_id_key" ON "drop_products"("drop_id", "product_id");

-- CreateIndex
CREATE INDEX "drop_invites_user_id_created_at_idx" ON "drop_invites"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "drop_invites_drop_id_affinity_idx" ON "drop_invites"("drop_id", "affinity");

-- CreateIndex
CREATE UNIQUE INDEX "drop_invites_drop_id_user_id_key" ON "drop_invites"("drop_id", "user_id");

-- CreateIndex
CREATE UNIQUE INDEX "bundles_fingerprint_key" ON "bundles"("fingerprint");

-- CreateIndex
CREATE INDEX "bundles_status_score_idx" ON "bundles"("status", "score");

-- CreateIndex
CREATE INDEX "bundles_occasion_score_idx" ON "bundles"("occasion", "score");

-- CreateIndex
CREATE INDEX "bundle_items_bundle_id_position_idx" ON "bundle_items"("bundle_id", "position");

-- CreateIndex
CREATE UNIQUE INDEX "bundle_items_bundle_id_product_id_key" ON "bundle_items"("bundle_id", "product_id");

-- CreateIndex
CREATE UNIQUE INDEX "resale_listings_closet_item_id_key" ON "resale_listings"("closet_item_id");

-- CreateIndex
CREATE INDEX "resale_listings_status_listed_at_idx" ON "resale_listings"("status", "listed_at");

-- CreateIndex
CREATE INDEX "resale_listings_seller_id_status_idx" ON "resale_listings"("seller_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "missions_key_key" ON "missions"("key");

-- CreateIndex
CREATE INDEX "missions_is_active_kind_idx" ON "missions"("is_active", "kind");

-- CreateIndex
CREATE INDEX "mission_progress_user_id_status_idx" ON "mission_progress"("user_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "mission_progress_mission_id_user_id_key" ON "mission_progress"("mission_id", "user_id");

-- AddForeignKey
ALTER TABLE "drops" ADD CONSTRAINT "drops_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "drop_products" ADD CONSTRAINT "drop_products_drop_id_fkey" FOREIGN KEY ("drop_id") REFERENCES "drops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "drop_products" ADD CONSTRAINT "drop_products_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "drop_invites" ADD CONSTRAINT "drop_invites_drop_id_fkey" FOREIGN KEY ("drop_id") REFERENCES "drops"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "drop_invites" ADD CONSTRAINT "drop_invites_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bundle_items" ADD CONSTRAINT "bundle_items_bundle_id_fkey" FOREIGN KEY ("bundle_id") REFERENCES "bundles"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bundle_items" ADD CONSTRAINT "bundle_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "bundle_items" ADD CONSTRAINT "bundle_items_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resale_listings" ADD CONSTRAINT "resale_listings_closet_item_id_fkey" FOREIGN KEY ("closet_item_id") REFERENCES "closet_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resale_listings" ADD CONSTRAINT "resale_listings_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "resale_listings" ADD CONSTRAINT "resale_listings_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mission_progress" ADD CONSTRAINT "mission_progress_mission_id_fkey" FOREIGN KEY ("mission_id") REFERENCES "missions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "mission_progress" ADD CONSTRAINT "mission_progress_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
