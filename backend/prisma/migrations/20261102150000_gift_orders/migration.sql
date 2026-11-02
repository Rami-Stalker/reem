-- «إرسال كهدية»: an order sent to someone else, paid up front, wrapped,
-- with a card and without prices in the parcel.
-- AlterTable
ALTER TABLE "orders" ADD COLUMN     "gift_from" TEXT,
ADD COLUMN     "gift_hide_prices" BOOLEAN NOT NULL DEFAULT true,
ADD COLUMN     "gift_message" TEXT,
ADD COLUMN     "gift_wrap" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "is_gift" BOOLEAN NOT NULL DEFAULT false;

