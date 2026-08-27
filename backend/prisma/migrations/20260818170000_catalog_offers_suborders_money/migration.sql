-- ============================================================================
-- Foundation redesign: canonical catalog + seller offers, per-seller
-- sub-orders, Decimal money with an explicit currency, frozen FX, returns,
-- disputes and real shipping operations.
--
-- DESTRUCTIVE. This migration drops products.seller_id/price/stock,
-- orders.total/subtotal and re-parents order_items/cart_items. It is written
-- for a PRE-LAUNCH database: reset and reseed rather than applying it over
-- production rows.
--
--   npx prisma migrate reset --force   (then: npx prisma db seed)
--
-- The enum casts below (OrderStatus, PaymentMethodType) will also fail on any
-- row holding a retired value (PAID, PROCESSING, VISA, BEMO).
-- ============================================================================

-- CreateEnum
CREATE TYPE "Currency" AS ENUM ('SYP', 'USD');

-- CreateEnum
CREATE TYPE "RoundingPolicy" AS ENUM ('NONE', 'NEAREST_100', 'NEAREST_500', 'NEAREST_1000');

-- CreateEnum
CREATE TYPE "OfferStatus" AS ENUM ('DRAFT', 'PENDING_REVIEW', 'ACTIVE', 'OUT_OF_STOCK', 'PAUSED', 'ARCHIVED');

-- CreateEnum
CREATE TYPE "AccountPricingTier" AS ENUM ('RETAIL', 'WHOLESALE');

-- CreateEnum
CREATE TYPE "SellerOrderStatus" AS ENUM ('NEW', 'AWAITING_SELLER_CONFIRMATION', 'PREPARING', 'READY_TO_SHIP', 'HANDED_TO_COURIER', 'IN_TRANSIT', 'DELIVERED', 'DELIVERY_FAILED', 'CANCELLED_BY_CUSTOMER', 'CANCELLED_BY_SELLER', 'REJECTED_ON_DELIVERY', 'RETURN_REQUESTED', 'RETURN_IN_TRANSIT', 'RETURNED', 'EXCHANGE_IN_PROGRESS', 'EXCHANGED', 'REFUND_PENDING', 'REFUNDED', 'DISPUTED');

-- CreateEnum
CREATE TYPE "FulfilmentMode" AS ENUM ('SELLER_SHIPS', 'PLATFORM_COURIER', 'THIRD_PARTY_CARRIER', 'PICKUP_POINT');

-- CreateEnum
CREATE TYPE "ReturnReason" AS ENUM ('DEFECTIVE', 'WRONG_ITEM', 'NOT_AS_DESCRIBED', 'DAMAGED_IN_TRANSIT', 'CHANGED_MIND', 'SIZE_ISSUE', 'LATE_DELIVERY', 'OTHER');

