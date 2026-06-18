/** Domain events. Emitters stay decoupled from the notification fan-out. */
export const AppEvent = {
  OrderStatusChanged: 'order.status_changed',
  PaymentStatusChanged: 'payment.status_changed',
  PostPublished: 'post.published',
  StoryPublished: 'story.published',
  CouponIssued: 'coupon.issued',
} as const;

export interface OrderStatusChangedPayload {
  userId: string;
  orderId: string;
  orderNumber: string;
  status: string;
}

export interface PostPublishedPayload {
  sellerId: string;
  postId: string;
}

export interface StoryPublishedPayload {
  sellerId: string;
  storyId: string;
}

export interface CouponIssuedPayload {
  userId: string;
  couponCode: string;
  title: string;
}
