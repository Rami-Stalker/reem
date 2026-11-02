-- A boutique's own policies and shipping settings, and the people who work
-- the shop with her.

-- CreateEnum
CREATE TYPE "StoreTeamRole" AS ENUM ('MANAGER', 'ORDERS', 'CATALOG');

-- CreateEnum
CREATE TYPE "StoreTeamStatus" AS ENUM ('INVITED', 'ACTIVE', 'REMOVED');

-- CreateTable
CREATE TABLE "seller_store_settings" (
    "id" UUID NOT NULL,
    "seller_id" UUID NOT NULL,
    "accepts_exchanges" BOOLEAN NOT NULL DEFAULT true,
    "exchange_note" TEXT,
    "return_note" TEXT,
    "care_note" TEXT,
    "custom_order_note" TEXT,
    "policies_updated_at" TIMESTAMP(3),
    "ships_from_governorate" TEXT,
    "ships_from_area" TEXT,
    "default_handling_days" INTEGER NOT NULL DEFAULT 1,
    "offers_pickup" BOOLEAN NOT NULL DEFAULT false,
    "pickup_address" TEXT,
    "pickup_hours" TEXT,
    "packaging_note" TEXT,
    "shipping_updated_at" TIMESTAMP(3),
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "seller_store_settings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "seller_team_members" (
    "id" UUID NOT NULL,
    "store_id" UUID NOT NULL,
    "member_id" UUID NOT NULL,
    "role" "StoreTeamRole" NOT NULL DEFAULT 'ORDERS',
    "status" "StoreTeamStatus" NOT NULL DEFAULT 'INVITED',
    "invited_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "accepted_at" TIMESTAMP(3),
    "removed_at" TIMESTAMP(3),
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "seller_team_members_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "seller_store_settings_seller_id_key" ON "seller_store_settings"("seller_id");

-- CreateIndex
CREATE INDEX "seller_team_members_member_id_status_idx" ON "seller_team_members"("member_id", "status");

-- CreateIndex
CREATE UNIQUE INDEX "seller_team_members_store_id_member_id_key" ON "seller_team_members"("store_id", "member_id");

-- AddForeignKey
ALTER TABLE "seller_store_settings" ADD CONSTRAINT "seller_store_settings_seller_id_fkey" FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_team_members" ADD CONSTRAINT "seller_team_members_store_id_fkey" FOREIGN KEY ("store_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "seller_team_members" ADD CONSTRAINT "seller_team_members_member_id_fkey" FOREIGN KEY ("member_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

