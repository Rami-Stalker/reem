import { BadRequestException } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { utcTimestamp } from '../../../common/sql/utc-timestamp';

type Tx = Prisma.TransactionClient;

/** One line's worth of stock to take off an offer. */
export interface StockClaim {
  offerId: string;
  offerVariantId: string | null;
  quantity: number;
  /** Used only to word the refusal — the customer sees a garment, not an id. */
  title: string;
}

/**
 * Takes stock off an offer, refusing rather than overselling.
 *
 * Checkout validates availability while it is building the basket, long
 * before the order transaction opens, and under READ COMMITTED that read is
 * already history by the time the write lands. Two women reaching for the
 * last dress both saw `stock: 1`, both passed the check, and an unconditional
 * `decrement` sold the same garment twice and left the count at -1. The
 * seller discovered it when she went to pack the second parcel.
 *
 * So the condition lives in the UPDATE, where Postgres re-evaluates it
 * against the row it has locked. The loser matches no rows and is turned away
 * here — at checkout, with her money untaken — instead of a day later.
 *
 * Both the offer and, when one was chosen, the offer variant are claimed:
 * a variant that ran out while the offer as a whole has stock is still a
 * garment in a size nobody has.
 */
export async function claimStock(tx: Tx, claim: StockClaim): Promise<void> {
  const soldOut = () =>
    new BadRequestException(
      `${claim.title} sold out while you were checking out`,
    );

  const offer = await tx.sellerOffer.updateMany({
    where: { id: claim.offerId, stock: { gte: claim.quantity } },
    data: { stock: { decrement: claim.quantity } },
  });
  if (offer.count === 0) throw soldOut();

  if (claim.offerVariantId) {
    const variant = await tx.sellerOfferVariant.updateMany({
      where: { id: claim.offerVariantId, stock: { gte: claim.quantity } },
      data: { stock: { decrement: claim.quantity } },
    });
    if (variant.count === 0) throw soldOut();
  }
}

/** One line's claim against a flash sale's capped units. */
export interface FlashSaleClaim {
  offerId: string;
  quantity: number;
}

/**
 * Counts a line against whichever live flash sale priced it.
 *
 * **The cap is soft, deliberately.** Making it hard would mean one of two
 * things at the moment it fills, and both are worse than slightly overselling
 * a discount. Refusing the order turns "the sale ran out" into "you cannot buy
 * this", which is not what a woman who reached checkout expects. Re-pricing
 * the line at full price charges her more than the figure she agreed to, which
 * is worse still. So the units are counted, always, and the cap governs
 * *eligibility* rather than the write: once `quantity_sold` reaches it,
 * `flashSalePriceOf` stops offering the sale to anyone who arrives afterwards.
 *
 * What that buys is a bound. Without any of this, a hundred simultaneous
 * baskets all read a cap with room in it and every one of them gets the price
 * — the shelf goes at a loss and the counter is meaningless. With it, the
 * overflow is limited to the orders already in flight when the cap filled, and
 * the counter afterwards tells the truth about what went.
 *
 * Returns whether a live sale actually took the units, so the caller can tell
 * a discounted line from a full-price one when it books the discount.
 */
export async function claimFlashSaleUnits(
  tx: Tx,
  claim: FlashSaleClaim,
  now: Date = new Date(),
): Promise<{ claimed: boolean }> {
  // `utcTimestamp`, never a bare Date: these are `timestamp without time
  // zone` columns holding UTC, and a bound Date arrives as an instant that
  // PostgreSQL converts using the session timezone — silently shifting the
  // window by the server's offset. See `common/sql/utc-timestamp.ts`.
  const rows = await tx.$queryRaw<{ id: string }[]>`
    UPDATE flash_sale_items i
    SET quantity_sold = i.quantity_sold + ${claim.quantity}
    FROM flash_sales s
    WHERE s.id = i.sale_id
      AND i.offer_id = ${claim.offerId}::uuid
      AND s.status = 'ACTIVE'
      AND s.starts_at <= ${utcTimestamp(now)}
      AND s.ends_at   >  ${utcTimestamp(now)}
    RETURNING i.id
  `;
  return { claimed: rows.length > 0 };
}

/**
 * Gives a cancelled line's units back to the flash sale that priced it.
 *
 * The counter above was only ever incremented. A cap of fifty that had ten
 * orders cancelled against it stopped offering its price after forty real
 * sales, and the sale's own report claimed fifty had gone — so the seller was
 * told a promotion sold out when a fifth of it never sold at all.
 *
 * Three differences from the claim, each deliberate:
 *
 * - **No time window.** The claim only counts against a *live* sale; the
 *   release must reach a sale that has since ended, because that is exactly
 *   the sale whose report is wrong. Matching the window here would leave the
 *   overcount permanent on any sale that closed before the cancellation.
 * - **Floored at zero.** `GREATEST(0, …)` — a counter that goes negative
 *   would make the remaining units read as more than the cap.
 * - **Every sale carrying the offer**, not one. The claim already writes to
 *   whichever live sale matches; nothing guarantees a single row, and undoing
 *   less than was claimed is the failure worth avoiding here.
 */
export async function releaseFlashSaleUnits(
  tx: Tx,
  claim: FlashSaleClaim,
): Promise<void> {
  await tx.$executeRaw`
    UPDATE flash_sale_items
    SET quantity_sold = GREATEST(0, quantity_sold - ${claim.quantity})
    WHERE offer_id = ${claim.offerId}::uuid
  `;
}
