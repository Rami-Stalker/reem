-- CreateEnum
CREATE TYPE "ModestyLevel" AS ENUM ('UNSPECIFIED', 'FULL_COVERAGE', 'MODEST', 'BALANCED', 'EXPRESSIVE');

-- CreateEnum
CREATE TYPE "StylePersona" AS ENUM ('CLASSIC', 'ROMANTIC', 'MINIMAL', 'GLAM', 'BOHO', 'SPORTY', 'MODEST_CHIC', 'VINTAGE');

-- CreateEnum
CREATE TYPE "OutfitSlot" AS ENUM ('DRESS', 'TOP', 'BOTTOM', 'OUTERWEAR', 'ABAYA', 'SHOES', 'BAG', 'JEWELRY', 'ACCESSORY', 'PERFUME', 'BEAUTY', 'GIFT');

-- CreateEnum
CREATE TYPE "AiStylistRole" AS ENUM ('USER', 'ASSISTANT', 'SYSTEM');

-- CreateEnum
CREATE TYPE "AiStylistModality" AS ENUM ('TEXT', 'VOICE', 'IMAGE');

-- CreateEnum
CREATE TYPE "AiStylistConversationStatus" AS ENUM ('ACTIVE', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "AiStylistFeedback" AS ENUM ('NONE', 'LIKED', 'SAVED', 'DISMISSED', 'ADDED_TO_CART', 'PURCHASED');

-- CreateEnum
CREATE TYPE "AiStylistOutfitStatus" AS ENUM ('SUGGESTED', 'SAVED', 'DISMISSED');

-- CreateTable
CREATE TABLE "user_style_preferences" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "modesty" "ModestyLevel" NOT NULL DEFAULT 'UNSPECIFIED',
    "personas" "StylePersona"[],
    "favourite_colours" TEXT[],
    "avoided_colours" TEXT[],
    "preferred_category_slugs" TEXT[],
    "avoided_category_slugs" TEXT[],
    "sizes" JSONB,
    "budget_min_syp" DECIMAL(18,4),
    "budget_max_syp" DECIMAL(18,4),
    "typical_min_syp" DECIMAL(18,4),
    "typical_max_syp" DECIMAL(18,4),
    "derived_signals" JSONB,
    "computed_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "user_style_preferences_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "user_style_signals" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "feedback" "AiStylistFeedback" NOT NULL,
    "weight" DOUBLE PRECISION NOT NULL DEFAULT 0,
    "source_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_style_signals_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_stylist_conversations" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "title" TEXT,
    "status" "AiStylistConversationStatus" NOT NULL DEFAULT 'ACTIVE',
    "brief" JSONB,
    "messages_count" INTEGER NOT NULL DEFAULT 0,
    "last_message_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ai_stylist_conversations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_stylist_messages" (
    "id" UUID NOT NULL,
    "conversation_id" UUID NOT NULL,
    "role" "AiStylistRole" NOT NULL,
    "modality" "AiStylistModality" NOT NULL DEFAULT 'TEXT',
    "content" TEXT NOT NULL,
    "brief" JSONB,
    "attachments" JSONB,
    "engine" TEXT,
    "latency_ms" INTEGER,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_stylist_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_stylist_recommendations" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "conversation_id" UUID,
    "message_id" UUID,
    "product_id" UUID NOT NULL,
    "offer_id" UUID,
    "slot" "OutfitSlot",
    "score" DOUBLE PRECISION NOT NULL,
    "position" INTEGER NOT NULL DEFAULT 0,
    "reason" TEXT NOT NULL,
    "reason_codes" TEXT[],
    "quoted_price_syp" DECIMAL(18,4),
    "feedback" "AiStylistFeedback" NOT NULL DEFAULT 'NONE',
    "feedback_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ai_stylist_recommendations_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_stylist_outfits" (
    "id" UUID NOT NULL,
    "user_id" UUID NOT NULL,
    "conversation_id" UUID,
    "message_id" UUID,
    "title" TEXT NOT NULL,
    "occasion" TEXT,
    "note" TEXT,
    "palette" TEXT[],
    "total_syp" DECIMAL(18,4),
    "status" "AiStylistOutfitStatus" NOT NULL DEFAULT 'SUGGESTED',
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ai_stylist_outfits_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "ai_stylist_outfit_items" (
    "id" UUID NOT NULL,
    "outfit_id" UUID NOT NULL,
    "slot" "OutfitSlot" NOT NULL,
    "product_id" UUID NOT NULL,
    "offer_id" UUID,
    "variant_id" UUID,
    "price_syp" DECIMAL(18,4),
    "reason" TEXT,
    "position" INTEGER NOT NULL DEFAULT 0,

    CONSTRAINT "ai_stylist_outfit_items_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "user_style_preferences_user_id_key" ON "user_style_preferences"("user_id");

-- CreateIndex
CREATE INDEX "user_style_signals_user_id_created_at_idx" ON "user_style_signals"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "user_style_signals_product_id_idx" ON "user_style_signals"("product_id");

-- CreateIndex
CREATE UNIQUE INDEX "user_style_signals_user_id_product_id_feedback_key" ON "user_style_signals"("user_id", "product_id", "feedback");

-- CreateIndex
CREATE INDEX "ai_stylist_conversations_user_id_status_last_message_at_idx" ON "ai_stylist_conversations"("user_id", "status", "last_message_at");

-- CreateIndex
CREATE INDEX "ai_stylist_messages_conversation_id_created_at_idx" ON "ai_stylist_messages"("conversation_id", "created_at");

-- CreateIndex
CREATE INDEX "ai_stylist_recommendations_user_id_created_at_idx" ON "ai_stylist_recommendations"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "ai_stylist_recommendations_conversation_id_created_at_idx" ON "ai_stylist_recommendations"("conversation_id", "created_at");

-- CreateIndex
CREATE INDEX "ai_stylist_recommendations_product_id_idx" ON "ai_stylist_recommendations"("product_id");

-- CreateIndex
CREATE INDEX "ai_stylist_recommendations_feedback_idx" ON "ai_stylist_recommendations"("feedback");

-- CreateIndex
CREATE INDEX "ai_stylist_outfits_user_id_status_created_at_idx" ON "ai_stylist_outfits"("user_id", "status", "created_at");

-- CreateIndex
CREATE INDEX "ai_stylist_outfits_conversation_id_idx" ON "ai_stylist_outfits"("conversation_id");

-- CreateIndex
CREATE INDEX "ai_stylist_outfit_items_product_id_idx" ON "ai_stylist_outfit_items"("product_id");

-- CreateIndex
CREATE UNIQUE INDEX "ai_stylist_outfit_items_outfit_id_slot_product_id_key" ON "ai_stylist_outfit_items"("outfit_id", "slot", "product_id");

-- AddForeignKey
ALTER TABLE "user_style_preferences" ADD CONSTRAINT "user_style_preferences_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_style_signals" ADD CONSTRAINT "user_style_signals_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "user_style_signals" ADD CONSTRAINT "user_style_signals_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_conversations" ADD CONSTRAINT "ai_stylist_conversations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_messages" ADD CONSTRAINT "ai_stylist_messages_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "ai_stylist_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_recommendations" ADD CONSTRAINT "ai_stylist_recommendations_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_recommendations" ADD CONSTRAINT "ai_stylist_recommendations_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "ai_stylist_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_recommendations" ADD CONSTRAINT "ai_stylist_recommendations_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "ai_stylist_messages"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_recommendations" ADD CONSTRAINT "ai_stylist_recommendations_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_outfits" ADD CONSTRAINT "ai_stylist_outfits_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_outfits" ADD CONSTRAINT "ai_stylist_outfits_conversation_id_fkey" FOREIGN KEY ("conversation_id") REFERENCES "ai_stylist_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_outfits" ADD CONSTRAINT "ai_stylist_outfits_message_id_fkey" FOREIGN KEY ("message_id") REFERENCES "ai_stylist_messages"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_outfit_items" ADD CONSTRAINT "ai_stylist_outfit_items_outfit_id_fkey" FOREIGN KEY ("outfit_id") REFERENCES "ai_stylist_outfits"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ai_stylist_outfit_items" ADD CONSTRAINT "ai_stylist_outfit_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
