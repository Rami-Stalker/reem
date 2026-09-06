-- CreateEnum
CREATE TYPE "SellerHealthBand" AS ENUM ('BUILDING', 'AT_RISK', 'STEADY', 'STRONG', 'EXEMPLARY');

-- CreateTable
CREATE TABLE "product_health_snapshots" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "components" JSONB NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "advice" JSONB NOT NULL,
    "peers" JSONB,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_health_snapshots_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "seller_health_snapshots" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "day" DATE NOT NULL,
    "score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "band" "SellerHealthBand" NOT NULL DEFAULT 'BUILDING',
    "dimensions" JSONB NOT NULL,
    "confidence" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "momentum" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "advice" JSONB NOT NULL,
    "window_days" INTEGER NOT NULL DEFAULT 90,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "seller_health_snapshots_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "product_health_snapshots_seller_id_day_score_idx" ON "product_health_snapshots"("seller_id", "day", "score");

-- CreateIndex
CREATE INDEX "product_health_snapshots_product_id_day_idx" ON "product_health_snapshots"("product_id", "day");

-- CreateIndex
CREATE UNIQUE INDEX "product_health_snapshots_seller_id_product_id_day_key" ON "product_health_snapshots"("seller_id", "product_id", "day");

-- CreateIndex
CREATE INDEX "seller_health_snapshots_seller_id_day_idx" ON "seller_health_snapshots"("seller_id", "day");

-- CreateIndex
CREATE INDEX "seller_health_snapshots_band_score_idx" ON "seller_health_snapshots"("band", "score");

-- CreateIndex
CREATE UNIQUE INDEX "seller_health_snapshots_seller_id_day_key" ON "seller_health_snapshots"("seller_id", "day");

-- AddForeignKey
ALTER TABLE "product_health_snapshots" ADD CONSTRAINT "product_health_snapshots_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_health_snapshots" ADD CONSTRAINT "product_health_snapshots_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_health_snapshots" ADD CONSTRAINT "seller_health_snapshots_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
