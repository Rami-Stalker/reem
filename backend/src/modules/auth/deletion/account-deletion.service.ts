import { ConflictException, Injectable, Logger } from '@nestjs/common';
import {
  AppointmentStatus,
  AuditSeverity,
  CommerceContentCommentStatus,
  CommerceContentStatus,
  DeviceTrustLevel,
  OfferStatus,
  OrderStatus,
  PayoutStatus,
  Prisma,
  SalonStatus,
  SellerOrderStatus,
  SessionStatus,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { AuditService } from '../audit.service';
import { RequestContext } from '../interfaces/request-context.interface';

/** What stands between her and deleting the account, as the app shows it. */
export type DeletionBlockerCode =
  | 'STAFF_ACCOUNT'
  | 'OPEN_ORDERS'
  | 'OPEN_SALES'
  | 'WALLET_BALANCE'
  | 'PENDING_PAYOUTS'
  | 'UPCOMING_APPOINTMENTS';

export interface DeletionBlocker {
  code: DeletionBlockerCode;
  count: number;
}

/** The name an anonymised account shows wherever its old rows still appear. */
export const DELETED_ACCOUNT_NAME = 'حساب محذوف';

/** Only these may delete themselves. Staff accounts are closed by an admin. */
const SELF_SERVICE_ROLES: readonly UserRole[] = [
  UserRole.CUSTOMER,
  UserRole.SELLER,
];

/**
 * A parcel still moving, or money still moving because of it.
 *
 * Delivered and cancelled are not here: a delivered parcel inside its return
 * window must not hold an account hostage, and a return opened later is the
 * seller's to settle against the order record, which is kept.
 */
const OPEN_SELLER_ORDER: readonly SellerOrderStatus[] = [
  SellerOrderStatus.NEW,
  SellerOrderStatus.AWAITING_SELLER_CONFIRMATION,
  SellerOrderStatus.PREPARING,
  SellerOrderStatus.READY_TO_SHIP,
  SellerOrderStatus.HANDED_TO_COURIER,
  SellerOrderStatus.IN_TRANSIT,
  SellerOrderStatus.DELIVERY_FAILED,
  SellerOrderStatus.RETURN_REQUESTED,
  SellerOrderStatus.RETURN_IN_TRANSIT,
  SellerOrderStatus.EXCHANGE_IN_PROGRESS,
  SellerOrderStatus.REFUND_PENDING,
  SellerOrderStatus.DISPUTED,
];

/**
 * She deletes her own account.
 *
 * ## What "deleted" means here
 *
 * The user row is kept and emptied, not removed. Orders, invoices, ledger
 * entries, payouts and commissions point at it, and those are records the law
 * and the accounts require us to keep — removing the row would either cascade
 * them away or be refused by the foreign keys. So the row stays as an
 * anonymous anchor: no name, no phone, no email, no photo, no password, no way
 * to sign in, and her phone number free to register a new account.
 *
 * Everything that only described *her* is deleted outright: addresses, saved
 * payment methods, basket, favourites, wishlists, search history, follows,
 * notifications, her stylist conversations and taste profile, every
 * credential and device. Her public content is taken down, which is what the
 * content policy promises. Reviews she wrote stay, under "حساب محذوف", because
 * they are part of a shop's reputation — also what the policy says. What a
 * review said about *her body* does not stay with it: the photographs of her
 * wearing the piece, her height band and her usual size are removed, and her
 * fit profile is deleted. How the piece fit and the size that shipped are
 * about the product, and remain.
 *
 * Kept: orders and their delivery snapshots, invoices, the ledger and wallet
 * history, payouts, the audit and security logs (fraud and dispute evidence,
 * pruned by their own retention jobs), and chat messages she sent, which
 * belong to the other woman's conversation as much as to hers.
 *
 * ## When it is refused
 *
 * While deleting would strand somebody: a parcel still on its way to or from
 * her, money still owed to her, an appointment still to come. Each comes back
 * as a blocker the app can name, and the check runs before the step-up so she
 * is not asked for a code only to be told no.
 */
@Injectable()
export class AccountDeletionService {
  private readonly logger = new Logger(AccountDeletionService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly audit: AuditService,
  ) {}

  /** Whether she can delete the account now, and if not, why not. */
  async preflight(userId: string) {
    const blockers = await this.blockersFor(userId);
    return {
      can_delete: blockers.length === 0,
      blockers,
    };
  }

  async deleteAccount(
    userId: string,
    reason: string | undefined,
    context?: RequestContext,
  ) {
    const blockers = await this.blockersFor(userId);
    if (blockers.length > 0) {
      throw new ConflictException({
        code: 'ACCOUNT_DELETION_BLOCKED',
        message: 'This account cannot be deleted yet',
        blockers,
      });
    }

    const now = new Date();
    await this.prisma.$transaction(
      async (tx) => {
        // Taken first and under a row lock, so two taps cannot both run the
        // wipe, and nothing re-enables the account half way through.
        const locked = await tx.$queryRaw<{ deleted_at: Date | null }[]>`
          SELECT deleted_at FROM users WHERE id = ${userId}::uuid FOR UPDATE`;
        if (locked.length === 0 || locked[0].deleted_at) {
          throw new ConflictException({
            code: 'ACCOUNT_ALREADY_DELETED',
            message: 'This account has already been deleted',
          });
        }

        await this.endEveryWayIn(tx, userId, now);
        await this.removePersonalData(tx, userId);
        await this.takeDownContent(tx, userId, now);
        await this.closeShop(tx, userId);
        await this.anonymise(tx, userId, now);
      },
      { timeout: 60_000 },
    );

    await this.audit.record({
      actorId: userId,
      action: 'account_deleted',
      category: 'privacy',
      outcome: 'success',
      severity: AuditSeverity.WARNING,
      // Only her own words, and only if she chose to give them. Nothing that
      // identifies her goes in here: this log outlives the account.
      metadata: reason ? { reason } : undefined,
      context,
    });
    this.logger.log(`Account ${userId} deleted by its owner`);

    return { deleted: true };
  }

  // ── What blocks it ───────────────────────────────────────────────────────

  async blockersFor(userId: string): Promise<DeletionBlocker[]> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { role: true },
    });
    if (!user) return [];

    const blockers: DeletionBlocker[] = [];
    if (!SELF_SERVICE_ROLES.includes(user.role)) {
      // A staff account carries permissions over other women's data, and
      // closing one is an admin decision with its own audit trail.
      blockers.push({ code: 'STAFF_ACCOUNT', count: 1 });
    }

    const [
      unpaidOrders,
      openPurchases,
      openSales,
      wallets,
      payouts,
      appointments,
    ] = await Promise.all([
      this.prisma.order.count({
        where: { userId, status: OrderStatus.PENDING_PAYMENT },
      }),
      this.prisma.sellerOrder.count({
        where: { order: { userId }, status: { in: [...OPEN_SELLER_ORDER] } },
      }),
      this.prisma.sellerOrder.count({
        where: { sellerId: userId, status: { in: [...OPEN_SELLER_ORDER] } },
      }),
      this.prisma.wallet.findMany({
        where: { userId, balance: { not: 0 } },
        select: { id: true },
      }),
      this.prisma.sellerPayout.count({
        where: {
          sellerId: userId,
          status: { in: [PayoutStatus.PENDING, PayoutStatus.APPROVED] },
        },
      }),
      this.prisma.appointment.count({
        where: {
          status: {
            in: [AppointmentStatus.PENDING, AppointmentStatus.CONFIRMED],
          },
          OR: [{ customerId: userId }, { salon: { ownerId: userId } }],
        },
      }),
    ]);

    if (unpaidOrders + openPurchases > 0) {
      blockers.push({ code: 'OPEN_ORDERS', count: unpaidOrders + openPurchases });
    }
    if (openSales > 0) blockers.push({ code: 'OPEN_SALES', count: openSales });
    if (wallets.length > 0) {
      blockers.push({ code: 'WALLET_BALANCE', count: wallets.length });
    }
    if (payouts > 0) blockers.push({ code: 'PENDING_PAYOUTS', count: payouts });
    if (appointments > 0) {
      blockers.push({ code: 'UPCOMING_APPOINTMENTS', count: appointments });
    }
    return blockers;
  }

  // ── The wipe ─────────────────────────────────────────────────────────────

  /** Every session, token, device and second factor. Nothing can sign in. */
  private async endEveryWayIn(
    tx: Prisma.TransactionClient,
    userId: string,
    now: Date,
  ) {
    await tx.refreshToken.updateMany({
      where: { userId, revokedAt: null },
      data: { revokedAt: now },
    });
    await tx.session.updateMany({
      where: { userId, status: SessionStatus.ACTIVE },
      data: {
        status: SessionStatus.REVOKED,
        revokedAt: now,
        revokedReason: 'account_deleted',
      },
    });
    await tx.deviceKey.updateMany({
      where: { userId, revokedAt: null },
      data: {
        revokedAt: now,
        revokedReason: 'account_deleted',
        trustLevel: DeviceTrustLevel.BLOCKED,
      },
    });
    await tx.pushToken.deleteMany({ where: { userId } });
    await tx.device.deleteMany({ where: { userId } });
    await tx.totpCredential.deleteMany({ where: { userId } });
    await tx.recoveryCode.deleteMany({ where: { userId } });
    await tx.stepUpGrant.deleteMany({ where: { userId } });
    await tx.phoneChangeRequest.deleteMany({ where: { userId } });
  }

  /** What only ever described her. Deleted, not hidden. */
  private async removePersonalData(
    tx: Prisma.TransactionClient,
    userId: string,
  ) {
    await tx.address.deleteMany({ where: { userId } });
    await tx.paymentMethod.deleteMany({ where: { userId } });
    await tx.cartItem.deleteMany({ where: { userId } });
    await tx.searchHistory.deleteMany({ where: { userId } });
    await tx.favorite.deleteMany({ where: { userId } });
    await tx.sellerFavorite.deleteMany({
      where: { OR: [{ userId }, { sellerId: userId }] },
    });
    await tx.wishlistShare.deleteMany({ where: { userId } });
    await tx.wishlistCollection.deleteMany({ where: { userId } });
    await tx.notification.deleteMany({ where: { userId } });
    await tx.notificationDelivery.deleteMany({ where: { userId } });
    await tx.notificationPreference.deleteMany({ where: { userId } });
    await tx.userPresence.deleteMany({ where: { userId } });
    await tx.userStylePreference.deleteMany({ where: { userId } });
    // «تقييمات من بمقاسي». Her review text stays under "حساب محذوف"; the
    // photographs of her in the piece, and the height and size that
    // described her, do not.
    await tx.fitProfile.deleteMany({ where: { userId } });
    await tx.productReview.updateMany({
      where: { userId },
      data: { photoUrls: [], heightBand: null, usualSize: null },
    });
    await tx.userStyleSignal.deleteMany({ where: { userId } });
    await tx.aiStylistConversation.deleteMany({ where: { userId } });

    // Follows, in both directions, with the counters on the other side kept
    // honest — otherwise every shop she followed keeps a follower who is gone.
    const following = await tx.follow.findMany({
      where: { followerId: userId },
      select: { followingId: true },
    });
    const followers = await tx.follow.findMany({
      where: { followingId: userId },
      select: { followerId: true },
    });
    await tx.follow.deleteMany({
      where: { OR: [{ followerId: userId }, { followingId: userId }] },
    });
    if (following.length > 0) {
      await tx.user.updateMany({
        where: {
          id: { in: following.map((row) => row.followingId) },
          followersCount: { gt: 0 },
        },
        data: { followersCount: { decrement: 1 } },
      });
    }
    if (followers.length > 0) {
      await tx.user.updateMany({
        where: {
          id: { in: followers.map((row) => row.followerId) },
          followingCount: { gt: 0 },
        },
        data: { followingCount: { decrement: 1 } },
      });
    }
  }

  /**
   * Her posts, reels and comments come down; her likes, saves and reshares
   * go. Posts are marked DELETED and comments REMOVED rather than erased, so
   * a report already filed against one keeps its evidence; neither is shown
   * anywhere.
   */
  private async takeDownContent(
    tx: Prisma.TransactionClient,
    userId: string,
    now: Date,
  ) {
    await tx.commerceContent.updateMany({
      where: {
        authorId: userId,
        status: {
          notIn: [CommerceContentStatus.REMOVED, CommerceContentStatus.DELETED],
        },
      },
      data: { status: CommerceContentStatus.DELETED, removedAt: now },
    });
    await tx.commerceContentComment.updateMany({
      where: {
        userId,
        status: { not: CommerceContentCommentStatus.REMOVED },
      },
      data: { status: CommerceContentCommentStatus.REMOVED, removedAt: now },
    });
    await tx.commerceContentReaction.deleteMany({ where: { userId } });
    await tx.commerceContentSave.deleteMany({ where: { userId } });
    await tx.commerceContentReshare.deleteMany({
      where: { resharerId: userId },
    });
  }

  /** A seller's offers stop selling and her salons stop taking bookings. */
  private async closeShop(tx: Prisma.TransactionClient, userId: string) {
    await tx.sellerOffer.updateMany({
      where: { sellerId: userId },
      data: { isActive: false, status: OfferStatus.ARCHIVED },
    });
    await tx.salon.updateMany({
      where: { ownerId: userId },
      data: { status: SalonStatus.SUSPENDED },
    });
  }

  /** The row that is left: an anchor for the records, and nothing else. */
  private async anonymise(
    tx: Prisma.TransactionClient,
    userId: string,
    now: Date,
  ) {
    await tx.user.update({
      where: { id: userId },
      data: {
        name: DELETED_ACCOUNT_NAME,
        // Unique, and derived from nothing she chose.
        username: `deleted-${userId}`,
        email: null,
        // Freed, so the number can register a new account.
        phone: null,
        passwordHash: null,
        passwordSetAt: null,
        bio: null,
        imageUrl: null,
        location: null,
        isVerified: false,
        verifiedAt: null,
        phoneVerifiedAt: null,
        emailVerifiedAt: null,
        mfaEnabled: false,
        profileIsPublic: false,
        profilePublicSince: null,
        followersCount: 0,
        followingCount: 0,
        lockedUntil: null,
        failedLoginCount: 0,
        disabledAt: now,
        deletedAt: now,
      },
    });
  }
}
