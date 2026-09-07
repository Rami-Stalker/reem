import { Injectable } from '@nestjs/common';
import { Request } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../decorators/current-user.decorator';
import {
  AuthorizationPolicy,
  OwnershipResource,
  OwnershipRule,
} from './authorization.types';
import { resolvePermissions } from './permission-resolver';
import { SellerLevel, UserRole } from '@prisma/client';

/** Roles that may act on a resource they do not own, and on which resources. */
const OWNERSHIP_BYPASS: Record<OwnershipResource, UserRole[]> = {
  // Moderation is the job: a moderator must be able to take down a post or a
  // story she did not write.
  post: [UserRole.OPERATIONS_ADMIN, UserRole.CONTENT_MODERATOR, UserRole.ADMIN],
  story: [UserRole.OPERATIONS_ADMIN, UserRole.CONTENT_MODERATOR, UserRole.ADMIN],
  // The same three, for the same reason, on the platform the other two are
  // being folded into. Support is deliberately absent: answering "where is my
  // parcel" is not a reason to edit somebody's photographs.
  commerceContent: [
    UserRole.OPERATIONS_ADMIN,
    UserRole.CONTENT_MODERATOR,
    UserRole.ADMIN,
  ],
  // Catalog: operations and moderation curate listings.
  product: [
    UserRole.OPERATIONS_ADMIN,
    UserRole.CONTENT_MODERATOR,
    UserRole.ADMIN,
  ],
  sellerOffer: [UserRole.OPERATIONS_ADMIN, UserRole.ADMIN],
  // Fulfilment and money: support answers "where is my parcel", finance
  // reconciles it. A content moderator has no business in either.
  sellerOrder: [
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPPORT_ADMIN,
    UserRole.SUPPORT,
    UserRole.FINANCE_ADMIN,
    UserRole.ADMIN,
  ],
  order: [
    UserRole.OPERATIONS_ADMIN,
    UserRole.SUPPORT_ADMIN,
    UserRole.SUPPORT,
    UserRole.FINANCE_ADMIN,
    UserRole.ADMIN,
  ],
  /**
   * Nobody.
   *
   * A wishlist is a list of things a woman wants and has not bought — the most
   * revealing object in the product and the one with no operational reason to
   * be read by staff. There is no support ticket that is answered by reading
   * it, so no role gets to.
   */
  wishlistCollection: [],
};

@Injectable()
export class AuthorizationService {
  constructor(private readonly prisma: PrismaService) {}

  async can(
    user: AuthUser | undefined,
    policy: AuthorizationPolicy,
    request: Request,
  ): Promise<boolean> {
    if (!user) return policy.allowGuest === true;
    if (user.role === UserRole.SUPER_ADMIN) return true;

    if (policy.roles?.length && !policy.roles.includes(user.role)) {
      return false;
    }

    if (policy.permissions?.length) {
      const permissions = await this.permissionsFor(user, request);
      const allowed = policy.permissions.every((permission) =>
        permissions.has(permission),
      );
      if (!allowed) return false;
    }

    if (policy.requireSellerVerified) {
      if (!(await this.isVerifiedSeller(user, policy.sellerLevels))) {
        return false;
      }
    }

    if (policy.ownership) {
      return this.ownsOrCanBypass(user, policy.ownership, request);
    }

    return true;
  }

  isAdministrativeRole(role: UserRole): boolean {
    const administrativeRoles: UserRole[] = [
      UserRole.SUPER_ADMIN,
      UserRole.OPERATIONS_ADMIN,
      UserRole.SUPPORT_ADMIN,
      UserRole.FINANCE_ADMIN,
      UserRole.CONTENT_MODERATOR,
      UserRole.ADMIN,
      UserRole.SUPPORT,
    ];
    return administrativeRoles.includes(role);
  }

  /**
   * The permissions this principal actually holds, right now.
   *
   * It used to read the `permissions` claim off the access token and, if that
   * was non-empty, never consult the database at all. So the set that decided
   * every request was the set as it stood when the token was minted, and a
   * revoked permission or a lapsed `UserRoleAssignment` kept working until the
   * token expired. The role was refreshed from the database on every request
   * by the JWT strategy — permissions were not, which made permission-gated
   * routes strictly weaker than role-gated ones, the opposite of the intent.
   *
   * Now it resolves from the database, memoised for the life of the request so
   * a route with several policies pays for one lookup. Routes that declare no
   * permissions never reach here and pay nothing.
   */
  async permissionsFor(user: AuthUser, request?: Request): Promise<Set<string>> {
    const cache = request as PermissionCarrier | undefined;
    if (cache?.__resolvedPermissions) return cache.__resolvedPermissions;

    const permissions = await resolvePermissions(
      this.prisma,
      user.id,
      user.role,
    );
    if (cache) cache.__resolvedPermissions = permissions;
    return permissions;
  }

