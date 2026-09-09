import { Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  GuestSavedItemType,
  GuestSession,
  GuestSessionStatus,
  Prisma,
  RiskLevel,
  SecurityEventType,
} from '@prisma/client';
import { createHmac, randomBytes } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { RequestContext } from './interfaces/request-context.interface';
import { DeviceService } from './device.service';

export interface GuestSessionEnvelope {
  guest: {
    id: string;
    status: string;
    expires_at: string;
    last_seen_at: string;
  };
  guest_token: string;
}

export interface GuestMigrationSummary {
  cart_items: number;
  saved_items: number;
  /** Orders she placed as a guest and now owns under her account. */
  orders: number;
}

@Injectable()
export class GuestService {
  private readonly guestPepper: string;
  private readonly guestExpiresMs = 30 * 24 * 60 * 60_000;

  constructor(
    private readonly prisma: PrismaService,
    private readonly devices: DeviceService,
    config: ConfigService,
  ) {
    // Its own secret, not the JWT refresh key. Sharing them meant rotating
    // the JWT key after a compromise would also invalidate every guest
    // session on the platform — every anonymous cart, silently emptied.
    this.guestPepper = config.get<string>('security.guestTokenPepper') as string;
  }

  async issue(context: RequestContext): Promise<GuestSessionEnvelope> {
    const existingToken = context.guestToken?.trim();
    if (existingToken) {
      const existing = await this.touch(existingToken, context);
      if (existing) return this.envelope(existing, existingToken);
    }

    const guestToken = `gst_${randomBytes(32).toString('base64url')}`;
    const expiresAt = this.expiresAt();
    const guest = await this.prisma.guestSession.create({
      data: {
        tokenHash: this.hashGuestToken(guestToken),
        expiresAt,
        deviceId: context.deviceId,
        deviceName: context.deviceName,
        platform: context.platform,
        appVersion: context.appVersion,
        fingerprintHash: this.devices.fingerprintHash(context),
        ipAddress: context.ipAddress,
        userAgent: context.userAgent,
        securityEvents: {
          create: {
            type: SecurityEventType.GUEST_CREATED,
            riskLevel: RiskLevel.LOW,
            ipAddress: context.ipAddress,
            userAgent: context.userAgent,
            metadata: this.json({
              platform: context.platform,
              app_version: context.appVersion,
            }),
          },
        },
      },
    });

    return this.envelope(guest, guestToken);
  }

  async touch(
    guestToken: string,
    context: RequestContext,
  ): Promise<GuestSession | null> {
    const guest = await this.prisma.guestSession.findUnique({
      where: { tokenHash: this.hashGuestToken(guestToken) },
    });
    if (!this.isActive(guest)) return null;

    return this.prisma.guestSession.update({
      where: { id: guest.id },
      data: {
        lastSeenAt: new Date(),
        expiresAt: this.expiresAt(),
        deviceId: context.deviceId ?? guest.deviceId,
        deviceName: context.deviceName ?? guest.deviceName,
        platform: context.platform ?? guest.platform,
        appVersion: context.appVersion ?? guest.appVersion,
        fingerprintHash: this.devices.fingerprintHash(context),
        ipAddress: context.ipAddress ?? guest.ipAddress,
        userAgent: context.userAgent ?? guest.userAgent,
      },
    });
  }

  async requireActiveGuest(
    guestToken: string | undefined,
    context: RequestContext,
  ): Promise<GuestSession> {
    if (!guestToken) {
      throw new UnauthorizedException('Guest session is required');
    }
    const guest = await this.touch(guestToken, context);
    if (!guest) {
      throw new UnauthorizedException('Guest session has expired');
    }
    return guest;
  }

