import {
  DeviceTrustLevel,
  PrismaClient,
  PresenceStatus,
  SellerBadgeType,
  SellerLevel,
  SellerProgramTier,
  SellerVerificationStatus,
  TrustVerificationStatus,
  UserRole,
} from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import {
  COMMUNITY_FAMILY_NAMES,
  COMMUNITY_FIRST_NAMES,
  CUSTOMERS,
  SELLERS,
} from './data';
import { avatarImage, storeLogo } from './media';
import { Rng } from './rng';
import { DemoCustomer, DemoSeller } from './context';

const SELLER_PASSWORD = 'Seller123!';
const CUSTOMER_PASSWORD = 'Password123!';

/**
 * Creates the boutiques and shoppers the rest of the demo dataset hangs off.
 *
 * Password hashing is the slowest part of the seed (bcrypt cost 12 × 20 users),
 * so the two hashes are computed once and shared — every demo seller uses the
 * same password anyway, and it is printed at the end of the run.
 */
export async function seedPeople(
  prisma: PrismaClient,
  rng: Rng,
  adminId: string,
): Promise<{ sellers: DemoSeller[]; customers: DemoCustomer[] }> {
  const [sellerHash, customerHash] = await Promise.all([
    bcrypt.hash(SELLER_PASSWORD, 12),
    bcrypt.hash(CUSTOMER_PASSWORD, 12),
  ]);

  const sellerRole = await prisma.role.findUnique({
    where: { name: UserRole.SELLER },
  });
  const customerRole = await prisma.role.findUnique({
    where: { name: UserRole.CUSTOMER },
  });

  const sellers: DemoSeller[] = [];

  for (const seed of SELLERS) {
    const verifiedAt = rng.pastDate(400, 60);
    const user = await prisma.user.create({
      data: {
        name: seed.name,
        username: seed.username,
        phone: seed.phone,
        passwordHash: sellerHash,
        passwordSetAt: new Date(),
        role: UserRole.SELLER,
        bio: seed.bio,
        location: `${seed.city}، سوريا`,
        imageUrl: storeLogo(seed.username),
        isVerified: seed.level !== 'BASIC',
        phoneVerifiedAt: verifiedAt,
        declaredFemale: true,
        declaredFemaleAt: verifiedAt,
        sellerLevel: SellerLevel[seed.level],
        sellerVerifiedAt: seed.level === 'BASIC' ? null : verifiedAt,
        // A verified shop's page is open, as approval opens it in the app.
        profileIsPublic: seed.level !== 'BASIC',
        profilePublicSince: seed.level === 'BASIC' ? null : verifiedAt,
        sellerPremiumUntil:
          seed.level === 'PREMIUM' ? rng.futureDate(300, 90) : null,
        points: rng.int(500, 6000),
        lifetimePoints: rng.int(6000, 24000),
        tier: seed.level === 'PREMIUM' ? 'Platinum' : 'Gold',
        lastLoginAt: rng.pastDate(6),
        createdAt: rng.pastDate(500, 120),
      },
    });

    if (sellerRole) {
      await prisma.userRoleAssignment.create({
        data: { userId: user.id, roleId: sellerRole.id },
      });
    }

    await prisma.sellerVerification.create({
      data: {
        userId: user.id,
        status:
          seed.level === 'BASIC'
            ? SellerVerificationStatus.UNDER_REVIEW
            : SellerVerificationStatus.APPROVED,
        businessName: seed.store,
        legalName: seed.legalName,
        businessCategory: seed.categories[0],
        storeDescription: seed.bio,
        storeLogoUrl: storeLogo(seed.username),
        contactPhone: seed.phone,
        businessAddress: `${seed.governorate} - ${seed.city}`,
        warehouseAddress: `${seed.governorate} - ${seed.city}`,
        commercialRegistration: `CR-${seed.username.toUpperCase()}`,
        taxId: `TAX-${seed.username.toUpperCase()}`,
        bankName: 'بنك بيمو السعودي الفرنسي',
        accountHolder: seed.legalName,
        iban: `SY${rng.int(10, 99)}0000${rng.int(100000, 999999)}`,
        shippingMethods: ['PLATFORM_COURIER', 'SELLER_SHIPS'],
        returnPolicy: 'الاستبدال والإرجاع خلال ٧ أيام من الاستلام.',
        productCategories: seed.categories,
        yearsExperience: seed.years,
        documentUrls: [`https://example.com/docs/${seed.username}.pdf`],
        reviewedBy: seed.level === 'BASIC' ? null : adminId,
        reviewedAt: seed.level === 'BASIC' ? null : verifiedAt,
        submittedAt: rng.pastDate(500, 200),
      },
    });

    sellers.push({
      id: user.id,
      name: seed.name,
      store: seed.store,
      categories: seed.categories,
      governorate: seed.governorate,
      city: seed.city,
      level: seed.level,
    });
  }

  const customers: DemoCustomer[] = [];

  for (const seed of CUSTOMERS) {
    const lifetimePoints = rng.int(200, 9000);
    const user = await prisma.user.create({
      data: {
        name: seed.name,
        username: seed.username,
        phone: seed.phone,
        passwordHash: customerHash,
        passwordSetAt: new Date(),
        role: UserRole.CUSTOMER,
        bio: seed.bio,
        location: `${seed.city}، سوريا`,
        imageUrl: avatarImage(seed.username),
        isVerified: true,
        phoneVerifiedAt: rng.pastDate(300, 30),
        declaredFemale: true,
        declaredFemaleAt: rng.pastDate(300, 30),
        points: Math.round(lifetimePoints * rng.float(0.2, 0.8)),
        lifetimePoints,
        tier: seed.tier,
        lastLoginAt: rng.pastDate(4),
        createdAt: rng.pastDate(360, 20),
      },
    });

    if (customerRole) {
      await prisma.userRoleAssignment.create({
        data: { userId: user.id, roleId: customerRole.id },
      });
    }

    await prisma.address.create({
      data: {
        userId: user.id,
        label: 'المنزل',
        recipientName: seed.name,
        recipientPhone: seed.phone,
        governorate: seed.governorate,
        district: seed.district,
        city: seed.city,
        addressLine: seed.address,
        isDefault: true,
      },
    });

    customers.push({
      id: user.id,
      name: seed.name,
      phone: seed.phone,
      governorate: seed.governorate,
      city: seed.city,
      district: seed.district,
      address: seed.address,
      tier: seed.tier,
    });
  }

  return { sellers, customers };
}

