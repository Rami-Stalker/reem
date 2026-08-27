-- CreateEnum
CREATE TYPE "InvoiceKind" AS ENUM ('ORDER', 'SELLER_ORDER');

-- CreateTable
CREATE TABLE "invoices" (
    "id" UUID NOT NULL,
    "number" TEXT NOT NULL,
    "kind" "InvoiceKind" NOT NULL,
    "order_id" UUID NOT NULL,
    "seller_order_id" UUID,
    "subject_key" TEXT NOT NULL,
    "currency" "Currency" NOT NULL,
    "items_subtotal" DECIMAL(18,4) NOT NULL,
    "discount_total" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "shipping_total" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "grand_total" DECIMAL(18,4) NOT NULL,
    "commission_amount" DECIMAL(18,4),
    "seller_net" DECIMAL(18,4),
    "fx_rate" DECIMAL(18,6) NOT NULL,
    "issued_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "issued_by_id" UUID,
    "created_at" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "invoices_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "invoices_number_key" ON "invoices"("number");

-- CreateIndex
CREATE INDEX "invoices_order_id_idx" ON "invoices"("order_id");

-- CreateIndex
CREATE INDEX "invoices_seller_order_id_idx" ON "invoices"("seller_order_id");

-- CreateIndex
CREATE INDEX "invoices_issued_at_idx" ON "invoices"("issued_at");

-- CreateIndex
CREATE UNIQUE INDEX "invoices_kind_subject_key_key" ON "invoices"("kind", "subject_key");

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_order_id_fkey" FOREIGN KEY ("order_id") REFERENCES "orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "invoices" ADD CONSTRAINT "invoices_seller_order_id_fkey" FOREIGN KEY ("seller_order_id") REFERENCES "seller_orders"("id") ON DELETE CASCADE ON UPDATE CASCADE;