-- CreateEnum
CREATE TYPE "ReturnStatus" AS ENUM ('REQUESTED', 'APPROVED', 'REJECTED', 'IN_TRANSIT', 'RECEIVED', 'REFUNDED', 'EXCHANGED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "ReturnResolution" AS ENUM ('NONE', 'REFUND_TO_WALLET', 'REFUND_TO_SOURCE', 'EXCHANGE', 'REPAIR');

-- CreateEnum
CREATE TYPE "ReturnCostBearer" AS ENUM ('CUSTOMER', 'SELLER', 'PLATFORM');

-- CreateEnum
CREATE TYPE "DisputeStatus" AS ENUM ('OPEN', 'UNDER_REVIEW', 'ESCALATED', 'RESOLVED_FOR_CUSTOMER', 'RESOLVED_FOR_SELLER', 'RESOLVED_SPLIT', 'APPEALED', 'CLOSED');

-- CreateEnum
CREATE TYPE "CourierKind" AS ENUM ('PLATFORM_STAFF', 'THIRD_PARTY', 'SELLER_SELF');

-- CreateEnum
CREATE TYPE "ShipmentStatus" AS ENUM ('CREATED', 'ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'OUT_FOR_DELIVERY', 'DELIVERED', 'FAILED', 'RETURNING', 'RETURNED', 'CANCELLED');

-- CreateEnum
CREATE TYPE "DeliveryFailureReason" AS ENUM ('NO_ANSWER', 'WRONG_ADDRESS', 'CUSTOMER_REFUSED', 'POSTPONED', 'UNREACHABLE_AREA', 'OTHER');

-- AlterEnum
BEGIN;
CREATE TYPE "OrderStatus_new" AS ENUM ('DRAFT', 'PENDING_PAYMENT', 'CONFIRMED', 'PARTIALLY_SHIPPED', 'SHIPPED', 'PARTIALLY_DELIVERED', 'DELIVERED', 'PARTIALLY_CANCELLED', 'CANCELLED', 'CLOSED');
ALTER TABLE "orders" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "orders" ALTER COLUMN "status" TYPE "OrderStatus_new" USING ("status"::text::"OrderStatus_new");
ALTER TYPE "OrderStatus" RENAME TO "OrderStatus_old";
ALTER TYPE "OrderStatus_new" RENAME TO "OrderStatus";
DROP TYPE "OrderStatus_old";
ALTER TABLE "orders" ALTER COLUMN "status" SET DEFAULT 'PENDING_PAYMENT';
COMMIT;

-- AlterEnum
BEGIN;
CREATE TYPE "PaymentMethodType_new" AS ENUM ('COD', 'COURIER_COLLECT', 'SYRIATEL_CASH', 'MTN_CASH', 'SHAM_CASH', 'BANK_CARD', 'BANK_TRANSFER', 'HAWALA', 'PLATFORM_WALLET');
ALTER TABLE "payments" ALTER COLUMN "method" TYPE "PaymentMethodType_new" USING ("method"::text::"PaymentMethodType_new");
ALTER TYPE "PaymentMethodType" RENAME TO "PaymentMethodType_old";
ALTER TYPE "PaymentMethodType_new" RENAME TO "PaymentMethodType";
DROP TYPE "PaymentMethodType_old";
COMMIT;

-- AlterEnum
ALTER TYPE "OtpChannel" ADD VALUE 'WHATSAPP';

-- DropForeignKey
ALTER TABLE "products" DROP CONSTRAINT "products_seller_id_fkey";

-- DropForeignKey
ALTER TABLE "posts" DROP CONSTRAINT "posts_product_id_fkey";

-- DropForeignKey
ALTER TABLE "orders" DROP CONSTRAINT "orders_user_id_fkey";

-- DropForeignKey
ALTER TABLE "order_items" DROP CONSTRAINT "order_items_order_id_fkey";

-- DropForeignKey
ALTER TABLE "order_items" DROP CONSTRAINT "order_items_product_id_fkey";

-- DropForeignKey
ALTER TABLE "cart_items" DROP CONSTRAINT "cart_items_product_id_fkey";

-- DropForeignKey
ALTER TABLE "cart_items" DROP CONSTRAINT "cart_items_variant_id_fkey";

-- DropForeignKey
ALTER TABLE "guest_cart_items" DROP CONSTRAINT "guest_cart_items_product_id_fkey";

-- DropForeignKey
ALTER TABLE "guest_cart_items" DROP CONSTRAINT "guest_cart_items_variant_id_fkey";

-- DropForeignKey
ALTER TABLE "chats" DROP CONSTRAINT "chats_order_id_fkey";

-- DropForeignKey
ALTER TABLE "commission_ledgers" DROP CONSTRAINT "commission_ledgers_order_id_fkey";

-- DropIndex
DROP INDEX "products_seller_id_idx";

-- DropIndex
DROP INDEX "products_category_idx";

-- DropIndex
DROP INDEX "products_is_featured_idx";

-- DropIndex
DROP INDEX "products_status_idx";

-- DropIndex
DROP INDEX "products_status_views_count_idx";

-- DropIndex
DROP INDEX "products_category_status_created_at_idx";

-- DropIndex
DROP INDEX "orders_user_id_idx";

-- DropIndex
DROP INDEX "order_items_order_id_idx";

-- DropIndex
DROP INDEX "guest_cart_items_product_id_idx";

-- DropIndex
DROP INDEX "chats_order_id_idx";

-- DropIndex
DROP INDEX "commission_ledgers_order_id_idx";

-- DropIndex
DROP INDEX "commission_ledgers_order_id_seller_id_key";

-- AlterTable
ALTER TABLE "users" ADD COLUMN     "declared_female" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "preferred_currency" "Currency" NOT NULL DEFAULT 'SYP',
ADD COLUMN     "pricing_tier" "AccountPricingTier" NOT NULL DEFAULT 'RETAIL';

-- AlterTable
ALTER TABLE "products" DROP COLUMN "category",
DROP COLUMN "is_available",
DROP COLUMN "is_featured",
DROP COLUMN "old_price",
DROP COLUMN "price",
DROP COLUMN "seller_id",
DROP COLUMN "show_in_feed",
DROP COLUMN "stock",
ADD COLUMN     "attributes" JSONB,
ADD COLUMN     "brand_id" UUID,
ADD COLUMN     "category_id" UUID NOT NULL,
ADD COLUMN     "created_by_seller_id" UUID,
ADD COLUMN     "gtin" TEXT,
ADD COLUMN     "max_price_syp" DECIMAL(18,4),
ADD COLUMN     "min_price_syp" DECIMAL(18,4),
ADD COLUMN     "moderation_status" "ModerationStatus" NOT NULL DEFAULT 'OPEN',
ADD COLUMN     "offers_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "slug" TEXT NOT NULL;

-- AlterTable
ALTER TABLE "product_variants" DROP COLUMN "price",
DROP COLUMN "sku",
DROP COLUMN "stock",
ADD COLUMN     "image_url" TEXT,
ALTER COLUMN "attributes" SET NOT NULL;

-- AlterTable
ALTER TABLE "posts" ALTER COLUMN "product_id" DROP NOT NULL;

-- AlterTable
ALTER TABLE "commerce_contents" ADD COLUMN     "revenue_currency" "Currency" NOT NULL DEFAULT 'SYP',
ALTER COLUMN "revenue_generated" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "orders" DROP COLUMN "delivery_fee",
DROP COLUMN "delivery_status",
DROP COLUMN "discount",
DROP COLUMN "estimated_delivery_at",
DROP COLUMN "subtotal",
DROP COLUMN "total",
ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP',
ADD COLUMN     "discount_total" DECIMAL(18,4) NOT NULL DEFAULT 0,
ADD COLUMN     "district" TEXT,
ADD COLUMN     "fx_frozen_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
ADD COLUMN     "fx_rate" DECIMAL(18,6) NOT NULL,
ADD COLUMN     "fx_rate_id" UUID,
ADD COLUMN     "grand_total" DECIMAL(18,4) NOT NULL,
ADD COLUMN     "guest_session_id" UUID,
ADD COLUMN     "items_subtotal" DECIMAL(18,4) NOT NULL,
ADD COLUMN     "placed_at" TIMESTAMP(3),
ADD COLUMN     "points_applied" DECIMAL(18,4) NOT NULL DEFAULT 0,
ADD COLUMN     "privacy_mask_enabled" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "rounding_policy" "RoundingPolicy" NOT NULL DEFAULT 'NEAREST_1000',
ADD COLUMN     "shipping_total" DECIMAL(18,4) NOT NULL DEFAULT 0,
ADD COLUMN     "wallet_applied" DECIMAL(18,4) NOT NULL DEFAULT 0,
ALTER COLUMN "user_id" DROP NOT NULL;

-- AlterTable
ALTER TABLE "order_items" DROP COLUMN "order_id",
DROP COLUMN "price",
DROP COLUMN "variant_name",
ADD COLUMN     "currency" "Currency" NOT NULL,
ADD COLUMN     "customisation" JSONB,
ADD COLUMN     "line_total" DECIMAL(18,4) NOT NULL,
ADD COLUMN     "offer_id" UUID,
ADD COLUMN     "seller_order_id" UUID NOT NULL,
ADD COLUMN     "seller_snapshot" TEXT NOT NULL,
ADD COLUMN     "unit_discount" DECIMAL(18,4) NOT NULL DEFAULT 0,
ADD COLUMN     "unit_price" DECIMAL(18,4) NOT NULL,
ADD COLUMN     "variant_snapshot" TEXT,
ALTER COLUMN "product_id" DROP NOT NULL;

-- AlterTable
ALTER TABLE "order_events" ADD COLUMN     "actor_id" UUID,
ADD COLUMN     "actor_role" TEXT,
ADD COLUMN     "from_status" TEXT,
ADD COLUMN     "metadata" JSONB,
ADD COLUMN     "seller_order_id" UUID,
ADD COLUMN     "to_status" TEXT,
ALTER COLUMN "order_id" DROP NOT NULL;

-- AlterTable
ALTER TABLE "cart_items" DROP COLUMN "product_id",
DROP COLUMN "variant_id",
ADD COLUMN     "offer_id" UUID NOT NULL,
ADD COLUMN     "offer_variant_id" UUID;

-- AlterTable
ALTER TABLE "guest_cart_items" DROP COLUMN "product_id",
DROP COLUMN "variant_id",
ADD COLUMN     "offer_id" UUID NOT NULL,
ADD COLUMN     "offer_variant_id" UUID;

-- AlterTable
ALTER TABLE "payments" ADD COLUMN     "captured_amount" DECIMAL(18,4) NOT NULL DEFAULT 0,
ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP',
ADD COLUMN     "refunded_amount" DECIMAL(18,4) NOT NULL DEFAULT 0,
ALTER COLUMN "amount" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "payment_transactions" ADD COLUMN     "currency" "Currency" NOT NULL,
ALTER COLUMN "amount" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "wishlist_collection_items" ADD COLUMN     "price_currency" "Currency",
ALTER COLUMN "price_when_saved" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "chats" DROP COLUMN "order_id",
ADD COLUMN     "seller_order_id" UUID;

-- AlterTable
ALTER TABLE "coupons" ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP',
ADD COLUMN     "funded_by_seller" BOOLEAN NOT NULL DEFAULT false,
ALTER COLUMN "discount_percent" SET DATA TYPE DECIMAL(5,2),
ALTER COLUMN "amount_off" SET DATA TYPE DECIMAL(18,4),
ALTER COLUMN "min_order_amount" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "coupon_redemptions" ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP',
ALTER COLUMN "amount" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "referral_rewards" ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP',
ALTER COLUMN "cashback_amount" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "membership_accounts" ADD COLUMN     "spend_currency" "Currency" NOT NULL DEFAULT 'SYP',
ALTER COLUMN "current_period_spend" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "loyalty_rewards" ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP',
ALTER COLUMN "cashback_amount" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "cashback_ledger" ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP',
ALTER COLUMN "amount" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "financial_ledger_entries" ALTER COLUMN "amount" SET DATA TYPE DECIMAL(18,4),
DROP COLUMN "currency",
ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP';

-- AlterTable
ALTER TABLE "commission_rules" ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP',
ALTER COLUMN "fixed_fee" SET DATA TYPE DECIMAL(18,4),
ALTER COLUMN "min_commission" SET DATA TYPE DECIMAL(18,4),
ALTER COLUMN "max_commission" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "commission_ledgers" DROP COLUMN "order_id",
ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP',
ADD COLUMN     "seller_order_id" UUID,
ALTER COLUMN "gross" SET DATA TYPE DECIMAL(18,4),
ALTER COLUMN "commission" SET DATA TYPE DECIMAL(18,4),
ALTER COLUMN "platform_fee" SET DATA TYPE DECIMAL(18,4),
ALTER COLUMN "net" SET DATA TYPE DECIMAL(18,4);

-- AlterTable
ALTER TABLE "seller_payouts" ALTER COLUMN "gross" SET DATA TYPE DECIMAL(18,4),
ALTER COLUMN "commission" SET DATA TYPE DECIMAL(18,4),
ALTER COLUMN "platform_fees" SET DATA TYPE DECIMAL(18,4),
ALTER COLUMN "adjustments" SET DATA TYPE DECIMAL(18,4),
ALTER COLUMN "net" SET DATA TYPE DECIMAL(18,4),
DROP COLUMN "currency",
ADD COLUMN     "currency" "Currency" NOT NULL DEFAULT 'SYP';

-- DropEnum
DROP TYPE "DeliveryStatus";

-- CreateTable
CREATE TABLE "categories" (
    "id" UUID NOT NULL,
    "parent_id" UUID,
    "level" INTEGER NOT NULL DEFAULT 0,
    "slug" TEXT NOT NULL,
    "name_ar" TEXT NOT NULL,
    "name_en" TEXT NOT NULL,
    "icon_url" TEXT,
    "image_url" TEXT,
    "attribute_schema" JSONB,
    "is_sensitive" BOOLEAN NOT NULL DEFAULT false,
    "returns_allowed" BOOLEAN NOT NULL DEFAULT true,
    "size_chart_id" UUID,
    "sort_order" INTEGER NOT NULL DEFAULT 0,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "categories_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "brands" (
    "id" UUID NOT NULL,
    "slug" TEXT NOT NULL,
    "name_ar" TEXT NOT NULL,
    "name_en" TEXT NOT NULL,
    "logo_url" TEXT,
    "description" TEXT,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "is_verified" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "brands_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "size_charts" (
    "id" UUID NOT NULL,
    "slug" TEXT NOT NULL,
    "name_ar" TEXT NOT NULL,
    "name_en" TEXT NOT NULL,
    "columns" JSONB NOT NULL,
    "rows" JSONB NOT NULL,

    CONSTRAINT "size_charts_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "seller_offers" (
    "id" UUID NOT NULL,
    "product_id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "price" DECIMAL(18,4) NOT NULL,
    "compare_at_price" DECIMAL(18,4),
    "wholesale_price" DECIMAL(18,4),
    "wholesale_min_qty" INTEGER,
    "stock" INTEGER NOT NULL DEFAULT 0,
    "min_order_qty" INTEGER NOT NULL DEFAULT 1,
    "max_order_qty" INTEGER,
    "sku" TEXT,
    "handling_days" INTEGER NOT NULL DEFAULT 1,
    "is_made_to_order" BOOLEAN NOT NULL DEFAULT false,
    "requires_deposit" BOOLEAN NOT NULL DEFAULT false,
    "deposit_percent" DECIMAL(5,2),
    "accepts_returns" BOOLEAN NOT NULL DEFAULT true,
    "status" "OfferStatus" NOT NULL DEFAULT 'DRAFT',
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "seller_offers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "seller_offer_variants" (
    "id" UUID NOT NULL,
    "offer_id" UUID NOT NULL,
    "variant_id" UUID NOT NULL,
    "price" DECIMAL(18,4),
    "stock" INTEGER NOT NULL DEFAULT 0,
    "sku" TEXT,

    CONSTRAINT "seller_offer_variants_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "inventory_batches" (
    "id" UUID NOT NULL,
    "offer_id" UUID NOT NULL,
    "batch_ref" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "expires_at" TIMESTAMP(3),
    "alert_days" INTEGER NOT NULL DEFAULT 30,
    "blocked_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "inventory_batches_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "exchange_rates" (
    "id" UUID NOT NULL,
    "base" "Currency" NOT NULL,
    "quote" "Currency" NOT NULL,
    "rate" DECIMAL(18,6) NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'manual',
    "effective_from" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "effective_to" TIMESTAMP(3),
    "created_by_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "exchange_rates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "seller_orders" (
    "id" UUID NOT NULL,
    "number" TEXT NOT NULL,
    "order_id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "status" "SellerOrderStatus" NOT NULL DEFAULT 'NEW',
    "fulfilment_mode" "FulfilmentMode" NOT NULL DEFAULT 'PLATFORM_COURIER',
    "currency" "Currency" NOT NULL,
    "items_subtotal" DECIMAL(18,4) NOT NULL,
    "discount_total" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "shipping_cost" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "commission_base" DECIMAL(18,4) NOT NULL,
    "commission_amount" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "seller_net" DECIMAL(18,4) NOT NULL,
    "escrow_release_at" TIMESTAMP(3),
    "escrow_released" BOOLEAN NOT NULL DEFAULT false,
    "confirmed_at" TIMESTAMP(3),
    "shipped_at" TIMESTAMP(3),
    "delivered_at" TIMESTAMP(3),
    "closed_at" TIMESTAMP(3),
    "cancellation_reason" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "seller_orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "return_requests" (
    "id" UUID NOT NULL,
    "number" TEXT NOT NULL,
    "seller_order_id" UUID NOT NULL,
    "requested_by_id" UUID NOT NULL,
    "reason" "ReturnReason" NOT NULL,
    "reason_note" TEXT,
    "status" "ReturnStatus" NOT NULL DEFAULT 'REQUESTED',
    "resolution" "ReturnResolution" NOT NULL DEFAULT 'NONE',
    "shipping_borne_by" "ReturnCostBearer",
    "currency" "Currency" NOT NULL,
    "refund_amount" DECIMAL(18,4),
    "evidence" JSONB,
    "window_closes_at" TIMESTAMP(3) NOT NULL,
    "decided_by_id" UUID,
    "decided_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "return_requests_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "return_items" (
    "id" UUID NOT NULL,
    "return_id" UUID NOT NULL,
    "order_item_id" UUID NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 1,

    CONSTRAINT "return_items_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "disputes" (
    "id" UUID NOT NULL,
    "number" TEXT NOT NULL,
    "seller_order_id" UUID NOT NULL,
    "opened_by_id" UUID NOT NULL,
    "status" "DisputeStatus" NOT NULL DEFAULT 'OPEN',
    "subject" TEXT NOT NULL,
    "currency" "Currency" NOT NULL,
    "frozen_amount" DECIMAL(18,4) NOT NULL,
    "due_at" TIMESTAMP(3) NOT NULL,
    "extended_to" TIMESTAMP(3),
    "appeal_used" BOOLEAN NOT NULL DEFAULT false,
    "decision_note" TEXT,
    "decided_by_id" UUID,
    "decided_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "disputes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "dispute_messages" (
    "id" UUID NOT NULL,
    "dispute_id" UUID NOT NULL,
    "author_id" UUID NOT NULL,
    "body" TEXT NOT NULL,
    "evidence" JSONB,
    "is_internal" BOOLEAN NOT NULL DEFAULT false,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "dispute_messages_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shipping_zones" (
    "id" UUID NOT NULL,
    "governorate" TEXT NOT NULL,
    "district" TEXT,
    "is_rural" BOOLEAN NOT NULL DEFAULT false,
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "base_fee" DECIMAL(18,4) NOT NULL,
    "min_fee" DECIMAL(18,4) NOT NULL,
    "max_fee" DECIMAL(18,4) NOT NULL,
    "express_fee" DECIMAL(18,4),
    "eta_hours_min" INTEGER NOT NULL,
    "eta_hours_max" INTEGER NOT NULL,
    "supports_pickup_point" BOOLEAN NOT NULL DEFAULT false,
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "shipping_zones_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "couriers" (
    "id" UUID NOT NULL,
    "user_id" UUID,
    "kind" "CourierKind" NOT NULL DEFAULT 'PLATFORM_STAFF',
    "display_name" TEXT NOT NULL,
    "phone" TEXT NOT NULL,
    "company_name" TEXT,
    "governorates" TEXT[],
    "is_active" BOOLEAN NOT NULL DEFAULT true,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "couriers_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shipments" (
    "id" UUID NOT NULL,
    "tracking_code" TEXT NOT NULL,
    "seller_order_id" UUID NOT NULL,
    "courier_id" UUID,
    "zone_id" UUID,
    "status" "ShipmentStatus" NOT NULL DEFAULT 'CREATED',
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "cod_amount" DECIMAL(18,4),
    "collected_amount" DECIMAL(18,4),
    "scheduled_for" TIMESTAMP(3),
    "is_express" BOOLEAN NOT NULL DEFAULT false,
    "picked_up_at" TIMESTAMP(3),
    "delivered_at" TIMESTAMP(3),
    "proof_image_url" TEXT,
    "recipient_note" TEXT,
    "failure_reason" "DeliveryFailureReason",
    "failure_note" TEXT,
    "attempt_count" INTEGER NOT NULL DEFAULT 0,
    "masked_phone" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "shipments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "shipment_events" (
    "id" UUID NOT NULL,
    "shipment_id" UUID NOT NULL,
    "status" "ShipmentStatus" NOT NULL,
    "note" TEXT,
    "latitude" DOUBLE PRECISION,
    "longitude" DOUBLE PRECISION,
    "actor_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "shipment_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "cash_settlements" (
    "id" UUID NOT NULL,
    "courier_id" UUID NOT NULL,
    "period_date" DATE NOT NULL,
    "currency" "Currency" NOT NULL DEFAULT 'SYP',
    "expected" DECIMAL(18,4) NOT NULL,
    "collected" DECIMAL(18,4) NOT NULL,
    "variance" DECIMAL(18,4) NOT NULL,
    "settled_at" TIMESTAMP(3),
    "settled_by_id" UUID,
    "note" TEXT,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "cash_settlements_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "categories_slug_key" ON "categories"("slug");

-- CreateIndex
CREATE INDEX "categories_parent_id_sort_order_idx" ON "categories"("parent_id", "sort_order");

-- CreateIndex
CREATE INDEX "categories_level_is_active_idx" ON "categories"("level", "is_active");

-- CreateIndex
CREATE UNIQUE INDEX "brands_slug_key" ON "brands"("slug");

-- CreateIndex
CREATE INDEX "brands_is_active_idx" ON "brands"("is_active");

-- CreateIndex
CREATE UNIQUE INDEX "size_charts_slug_key" ON "size_charts"("slug");

-- CreateIndex
CREATE INDEX "seller_offers_seller_id_status_idx" ON "seller_offers"("seller_id", "status");

-- CreateIndex
CREATE INDEX "seller_offers_product_id_status_price_idx" ON "seller_offers"("product_id", "status", "price");

-- CreateIndex
CREATE INDEX "seller_offers_status_is_active_idx" ON "seller_offers"("status", "is_active");

-- CreateIndex
CREATE UNIQUE INDEX "seller_offers_product_id_seller_id_key" ON "seller_offers"("product_id", "seller_id");

-- CreateIndex
CREATE INDEX "seller_offer_variants_variant_id_idx" ON "seller_offer_variants"("variant_id");

-- CreateIndex
CREATE UNIQUE INDEX "seller_offer_variants_offer_id_variant_id_key" ON "seller_offer_variants"("offer_id", "variant_id");

-- CreateIndex
CREATE INDEX "inventory_batches_expires_at_idx" ON "inventory_batches"("expires_at");

-- CreateIndex
CREATE UNIQUE INDEX "inventory_batches_offer_id_batch_ref_key" ON "inventory_batches"("offer_id", "batch_ref");

-- CreateIndex
CREATE INDEX "exchange_rates_base_quote_effective_from_idx" ON "exchange_rates"("base", "quote", "effective_from");

-- CreateIndex
CREATE UNIQUE INDEX "seller_orders_number_key" ON "seller_orders"("number");

-- CreateIndex
CREATE INDEX "seller_orders_seller_id_status_idx" ON "seller_orders"("seller_id", "status");

-- CreateIndex
CREATE INDEX "seller_orders_order_id_idx" ON "seller_orders"("order_id");

-- CreateIndex
CREATE INDEX "seller_orders_escrow_released_escrow_release_at_idx" ON "seller_orders"("escrow_released", "escrow_release_at");

-- CreateIndex
CREATE INDEX "seller_orders_status_created_at_idx" ON "seller_orders"("status", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "return_requests_number_key" ON "return_requests"("number");

-- CreateIndex
CREATE INDEX "return_requests_seller_order_id_idx" ON "return_requests"("seller_order_id");

-- CreateIndex
CREATE INDEX "return_requests_status_idx" ON "return_requests"("status");

-- CreateIndex
CREATE INDEX "return_items_order_item_id_idx" ON "return_items"("order_item_id");

-- CreateIndex
CREATE UNIQUE INDEX "return_items_return_id_order_item_id_key" ON "return_items"("return_id", "order_item_id");

-- CreateIndex
CREATE UNIQUE INDEX "disputes_number_key" ON "disputes"("number");

-- CreateIndex
CREATE UNIQUE INDEX "disputes_seller_order_id_key" ON "disputes"("seller_order_id");

-- CreateIndex
CREATE INDEX "disputes_status_due_at_idx" ON "disputes"("status", "due_at");

-- CreateIndex
CREATE INDEX "dispute_messages_dispute_id_created_at_idx" ON "dispute_messages"("dispute_id", "created_at");

-- CreateIndex
CREATE INDEX "shipping_zones_is_active_idx" ON "shipping_zones"("is_active");

-- CreateIndex
CREATE UNIQUE INDEX "shipping_zones_governorate_district_is_rural_key" ON "shipping_zones"("governorate", "district", "is_rural");

-- CreateIndex
CREATE UNIQUE INDEX "couriers_user_id_key" ON "couriers"("user_id");

-- CreateIndex
CREATE INDEX "couriers_is_active_idx" ON "couriers"("is_active");

-- CreateIndex
CREATE UNIQUE INDEX "shipments_tracking_code_key" ON "shipments"("tracking_code");

-- CreateIndex
CREATE UNIQUE INDEX "shipments_seller_order_id_key" ON "shipments"("seller_order_id");

-- CreateIndex
CREATE INDEX "shipments_courier_id_status_idx" ON "shipments"("courier_id", "status");

-- CreateIndex
CREATE INDEX "shipments_status_idx" ON "shipments"("status");

-- CreateIndex
CREATE INDEX "shipment_events_shipment_id_created_at_idx" ON "shipment_events"("shipment_id", "created_at");

-- CreateIndex
CREATE INDEX "cash_settlements_period_date_idx" ON "cash_settlements"("period_date");

-- CreateIndex
CREATE UNIQUE INDEX "cash_settlements_courier_id_period_date_key" ON "cash_settlements"("courier_id", "period_date");

-- CreateIndex
CREATE UNIQUE INDEX "products_slug_key" ON "products"("slug");

-- CreateIndex
CREATE UNIQUE INDEX "products_gtin_key" ON "products"("gtin");

-- CreateIndex
CREATE INDEX "products_category_id_status_idx" ON "products"("category_id", "status");

-- CreateIndex
CREATE INDEX "products_brand_id_status_idx" ON "products"("brand_id", "status");

-- CreateIndex
CREATE INDEX "products_status_min_price_syp_idx" ON "products"("status", "min_price_syp");

-- CreateIndex
CREATE INDEX "products_moderation_status_idx" ON "products"("moderation_status");

-- CreateIndex
CREATE UNIQUE INDEX "product_variants_product_id_name_key" ON "product_variants"("product_id", "name");

-- CreateIndex
CREATE INDEX "orders_user_id_created_at_idx" ON "orders"("user_id", "created_at");

-- CreateIndex
CREATE INDEX "orders_guest_session_id_idx" ON "orders"("guest_session_id");

-- CreateIndex
CREATE INDEX "order_items_seller_order_id_idx" ON "order_items"("seller_order_id");

-- CreateIndex
CREATE INDEX "order_items_product_id_idx" ON "order_items"("product_id");

-- CreateIndex
CREATE INDEX "order_events_seller_order_id_created_at_idx" ON "order_events"("seller_order_id", "created_at");

-- CreateIndex
CREATE UNIQUE INDEX "cart_items_user_id_offer_id_offer_variant_id_key" ON "cart_items"("user_id", "offer_id", "offer_variant_id");

-- CreateIndex
CREATE INDEX "guest_cart_items_offer_id_idx" ON "guest_cart_items"("offer_id");

-- CreateIndex
CREATE UNIQUE INDEX "guest_cart_items_guest_session_id_offer_id_offer_variant_id_key" ON "guest_cart_items"("guest_session_id", "offer_id", "offer_variant_id");

-- CreateIndex
CREATE INDEX "payments_status_idx" ON "payments"("status");

-- CreateIndex
CREATE INDEX "chats_seller_order_id_idx" ON "chats"("seller_order_id");

-- CreateIndex
CREATE UNIQUE INDEX "commission_ledgers_seller_order_id_key" ON "commission_ledgers"("seller_order_id");

-- CreateIndex
CREATE INDEX "commission_ledgers_seller_order_id_idx" ON "commission_ledgers"("seller_order_id");

-- AddForeignKey
ALTER TABLE "categories" ADD CONSTRAINT "categories_parent_id_fkey" FOREIGN KEY ("parent_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "categories" ADD CONSTRAINT "categories_size_chart_id_fkey" FOREIGN KEY ("size_chart_id") REFERENCES "size_charts"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_category_id_fkey" FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_brand_id_fkey" FOREIGN KEY ("brand_id") REFERENCES "brands"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "products" ADD CONSTRAINT "products_created_by_seller_id_fkey" FOREIGN KEY ("created_by_seller_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_offers" ADD CONSTRAINT "seller_offers_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_offers" ADD CONSTRAINT "seller_offers_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_offer_variants" ADD CONSTRAINT "seller_offer_variants_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_offer_variants" ADD CONSTRAINT "seller_offer_variants_variant_id_fkey" FOREIGN KEY ("variant_id") REFERENCES "product_variants"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "inventory_batches" ADD CONSTRAINT "inventory_batches_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "posts" ADD CONSTRAINT "posts_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_fx_rate_id_fkey" FOREIGN KEY ("fx_rate_id") REFERENCES "exchange_rates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_orders" ADD CONSTRAINT "seller_orders_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_orders" ADD CONSTRAINT "seller_orders_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_seller_order_id_fkey" FOREIGN KEY ("seller_order_id") REFERENCES "seller_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_items" ADD CONSTRAINT "order_items_product_id_fkey" FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "order_events" ADD CONSTRAINT "order_events_seller_order_id_fkey" FOREIGN KEY ("seller_order_id") REFERENCES "seller_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cart_items" ADD CONSTRAINT "cart_items_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cart_items" ADD CONSTRAINT "cart_items_offer_variant_id_fkey" FOREIGN KEY ("offer_variant_id") REFERENCES "seller_offer_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "guest_cart_items" ADD CONSTRAINT "guest_cart_items_offer_id_fkey" FOREIGN KEY ("offer_id") REFERENCES "seller_offers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "guest_cart_items" ADD CONSTRAINT "guest_cart_items_offer_variant_id_fkey" FOREIGN KEY ("offer_variant_id") REFERENCES "seller_offer_variants"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "return_requests" ADD CONSTRAINT "return_requests_seller_order_id_fkey" FOREIGN KEY ("seller_order_id") REFERENCES "seller_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "return_items" ADD CONSTRAINT "return_items_return_id_fkey" FOREIGN KEY ("return_id") REFERENCES "return_requests"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "return_items" ADD CONSTRAINT "return_items_order_item_id_fkey" FOREIGN KEY ("order_item_id") REFERENCES "order_items"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "disputes" ADD CONSTRAINT "disputes_seller_order_id_fkey" FOREIGN KEY ("seller_order_id") REFERENCES "seller_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "dispute_messages" ADD CONSTRAINT "dispute_messages_dispute_id_fkey" FOREIGN KEY ("dispute_id") REFERENCES "disputes"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "couriers" ADD CONSTRAINT "couriers_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shipments" ADD CONSTRAINT "shipments_seller_order_id_fkey" FOREIGN KEY ("seller_order_id") REFERENCES "seller_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shipments" ADD CONSTRAINT "shipments_courier_id_fkey" FOREIGN KEY ("courier_id") REFERENCES "couriers"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shipments" ADD CONSTRAINT "shipments_zone_id_fkey" FOREIGN KEY ("zone_id") REFERENCES "shipping_zones"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "shipment_events" ADD CONSTRAINT "shipment_events_shipment_id_fkey" FOREIGN KEY ("shipment_id") REFERENCES "shipments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "cash_settlements" ADD CONSTRAINT "cash_settlements_courier_id_fkey" FOREIGN KEY ("courier_id") REFERENCES "couriers"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "chats" ADD CONSTRAINT "chats_seller_order_id_fkey" FOREIGN KEY ("seller_order_id") REFERENCES "seller_orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "commission_ledgers" ADD CONSTRAINT "commission_ledgers_seller_order_id_fkey" FOREIGN KEY ("seller_order_id") REFERENCES "seller_orders"("id") ON DELETE SET NULL ON UPDATE CASCADE;

