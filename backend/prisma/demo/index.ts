import { Prisma, PrismaClient, UserRole } from '@prisma/client';
import { DemoContext, DemoCustomer, DemoSeller } from './context';
import { Rng } from './rng';
import {
  seedCommunity,
  seedDeviceFootprint,
  seedPeople,
  seedSellerReputation,
} from './people';
import { seedCatalog } from './catalog';
import { seedLoyaltyBase, seedMemberships } from './loyalty';
import {
  seedCommerceContent,
  seedFollows,
  seedPosts,
  seedStories,
} from './social';
import {
  seedCarts,
  seedChats,
  seedNotifications,
  seedSavedItems,
  seedSearchHistory,
} from './engagement';
import { seedMoneyMovements, seedOrders, seedReviews } from './commerce';
import {
  seedAiActivity,
  seedAnalytics,
  seedBackOffice,
  seedNotificationOps,
} from './ops';
import { seedGuestJourneys } from './guests';
import {
  seedAuthTrail,
  seedContentAnalytics,
  seedMessageAttachments,
} from './auth-trail';
import { reconcileCounters } from './reconcile';
import { seedTrendActivity } from './trend-activity';

/** Community accounts created so engagement counters are real, not invented. */
const COMMUNITY_SIZE = 40;

/** Fixed seed — two runs of `db:seed` produce the same catalog and history. */
const RNG_SEED = 'reem-demo-2026';

/**
 * Tables the foundation seed does not truncate because it never writes to them.
 * Everything else hangs off `users`, `products` or `orders` and is removed by
 * the cascades in `seed.ts`.
 */
async function clearDemoOwnedTables(prisma: PrismaClient): Promise<void> {
  // Guest sessions hang off nothing (their user link is `SetNull`), and
  // security events outlive the users that caused them — both survive the
  // foundation seed's cascades and would collide on re-seed.
  await prisma.guestSavedItem.deleteMany();
  await prisma.guestCartItem.deleteMany();
  await prisma.securityEvent.deleteMany();
  await prisma.guestSession.deleteMany();
  await prisma.exclusiveOfferClaim.deleteMany();
  await prisma.loyaltyReward.deleteMany();
  await prisma.membershipAccount.deleteMany();
  await prisma.membershipTier.deleteMany();
  await prisma.notificationEvent.deleteMany();
  await prisma.notificationDelivery.deleteMany();
  await prisma.notificationCampaign.deleteMany();
  await prisma.notificationTemplate.deleteMany();
  await prisma.moderationCase.deleteMany();
  await prisma.adminReport.deleteMany();
  await prisma.systemSetting.deleteMany();
}

/**
 * Reads back what the foundation seed created, so the demo layer extends it
 * instead of duplicating it. Querying rather than threading the objects through
 * keeps `seed.ts` free of demo-specific plumbing.
 */
async function bootstrap(prisma: PrismaClient): Promise<DemoContext> {
  const admin = await prisma.user.findFirst({
    where: { role: { in: [UserRole.SUPER_ADMIN, UserRole.ADMIN] } },
    orderBy: { createdAt: 'asc' },
  });
  if (!admin) {
    throw new Error(
      'Demo seed needs the foundation seed to have created an admin first.',
    );
  }

  const existingSellers = await prisma.user.findMany({
    where: { role: UserRole.SELLER },
    include: { sellerVerification: { select: { businessName: true } } },
  });

  const sellers: DemoSeller[] = [];
  for (const seller of existingSellers) {
    // Their catalog affinity is whatever they already list, so demo products
    // land in the same aisles they were seeded into.
    const categories = await prisma.category.findMany({
      where: { products: { some: { offers: { some: { sellerId: seller.id } } } } },
      select: { slug: true },
    });
    sellers.push({
      id: seller.id,
      name: seller.name,
      store: seller.sellerVerification?.businessName ?? seller.name,
      categories: categories.map((category) => category.slug),
      governorate: 'دمشق',
      city: 'دمشق',
      level: seller.sellerLevel,
    });
  }

  const existingCustomers = await prisma.user.findMany({
    where: { role: UserRole.CUSTOMER },
  });
  const customers: DemoCustomer[] = existingCustomers.map((customer) => ({
    id: customer.id,
    name: customer.name,
    phone: customer.phone ?? '+963900000000',
    governorate: 'دمشق',
    city: 'دمشق',
    district: 'المزة',
    address: 'شارع النخيل، بناء ٤',
    tier: customer.tier,
  }));

  const leaves = await prisma.category.findMany({
    where: { level: 2 },
    select: { id: true, slug: true },
  });

  const brands = await prisma.brand.findMany({ select: { id: true } });

  const fxRate = await prisma.exchangeRate.findFirst({
    where: { base: 'USD', quote: 'SYP' },
    orderBy: { effectiveFrom: 'desc' },
  });

  return {
    prisma,
    rng: new Rng(RNG_SEED),
    adminId: admin.id,
    sellers,
    customers,
    leafBySlug: new Map(leaves.map((leaf) => [leaf.slug, leaf.id])),
    brandIds: brands.map((brand) => brand.id),
    fxRate: fxRate?.rate ?? new Prisma.Decimal(130),
    fxRateId: fxRate?.id ?? null,
    products: [],
  };
}

