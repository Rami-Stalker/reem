-- The three facts an honest product card needs.
--
-- Social proof and scarcity only work because they are true, and checking that
-- they are true per card is three joins a page. Most catalogues resolve that
-- either by dropping the badges or by caching a guess that drifts — and a
-- drifted "only 2 left" is a dark pattern whether or not anybody meant it to
-- be. These are refreshed by the same sweep that scores the listing, so the
-- badge and the ranking can never disagree about the same shelf.
-- AlterTable
ALTER TABLE "products" ADD COLUMN     "live_offers_count" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "live_stock" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "recent_orders_30" INTEGER NOT NULL DEFAULT 0;

