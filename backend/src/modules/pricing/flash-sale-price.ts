import { Currency, FlashSaleStatus } from '@prisma/client';
import { Money } from '../../common/money';

/**
 * The shape a line needs to carry for a sale price to be resolvable.
 *
 * Deliberately structural rather than a Prisma type: the cart, the guest cart
 * and checkout all load the same relation and none of them should have to
 * agree on a generated payload type to use this.
 */
export interface FlashSalePriced {
  flashSaleItems?: readonly {
    salePrice: unknown;
    currency: Currency;
    quantityCap: number | null;
    quantitySold: number;
    sale: {
      status: FlashSaleStatus;
      startsAt: Date;
      endsAt: Date;
    };
  }[];
}

/**
 * The one place that decides whether a listing is on sale right now.
 *
 * Price is resolved in exactly one function — `unitPriceOf` — and this is what
 * that function asks. Everything the customer is shown and everything she is
 * charged runs through the same answer, which is the only way the card, the
 * basket, the checkout summary and the order line cannot disagree.
 *
 * A sale applies when four things are true, and all four are checked here
 * rather than trusted from a query:
 *
 * - the sale is `ACTIVE` (not draft, not paused, not ended);
 * - now is inside its window;
 * - the cap has not been reached — a sold-out doorbuster is over even while
 *   the window is open;
 * - the price is in the same currency as the offer, because a sale price in
 *   another currency is not a discount, it is a mistake.
 *
 * When several sales cover one offer, the cheapest wins. That is a decision,
 * not an accident: a customer shown two prices for one dress should get the
 * lower one, and any other rule requires explaining to her why she did not.
 */
export function flashSalePriceOf(
  line: FlashSalePriced,
  offerCurrency: Currency,
  now: Date = new Date(),
): Money | null {
  const items = line.flashSaleItems ?? [];
  if (items.length === 0) return null;

  let best: Money | null = null;

  for (const item of items) {
    if (item.sale.status !== FlashSaleStatus.ACTIVE) continue;
    if (item.sale.startsAt > now || item.sale.endsAt <= now) continue;
    if (item.currency !== offerCurrency) continue;
    if (item.quantityCap !== null && item.quantitySold >= item.quantityCap) {
      continue;
    }

    const price = Money.of(item.salePrice as never, item.currency);
    if (!best || price.lessThan(best)) best = price;
  }

  return best;
}

/**
 * Whether a line is *carrying* sale data at all.
 *
 * Distinguishes "loaded, and not on sale" from "never loaded". A caller that
 * forgot the include would otherwise silently charge full price, which is the
 * quietest possible way for a sale to fail.
 */
export function flashSaleLoaded(line: FlashSalePriced): boolean {
  return Array.isArray(line.flashSaleItems);
}