/**
 * Reputation, badges and trust status for every seller — the storefront header,
 * the seller leaderboard and the trust filters all read these rows.
 * Runs after reviews exist so the aggregates are real, not invented.
 */
export async function seedSellerReputation(
  prisma: PrismaClient,
  rng: Rng,
  sellers: DemoSeller[],
  adminId: string,
): Promise<void> {
  for (const seller of sellers) {
    const reviews = await prisma.sellerReview.findMany({
      where: { sellerId: seller.id, status: 'APPROVED' },
      select: { rating: true, verifiedPurchase: true },
    });

    const average = reviews.length
      ? reviews.reduce((sum, review) => sum + review.rating, 0) / reviews.length
      : 0;
    const fulfillment = rng.float(78, 99, 1);
    const response = rng.float(72, 98, 1);
    const satisfaction = average ? (average / 5) * 100 : rng.float(70, 90, 1);
    const performance = Number(
      ((fulfillment + response + satisfaction) / 3).toFixed(1),
    );

    const tier: SellerProgramTier =
      performance >= 92
        ? SellerProgramTier.ELITE
        : performance >= 85
          ? SellerProgramTier.TOP
          : performance >= 78
            ? SellerProgramTier.RISING
            : SellerProgramTier.STANDARD;

    await prisma.sellerReputation.create({
      data: {
        sellerId: seller.id,
        averageRating: Number(average.toFixed(2)),
        reviewsCount: reviews.length,
        verifiedReviewsCount: reviews.filter((r) => r.verifiedPurchase).length,
        performanceScore: performance,
        customerSatisfactionScore: Number(satisfaction.toFixed(1)),
        // Deliberately null: the demo dataset has no seller↔buyer chat
        // history, so there is nothing to derive a reply time from. Seeding a
        // plausible-looking number here is what made a fabricated score look
        // measured on a real dashboard.
        responseScore: null,
        fulfillmentScore: fulfillment,
        topSellerTier: tier,
        trustedStatus:
          seller.level === 'BASIC'
            ? TrustVerificationStatus.PENDING
            : TrustVerificationStatus.VERIFIED,
      },
    });

    await prisma.trustedSellerVerification.create({
      data: {
        sellerId: seller.id,
        status:
          seller.level === 'BASIC'
            ? TrustVerificationStatus.PENDING
            : TrustVerificationStatus.VERIFIED,
        evidence: {
          commercial_registration: true,
          identity_document: true,
          bank_account: seller.level !== 'BASIC',
        },
        reviewedBy: seller.level === 'BASIC' ? null : adminId,
        reviewedAt: seller.level === 'BASIC' ? null : rng.pastDate(90, 10),
      },
    });

    const badges: { type: SellerBadgeType; label: string; reason: string }[] = [];
    if (seller.level !== 'BASIC') {
      badges.push({
        type: SellerBadgeType.TRUSTED,
        label: 'بائعة موثوقة',
        reason: 'اكتملت جميع مستندات التوثيق',
      });
    }
    if (tier === SellerProgramTier.ELITE || tier === SellerProgramTier.TOP) {
      badges.push({
        type: SellerBadgeType.TOP_SELLER,
        label: 'من الأعلى مبيعاً',
        reason: 'ضمن أفضل ١٠٪ من البائعات هذا الشهر',
      });
    }
    if (fulfillment >= 92) {
      badges.push({
        type: SellerBadgeType.FAST_SHIPPER,
        label: 'شحن سريع',
        reason: 'متوسط التجهيز أقل من ٢٤ ساعة',
      });
    }
    if (average >= 4.5) {
      badges.push({
        type: SellerBadgeType.CUSTOMER_LOVED,
        label: 'محبوبة من الزبونات',
        reason: 'تقييم متوسط ٤.٥ فأعلى',
      });
    }

    for (const badge of badges) {
      await prisma.sellerBadge.create({
        data: { sellerId: seller.id, ...badge, awardedAt: rng.pastDate(120, 5) },
      });
    }
  }
}

