import { SellerLevel, UserRole } from '@prisma/client';

export type AuthorizationResource =
  | 'account'
  | 'admin'
  | 'analytics'
  /// The authentication record of an account: events, attempts, challenges.
  | 'audit'
  | 'cart'
  | 'commission'
  | 'content'
  | 'device'
  | 'favorite'
  | 'finance'
  | 'guest'
  | 'order'
  | 'post'
  | 'product'
  | 'review'
  | 'seller'
  | 'session'
  | 'story'
  | 'support'
  | 'wishlist';

export type OwnershipResource =
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
