import { User } from '@prisma/client';

export type UserPublic = Pick<
  User,
  | 'id'
  | 'name'
  | 'username'
  | 'email'
  | 'phone'
  | 'bio'
  | 'imageUrl'
  | 'location'
  | 'role'
  | 'isVerified'
  | 'mfaEnabled'
  | 'deviceVerificationRequired'
  | 'followersCount'
  | 'followingCount'
  | 'createdAt'
>;

/** Public user shape returned across the API (snake_case JSON contract). */
export function serializeUser(user: UserPublic) {
  return {
    id: user.id,
    name: user.name,
    username: user.username,
    email: user.email,
    phone: user.phone,
    bio: user.bio,
    image_url: user.imageUrl,
    location: user.location,
    role: user.role.toLowerCase(),
    is_verified: user.isVerified,
    mfa_enabled: user.mfaEnabled,
    device_verification_required: user.deviceVerificationRequired,
    followers_count: user.followersCount,
    following_count: user.followingCount,
    created_at: user.createdAt.toISOString(),
  };
}

export interface ProfileExtras {
  isFollowing?: boolean;
  isMe?: boolean;
  productsCount?: number;
  postsCount?: number;
  /** Seller-only aggregate stats; omitted for non-sellers. */
  sellerStats?: {
    productsCount: number;
    totalSales: number;
    ordersCount: number;
    averageRating: number;
  } | null;
}

/** Richer shape for the profile screen: relationship + aggregate stats. */
export function serializeUserProfile(user: UserPublic, extras: ProfileExtras = {}) {
  return {
    ...serializeUser(user),
    is_following: extras.isFollowing ?? false,
    is_me: extras.isMe ?? false,
    products_count: extras.productsCount ?? 0,
    posts_count: extras.postsCount ?? 0,
    seller_stats: extras.sellerStats
      ? {
          products_count: extras.sellerStats.productsCount,
          total_sales: extras.sellerStats.totalSales,
          orders_count: extras.sellerStats.ordersCount,
          average_rating: extras.sellerStats.averageRating,
        }
      : null,
  };
}
