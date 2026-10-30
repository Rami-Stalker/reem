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
> &
  Partial<
    Pick<
      User,
      | 'sellerLevel'
      | 'sellerVerifiedAt'
      | 'sellerPremiumUntil'
      | 'phoneVerifiedAt'
      | 'emailVerifiedAt'
      | 'profileIsPublic'
    >
  >;

/**
 * The full shape, contact details included — for the signed-in woman looking
 * at her OWN account, and for staff who legitimately need to reach her.
 *
 * Never hand this to a third party. `serializeUser` used to be the only shape
 * the API had, so every screen that mentions somebody else — a seller on an
 * order, a reviewer under a product, the author of a post, any profile at all
 * — published her `phone`, her `email`, and her `mfa_enabled` /
 * `device_verification_required` posture to whoever asked. On a platform whose
 * whole premise is that a woman can shop without her number circulating, that
 * is the one thing the payload must not carry; the two security flags are
 * worse still, because they tell an attacker which account is the soft target.
 *
 * Use {@link serializePublicUser} for anyone who is not the viewer.
 */
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
    seller_level: user.sellerLevel?.toLowerCase() ?? 'basic',
    seller_verified_at: user.sellerVerifiedAt?.toISOString() ?? null,
    seller_premium_until: user.sellerPremiumUntil?.toISOString() ?? null,
    is_verified: user.isVerified,
    phone_verified_at: user.phoneVerifiedAt?.toISOString() ?? null,
    email_verified_at: user.emailVerifiedAt?.toISOString() ?? null,
    mfa_enabled: user.mfaEnabled,
    device_verification_required: user.deviceVerificationRequired,
    followers_count: user.followersCount,
    following_count: user.followingCount,
    created_at: user.createdAt.toISOString(),
  };
}

/**
 * What one woman may see of another: who she is, not how to reach her.
 *
 * Everything identifying stays — name, username, avatar, bio, location, seller
 * standing, follower counts — because that is what a storefront header and a
 * review byline are made of. What leaves is the contact pair (`email`,
 * `phone`), the two verification timestamps that imply it, and the account's
 * security posture (`mfa_enabled`, `device_verification_required`).
 *
 * The keys are dropped rather than nulled: a `phone: null` reads as "she has
 * no number on file", which is a different and false claim.
 */
export function serializePublicUser(user: UserPublic) {
  const {
    email: _email,
    phone: _phone,
    phone_verified_at: _phoneVerifiedAt,
    email_verified_at: _emailVerifiedAt,
    mfa_enabled: _mfaEnabled,
    device_verification_required: _deviceVerificationRequired,
    ...visible
  } = serializeUser(user);
  return visible;
}

export interface ProfileExtras {
  /** A boutique's advertising plan — `silver`, `gold`, `diamond` — or null. */
  adTier?: string | null;
  isFollowing?: boolean;
  isMe?: boolean;
  productsCount?: number;
  postsCount?: number;
  /** Pieces she added to her page that this viewer may see. */
  picksCount?: number;
  /** Whether she has a live story this viewer may watch — the avatar ring. */
  hasStory?: boolean;
  /** Seller-only aggregate stats; omitted for non-sellers. */
  sellerStats?: {
    productsCount: number;
    /** One entry per currency the seller has sold in. */
    totalSales: { amount: string; currency: string }[];
    ordersCount: number;
    averageRating: number;
  } | null;
}

/**
 * Richer shape for the profile screen: relationship + aggregate stats.
 *
 * `isMe` decides which base shape is used, so `GET /users/:id` cannot hand a
 * stranger the contact details it correctly shows the account's owner. The
 * flag is already computed by the caller for `is_me`, so the privacy boundary
 * costs nothing and cannot drift out of step with the answer it reports.
 */
export function serializeUserProfile(user: UserPublic, extras: ProfileExtras = {}) {
  const isMe = extras.isMe ?? false;
  return {
    ...(isMe ? serializeUser(user) : serializePublicUser(user)),
    is_following: extras.isFollowing ?? false,
    is_me: isMe,
    products_count: extras.productsCount ?? 0,
    posts_count: extras.postsCount ?? 0,
    picks_count: extras.picksCount ?? 0,
    has_story: extras.hasStory ?? false,
    // Public by nature: a closed page has to be able to say it is closed,
    // or a stranger reads an empty page as a woman who never posted.
    profile_is_public: user.profileIsPublic ?? false,
    ad_tier: extras.adTier ?? null,
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
