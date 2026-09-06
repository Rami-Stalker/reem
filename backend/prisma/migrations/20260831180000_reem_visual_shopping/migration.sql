-- Reem Visual Shopping — search and shop by photograph.
--
-- Purely additive: four new enums, four new tables, one new value appended to
-- no existing enum at all. Nothing existing is altered or dropped, so the
-- migration is safe against a live database and safe to leave in place if the
-- feature is never switched on — with no product embeddings indexed, visual
-- search simply reports that it has nothing to compare against.

-- CreateEnum
CREATE TYPE "VisualSearchSource" AS ENUM ('CAMERA', 'GALLERY', 'SCREENSHOT', 'SHARED', 'CATALOG');

-- CreateEnum
CREATE TYPE "VisualSearchStatus" AS ENUM ('PENDING', 'READY', 'FAILED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "VisualRegionDetector" AS ENUM ('WHOLE', 'LAYOUT', 'VISION');

-- CreateEnum
CREATE TYPE "VisualTryOnStatus" AS ENUM ('REQUESTED', 'PROCESSING', 'READY', 'FAILED', 'UNAVAILABLE', 'REVOKED');

-- CreateTable
CREATE TABLE "product_image_embeddings" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "media_url" TEXT NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "embedder" TEXT NOT NULL,
    "dimensions" INTEGER NOT NULL,
    "vector" DOUBLE PRECISION[],
    "palette_keys" TEXT[],
    "pattern" TEXT,
    "source_checksum" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "product_image_embeddings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visual_search_sessions" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "status" "VisualSearchStatus" NOT NULL DEFAULT 'PENDING',
    "source" "VisualSearchSource" NOT NULL DEFAULT 'GALLERY',
    "query_asset_id" UUID,
    "checksum" TEXT NOT NULL,
    "embedder" TEXT NOT NULL,
    "dimensions" INTEGER NOT NULL,
    "vector" DOUBLE PRECISION[],
    "understanding" JSONB,
    "brief" JSONB,
    "refinements" JSONB,
    "refinements_count" INTEGER NOT NULL DEFAULT 0,
    "engine" TEXT,
    "latency_ms" INTEGER,
    "image_expires_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "visual_search_sessions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visual_search_regions" (
    "id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "detector" "VisualRegionDetector" NOT NULL DEFAULT 'WHOLE',
    "slot" "OutfitSlot",
    "label" TEXT NOT NULL,
    "bounding_box" JSONB NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "vector" DOUBLE PRECISION[],
    "palette_keys" TEXT[],
    "position" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "visual_search_regions_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visual_search_results" (
    "id" UUID NOT NULL,
    "session_id" UUID NOT NULL,
    "region_id" UUID,
    "product_id" UUID NOT NULL,
    "offer_id" UUID,
    "matched_media_url" TEXT,
    "similarity" DOUBLE PRECISION NOT NULL,
    "visual_score" DOUBLE PRECISION NOT NULL,
    "attribute_score" DOUBLE PRECISION NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "reason" TEXT NOT NULL,
    "reason_codes" TEXT[],
    "quoted_price_syp" DECIMAL(18,4),
    "feedback" "AiStylistFeedback" NOT NULL DEFAULT 'NONE',
    "feedback_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "visual_search_results_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "visual_try_on_requests" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "session_id" UUID,
    "product_id" UUID NOT NULL,
    "variant_id" UUID,
    "offer_id" UUID,
    "source_asset_id" UUID,
    "result_asset_id" UUID,
    "provider" TEXT NOT NULL DEFAULT 'none',
    "status" "VisualTryOnStatus" NOT NULL DEFAULT 'UNAVAILABLE',
    "failure_code" TEXT,
    "consent_at" TIMESTAMP(3),
    "expires_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "visual_try_on_requests_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "product_image_embeddings_embedder_product_id_idx" ON "product_image_embeddings"("embedder", "product_id");

-- CreateIndex
CREATE INDEX "product_image_embeddings_embedder_updated_at_idx" ON "product_image_embeddings"("embedder", "updated_at");

-- CreateIndex
CREATE UNIQUE INDEX "product_image_embeddings_product_id_media_url_embedder_key" ON "product_image_embeddings"("product_id", "media_url", "embedder");

-- CreateIndex
CREATE INDEX "visual_search_sessions_user_id_created_at_idx" ON "visual_search_sessions"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "visual_search_sessions_status_image_expires_at_idx" ON "visual_search_sessions"("status", "image_expires_at");

-- CreateIndex
CREATE INDEX "visual_search_sessions_user_id_checksum_idx" ON "visual_search_sessions"("user_id", "checksum");

-- CreateIndex
CREATE INDEX "visual_search_regions_session_id_position_idx" ON "visual_search_regions"("session_id", "position");

-- CreateIndex
CREATE INDEX "visual_search_results_session_id_position_idx" ON "visual_search_results"("session_id", "position");

-- CreateIndex
CREATE INDEX "visual_search_results_product_id_idx" ON "visual_search_results"("product_id");

-- CreateIndex
CREATE INDEX "visual_search_results_feedback_idx" ON "visual_search_results"("feedback");

-- CreateIndex
CREATE INDEX "visual_try_on_requests_user_id_created_at_idx" ON "visual_try_on_requests"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "visual_try_on_requests_status_expires_at_idx" ON "visual_try_on_requests"("status", "expires_at");

-- CreateIndex
CREATE INDEX "visual_try_on_requests_product_id_idx" ON "visual_try_on_requests"("product_id");

-- AddForeignKey
ALTER TABLE "product_image_embeddings" ADD CONSTRAINT "product_image_embeddings_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_search_sessions" ADD CONSTRAINT "visual_search_sessions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_search_sessions" ADD CONSTRAINT "visual_search_sessions_query_asset_id_fkey" FOREIGN KEY ("query_asset_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_search_regions" ADD CONSTRAINT "visual_search_regions_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "visual_search_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_search_results" ADD CONSTRAINT "visual_search_results_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "visual_search_sessions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_search_results" ADD CONSTRAINT "visual_search_results_region_id_fkey" FOREIGN KEY ("region_id") REFERENCES "visual_search_regions"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_search_results" ADD CONSTRAINT "visual_search_results_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_try_on_requests" ADD CONSTRAINT "visual_try_on_requests_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_try_on_requests" ADD CONSTRAINT "visual_try_on_requests_session_id_fkey" FOREIGN KEY ("session_id") REFERENCES "visual_search_sessions"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_try_on_requests" ADD CONSTRAINT "visual_try_on_requests_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_try_on_requests" ADD CONSTRAINT "visual_try_on_requests_source_asset_id_fkey" FOREIGN KEY ("source_asset_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "visual_try_on_requests" ADD CONSTRAINT "visual_try_on_requests_result_asset_id_fkey" FOREIGN KEY ("result_asset_id") REFERENCES "media_assets"("id") ON DELETE SET NULL ON UPDATE CASCADE;
