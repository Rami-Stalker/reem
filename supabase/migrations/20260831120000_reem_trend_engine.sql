-- GENERATED from backend/prisma/migrations/20260831120000_reem_trend_engine/migration.sql
-- by supabase/edge/scripts/generate-baseline.mjs. Do not edit: change the
-- Prisma schema, create a Prisma migration, and regenerate.
-- prisma checksum: 13b8d472172ddcda21a148cdbab7bfb3b067d0a5cfae8dfd44acba0e25413e7f

SET search_path = public, extensions;


-- Reem Trend Engine — market analysis, trend scoring, forecasting and insights.
--
-- Purely additive: eleven new enums, eleven new AnalyticsEventType values
-- appended to the end of the existing enum, and ten new tables. Nothing
-- existing is altered or dropped, so the migration is safe to run against a
-- live database and safe to leave in place if the engine is never switched on.

-- CreateEnum
CREATE TYPE "TrendWindow" AS ENUM ('D7', 'D14', 'D30');

-- CreateEnum
CREATE TYPE "TrendStage" AS ENUM ('DORMANT', 'EMERGING', 'RISING', 'PEAKING', 'STEADY', 'COOLING', 'DECLINING');

-- CreateEnum
CREATE TYPE "TrendSubjectKind" AS ENUM ('PRODUCT', 'CATEGORY', 'BRAND', 'ATTRIBUTE', 'SEARCH_TERM', 'SELLER', 'PLATFORM');

-- CreateEnum
CREATE TYPE "TrendAttributeDimension" AS ENUM ('COLOR', 'PRICE_BAND', 'BRAND', 'SIZE', 'MATERIAL', 'OCCASION');

-- CreateEnum
CREATE TYPE "TrendInsightAudience" AS ENUM ('ADMIN', 'SELLER');

-- CreateEnum
CREATE TYPE "TrendInsightKind" AS ENUM ('RISING_DEMAND', 'EMERGING_PRODUCT', 'DECLINING_DEMAND', 'LOW_CONVERSION', 'HIGH_VIEW_NO_SALES', 'CART_ABANDONMENT', 'STOCK_OPPORTUNITY', 'STOCK_RISK', 'OVERSTOCK', 'PRICE_OPPORTUNITY', 'CATEGORY_MOMENTUM', 'COLOR_MOMENTUM', 'PRICE_BAND_SHIFT', 'UNMET_DEMAND', 'SEARCH_SURGE', 'RATING_RISK', 'RETURN_RISK', 'SELLER_PERFORMANCE', 'ASSORTMENT_GAP', 'FORECAST_SPIKE');

-- CreateEnum
CREATE TYPE "TrendInsightSeverity" AS ENUM ('INFO', 'OPPORTUNITY', 'WARNING', 'CRITICAL');

-- CreateEnum
CREATE TYPE "TrendInsightStatus" AS ENUM ('OPEN', 'ACKNOWLEDGED', 'ACTIONED', 'DISMISSED', 'EXPIRED');

-- CreateEnum
CREATE TYPE "UnmetDemandStatus" AS ENUM ('OPEN', 'ACKNOWLEDGED', 'SOURCING', 'ADDRESSED', 'DISMISSED');

-- CreateEnum
CREATE TYPE "TrendForecastMethod" AS ENUM ('HOLT_DAMPED', 'SEASONAL_NAIVE', 'MOVING_AVERAGE', 'INSUFFICIENT_DATA', 'MODEL');

-- CreateEnum
CREATE TYPE "TrendRunKind" AS ENUM ('DAILY_ROLLUP', 'SCORING', 'FORECAST', 'SEARCH_INTELLIGENCE', 'INSIGHTS', 'RETENTION', 'FULL', 'BACKFILL');

-- CreateEnum
CREATE TYPE "TrendRunStatus" AS ENUM ('RUNNING', 'SUCCEEDED', 'FAILED');

-- AlterEnum
-- This migration adds more than one value to an enum.
-- With PostgreSQL versions 11 and earlier, this is not possible
-- in a single migration. This can be worked around by creating
-- multiple migrations, each migration adding only one value to
-- the enum.


