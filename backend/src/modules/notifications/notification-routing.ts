import { NotificationCategory, NotificationType } from '@prisma/client';

/**
 * Where a notification lands on the phone, and where it goes when she taps it.
 *
 * This file is one half of a contract; the other half is
 * `lib/core/notifications/notification_channels.dart` in the Flutter client.
 * The two have to agree literally, character for character, because of how
 * both platforms behave when they do not:
 *
 *  - **Android** silently discards a notification naming a channel the device
 *    has not created. Not an error, not a log line — the push arrives, the
 *    system drops it, and the only symptom is a woman who says she never gets
 *    notified while the delivery table says SENT.
 *  - **The deep link** is read by GoRouter on the client. A path that matches
 *    no route drops whoever tapped it on the 404 page, which is a worse
 *    outcome than not sending at all.
 *
 * So both live here as named constants rather than as string literals spread
 * through the service, and the client's copy carries a pointer back.
 */

/** The drawers on her phone. Mirrored in the Flutter client, exactly. */
export const PushChannel = {
  /** Her orders: paid, packed, shipped, delivered, refunded. */
  Orders: 'reem_orders',
  /** Somebody wrote to her. The one people leave on when they mute the rest. */
  Messages: 'reem_messages',
  /** Likes, comments, reshares, new followers. */
  Social: 'reem_social',
  /** Activity in a shopping room she is part of. */
  Rooms: 'reem_rooms',
  /** Coupons, drops, campaigns. The one she is most likely to turn off. */
  Offers: 'reem_offers',
  /** Moderation outcomes, security, everything else the platform must say. */
  System: 'reem_system',
} as const;

export type PushChannelId = (typeof PushChannel)[keyof typeof PushChannel];

/** The custom scheme registered on both platforms. */
const SCHEME = 'reem://';

/** Which drawer a notification of this kind belongs in. */
export function channelFor(type: NotificationType): PushChannelId {
  switch (type) {
    case 'order':
    case 'payment':
      return PushChannel.Orders;
    case 'message':
      return PushChannel.Messages;
    case 'like':
    case 'comment':
    case 'follow':
    case 'post':
    case 'story':
      return PushChannel.Social;
    case 'room':
      return PushChannel.Rooms;
    case 'promo':
    case 'coupon':
      return PushChannel.Offers;
    default:
      return PushChannel.System;
  }
}

/**
 * How long the provider should keep trying, in seconds.
 *
 * FCM's default is four weeks, which is absurd for everything Reem sends: a
 * chat message delivered on Thursday about a conversation she had on Monday
 * is not a late notification, it is a wrong one. Each of these is "after this,
 * she has found out some other way".
 */
export function ttlFor(type: NotificationType): number {
  switch (type) {
    case 'message':
      // An hour. After that she has opened the app and read it.
      return 60 * 60;
    case 'order':
    case 'payment':
      // A day. An order that shipped yesterday is still news this morning.
      return 24 * 60 * 60;
    case 'promo':
    case 'coupon':
      // Six hours. A flash sale that ended is worse than silence.
      return 6 * 60 * 60;
    default:
      return 12 * 60 * 60;
  }
}

/**
 * Whether this wakes a sleeping phone.
 *
 * Deliberately not "everything". Android meters senders that mark every push
 * urgent and quietly deprioritises them, so spending the budget on promotions
 * costs delivery of the order updates — which is the trade nobody notices
 * making until the important messages stop arriving.
 */
export function urgencyFor(category: NotificationCategory): boolean {
  return category === NotificationCategory.TRANSACTIONAL;
}

/** The `data` a notification row carries, loosely typed as it is stored. */
type NotificationData = Record<string, unknown> | null | undefined;

function str(data: NotificationData, ...keys: string[]): string | undefined {
  if (!data) return undefined;
  for (const key of keys) {
    const value = data[key];
    if (typeof value === 'string' && value.length > 0) return value;
  }
  return undefined;
}

/**
 * The route to open when she taps it.
 *
 * Every branch either produces a path that exists in `RoutePaths` or falls
 * through to the inbox. The fallback is the point: a notification that opens
 * *something* she can read is a notification that worked, and one that opens
 * a 404 is a bug she experiences rather than one we find.
 */
export function deepLinkFor(
  type: NotificationType,
  data: NotificationData,
): string {
  const inbox = `${SCHEME}notifications`;

  switch (type) {
    case 'order':
    case 'payment': {
      const orderId = str(data, 'orderId', 'order_id');
      return orderId ? `${SCHEME}order/${orderId}` : `${SCHEME}orders`;
    }
    case 'message': {
      const chatId = str(data, 'chatId', 'chat_id');
      // Query parameter, not a path segment: that is how the route reads it.
      return chatId ? `${SCHEME}chat-details?id=${chatId}` : `${SCHEME}chats`;
    }
    case 'like':
    case 'comment':
    case 'post': {
      const contentId = str(data, 'contentId', 'content_id', 'postId', 'post_id');
      return contentId ? `${SCHEME}content/${contentId}` : inbox;
    }
    case 'follow': {
      const followerId = str(data, 'followerId', 'follower_id', 'actorId');
      return followerId ? `${SCHEME}user/${followerId}` : inbox;
    }
    case 'room': {
      const roomId = str(data, 'roomId', 'room_id');
      return roomId ? `${SCHEME}rooms/${roomId}` : `${SCHEME}rooms`;
    }
    case 'coupon':
      return `${SCHEME}coupons`;
    case 'promo': {
      // A campaign may name its own destination; an operator typing a bad one
      // is caught here rather than on a customer's phone.
      const link = str(data, 'deepLink', 'deep_link');
      if (link && link.startsWith(SCHEME)) return link;
      return `${SCHEME}home`;
    }
    case 'story':
      return `${SCHEME}home`;
    default:
      return inbox;
  }
}

/**
 * What this notification replaces on the lock screen.
 *
 * Grouped by the *thing*, not by the event: four likes on one post collapse
 * onto each other, but a like on post A and a like on post B do not. This is
 * the difference between an app that tells her something and an app she mutes.
 *
 * Undefined means "never replace anything" — which is right for a coupon, a
 * follow, and anything one-of-a-kind.
 */
export function collapseKeyFor(
  type: NotificationType,
  data: NotificationData,
): string | undefined {
  switch (type) {
    case 'order':
    case 'payment': {
      const orderId = str(data, 'orderId', 'order_id');
      // The newest status for one order is the only one worth showing. Four
      // lines walking her through paid, packed, shipped is four times the
      // noise for one fact.
      return orderId ? `order-${orderId}` : undefined;
    }
    case 'message': {
      const chatId = str(data, 'chatId', 'chat_id');
      return chatId ? `chat-${chatId}` : undefined;
    }
    case 'like':
    case 'comment': {
      const contentId = str(data, 'contentId', 'content_id');
      return contentId ? `content-${contentId}` : undefined;
    }
    case 'room': {
      const roomId = str(data, 'roomId', 'room_id');
      return roomId ? `room-${roomId}` : undefined;
    }
    default:
      return undefined;
  }
}