  async migrateToUser(
    guestToken: string | undefined,
    userId: string,
    context: RequestContext,
  ): Promise<GuestMigrationSummary | null> {
    if (!guestToken) return null;
    const tokenHash = this.hashGuestToken(guestToken);

    return this.prisma.$transaction(async (tx) => {
      const guest = await tx.guestSession.findUnique({
        where: { tokenHash },
        include: { cartItems: true, savedItems: true },
      });
      if (!this.isActive(guest)) return null;

      for (const item of guest.cartItems) {
        const existing = await tx.cartItem.findFirst({
          where: {
            userId,
            offerId: item.offerId,
            offerVariantId: item.offerVariantId,
          },
        });
        if (existing) {
          await tx.cartItem.update({
            where: { id: existing.id },
            data: { quantity: existing.quantity + item.quantity },
          });
        } else {
          await tx.cartItem.create({
            data: {
              userId,
              offerId: item.offerId,
              offerVariantId: item.offerVariantId,
              quantity: item.quantity,
            },
          });
        }
      }

      for (const item of guest.savedItems) {
        await this.migrateSavedItem(tx, userId, item);
      }

      // Her orders come with her.
      //
      // Since guest checkout exists, a visitor can buy before she has an
      // account — and her only claim on that order is this session. Marking
      // the session MIGRATED below retires the token, so without this the
      // orders she has already paid for would belong to a session she can no
      // longer present and to no account at all: invisible to her, and
      // reachable by nobody but support.
      //
      // `guestSessionId` is deliberately left in place rather than cleared. It
      // is how the order came in, which is worth keeping — and the ownership
      // check reads `userId` for a signed-in buyer, so the stale session id
      // grants nothing once the session itself is retired.
      const claimed = await tx.order.updateMany({
        where: { guestSessionId: guest.id, userId: null },
        data: { userId },
      });

      // And the reasoning behind any cash order she placed, so the trust
      // engine reads her history as hers from here on rather than starting
      // her at the platform's opening assumption.
      await tx.codRiskAssessment.updateMany({
        where: { order: { guestSessionId: guest.id }, userId: null },
        data: { userId },
      });


      await tx.guestSession.update({
        where: { id: guest.id },
        data: {
          status: GuestSessionStatus.MIGRATED,
          migratedToUserId: userId,
          migratedAt: new Date(),
          ipAddress: context.ipAddress ?? guest.ipAddress,
          userAgent: context.userAgent ?? guest.userAgent,
        },
      });

      await tx.securityEvent.create({
        data: {
          type: SecurityEventType.GUEST_MIGRATED,
          riskLevel: RiskLevel.LOW,
          actorId: userId,
          guestSessionId: guest.id,
          ipAddress: context.ipAddress,
          userAgent: context.userAgent,
          metadata: this.json({
            cart_items: guest.cartItems.length,
            saved_items: guest.savedItems.length,
            orders: claimed.count,
          }),
        },
      });

      return {
        cart_items: guest.cartItems.length,
        saved_items: guest.savedItems.length,
        orders: claimed.count,
      };
    });
  }

  hashGuestToken(token: string): string {
    return createHmac('sha256', this.guestPepper).update(token).digest('hex');
  }

  serialize(guest: GuestSession) {
    return {
      id: guest.id,
      status: guest.status.toLowerCase(),
      expires_at: guest.expiresAt.toISOString(),
      last_seen_at: guest.lastSeenAt.toISOString(),
    };
  }

  private async migrateSavedItem(
    tx: Prisma.TransactionClient,
    userId: string,
    item: {
      type: GuestSavedItemType;
      productId: string | null;
      sellerId: string | null;
      contentId: string | null;
    },
  ) {
    if (item.type === GuestSavedItemType.PRODUCT && item.productId) {
      const existing = await tx.favorite.findUnique({
        where: { userId_productId: { userId, productId: item.productId } },
      });
      if (!existing) {
        await tx.favorite.create({
          data: { userId, productId: item.productId },
        });
        await tx.product.update({
          where: { id: item.productId },
          data: { favoritesCount: { increment: 1 } },
        });
      }
      return;
    }

    if (item.type === GuestSavedItemType.SELLER && item.sellerId) {
      await tx.sellerFavorite.upsert({
        where: { userId_sellerId: { userId, sellerId: item.sellerId } },
        create: { userId, sellerId: item.sellerId },
        update: {},
      });
      return;
    }

    // `POST` keeps its wire spelling — it is in the shipped client's request
    // bodies — while the column beneath it follows the rows onto the content
    // platform.
    if (item.type === GuestSavedItemType.POST && item.contentId) {
      const contentId = item.contentId;
      const existing = await tx.commerceContentSave.findUnique({
        where: { contentId_userId: { contentId, userId } },
      });
      if (!existing) {
        await tx.commerceContentSave.create({ data: { userId, contentId } });
        await tx.commerceContent.update({
          where: { id: contentId },
          data: { savesCount: { increment: 1 } },
        });
      }
    }
  }

  private envelope(
    guest: GuestSession,
    guestToken: string,
  ): GuestSessionEnvelope {
    return {
      guest: this.serialize(guest),
      guest_token: guestToken,
    };
  }

  private isActive(guest: GuestSession | null): guest is GuestSession {
    return (
      !!guest &&
      guest.status === GuestSessionStatus.ACTIVE &&
      guest.expiresAt > new Date()
    );
  }

  private expiresAt(): Date {
    return new Date(Date.now() + this.guestExpiresMs);
  }

  private json(value: Record<string, unknown>): Prisma.InputJsonValue {
    return value as Prisma.InputJsonValue;
  }
}
