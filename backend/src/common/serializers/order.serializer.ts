import {
  CodAssurance,
  CodAssuranceState,
  DeliveryDispatch,
  Order,
  OrderEvent,
  OrderItem,
  Payment,
  PaymentStatus,
  SellerOrder,
  Shipment,
  User,
} from '@prisma/client';
import { Money, deriveOrderStatus } from '../money';
import { needsCustomerAction, railOf } from '../payments/payment-rails';
import { serializePublicUser } from './user.serializer';

/**
 * Order JSON.
 *
 * The shape is now two-level, mirroring the model: a parent order the customer
 * paid for once, and one sub-order per seller that ships, is tracked, can be
 * cancelled and is settled independently (Q40/Q65).
 */

export type SellerOrderRecord = SellerOrder & {
  seller: User;
  items: OrderItem[];
  shipment?: (Shipment & { dispatch?: DeliveryDispatchRecord | null }) | null;
  events?: OrderEvent[];
};

/**
 * What a customer may know about the delivery company carrying her parcel.
 *
 * Its name and its tracking number, because those are what she needs to chase
 * it — and nothing else. The carrier's own identifiers, our request payloads
 * and every credential stay on the server side of this line.
 */
export type DeliveryDispatchRecord = DeliveryDispatch & {
  provider?: { displayName: string } | null;
};

export type OrderWithItems = Order & {
  sellerOrders: (SellerOrder & { items: OrderItem[] })[];
};

export type OrderDetailRecord = Order & {
  sellerOrders: SellerOrderRecord[];
  payment: Payment | null;
  events: OrderEvent[];
  codRiskAssessment?: {
    state: CodAssuranceState;
    assurance: CodAssurance;
  } | null;
};

export function serializeOrderItem(item: OrderItem) {
  const unitPrice = Money.of(item.unitPrice, item.currency);
  const unitDiscount = Money.of(item.unitDiscount, item.currency);

  return {
    id: item.id,
    offer_id: item.offerId,
    product_id: item.productId,
    variant_id: item.variantId,
    title: item.titleSnapshot,
    image: item.imageSnapshot,
    variant_name: item.variantSnapshot,
    seller_name: item.sellerSnapshot,
    quantity: item.quantity,
    currency: item.currency,
    unit_price: unitPrice.toJSON(),
    unit_discount: unitDiscount.toJSON(),
    line_total: Money.of(item.lineTotal, item.currency).toJSON(),
    customisation: item.customisation ?? null,
  };
}

export function serializeShipment(
  shipment: Shipment & { dispatch?: DeliveryDispatchRecord | null },
) {
  return {
    id: shipment.id,
    tracking_code: shipment.trackingCode,
    status: shipment.status.toLowerCase(),
    courier_id: shipment.courierId,
    scheduled_for: shipment.scheduledFor?.toISOString() ?? null,
    is_express: shipment.isExpress,
    picked_up_at: shipment.pickedUpAt?.toISOString() ?? null,
    delivered_at: shipment.deliveredAt?.toISOString() ?? null,
    proof_image_url: shipment.proofImageUrl,
    failure_reason: shipment.failureReason?.toLowerCase() ?? null,
    attempt_count: shipment.attemptCount,
    cod_amount: shipment.codAmount
      ? Money.of(shipment.codAmount, shipment.currency).toJSON()
      : null,
    collected_amount: shipment.collectedAmount
      ? Money.of(shipment.collectedAmount, shipment.currency).toJSON()
      : null,
    carrier: shipment.dispatch
      ? {
          name:
            shipment.dispatch.provider?.displayName ??
            shipment.dispatch.providerCode,
          status: shipment.dispatch.status.toLowerCase(),
          tracking_number: shipment.dispatch.trackingNumber,
          tracking_url: shipment.dispatch.trackingUrl,
          picked_up_at: shipment.dispatch.pickedUpAt?.toISOString() ?? null,
          delivered_at: shipment.dispatch.deliveredAt?.toISOString() ?? null,
        }
      : null,
  };
}

export function serializeSellerOrder(sellerOrder: SellerOrderRecord) {
  return {
    id: sellerOrder.id,
    number: sellerOrder.number,
    seller: serializePublicUser(sellerOrder.seller),
    status: sellerOrder.status.toLowerCase(),
    fulfilment_mode: sellerOrder.fulfilmentMode.toLowerCase(),
    currency: sellerOrder.currency,
    items_subtotal: Money.of(
      sellerOrder.itemsSubtotal,
      sellerOrder.currency,
    ).toJSON(),
    discount_total: Money.of(
      sellerOrder.discountTotal,
      sellerOrder.currency,
    ).toJSON(),
    shipping_cost: Money.of(
      sellerOrder.shippingCost,
      sellerOrder.currency,
    ).toJSON(),
    confirmed_at: sellerOrder.confirmedAt?.toISOString() ?? null,
    shipped_at: sellerOrder.shippedAt?.toISOString() ?? null,
    delivered_at: sellerOrder.deliveredAt?.toISOString() ?? null,
    cancellation_reason: sellerOrder.cancellationReason,
    items: sellerOrder.items.map(serializeOrderItem),
    shipment: sellerOrder.shipment
      ? serializeShipment(sellerOrder.shipment)
      : null,
    ...(sellerOrder.events
      ? { timeline: sellerOrder.events.map(serializeOrderEvent) }
      : {}),
  };
}

