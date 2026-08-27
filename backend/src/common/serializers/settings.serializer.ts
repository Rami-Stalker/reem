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

export function serializeNotification(notification: Notification) {
  return {
    id: notification.id,
    title: notification.title,
    body: notification.body,
    type: notification.type,
    image_url: notification.imageUrl,
    data: notification.data ?? null,
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
