import { Order, OrderEvent, OrderItem, Payment } from '@prisma/client';

export type OrderWithItems = Order & { items: OrderItem[] };
export type OrderDetailRecord = Order & {
  items: OrderItem[];
  payment: Payment | null;
  events: OrderEvent[];
};

const round = (n: number) => Math.round(n * 100) / 100;

export function serializeOrderItem(item: OrderItem) {
  return {
    id: item.id,
    product_id: item.productId,
    title: item.titleSnapshot,
    image: item.imageSnapshot,
    variant_id: item.variantId,
    variant_name: item.variantName,
    quantity: item.quantity,
    price: item.price,
    line_total: round(item.price * item.quantity),
  };
}

export function serializePayment(payment: Payment) {
  return {
    id: payment.id,
    order_id: payment.orderId,
    method: payment.method.toLowerCase(),
    status: payment.status.toLowerCase(),
    amount: payment.amount,
    transaction_ref: payment.transactionRef,
    provider_ref: payment.providerRef,
    failure_reason: payment.failureReason,
    paid_at: payment.paidAt?.toISOString() ?? null,
    created_at: payment.createdAt.toISOString(),
  };
}

export function serializeOrderEvent(event: OrderEvent) {
  return {
    id: event.id,
    title: event.title,
    description: event.description,
    created_at: event.createdAt.toISOString(),
  };
}

/** Compact shape for order lists. */
export function serializeOrder(order: OrderWithItems) {
  return {
    id: order.id,
    number: order.number,
    status: order.status.toLowerCase(),
    delivery_status: order.deliveryStatus.toLowerCase(),
    subtotal: order.subtotal,
    discount: order.discount,
    delivery_fee: order.deliveryFee,
    total: order.total,
    items_count: order.items.length,
    created_at: order.createdAt.toISOString(),
  };
}

/** Full shape for the order detail / tracking screen. */
export function serializeOrderDetail(order: OrderDetailRecord) {
  return {
    ...serializeOrder(order),
    coupon_code: order.couponCode,
    notes: order.notes,
    delivery_instructions: order.deliveryInstructions,
    estimated_delivery_at: order.estimatedDeliveryAt?.toISOString() ?? null,
    shipping: {
      recipient_name: order.recipientName,
      recipient_phone: order.recipientPhone,
      governorate: order.governorate,
      city: order.city,
      address_line: order.addressLine,
      landmark: order.landmark,
    },
    items: order.items.map(serializeOrderItem),
    payment: order.payment ? serializePayment(order.payment) : null,
    timeline: order.events.map(serializeOrderEvent),
  };
}
