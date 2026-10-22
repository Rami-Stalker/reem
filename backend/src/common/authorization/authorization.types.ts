import { SellerLevel, UserRole } from '@prisma/client';

export type AuthorizationResource =
  | 'account'
  | 'admin'
  | 'analytics'
  /// The authentication record of an account: events, attempts, challenges.
  | 'audit'
  | 'cart'
  | 'commission'
  | 'comment'
  | 'content'
  | 'device'
  | 'favorite'
  | 'finance'
  | 'guest'
  | 'order'
  /// The published terms, privacy and policy documents, and their versions.
  | 'policy'
  | 'post'
  | 'product'
  | 'review'
  /// الصالونات والجمال — a salon and its menu, hours and queue.
  | 'salon'
  /// One booking. Its own resource rather than a verb on `salon`, because the
  /// two have different owners: a salon belongs to the woman who runs it, an
  /// appointment belongs equally to her and to the customer who made it.
  | 'appointment'
  | 'seller'
  | 'session'
  | 'story'
  | 'support'
  | 'wishlist';

export type OwnershipResource =
  /**
   * A piece of social content — a post, a reel, a story. One resource for all
   * three: they differ by content type, which is registry data, and an
   * ownership rule that had to be extended every time a format was added would
   * be a rule that fails open on the newest one.
   */
  | 'commerceContent'
  | 'order'
  | 'post'
  /**
   * A canonical catalog entry has no single owner — several sellers may list
   * it. "Owning" a product means holding a live offer on it.
   */
  | 'product'
  | 'sellerOffer'
  | 'sellerOrder'
  | 'story'
  | 'wishlistCollection';

export interface OwnershipRule {
  resource: OwnershipResource;
  param?: string;
}

export interface AuthorizationPolicy {
  action: string;
  resource: AuthorizationResource;
  roles?: UserRole[];
  permissions?: string[];
  allowGuest?: boolean;
  requireSellerVerified?: boolean;
  sellerLevels?: SellerLevel[];
  ownership?: OwnershipRule;
}
