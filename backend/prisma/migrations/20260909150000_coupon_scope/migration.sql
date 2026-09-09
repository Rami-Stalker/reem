-- A coupon now says what it may be spent on.
--
-- `funded_by_seller` recorded that a seller paid for a discount, and nothing
-- recorded *which* seller's goods it applied to. Checkout evaluated every code
-- against the whole basket subtotal and then reduced the commission base of
-- every seller in it, weighted by their share -- so a code one boutique
-- created was paid for, in part, by every other boutique the customer happened
-- to buy from in the same order. They were never told, and there was nothing
-- in the data that would have let anyone notice.
--
-- All three columns null means "the whole basket", which is exactly what every
-- existing coupon meant, so nothing in flight changes behaviour.

ALTER TABLE "coupons" ADD COLUMN IF NOT EXISTS "seller_id" UUID;
ALTER TABLE "coupons" ADD COLUMN IF NOT EXISTS "category_id" UUID;
ALTER TABLE "coupons" ADD COLUMN IF NOT EXISTS "product_id" UUID;

DO $$ BEGIN
  ALTER TABLE "coupons" ADD CONSTRAINT "coupons_seller_id_fkey"
    FOREIGN KEY ("seller_id") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "coupons" ADD CONSTRAINT "coupons_category_id_fkey"
    FOREIGN KEY ("category_id") REFERENCES "categories"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
  ALTER TABLE "coupons" ADD CONSTRAINT "coupons_product_id_fkey"
    FOREIGN KEY ("product_id") REFERENCES "products"("id") ON DELETE CASCADE ON UPDATE CASCADE;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS "coupons_seller_id_idx" ON "coupons" ("seller_id");
CREATE INDEX IF NOT EXISTS "coupons_category_id_idx" ON "coupons" ("category_id");
CREATE INDEX IF NOT EXISTS "coupons_product_id_idx" ON "coupons" ("product_id");
