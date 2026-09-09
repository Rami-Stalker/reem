-- The cost of carrying a parcel now reaches the books.
--
-- `SHIPPING_EXPENSE` has been in the chart of accounts since the ledger was
-- built, and `EconomicsService` reads it when it computes contribution margin
-- -- but nothing ever wrote to it. The platform booked the delivery fee it
-- charged the customer (`SHIPPING_REVENUE`) and never booked what it paid the
-- carrier, so every margin figure on the admin dashboard was overstated by the
-- entire cost of delivery. `DeliveryDispatch.fee_amount` -- what the carrier
-- told us the journey cost -- was stored, displayed, and posted nowhere.
--
-- Two additions make the entry possible and balanced:
--
--   COURIER_PAYABLE       a liability, one account per carrier. The platform
--                         bears the delivery cost in full (the seller's net is
--                         computed on goods alone), and a courier hands over
--                         the GROSS cash it collected rather than netting its
--                         own fee, so what it is owed has to accrue somewhere.
--
--   DELIVERY_COST_ACCRUED the entry type, kept separate from COMMISSION_EARNED
--                         so a carrier's bill can be posted in the carrier's
--                         own currency and reconciled on its own reference.

ALTER TYPE "LedgerAccountCode" ADD VALUE IF NOT EXISTS 'COURIER_PAYABLE';
ALTER TYPE "JournalEntryType" ADD VALUE IF NOT EXISTS 'DELIVERY_COST_ACCRUED';
