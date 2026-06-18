import { CartItem, Product, ProductMedia, ProductVariant } from '@prisma/client';

export type CartItemRecord = CartItem & {
  product: Product & { media: ProductMedia[] };
  variant: ProductVariant | null;
};

const round = (n: number) => Math.round(n * 100) / 100;

export function unitPriceOf(item: CartItemRecord): number {
  return item.variant?.price ?? item.product.price;
}

export function availableStockOf(item: CartItemRecord): number {
  return item.variant ? item.variant.stock : item.product.stock;
}

export function serializeCartItem(item: CartItemRecord) {
  const price = unitPriceOf(item);
  const stock = availableStockOf(item);
  return {
    id: item.id,
    product: {
      id: item.product.id,
      title: item.product.title,
      image: item.product.media[0]?.url ?? null,
      price: item.product.price,
      status: item.product.status.toLowerCase(),
    },
    variant: item.variant
      ? {
          id: item.variant.id,
          name: item.variant.name,
          price: item.variant.price,
          stock: item.variant.stock,
        }
      : null,
    quantity: item.quantity,
    unit_price: price,
    line_total: round(price * item.quantity),
    in_stock: stock >= item.quantity,
    available_stock: stock,
  };
}

export function serializeCart(items: CartItemRecord[]) {
  const lines = items.map(serializeCartItem);
  const subtotal = round(lines.reduce((sum, l) => sum + l.line_total, 0));
  const totalQuantity = items.reduce((sum, i) => sum + i.quantity, 0);

  return {
    items: lines,
    summary: {
      subtotal,
      discount: 0,
      delivery_fee: 0,
      total: subtotal,
      items_count: items.length,
      total_quantity: totalQuantity,
    },
  };
}