  private async isVerifiedSeller(
    user: AuthUser,
    levels?: SellerLevel[],
  ): Promise<boolean> {
    if (user.role !== UserRole.SELLER) return false;
    const seller = await this.prisma.user.findUnique({
      where: { id: user.id },
      select: {
        sellerLevel: true,
        sellerVerifiedAt: true,
        sellerPremiumUntil: true,
      },
    });
    if (!seller?.sellerVerifiedAt) return false;
    if (!levels?.length) return true;
    if (!levels.includes(seller.sellerLevel)) return false;
    if (
      seller.sellerLevel === SellerLevel.PREMIUM &&
      seller.sellerPremiumUntil &&
      seller.sellerPremiumUntil < new Date()
    ) {
      return false;
    }
    return true;
  }

  /**
   * Ownership, or a role explicitly allowed past it **for this resource**.
   *
   * The bypass used to be a single `isAdministrativeRole` check, which let any
   * of the seven staff roles read any object of any kind by id — so a content
   * moderator, whose job is posts and stories, could read a customer's orders
   * and her wishlist. That is the same over-reach the forensics endpoints were
   * carefully written to avoid, arriving through the back door. See
   * {@link OWNERSHIP_BYPASS}, which names the roles per resource and gives
   * wishlists to nobody.
   */
  private async ownsOrCanBypass(
    user: AuthUser,
    ownership: OwnershipRule,
    request: Request,
  ): Promise<boolean> {
    if (OWNERSHIP_BYPASS[ownership.resource].includes(user.role)) return true;

    const rawId = request.params[ownership.param ?? 'id'];
    const id = Array.isArray(rawId) ? rawId[0] : rawId;
    if (!id) return false;

    return this.owns(ownership.resource, id, user.id);
  }

  /**
   * Ownership is a predicate, not a single owner id: a shared catalog entry is
   * "owned" by every seller listing it, and a sub-order by exactly one.
   */
  private async owns(
    resource: OwnershipRule['resource'],
    id: string,
    userId: string,
  ): Promise<boolean> {
    switch (resource) {
      case 'product': {
        const offer = await this.prisma.sellerOffer.findFirst({
          where: { productId: id, sellerId: userId },
          select: { id: true },
        });
        return offer !== null;
      }
      case 'sellerOffer': {
        const row = await this.prisma.sellerOffer.findUnique({
          where: { id },
          select: { sellerId: true },
        });
        return row?.sellerId === userId;
      }
      case 'sellerOrder': {
        // Either party to the parcel may read it: the seller fulfilling it and
        // the customer who bought it.
        const row = await this.prisma.sellerOrder.findUnique({
          where: { id },
          select: { sellerId: true, order: { select: { userId: true } } },
        });
        return row?.sellerId === userId || row?.order.userId === userId;
      }
      case 'post': {
        const row = await this.prisma.commerceContent.findFirst({
          where: { id, contentType: 'product_post' },
          select: { authorId: true },
        });
        return row?.authorId === userId;
      }
      case 'commerceContent': {
        const row = await this.prisma.commerceContent.findUnique({
          where: { id },
          select: { authorId: true },
        });
        return row?.authorId === userId;
      }
      case 'story': {
        const row = await this.prisma.commerceContent.findFirst({
          where: { id, contentType: 'story' },
          select: { authorId: true },
        });
        return row?.authorId === userId;
      }
      case 'order': {
        const row = await this.prisma.order.findUnique({
          where: { id },
          select: { userId: true },
        });
        return row?.userId === userId;
      }
      case 'wishlistCollection': {
        const row = await this.prisma.wishlistCollection.findUnique({
          where: { id },
          select: { userId: true },
        });
        return row?.userId === userId;
      }
    }
  }
}

/** Per-request memo for the resolved permission set. */
interface PermissionCarrier {
  __resolvedPermissions?: Set<string>;
}
