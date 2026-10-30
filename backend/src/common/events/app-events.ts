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
  /** Fired once per order, when checkout commits it — never on a retry. */
  OrderPlaced: 'order.placed',
  CommerceContentPublished: 'commerce_content.published',
  CommerceContentSubmitted: 'commerce_content.submitted',
  ContentLiked: 'content.liked',
  ContentCommented: 'content.commented',
  ContentReshared: 'content.reshared',
  ContentRemoved: 'content.removed',
  ContentReinstated: 'content.reinstated',
  UserFollowed: 'user.followed',
  PostPublished: 'post.published',
  StoryPublished: 'story.published',
  CouponIssued: 'coupon.issued',
  /** A Gold or Diamond boutique started a campaign; her followers hear of it. */
  PromotionLaunched: 'promotion.launched',
  /** A boutique sent the reference for a plan paid by transfer. */
  AdPlanPurchaseSubmitted: 'ad_plan_purchase.submitted',
  /** Finance confirmed or rejected that transfer. */
  AdPlanPurchaseDecided: 'ad_plan_purchase.decided',
  /** Her plan ends soon, or has ended — plans never renew by themselves. */
  AdPlanEnding: 'ad_plan.ending',
  /** A campaign's window closed; she is told what it did. */
  AdCampaignEnded: 'ad_campaign.ended',
} as const;

export interface OrderStatusChangedPayload {
  userId: string;
  orderId: string;
  orderNumber: string;
  status: string;
}

export interface OrderPlacedPayload {
  /** Null for a guest checkout. */
  userId: string | null;
  orderId: string;
}

export interface PostPublishedPayload {
  sellerId: string;
  postId: string;
}

export interface CommerceContentPublishedPayload {
  authorId: string;
  contentId: string;
  contentType: string;
  channels: string[];
}

export interface CommerceContentSubmittedPayload {
  authorId: string;
  contentId: string;
  contentType: string;
}

export interface StoryPublishedPayload {
  sellerId: string;
  storyId: string;
}

/**
 * Somebody acted on a woman's content. One shape for all three gestures — the
 * fan-out is identical and the only difference is the sentence.
 */
export interface ContentEngagementPayload {
  /** Who is told. */
  authorId: string;
  /** Who did it. Never notified about her own gesture. */
  actorId: string;
  contentId: string;
  commentId?: string;
  reshareId?: string;
}

/**
 * A moderator took content down, and the woman who published it is owed the
 * reason. `reason` is required here for the same purpose the CHECK constraint
 * on `commerce_content_moderation_actions` serves: a silent takedown is the
 * thing the requirement forbids.
 */
export interface ContentModeratedPayload {
  authorId: string;
  contentId: string;
  contentType: string;
  reason: string;
  moderationActionId: string;
}

export interface UserFollowedPayload {
  /** The woman being followed. */
  userId: string;
  followerId: string;
}

export interface CouponIssuedPayload {
  userId: string;
  couponCode: string;
  title: string;
}

export interface PromotionLaunchedPayload {
  sellerId: string;
  promotionId: string;
  productId: string;
  productTitle: string;
}

export interface AdPlanPurchaseSubmittedPayload {
  purchaseId: string;
  sellerId: string;
  tier: string;
  /** Formatted, for the notice. */
  amount: string;
}

export interface AdPlanPurchaseDecidedPayload {
  purchaseId: string;
  sellerId: string;
  tier: string;
  confirmed: boolean;
  /** When the plan starts — now, or after the one she already has. */
  startsAt?: string;
  reason?: string;
}

export interface AdPlanEndingPayload {
  sellerId: string;
  subscriptionId: string;
  tier: string;
  /** Whole days left; 0 means it has ended. */
  daysLeft: number;
}

export interface AdCampaignEndedPayload {
  sellerId: string;
  promotionId: string;
  productTitle: string;
  reach: number;
  clicks: number;
  orders: number;
}
