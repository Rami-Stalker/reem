import { Currency, Prisma } from '@prisma/client';
import { Money } from '../../common/money';
import { CART_INCLUDE, GUEST_CART_INCLUDE } from './cart.repository';

export type CartItemRecord =
  | Prisma.CartItemGetPayload<{ include: typeof CART_INCLUDE }>
  | Prisma.GuestCartItemGetPayload<{ include: typeof GUEST_CART_INCLUDE }>;

/** The unit price actually charged: the offer variant's, else the offer's. */
export function unitPriceOf(item: CartItemRecord): Money {
  return Money.of(
    item.offerVariant?.price ?? item.offer.price,
    item.offer.currency,
  );
}

export function availableStockOf(item: CartItemRecord): number {
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
