-- CreateEnum
CREATE TYPE "GraphNode" AS ENUM ('USER', 'PRODUCT', 'SELLER', 'CATEGORY', 'OCCASION', 'TERM', 'SLOT');

-- CreateEnum
CREATE TYPE "GraphEdge" AS ENUM ('VIEWED', 'SEARCHED', 'ENGAGED', 'SAVED', 'CONSIDERED', 'PURCHASED', 'OWNS', 'BUYS_FROM', 'SHOPS_FOR', 'NEEDS');

-- CreateEnum
CREATE TYPE "AffinityKind" AS ENUM ('SIMILAR', 'COMPLEMENT', 'SUBSTITUTE', 'BOUGHT_TOGETHER');

-- CreateTable
CREATE TABLE "commerce_edges" (
    "id" UUID NOT NULL,
    "subject_type" "GraphNode" NOT NULL,
    "subject_id" UUID NOT NULL,
    "object_type" "GraphNode" NOT NULL,
    "object_id" UUID NOT NULL,
    "kind" "GraphEdge" NOT NULL,
    "weight" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "observations" INTEGER NOT NULL DEFAULT 1,
    "evidence" JSONB,
    "first_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "last_seen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "commerce_edges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "product_affinities" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "related_id" UUID NOT NULL,
    "kind" "AffinityKind" NOT NULL,
    "score" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "basis" JSONB,
    "computed_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "product_affinities_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "commerce_edges_subject_type_subject_id_kind_weight_idx" ON "commerce_edges"("subject_type", "subject_id", "kind", "weight");

-- CreateIndex
CREATE INDEX "commerce_edges_object_type_object_id_kind_weight_idx" ON "commerce_edges"("object_type", "object_id", "kind", "weight");

-- CreateIndex
CREATE INDEX "commerce_edges_last_seen_at_idx" ON "commerce_edges"("last_seen_at");

-- CreateIndex
CREATE UNIQUE INDEX "commerce_edges_subject_type_subject_id_object_type_object_i_key" ON "commerce_edges"("subject_type", "subject_id", "object_type", "object_id", "kind");

-- CreateIndex
CREATE INDEX "product_affinities_product_id_kind_score_idx" ON "product_affinities"("product_id", "kind", "score");

-- CreateIndex
CREATE INDEX "product_affinities_related_id_kind_idx" ON "product_affinities"("related_id", "kind");

-- CreateIndex
CREATE UNIQUE INDEX "product_affinities_product_id_related_id_kind_key" ON "product_affinities"("product_id", "related_id", "kind");

-- AddForeignKey
ALTER TABLE "product_affinities" ADD CONSTRAINT "product_affinities_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "product_affinities" ADD CONSTRAINT "product_affinities_related_id_fkey" FOREIGN KEY ("related_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
