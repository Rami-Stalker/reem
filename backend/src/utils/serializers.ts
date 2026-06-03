import type {
  Address,
  Chat,
  Coupon,
  Message,
  Notification,
  Order,
  PaymentMethod,
  Post,
  Product,
  Story,
  User,
  ProductMedia,
  ChatParticipant,
} from '@prisma/client';

type UserPublic = Pick<
  User,
  'id' | 'name' | 'username' | 'email' | 'bio' | 'imageUrl' | 'isVerified' | 'createdAt'
>;

type ProductWithRelations = Product & {
  seller: User;
  media: ProductMedia[];
};

type PostWithRelations = Post & {
  author: User;
  product: ProductWithRelations;
  likes?: { userId: string }[];
};

type StoryWithRelations = Story & {
  user: User;
  views?: { userId: string }[];
};

type OrderWithItems = Order & {
  items: { id: string }[];
};

type ChatWithRelations = Chat & {
  participants: (ChatParticipant & { user: User })[];
  messages: Message[];
};

export function serializeUser(user: UserPublic) {
  return {
    id: user.id,
    name: user.name,
    username: user.username,
    email: user.email,
    bio: user.bio,
    image_url: user.imageUrl,
    is_verified: user.isVerified,
    created_at: user.createdAt.toISOString(),
  };
}

export function serializeProduct(
  product: ProductWithRelations,
  options?: { isLiked?: boolean },
) {
  return {
    id: product.id,
    seller: serializeUser(product.seller),
    title: product.title,
    description: product.description,
    price: product.price,
    old_price: product.oldPrice,
    media: product.media
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map((m) => ({
        url: m.url,
        type: m.type,
      })),
    is_available: product.isAvailable,
    is_featured: product.isFeatured,
    views_count: product.viewsCount,
    likes_count: product.likesCount,
    created_at: product.createdAt.toISOString(),
    ...(options?.isLiked !== undefined ? { is_liked: options.isLiked } : {}),
  };
}

export function serializePost(
  post: PostWithRelations,
  currentUserId?: string,
) {
  const isLiked =
    currentUserId && post.likes
      ? post.likes.some((l) => l.userId === currentUserId)
      : false;

  return {
    id: post.id,
    author: serializeUser(post.author),
    product: serializeProduct(post.product),
    caption: post.caption,
    likes_count: post.likesCount,
    comments_count: post.commentsCount,
    shares_count: post.sharesCount,
    is_liked: isLiked,
    created_at: post.createdAt.toISOString(),
  };
}

export function serializeStory(
  story: StoryWithRelations,
  currentUserId?: string,
) {
  const isViewed =
    currentUserId && story.views
      ? story.views.some((v) => v.userId === currentUserId)
      : false;

  return {
    id: story.id,
    user: serializeUser(story.user),
    media: {
      url: story.mediaUrl,
      type: story.mediaType,
    },
    link: story.link,
    is_viewed: isViewed,
    expires_at: story.expiresAt.toISOString(),
    created_at: story.createdAt.toISOString(),
  };
}

export function serializeOrder(order: OrderWithItems) {
  return {
    id: order.id,
    status: order.status.toLowerCase(),
    total: order.total,
    items_count: order.items.length,
    created_at: order.createdAt.toISOString(),
  };
}

export function serializeAddress(address: Address) {
  return {
    id: address.id,
    label: address.label,
    street: address.street,
    city: address.city,
    country: address.country,
    postal_code: address.postalCode,
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

export function serializeChatThread(
  chat: ChatWithRelations,
  currentUserId: string,
) {
  const other = chat.participants.find((p) => p.userId !== currentUserId)?.user;
  const lastMessage = chat.messages[0];
  const unreadCount = 0;

  return {
    id: chat.id,
    title: other?.name ?? 'Chat',
    avatar_url: other?.imageUrl ?? '',
    last_message: lastMessage?.content ?? '',
    unread_count: unreadCount,
    updated_at: (lastMessage?.createdAt ?? chat.updatedAt).toISOString(),
    online: false,
  };
}

export function serializeMessage(message: Message, currentUserId: string) {
  return {
    id: message.id,
    chat_id: message.chatId,
    sender_id: message.senderId,
    content: message.content,
    sent_at: message.createdAt.toISOString(),
    created_at: message.createdAt.toISOString(),
    is_mine: message.senderId === currentUserId,
  };
}

export function authResponse(user: UserPublic, tokens: {
  access_token: string;
  refresh_token: string;
}) {
  return {
    user: serializeUser(user),
    tokens,
  };
}