/**
 * Layers the showcase dataset on top of the foundation seed: boutiques,
 * shoppers, ~160 catalog products with competing offers, the social feed, a
 * full order history across every lifecycle state, and the finance, analytics
 * and back-office rows the dashboards read.
 *
 * Ordering is not cosmetic — coupons exist before orders redeem them, orders
 * exist before reviews are written against them, reviews exist before seller
 * reputation is computed, and the counter reconciliation runs last.
 */
export async function seedDemo(prisma: PrismaClient): Promise<void> {
  const started = Date.now();
  const log = (message: string) =>
    console.log(`  · ${message} (${((Date.now() - started) / 1000).toFixed(1)}s)`);

  await clearDemoOwnedTables(prisma);
  const ctx = await bootstrap(prisma);

  const { sellers, customers } = await seedPeople(prisma, ctx.rng, ctx.adminId);
  ctx.sellers.push(...sellers);
  ctx.customers.push(...customers);
  log(`${ctx.sellers.length} boutiques, ${ctx.customers.length} shoppers`);

  const communityIds = await seedCommunity(prisma, ctx.rng, COMMUNITY_SIZE);
  log(`${communityIds.length} community accounts`);

  ctx.products = await seedCatalog(ctx);
  log(`${ctx.products.length} purchasable products`);

  await seedLoyaltyBase(ctx);
  log('membership tiers, coupons, referrals');

  await seedFollows(ctx, communityIds);
  const postIds = await seedPosts(ctx, communityIds);
  await seedStories(ctx, communityIds);
  await seedCommerceContent(ctx);
  log(`${postIds.length} posts, stories and rich content`);

  await seedSavedItems(ctx, postIds, communityIds);
  await seedCarts(ctx);
  await seedSearchHistory(ctx);
  await seedChats(ctx);
  await seedNotifications(ctx);
  log('favourites, wishlists, carts, chats, notifications');

  const orders = await seedOrders(ctx);
  log(`${orders.length} orders across the lifecycle`);

  await seedReviews(ctx, orders, communityIds);
  await seedMoneyMovements(ctx, orders);
  await seedMemberships(ctx);
  await seedSellerReputation(prisma, ctx.rng, ctx.sellers, ctx.adminId);
  log('reviews, points, payouts, memberships, reputation');

  await seedGuestJourneys(ctx, postIds);
  await seedDeviceFootprint(prisma, ctx.rng, [
    ...ctx.customers,
    ...ctx.sellers,
  ]);
  await seedAuthTrail(ctx);
  await seedContentAnalytics(ctx);
  await seedMessageAttachments(ctx);
  await seedAnalytics(ctx, orders);
  await seedAiActivity(ctx);
  await seedBackOffice(ctx);
  await seedNotificationOps(ctx);
  log('guest journeys, devices, auth trail, analytics, back-office');

  // Last of the content passes, because it browses the catalogue the
  // earlier ones built. The Trend Engine reads these rows and nothing else
  // produces them: without this pass both trend dashboards are correct and
  // empty, which is indistinguishable from broken.
  const events = await seedTrendActivity(ctx);
  log(`${events} browsing signals for the trend engine`);

  await reconcileCounters(prisma);
  log('counters reconciled against real rows');
}
