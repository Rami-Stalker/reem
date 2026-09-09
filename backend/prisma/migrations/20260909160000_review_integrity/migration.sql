-- One voice per customer, enforced where it cannot be raced.
--
-- The unique key on reviews was `(product_id, user_id, order_id)`, and
-- PostgreSQL treats NULLs as *distinct* in a unique index. An unverified
-- review carries no order, so `order_id` was NULL, so the key never matched
-- itself: one account could write the same product any number of times. The
-- service checked for an existing row first, but a check followed by an insert
-- is two moments -- two concurrent requests both found nothing and both wrote.
--
-- The order comes out of the key entirely. A customer who bought the same
-- dress twice gets one review of it, which is the honest reading: her opinion
-- of the garment is one opinion, not one per receipt.
--
-- Verified safe before writing: zero duplicate (product_id, user_id) and zero
-- duplicate (seller_id, user_id) rows exist.

DROP INDEX IF EXISTS "product_reviews_product_id_user_id_order_id_key";
CREATE UNIQUE INDEX IF NOT EXISTS "product_reviews_product_id_user_id_key"
  ON "product_reviews" ("product_id", "user_id");

DROP INDEX IF EXISTS "seller_reviews_seller_id_user_id_order_id_key";
CREATE UNIQUE INDEX IF NOT EXISTS "seller_reviews_seller_id_user_id_key"
  ON "seller_reviews" ("seller_id", "user_id");
