-- A product cannot be "liked" on this platform.
--
-- `products.likes_count` had no writer anywhere in the codebase: the heart on
-- a product is a favourite, which is `favorites_count` and has the `favorites`
-- table behind it. The column was seeded with an invented figure and shown on
-- the product page beside two real counters, which is how a shopper ends up
-- doubting all three.

ALTER TABLE "products" DROP COLUMN "likes_count";
