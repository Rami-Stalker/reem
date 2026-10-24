import {
  GuestSavedItemType,
  GuestSessionStatus,
  SecurityEventType,
} from '@prisma/client';
import { DemoContext } from './context';

/**
 * Guest journeys — the unauthenticated browse-and-collect flow.
 *
 * "Browsing without an account works, signing in only gates interaction and
 * purchase" is one of the platform's founding rules, and the guest cart is
 * what makes it real: a visitor fills a basket, then signs up and the basket
 * migrates to her account. Both halves of that story need rows — an active
 * guest still shopping, and a migrated one that proves the handover worked.
 */
export async function seedGuestJourneys(
  ctx: DemoContext,
  postIds: string[],
): Promise<void> {
  const { prisma, rng } = ctx;

  const devices = [
    { name: 'Xiaomi Redmi Note 12', platform: 'android' },
    { name: 'iPhone 12', platform: 'ios' },
    { name: 'Chrome', platform: 'web' },
  ];

  for (let index = 0; index < 4; index += 1) {
    const device = devices[index % devices.length];
    const createdAt = rng.pastDate(20, 0);
    // The last one has already converted into a registered shopper.
    const migrated = index === 3;

    const session = await prisma.guestSession.create({
      data: {
        tokenHash: `guest-token-${index}-${rng.int(100000, 999999)}`,
        status: migrated
          ? GuestSessionStatus.MIGRATED
          : GuestSessionStatus.ACTIVE,
        deviceId: `guest-device-${index}`,
        deviceName: device.name,
        platform: device.platform,
        appVersion: '1.4.0',
        fingerprintHash: `guest-fp-${index}`,
        ipAddress: `31.9.${rng.int(1, 254)}.${rng.int(1, 254)}`,
        userAgent: `Ohara/1.4.0 (${device.platform})`,
        migratedToUserId: migrated ? ctx.customers[0].id : null,
        migratedAt: migrated ? rng.pastDate(3) : null,
        expiresAt: rng.futureDate(30, 5),
        lastSeenAt: rng.pastDate(2),
        createdAt,
      },
    });

    await prisma.securityEvent.create({
      data: {
        type: migrated
          ? SecurityEventType.GUEST_MIGRATED
          : SecurityEventType.GUEST_CREATED,
        guestSessionId: session.id,
        actorId: migrated ? ctx.customers[0].id : null,
        ipAddress: session.ipAddress,
        userAgent: session.userAgent,
        createdAt,
      },
    });

    if (migrated) continue;

    for (const product of rng.sample(ctx.products, rng.int(1, 3))) {
      const offer = product.offers[0];
      if (!offer) continue;
      await prisma.guestCartItem.create({
        data: {
          guestSessionId: session.id,
          offerId: offer.id,
          offerVariantId: offer.variants.length
            ? rng.pick(offer.variants).id
            : null,
          quantity: rng.int(1, 2),
          createdAt: rng.pastDate(5),
        },
      });
    }

    for (const product of rng.sample(ctx.products, rng.int(1, 4))) {
      await prisma.guestSavedItem.create({
        data: {
          guestSessionId: session.id,
          type: GuestSavedItemType.PRODUCT,
          productId: product.id,
          createdAt: rng.pastDate(8),
        },
      });
    }

    await prisma.guestSavedItem.create({
      data: {
        guestSessionId: session.id,
        type: GuestSavedItemType.SELLER,
        sellerId: rng.pick(ctx.sellers).id,
      },
    });

    if (postIds.length) {
      await prisma.guestSavedItem.create({
        data: {
          guestSessionId: session.id,
          type: GuestSavedItemType.POST,
          contentId: rng.pick(postIds),
        },
      });
    }
  }
}
