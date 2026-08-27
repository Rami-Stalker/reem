/**
 * Domain events. Emitters stay decoupled from the notification fan-out.
 *
 * Every name here is emitted somewhere and listened to somewhere. A constant
 * with neither is not an extension point, it is a note about an intention —
 * `payment.status_changed` sat here unused while payment changes were already
 * announced as `order.status_changed`, which is what the customer is told
 * about anyway.
 */
export const AppEvent = {
  OrderStatusChanged: 'order.status_changed',
  CommerceContentPublished: 'commerce_content.published',
  CommerceContentSubmitted: 'commerce_content.submitted',
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

export interface CommerceContentPublishedPayload {
  sellerId: string;
  contentId: string;
  contentType: string;
  channels: string[];
}

export interface CommerceContentSubmittedPayload {
  sellerId: string;
  contentId: string;
  contentType: string;
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
