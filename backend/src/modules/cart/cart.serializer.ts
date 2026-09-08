import { Currency, Prisma } from '@prisma/client';
import { Money } from '../../common/money';
import { flashSalePriceOf } from '../pricing/flash-sale-price';
import { CART_INCLUDE, GUEST_CART_INCLUDE } from './cart.repository';

export type CartItemRecord =
  | Prisma.CartItemGetPayload<{ include: typeof CART_INCLUDE }>
  | Prisma.GuestCartItemGetPayload<{ include: typeof GUEST_CART_INCLUDE }>;

/**
 * What checkout actually needs from a line, whatever produced it.
 *
 * Checkout used to take `CartItemRecord[]`, which quietly made "a thing that
 * can be bought" mean "a row in the cart table". Reem Rooms buys from a
 * `PurchasePlan` and never writes a cart row, so the requirement is stated
 * structurally instead: an offer, an optional variant of it, and how many.
 *
 * Both cart tables satisfy this, which the assertion below keeps true — if a
 * future include drops a field checkout reads, this stops compiling here rather
 * than at the six call sites downstream.
 */
export interface PurchasableLine {
  offerId: string;
  offerVariantId: string | null;
  quantity: number;
  offer: Prisma.SellerOfferGetPayload<{
    include: {
      seller: true;
      product: { include: { media: true; category: true } };
      flashSaleItems: { include: { sale: true } };
    };
  }>;
  offerVariant: Prisma.SellerOfferVariantGetPayload<{
    include: { variant: true };
  }> | null;
}

// A cart line is a purchasable line. Compile-time only.
const _cartIsPurchasable: (line: CartItemRecord) => PurchasableLine = (line) =>
  line;
void _cartIsPurchasable;

/**
 * The unit price actually charged.
 *
 * A live flash sale first, then the offer variant's price, then the offer's.
 * Every screen and every charge comes through here — the card, the basket, the
 * checkout summary, the order line — which is the only arrangement under which
 * they cannot disagree about what a dress costs.
 *
 * A sale price beats a variant price rather than being applied on top of it.
 * Stacking would let a large size in a sale cost less than the sale price the
 * customer was shown, and the figure she was shown is the one she agreed to.
 */
export function unitPriceOf(item: PurchasableLine, now?: Date): Money {
  const sale = flashSalePriceOf(item.offer, item.offer.currency, now);
  if (sale) return sale;

  return Money.of(
    item.offerVariant?.price ?? item.offer.price,
    item.offer.currency,
  );
}

/** What this line would have cost without the sale, when it is on one. */
export function compareAtPriceOf(item: PurchasableLine, now?: Date): Money | null {
  const sale = flashSalePriceOf(item.offer, item.offer.currency, now);
  if (!sale) return null;
  return Money.of(
    item.offerVariant?.price ?? item.offer.price,
    item.offer.currency,
  );
}

export function availableStockOf(item: PurchasableLine): number {
  return item.offerVariant ? item.offerVariant.stock : item.offer.stock;
}

export function serializeCartItem(item: CartItemRecord) {
  const unitPrice = unitPriceOf(item);
  const stock = availableStockOf(item);

  return {
    id: item.id,
    offer_id: item.offerId,
    seller: {
      id: item.offer.seller.id,
      name: item.offer.seller.name,
      username: item.offer.seller.username,
      image_url: item.offer.seller.imageUrl,
    },
    product: {
      id: item.offer.product.id,
      slug: item.offer.product.slug,
      title: item.offer.product.title,
      image: item.offer.product.media[0]?.url ?? null,
      category_slug: item.offer.product.category.slug,
      // Q56 P1 — the cart already knows whether this line can be returned.
      returns_allowed:
        item.offer.product.category.returnsAllowed && item.offer.acceptsReturns,
    },
    variant: item.offerVariant
      ? {
          id: item.offerVariant.id,
          variant_id: item.offerVariant.variantId,
          name: item.offerVariant.variant.name,
          attributes: item.offerVariant.variant.attributes ?? null,
          stock: item.offerVariant.stock,
        }
      : null,
    quantity: item.quantity,
    currency: item.offer.currency,
    unit_price: unitPrice.toJSON(),
    line_total: unitPrice.times(item.quantity).toJSON(),
    in_stock: stock >= item.quantity,
    available_stock: stock,
    min_order_qty: item.offer.minOrderQty,
    max_order_qty: item.offer.maxOrderQty,
    is_made_to_order: item.offer.isMadeToOrder,
    handling_days: item.offer.handlingDays,
  };
}

/**
 * A basket can hold offers from several sellers priced in different currencies,
 * so it is grouped by seller and subtotalled per currency. The single
 * order-wide total is deliberately NOT computed here: it needs the FX rate,
 * the coupon and the shipping quote, and those belong to checkout. The old
 * serializer hardcoded `discount: 0, delivery_fee: 0, total: subtotal`, which
 * meant the cart and the checkout screen quoted different numbers.
 */
export function serializeCart(items: CartItemRecord[]) {
  const lines = items.map(serializeCartItem);

  const bySeller = new Map<string, CartItemRecord[]>();
  for (const item of items) {
    const group = bySeller.get(item.offer.sellerId) ?? [];
    group.push(item);
    bySeller.set(item.offer.sellerId, group);
  }

  const groups = [...bySeller.entries()].map(([sellerId, sellerItems]) => {
    const currency = sellerItems[0].offer.currency;
    const sameCurrency = sellerItems.every(
      (item) => item.offer.currency === currency,
    );
    const subtotal = sameCurrency
      ? Money.sum(
          sellerItems.map((item) => unitPriceOf(item).times(item.quantity)),
          currency,
        )
      : null;

    return {
      seller: {
        id: sellerId,
        name: sellerItems[0].offer.seller.name,
        username: sellerItems[0].offer.seller.username,
        image_url: sellerItems[0].offer.seller.imageUrl,
      },
      currency: sameCurrency ? currency : null,
      subtotal: subtotal?.toJSON() ?? null,
      item_ids: sellerItems.map((item) => item.id),
      items_count: sellerItems.length,
    };
  });

  const subtotals = subtotalsByCurrency(items);

  return {
    items: lines,
    // Q65 P1 — the customer sees up front that this basket becomes several
    // parcels from several sellers.
    seller_groups: groups,
    summary: {
      subtotals_by_currency: subtotals,
      items_count: items.length,
      sellers_count: groups.length,
      total_quantity: items.reduce((sum, item) => sum + item.quantity, 0),
    },
  };
}

function subtotalsByCurrency(items: CartItemRecord[]) {
  const totals = new Map<Currency, Money>();
  for (const item of items) {
    const line = unitPriceOf(item).times(item.quantity);
    const running = totals.get(item.offer.currency);
    totals.set(item.offer.currency, running ? running.plus(line) : line);
  }
  return [...totals.values()].map((total) => total.toJSON());
}
