-- The map pin she drops at checkout or in her address book.
--
-- Nullable on both tables: every existing row was typed, and typing stays a
-- way to give an address. The order keeps its own copy, like the rest of its
-- address snapshot, so editing the saved address never moves a parcel.
ALTER TABLE "addresses" ADD COLUMN "latitude" DOUBLE PRECISION;
ALTER TABLE "addresses" ADD COLUMN "longitude" DOUBLE PRECISION;

ALTER TABLE "orders" ADD COLUMN "latitude" DOUBLE PRECISION;
ALTER TABLE "orders" ADD COLUMN "longitude" DOUBLE PRECISION;