/**
 * Devices, sessions and presence — without these the account-security screen
 * and the "online now" counter on the admin dashboard render empty states.
 */
export async function seedDeviceFootprint(
  prisma: PrismaClient,
  rng: Rng,
  users: { id: string }[],
): Promise<void> {
  const platforms = [
    { name: 'Samsung Galaxy A54', platform: 'android', version: '1.4.0' },
    { name: 'iPhone 13', platform: 'ios', version: '1.4.0' },
    { name: 'Chrome على Windows', platform: 'web', version: '1.3.2' },
  ];

  for (const [index, user] of users.entries()) {
    const device = rng.pick(platforms);
    const createdAt = rng.pastDate(200, 10);
    const deviceRow = await prisma.device.create({
      data: {
        userId: user.id,
        fingerprintHash: `demo-fp-${index}-${rng.int(100000, 999999)}`,
        name: device.name,
        platform: device.platform,
        appVersion: device.version,
        trustLevel: rng.weighted([
          [DeviceTrustLevel.TRUSTED, 3],
          [DeviceTrustLevel.VERIFIED, 2],
          [DeviceTrustLevel.UNVERIFIED, 1],
        ]),
        verifiedAt: createdAt,
        lastSeenAt: rng.pastDate(5),
        createdAt,
      },
    });

    await prisma.session.create({
      data: {
        userId: user.id,
        deviceId: deviceRow.id,
        status: 'ACTIVE',
        ipAddress: `31.9.${rng.int(1, 254)}.${rng.int(1, 254)}`,
        userAgent: `Reem/${device.version} (${device.platform})`,
        lastSeenAt: rng.pastDate(3),
        idleExpiresAt: rng.futureDate(7, 1),
        absoluteExpiresAt: rng.futureDate(90, 30),
        createdAt: rng.pastDate(20),
      },
    });

    await prisma.userPresence.create({
      data: {
        userId: user.id,
        status: rng.weighted([
          [PresenceStatus.OFFLINE, 5],
          [PresenceStatus.ONLINE, 2],
          [PresenceStatus.AWAY, 1],
        ]),
        lastSeenAt: rng.pastDate(2),
      },
    });

    await prisma.notificationPreference.create({
      data: { userId: user.id, push: rng.bool(0.6), sms: rng.bool(0.2) },
    });
  }
}

/**
 * Community shoppers — accounts with a profile but no credentials and no
 * orders. They are what makes engagement counters honest: every like, follow,
 * story view and comment in the demo dataset is a real row written by a real
 * user, so `likes_count` on a post equals `COUNT(post_likes)` exactly. Without
 * them the only way to show a post with fifty likes would be to write fifty
 * into the column and hope nobody checks.
 */
export async function seedCommunity(
  prisma: PrismaClient,
  rng: Rng,
  count: number,
): Promise<string[]> {
  const ids: string[] = [];

  for (let index = 0; index < count; index += 1) {
    const first = COMMUNITY_FIRST_NAMES[index % COMMUNITY_FIRST_NAMES.length];
    const family =
      COMMUNITY_FAMILY_NAMES[
        Math.floor(index / COMMUNITY_FIRST_NAMES.length) %
          COMMUNITY_FAMILY_NAMES.length
      ];
    const username = `reem_${String(index + 1).padStart(3, '0')}`;

    const user = await prisma.user.create({
      data: {
        name: `${first} ${family}`,
        username,
        phone: `+9639330${String(10_000 + index).slice(-5)}`,
        role: UserRole.CUSTOMER,
        imageUrl: avatarImage(username),
        location: 'سوريا',
        declaredFemale: true,
        declaredFemaleAt: rng.pastDate(300, 5),
        points: rng.int(0, 400),
        lifetimePoints: rng.int(0, 900),
        createdAt: rng.pastDate(300, 5),
        lastLoginAt: rng.pastDate(30),
      },
    });
    ids.push(user.id);
  }

  return ids;
}