/** The seller-facing view of their own sub-order — no other seller's lines. */
export function serializeSellerOrderForSeller(
  sellerOrder: SellerOrderRecord,
  options: { revealCustomer: boolean; order: Order },
) {
  const { order } = options;
  return {
    ...serializeSellerOrder(sellerOrder),
    commission_amount: Money.of(
      sellerOrder.commissionAmount,
      sellerOrder.currency,
    ).toJSON(),
    seller_net: Money.of(sellerOrder.sellerNet, sellerOrder.currency).toJSON(),
    escrow_release_at: sellerOrder.escrowReleaseAt?.toISOString() ?? null,
    escrow_released: sellerOrder.escrowReleased,
    // Q44 P1 / Q57 P2 — identity is revealed only when the fulfilment mode
    // requires the seller to ship it themselves.
    shipping: options.revealCustomer
      ? {
          recipient_name: order.recipientName,
          recipient_phone: order.recipientPhone,
          governorate: order.governorate,
          district: order.district,
          city: order.city,
          address_line: order.addressLine,
          landmark: order.landmark,
        }
      : {
          recipient_name: null,
          recipient_phone: sellerOrder.shipment?.maskedPhone ?? null,
          governorate: order.governorate,
          district: order.district,
          city: null,
          address_line: null,
          landmark: null,
        },
  };
}

export function serializePayment(payment: Payment) {
  return {
    id: payment.id,
    order_id: payment.orderId,
    method: payment.method.toLowerCase(),
    status: payment.status.toLowerCase(),
    currency: payment.currency,
    amount: Money.of(payment.amount, payment.currency).toJSON(),
    captured_amount: Money.of(
      payment.capturedAmount,
      payment.currency,
    ).toJSON(),
    refunded_amount: Money.of(
      payment.refundedAmount,
      payment.currency,
    ).toJSON(),
    // What the rail asks of her, rather than leaving the app to infer it
    // from the method name.
    rail: railOf(payment.method),
    needs_customer_action:
      needsCustomerAction(payment.method) &&
      payment.status === PaymentStatus.PENDING,
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
    from_status: event.fromStatus,
    to_status: event.toStatus,
    actor_role: event.actorRole,
    created_at: event.createdAt.toISOString(),
  };
}

/** Compact shape for order lists. */
export function serializeOrder(order: OrderWithItems) {
  const itemsCount = order.sellerOrders.reduce(
    (count, sellerOrder) => count + sellerOrder.items.length,
    0,
  );

  return {
    id: order.id,
    number: order.number,
    status: order.status.toLowerCase(),
    currency: order.currency,
    items_subtotal: Money.of(order.itemsSubtotal, order.currency).toJSON(),
    discount_total: Money.of(order.discountTotal, order.currency).toJSON(),
    shipping_total: Money.of(order.shippingTotal, order.currency).toJSON(),
    wallet_applied: Money.of(order.walletApplied, order.currency).toJSON(),
    grand_total: Money.of(order.grandTotal, order.currency).toJSON(),
    // Q46 P2 — the rate this order was priced at, surfaced so the customer can
    // see why an old order shows a different SYP figure than today's catalog.
    fx_rate: order.fxRate.toFixed(6),
    fx_frozen_at: order.fxFrozenAt.toISOString(),
    sellers_count: order.sellerOrders.length,
    items_count: itemsCount,
    created_at: order.createdAt.toISOString(),
  };
}

/** Full shape for the order detail / tracking screen. */
export function serializeOrderDetail(order: OrderDetailRecord) {
  return {
    ...serializeOrder(order),
    // Recomputed rather than read, so a stale parent row can never contradict
    // its children on screen.
    derived_status: deriveOrderStatus(
      order.sellerOrders.map((sellerOrder) => sellerOrder.status),
      { paid: order.payment?.paidAt != null },
    ).toLowerCase(),
    coupon_code: order.couponCode,
    notes: order.notes,
    delivery_instructions: order.deliveryInstructions,
    privacy_mask_enabled: order.privacyMaskEnabled,
    shipping: {
      recipient_name: order.recipientName,
      recipient_phone: order.recipientPhone,
      governorate: order.governorate,
      district: order.district,
      city: order.city,
      address_line: order.addressLine,
      landmark: order.landmark,
    },
    seller_orders: order.sellerOrders.map(serializeSellerOrder),
    payment: order.payment ? serializePayment(order.payment) : null,
    // One boolean, and only when it is true. The customer's order does not
    // carry a risk score, a tier or a reason: the single thing she can act on
    // is whether a code is still owed, and anything more would be inviting her
    // to argue with a number nobody in support can change.
    awaiting_cod_confirmation:
      order.codRiskAssessment?.state === CodAssuranceState.PENDING,
    timeline: order.events.map(serializeOrderEvent),
  };
}
