import { Address, Coupon, Notification, PaymentMethod } from '@prisma/client';

export function serializeAddress(address: Address) {
  return {
    id: address.id,
    label: address.label,
    recipient_name: address.recipientName,
    recipient_phone: address.recipientPhone,
    governorate: address.governorate,
    district: address.district,
    city: address.city,
    address_line: address.addressLine,
    landmark: address.landmark,
    is_rural: address.isRural,
    delivery_instructions: address.deliveryInstructions,
    is_default: address.isDefault,
  };
}

export function serializeCoupon(coupon: Coupon) {
  return {
    id: coupon.id,
    code: coupon.code,
    title: coupon.title,
    discount_percent: coupon.discountPercent,
    expires_at: coupon.expiresAt.toISOString(),
    is_active: coupon.isActive,
  };
}

/**
 * `data` is a free-form blob, and its producers did not agree on a spelling:
 * order notifications carry `orderId`, stories `storyId`, chats `chat_id`.
 * Everything else on this API is snake_case, so a client that reads the
 * contract as written finds the key for a chat and misses the one for an
 * order — which is exactly what happened: tapping an order notification did
 * nothing, because the id it needed was spelled the other way.
 *
 * Normalising here rather than at each producer fixes the rows already in the
 * table too.
 */
function snakeCaseKeys(value: unknown): unknown {
  if (Array.isArray(value)) return value.map(snakeCaseKeys);
  if (value === null || typeof value !== 'object') return value;

  const out: Record<string, unknown> = {};
  for (const [key, nested] of Object.entries(value as Record<string, unknown>)) {
    const snake = key
      .replace(/([a-z0-9])([A-Z])/g, '$1_$2')
      .replace(/([A-Z]+)([A-Z][a-z])/g, '$1_$2')
      .toLowerCase();
    out[snake] = snakeCaseKeys(nested);
  }
  return out;
}

export function serializeNotification(notification: Notification) {
  return {
    id: notification.id,
    title: notification.title,
    body: notification.body,
    type: notification.type,
    image_url: notification.imageUrl,
    data: notification.data == null ? null : snakeCaseKeys(notification.data),
    is_read: notification.isRead,
    created_at: notification.createdAt.toISOString(),
  };
}

export function serializePaymentMethod(pm: PaymentMethod) {
  return {
    id: pm.id,
    brand: pm.brand,
    last4: pm.last4,
    exp_month: pm.expMonth,
    exp_year: pm.expYear,
    is_default: pm.isDefault,
  };
}