ALTER TYPE "AnalyticsEventType" ADD VALUE 'PRODUCT_IMPRESSION';
ALTER TYPE "AnalyticsEventType" ADD VALUE 'SEARCH_ZERO_RESULT';
ALTER TYPE "AnalyticsEventType" ADD VALUE 'SEARCH_RESULT_CLICK';
ALTER TYPE "AnalyticsEventType" ADD VALUE 'PRODUCT_SHARE';
ALTER TYPE "AnalyticsEventType" ADD VALUE 'PRODUCT_FAVORITE';
ALTER TYPE "AnalyticsEventType" ADD VALUE 'PRODUCT_UNFAVORITE';
ALTER TYPE "AnalyticsEventType" ADD VALUE 'WISHLIST_ADD';
ALTER TYPE "AnalyticsEventType" ADD VALUE 'CART_REMOVE';
ALTER TYPE "AnalyticsEventType" ADD VALUE 'CART_ABANDONED';
ALTER TYPE "AnalyticsEventType" ADD VALUE 'STORY_VIEW';
ALTER TYPE "AnalyticsEventType" ADD VALUE 'POST_ENGAGEMENT';

-- CreateTable
CREATE TABLE "product_demand_daily" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "brand_id" UUID,
    "day" DATE NOT NULL,
    "impressions" INTEGER NOT NULL DEFAULT 0,
    "views" INTEGER NOT NULL DEFAULT 0,
    "viewers" INTEGER NOT NULL DEFAULT 0,
    "search_hits" INTEGER NOT NULL DEFAULT 0,
    "search_clicks" INTEGER NOT NULL DEFAULT 0,
    "cart_adds" INTEGER NOT NULL DEFAULT 0,
    "cart_removals" INTEGER NOT NULL DEFAULT 0,
    "cart_abandons" INTEGER NOT NULL DEFAULT 0,
    "favorites" INTEGER NOT NULL DEFAULT 0,
    "wishlist_adds" INTEGER NOT NULL DEFAULT 0,
    "shares" INTEGER NOT NULL DEFAULT 0,
    "content_engagements" INTEGER NOT NULL DEFAULT 0,
    "checkouts" INTEGER NOT NULL DEFAULT 0,
    "orders" INTEGER NOT NULL DEFAULT 0,
    "units" INTEGER NOT NULL DEFAULT 0,
    "revenue_syp" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "cancels" INTEGER NOT NULL DEFAULT 0,
    "returns" INTEGER NOT NULL DEFAULT 0,
    "reviews" INTEGER NOT NULL DEFAULT 0,
    "rating_sum" INTEGER NOT NULL DEFAULT 0,
    "stock_units" INTEGER NOT NULL DEFAULT 0,
    "live_offers" INTEGER NOT NULL DEFAULT 0,
    "min_price_syp" DECIMAL(18,4),
    "in_stock" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "product_demand_daily_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "seller_demand_daily" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "orders" INTEGER NOT NULL DEFAULT 0,
    "units" INTEGER NOT NULL DEFAULT 0,
    "revenue_syp" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "cancels" INTEGER NOT NULL DEFAULT 0,
    "returns" INTEGER NOT NULL DEFAULT 0,
    "cart_adds" INTEGER NOT NULL DEFAULT 0,
    "checkouts" INTEGER NOT NULL DEFAULT 0,
    "stock_units" INTEGER NOT NULL DEFAULT 0,
    "price_syp" DECIMAL(18,4),
    "is_live" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "seller_demand_daily_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "category_demand_daily" (
    "id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "views" INTEGER NOT NULL DEFAULT 0,
    "search_hits" INTEGER NOT NULL DEFAULT 0,
    "cart_adds" INTEGER NOT NULL DEFAULT 0,
    "favorites" INTEGER NOT NULL DEFAULT 0,
    "orders" INTEGER NOT NULL DEFAULT 0,
    "units" INTEGER NOT NULL DEFAULT 0,
    "revenue_syp" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "returns" INTEGER NOT NULL DEFAULT 0,
    "reviews" INTEGER NOT NULL DEFAULT 0,
    "rating_sum" INTEGER NOT NULL DEFAULT 0,
    "live_products" INTEGER NOT NULL DEFAULT 0,
    "in_stock_products" INTEGER NOT NULL DEFAULT 0,
    "median_price_syp" DECIMAL(18,4),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "category_demand_daily_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trend_attribute_daily" (
    "id" UUID NOT NULL,
    "dimension" "TrendAttributeDimension" NOT NULL,
    "value" TEXT NOT NULL,
    "label_ar" TEXT NOT NULL,
    "scope_key" TEXT NOT NULL,
    "day" DATE NOT NULL,
    "views" INTEGER NOT NULL DEFAULT 0,
    "search_hits" INTEGER NOT NULL DEFAULT 0,
    "cart_adds" INTEGER NOT NULL DEFAULT 0,
    "favorites" INTEGER NOT NULL DEFAULT 0,
    "orders" INTEGER NOT NULL DEFAULT 0,
    "units" INTEGER NOT NULL DEFAULT 0,
    "revenue_syp" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "products" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "trend_attribute_daily_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "search_term_daily" (
    "id" UUID NOT NULL,
    "term_key" TEXT NOT NULL,
    "display" TEXT NOT NULL,
    "day" DATE NOT NULL,
    "searches" INTEGER NOT NULL DEFAULT 0,
    "zero_results" INTEGER NOT NULL DEFAULT 0,
    "results_sum" INTEGER NOT NULL DEFAULT 0,
    "clicks" INTEGER NOT NULL DEFAULT 0,
    "cart_adds" INTEGER NOT NULL DEFAULT 0,
    "orders" INTEGER NOT NULL DEFAULT 0,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "search_term_daily_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_trend_scores" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "window" "TrendWindow" NOT NULL,
    "captured_on" DATE NOT NULL,
    "score" DOUBLE PRECISION NOT NULL,
    "previous_score" DOUBLE PRECISION,
    "delta" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "stage" "TrendStage" NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "sample_size" INTEGER NOT NULL DEFAULT 0,
    "view_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "search_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "cart_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "conversion" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "sales_velocity" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "acceleration" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "engagement" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "quality" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "availability" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "metrics" JSONB,
    "rank" INTEGER,
    "category_rank" INTEGER,
    "method" TEXT NOT NULL DEFAULT 'reem-trend-kernel-v1',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_trend_scores_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "category_trend_scores" (
    "id" UUID NOT NULL,
    "category_id" UUID NOT NULL,
    "window" "TrendWindow" NOT NULL,
    "captured_on" DATE NOT NULL,
    "score" DOUBLE PRECISION NOT NULL,
    "previous_score" DOUBLE PRECISION,
    "delta" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "stage" "TrendStage" NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "sample_size" INTEGER NOT NULL DEFAULT 0,
    "view_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "search_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "cart_growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "conversion" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "sales_velocity" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "acceleration" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "engagement" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "quality" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "availability" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "metrics" JSONB,
    "rank" INTEGER,
    "method" TEXT NOT NULL DEFAULT 'reem-trend-kernel-v1',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "category_trend_scores_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trend_forecasts" (
    "id" UUID NOT NULL,
    "subject_kind" "TrendSubjectKind" NOT NULL,
    "subject_key" TEXT NOT NULL,
    "scope_key" TEXT NOT NULL DEFAULT 'PLATFORM',
    "generated_on" DATE NOT NULL,
    "horizon_days" INTEGER NOT NULL,
    "method" "TrendForecastMethod" NOT NULL,
    "points" JSONB NOT NULL,
    "total_units" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "total_revenue_syp" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "backtest_mae" DOUBLE PRECISION,
    "stockout_in_days" DOUBLE PRECISION,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "trend_forecasts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trend_insights" (
    "id" UUID NOT NULL,
    "audience" "TrendInsightAudience" NOT NULL,
    "seller_id" UUID,
    "kind" "TrendInsightKind" NOT NULL,
    "severity" "TrendInsightSeverity" NOT NULL DEFAULT 'INFO',
    "status" "TrendInsightStatus" NOT NULL DEFAULT 'OPEN',
    "subject_kind" "TrendSubjectKind" NOT NULL,
    "subject_key" TEXT NOT NULL,
    "product_id" UUID,
    "category_id" UUID,
    "title_ar" TEXT NOT NULL,
    "body_ar" TEXT NOT NULL,
    "action_ar" TEXT,
    "action_target" TEXT,
    "metrics" JSONB NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "priority" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "narrator" TEXT NOT NULL DEFAULT 'reem-trend-templates-v1',
    "dedupe_key" TEXT NOT NULL,
    "generated_on" DATE NOT NULL,
    "expires_at" TIMESTAMP(3) NOT NULL,
    "acknowledged_at" TIMESTAMP(3),
    "acknowledged_by" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "trend_insights_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "unmet_demand_signals" (
    "id" UUID NOT NULL,
    "term_key" TEXT NOT NULL,
    "display" TEXT NOT NULL,
    "facets" JSONB NOT NULL,
    "searches" INTEGER NOT NULL DEFAULT 0,
    "zero_results" INTEGER NOT NULL DEFAULT 0,
    "clicks" INTEGER NOT NULL DEFAULT 0,
    "orders" INTEGER NOT NULL DEFAULT 0,
    "miss_rate" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "demand_score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "growth" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "suggested_category_id" UUID,
    "suggestion_ar" TEXT,
    "status" "UnmetDemandStatus" NOT NULL DEFAULT 'OPEN',
    "reviewed_by" UUID,
    "reviewed_at" TIMESTAMP(3),
    "note" TEXT,
    "first_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "unmet_demand_signals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trend_engine_runs" (
    "id" UUID NOT NULL,
    "kind" "TrendRunKind" NOT NULL,
    "status" "TrendRunStatus" NOT NULL DEFAULT 'RUNNING',
    "from_day" DATE,
    "to_day" DATE,
    "started_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "finished_at" TIMESTAMP(3),
    "duration_ms" INTEGER,
    "rows_written" INTEGER NOT NULL DEFAULT 0,
    "stats" JSONB,
    "error" TEXT,
    "triggered_by" UUID,

    CONSTRAINT "trend_engine_runs_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "product_demand_daily_day_idx" ON "product_demand_daily"("day");

-- CreateIndex
CREATE INDEX "product_demand_daily_category_id_day_idx" ON "product_demand_daily"("category_id", "day");

-- CreateIndex
CREATE INDEX "product_demand_daily_brand_id_day_idx" ON "product_demand_daily"("brand_id", "day");

-- CreateIndex
CREATE UNIQUE INDEX "product_demand_daily_product_id_day_key" ON "product_demand_daily"("product_id", "day");

-- CreateIndex
CREATE INDEX "seller_demand_daily_seller_id_day_idx" ON "seller_demand_daily"("seller_id", "day");

-- CreateIndex
CREATE INDEX "seller_demand_daily_product_id_day_idx" ON "seller_demand_daily"("product_id", "day");

-- CreateIndex
CREATE UNIQUE INDEX "seller_demand_daily_seller_id_product_id_day_key" ON "seller_demand_daily"("seller_id", "product_id", "day");

-- CreateIndex
CREATE INDEX "category_demand_daily_day_idx" ON "category_demand_daily"("day");

-- CreateIndex
CREATE UNIQUE INDEX "category_demand_daily_category_id_day_key" ON "category_demand_daily"("category_id", "day");

-- CreateIndex
CREATE INDEX "trend_attribute_daily_dimension_day_idx" ON "trend_attribute_daily"("dimension", "day");

-- CreateIndex
CREATE INDEX "trend_attribute_daily_scope_key_day_idx" ON "trend_attribute_daily"("scope_key", "day");

-- CreateIndex
CREATE UNIQUE INDEX "trend_attribute_daily_dimension_value_scope_key_day_key" ON "trend_attribute_daily"("dimension", "value", "scope_key", "day");

-- CreateIndex
CREATE INDEX "search_term_daily_day_idx" ON "search_term_daily"("day");

-- CreateIndex
CREATE UNIQUE INDEX "search_term_daily_term_key_day_key" ON "search_term_daily"("term_key", "day");

-- CreateIndex
CREATE INDEX "product_trend_scores_window_captured_on_score_idx" ON "product_trend_scores"("window", "captured_on", "score");

-- CreateIndex
CREATE INDEX "product_trend_scores_category_id_window_captured_on_idx" ON "product_trend_scores"("category_id", "window", "captured_on");

-- CreateIndex
CREATE INDEX "product_trend_scores_window_captured_on_stage_idx" ON "product_trend_scores"("window", "captured_on", "stage");

-- CreateIndex
CREATE UNIQUE INDEX "product_trend_scores_product_id_window_captured_on_key" ON "product_trend_scores"("product_id", "window", "captured_on");

-- CreateIndex
CREATE INDEX "category_trend_scores_window_captured_on_score_idx" ON "category_trend_scores"("window", "captured_on", "score");

-- CreateIndex
CREATE UNIQUE INDEX "category_trend_scores_category_id_window_captured_on_key" ON "category_trend_scores"("category_id", "window", "captured_on");

-- CreateIndex
CREATE INDEX "trend_forecasts_generated_on_idx" ON "trend_forecasts"("generated_on");

-- CreateIndex
CREATE INDEX "trend_forecasts_scope_key_generated_on_idx" ON "trend_forecasts"("scope_key", "generated_on");

-- CreateIndex
CREATE UNIQUE INDEX "trend_forecasts_subject_kind_subject_key_scope_key_horizon__key" ON "trend_forecasts"("subject_kind", "subject_key", "scope_key", "horizon_days", "generated_on");

-- CreateIndex
CREATE INDEX "trend_insights_audience_status_priority_idx" ON "trend_insights"("audience", "status", "priority");

-- CreateIndex
CREATE INDEX "trend_insights_seller_id_status_priority_idx" ON "trend_insights"("seller_id", "status", "priority");

-- CreateIndex
CREATE INDEX "trend_insights_product_id_idx" ON "trend_insights"("product_id");

-- CreateIndex
CREATE INDEX "trend_insights_generated_on_idx" ON "trend_insights"("generated_on");

-- CreateIndex
CREATE INDEX "trend_insights_expires_at_idx" ON "trend_insights"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "trend_insights_dedupe_key_generated_on_key" ON "trend_insights"("dedupe_key", "generated_on");

-- CreateIndex
CREATE UNIQUE INDEX "unmet_demand_signals_term_key_key" ON "unmet_demand_signals"("term_key");

-- CreateIndex
CREATE INDEX "unmet_demand_signals_status_demand_score_idx" ON "unmet_demand_signals"("status", "demand_score");

-- CreateIndex
CREATE INDEX "unmet_demand_signals_last_seen_at_idx" ON "unmet_demand_signals"("last_seen_at");

-- CreateIndex
CREATE INDEX "trend_engine_runs_kind_started_at_idx" ON "trend_engine_runs"("kind", "started_at");

-- CreateIndex
CREATE INDEX "trend_engine_runs_status_started_at_idx" ON "trend_engine_runs"("status", "started_at");

-- AddForeignKey
ALTER TABLE "product_demand_daily" ADD CONSTRAINT "product_demand_daily_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_demand_daily" ADD CONSTRAINT "seller_demand_daily_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_demand_daily" ADD CONSTRAINT "seller_demand_daily_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "category_demand_daily" ADD CONSTRAINT "category_demand_daily_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_trend_scores" ADD CONSTRAINT "product_trend_scores_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "category_trend_scores" ADD CONSTRAINT "category_trend_scores_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trend_insights" ADD CONSTRAINT "trend_insights_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trend_insights" ADD CONSTRAINT "trend_insights_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trend_insights" ADD CONSTRAINT "trend_insights_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "unmet_demand_signals" ADD CONSTRAINT "unmet_demand_signals_suggested_category_id_fkey" FOREIGN KEY ("suggested_category_id") REFERENCES "categories"("id") ON DELETE SET NULL ON UPDATE CASCADE;


-- Recorded for Prisma, so the backend sees this migration as applied.
INSERT INTO public._prisma_migrations (id, checksum, finished_at, migration_name, applied_steps_count)
SELECT gen_random_uuid()::text, '13b8d472172ddcda21a148cdbab7bfb3b067d0a5cfae8dfd44acba0e25413e7f', now(), '20260831120000_reem_trend_engine', 1
WHERE NOT EXISTS (SELECT 1 FROM public._prisma_migrations WHERE migration_name = '20260831120000_reem_trend_engine');

-- Tables this migration created are not exposed to the Data API until a
-- policy says so (supabase/migrations/*_reem_supabase_rls.sql).
DO $$ BEGIN
  IF to_regprocedure('reem_supabase.lock_down_public()') IS NOT NULL THEN
    PERFORM reem_supabase.lock_down_public();
  END IF;
END $$;
