-- Proof-of-delivery code on every shipment.
ALTER TABLE "shipments" ADD COLUMN "handover_code" TEXT;
ALTER TABLE "shipments" ADD COLUMN "handover_attempts" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "shipments" ADD COLUMN "handover_verified_at" TIMESTAMP(3);

-- Driver link for carriers worked by phone.
ALTER TABLE "delivery_dispatches" ADD COLUMN "carrier_link_token" TEXT;
CREATE UNIQUE INDEX "delivery_dispatches_carrier_link_token_key"
    ON "delivery_dispatches"("carrier_link_token");

-- How a boutique delivers.
CREATE TABLE "seller_delivery_settings" (
    "seller_id" UUID NOT NULL,
    "self_delivery_enabled" BOOLEAN NOT NULL DEFAULT false,
    "self_delivery_governorates" TEXT[],
    "self_delivery_cities" TEXT[],
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updated_at" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "seller_delivery_settings_pkey" PRIMARY KEY ("seller_id")
);

ALTER TABLE "seller_delivery_settings"
    ADD CONSTRAINT "seller_delivery_settings_seller_id_fkey"
    FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
