import {
  PrismaClient,
  UserRole,
  CommerceAuthorKind,
  Currency,
  FulfilmentMode,
  OfferStatus,
  OrderStatus,
  PaymentMethodType,
  PaymentStatus,
  MediaType,
  NotificationType,
  ProductStatus,
  RoundingPolicy,
  SellerLevel,
  SellerOrderStatus,
  SellerVerificationStatus,
  ShipmentStatus,
  OtpTransportKind,
  Prisma,
} from '@prisma/client';
import { AppPermission } from '../src/common/permissions';
import { defaultPermissionsForRole } from '../src/common/role-permissions';
import * as bcrypt from 'bcryptjs';
import { DEFAULT_SHIPPING_ZONES } from '../src/modules/delivery/delivery.service';
import { seedDemo } from './demo';
import {
  avatarImage,
  categoryImage,
  productImage,
  storyImage,
} from './demo/media';

const D = Prisma.Decimal;

/** SYP prices, so the seed reflects the market the platform actually serves. */
const SYP = (value: number) => new D(value);

const prisma = new PrismaClient();

const hash = (plain: string) => bcrypt.hash(plain, 12);

/**
 * This file's first act is seventy-one `deleteMany()` calls — every table,
 * including `journalEntry` and `ledgerAccount`, which are the platform's
 * double-entry book of record. It then writes a `SUPER_ADMIN` whose password
 * is printed at the end and committed in this repository.
 *
 * It runs against whatever `DATABASE_URL` the environment happens to hold, and
 * `npm run db:setup` used to end by calling it — so the command named "set up
 * the database" finished by emptying it. Nothing about the wipe announces
 * itself first.
 *
 * The refusal is not tied to NODE_ENV alone being *absent*: an unset NODE_ENV
 * is exactly how a fail-open default reaches a production shell. Someone who
 * genuinely means it can still say so out loud.
 */
function assertSafeToWipe(): void {
  if (process.env.NODE_ENV !== 'production') return;
  if (process.env.ALLOW_DESTRUCTIVE_SEED === 'true') {
    console.warn(
      'ALLOW_DESTRUCTIVE_SEED is set — wiping a production database on purpose.',
    );
    return;
  }
  throw new Error(
    [
      'Refusing to seed: NODE_ENV=production.',
      '',
      'This script deletes every row in every table, the ledger included, and',
      'then creates an administrator whose password is public. If you truly',
      'mean to do that here, set ALLOW_DESTRUCTIVE_SEED=true.',
    ].join('\n'),
  );
}

async function main() {
  assertSafeToWipe();
  console.log('Seeding database...');

  // Clean (respecting FK order).
  await prisma.commerceContentModerationAction.deleteMany();
  await prisma.commerceContentEvent.deleteMany();
  await prisma.commerceContentViewer.deleteMany();
  await prisma.commerceContentVersion.deleteMany();
  await prisma.commerceContentProductTag.deleteMany();
  await prisma.commerceContentMedia.deleteMany();
  await prisma.commerceContent.deleteMany();
  await prisma.commerceContentTypeDefinition.deleteMany();
  await prisma.auditLog.deleteMany();
  await prisma.loginAttempt.deleteMany();
  await prisma.sellerVerification.deleteMany();
  await prisma.userRoleAssignment.deleteMany();
  await prisma.rolePermission.deleteMany();
  await prisma.permission.deleteMany();
  await prisma.role.deleteMany();
  await prisma.otpRequest.deleteMany();
  await prisma.message.deleteMany();
  await prisma.chatParticipant.deleteMany();
  await prisma.chat.deleteMany();
  await prisma.commerceContentReaction.deleteMany();
  await prisma.commerceContentSave.deleteMany();
  await prisma.commerceContentComment.deleteMany();
  await prisma.commerceContentViewer.deleteMany();
  await prisma.commerceContentReshare.deleteMany();
  await prisma.commerceContentAttribution.deleteMany();
  // The book of record, before anything it points at.
  //
  // `JournalLine.account` is RESTRICT, so a ledger account cannot go while a
  // line still references it — and both `Courier` and `User` cascade *into*
  // ledger accounts. The teardown below therefore used to be un-runnable the
  // moment a single order settled: `courier.deleteMany()` tried to cascade into
  // an account that journal lines were holding down, and the seed died there
  // with a foreign-key error. Deleting the entries first (which cascades to the
  // lines) frees the accounts, and the cascades further down then work.
  //
  // Wallets are left to cascade from `User`, which they already do.
  await prisma.journalEntry.deleteMany();
  await prisma.ledgerAccount.deleteMany();

  await prisma.shipmentEvent.deleteMany();
  await prisma.shipment.deleteMany();
  await prisma.cashSettlement.deleteMany();
  await prisma.courier.deleteMany();
  await prisma.disputeMessage.deleteMany();
  await prisma.dispute.deleteMany();
  await prisma.returnItem.deleteMany();
  await prisma.returnRequest.deleteMany();
  await prisma.sellerPayoutLedger.deleteMany();
  await prisma.sellerPayout.deleteMany();
  await prisma.commissionLedger.deleteMany();
  await prisma.commissionRule.deleteMany();
  await prisma.financialLedgerEntry.deleteMany();
  await prisma.orderEvent.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.sellerOrder.deleteMany();
  await prisma.paymentTransaction.deleteMany();
  await prisma.payment.deleteMany();
  await prisma.order.deleteMany();
  await prisma.favorite.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.paymentMethod.deleteMany();
  await prisma.address.deleteMany();
  await prisma.cartItem.deleteMany();
  await prisma.guestCartItem.deleteMany();
  await prisma.inventoryBatch.deleteMany();
  await prisma.sellerOfferVariant.deleteMany();
  await prisma.sellerOffer.deleteMany();
  await prisma.productMedia.deleteMany();
  await prisma.productVariant.deleteMany();
  await prisma.product.deleteMany();
  await prisma.category.deleteMany();
  await prisma.sizeChart.deleteMany();
  await prisma.brand.deleteMany();
  await prisma.challengeDelivery.deleteMany();
  await prisma.otpOutbox.deleteMany();
  await prisma.otpTransportRoute.deleteMany();
  await prisma.shippingZone.deleteMany();
  await prisma.exchangeRate.deleteMany();
  await prisma.follow.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.session.deleteMany();
  await prisma.device.deleteMany();
  await prisma.coupon.deleteMany();
  await prisma.user.deleteMany();

  // Permissions and role grants are DERIVED from the code, not restated here.
  //
  // They used to be a second literal copy, and the two had already drifted:
  // `trends:manage`, `security_forensics:read` and `account_recovery:review`
  // existed in `AppPermission` and in no seeded database, so a freshly seeded
  // environment quietly refused routes that were correct in review.
  //
  // `resolvePermissions` reads these tables and only falls back to the code
  // defaults when a role has *no* rows at all — so a table that is present and
  // stale is worse than one that is empty. Deriving is the only way to keep the
  // two equal.
  const permissionKeys = Object.values(AppPermission);
  for (const key of permissionKeys) {
    await prisma.permission.create({ data: { key } });
  }

  for (const name of Object.values(UserRole)) {
    const role = await prisma.role.create({
      data: {
        name,
        description: `${name.toLowerCase().replace('_', ' ')} permissions`,
      },
    });
    const keys =
      name === UserRole.SUPER_ADMIN
        ? [...permissionKeys]
        : defaultPermissionsForRole(name);
    const permissions = await prisma.permission.findMany({
      where: { key: { in: keys } },
    });
    await prisma.rolePermission.createMany({
      data: permissions.map((permission) => ({
        roleId: role.id,
        permissionId: permission.id,
      })),
    });
  }

  const contentTypeDefinitions = [
    {
      key: 'product_post',
      name: 'Post',
      // The key stays `product_post` — it is written on live rows — but the
      // label must not say "product post" to a woman posting a photograph of
      // herself in a dress she bought.
      description: "A photo post — a boutique's look book, or hers.",
      schema: {
        type: 'object',
        required: ['caption'],
        properties: {
          caption: { type: 'string' },
          cta: { type: 'string' },
          hashtags: { type: 'array', items: { type: 'string' } },
        },
      },
      uiSchema: { layout: 'post_editor' },
      capabilities: {
        supports_product_tags: true,
        supports_media: true,
        supports_ai_generation: true,
        moderation_required: false,
        // Who may publish this format. Read by the authoring service, so
        // enabling or pausing customer posts is a row edit rather than a
        // deploy — and the composer builds itself from the same answer the
        // server enforces, instead of a hard-coded list that has to agree.
        audiences: ['seller', 'customer'],
      },
      lifecycle: {
        default_channels: ['HOME_FEED', 'STORE_FEED', 'FOLLOWING_FEED'],
      },
    },
    {
      key: 'story',
      name: 'Story',
      description: 'Ephemeral, shoppable story content with product tags and expiry.',
      schema: {
        type: 'object',
        required: ['frames'],
        properties: {
          frames: { type: 'array', items: { type: 'object' } },
          template: { type: 'string' },
          caption: { type: 'string' },
        },
      },
      uiSchema: { layout: 'story_editor' },
      capabilities: {
        supports_product_tags: true,
        supports_media: true,
        supports_replies: true,
        supports_ai_generation: true,
        moderation_required: false,
        audiences: ['seller', 'customer'],
      },
      lifecycle: {
        expires_after_hours: 24,
        default_channels: ['STORY_FEED', 'STORE_FEED'],
      },
    },
    {
      key: 'reel',
      name: 'Reel',
      description:
        'Short shoppable video — up to thirty seconds, tagged with what is in it.',
      schema: {
        type: 'object',
        required: ['caption'],
        properties: {
          caption: { type: 'string' },
          hashtags: { type: 'array', items: { type: 'string' } },
          cta: { type: 'string' },
        },
      },
      uiSchema: { layout: 'reel_editor' },
      capabilities: {
        supports_product_tags: true,
        supports_media: true,
        supports_replies: true,
        video_required: true,
        // Q142 — video is capped at thirty seconds, with compression and
        // connection-adaptive quality, because the ops budget is $500/month and
        // the uplink is Syrian.
        max_duration_seconds: 30,
        max_media: 1,
        moderation_required: false,
        audiences: ['seller', 'customer'],
      },
      lifecycle: {
        default_channels: [
          'VIDEO_FEED',
          'HOME_FEED',
          'FOLLOWING_FEED',
          'STORE_FEED',
        ],
      },
    },
    {
      key: 'flash_offer',
      name: 'Flash offer',
      description: 'Time-limited promotion with shoppable products and offer-feed ranking.',
      schema: {
        type: 'object',
        required: ['headline', 'discount_label'],
        properties: {
          headline: { type: 'string' },
          discount_label: { type: 'string' },
          terms: { type: 'string' },
          coupon_code: { type: 'string' },
        },
      },
      uiSchema: { layout: 'offer_editor' },
      capabilities: {
        supports_product_tags: true,
        supports_media: true,
        supports_scheduling: true,
        supports_ai_generation: true,
        moderation_required: false,
        audiences: ['seller'],
      },
      lifecycle: {
        default_channels: ['OFFER_FEED', 'HOME_FEED', 'STORE_FEED'],
      },
    },
    {
      key: 'collection',
      name: 'Collection',
      description: 'Curated product collection for seasonal, category, or campaign moments.',
      schema: {
        type: 'object',
        required: ['name'],
        properties: {
          name: { type: 'string' },
          description: { type: 'string' },
          theme: { type: 'string' },
        },
      },
      uiSchema: { layout: 'collection_editor' },
      capabilities: {
        supports_product_tags: true,
        supports_media: true,
        supports_localization: true,
        supports_ai_generation: true,
        moderation_required: false,
        audiences: ['seller'],
      },
      lifecycle: {
        default_channels: ['COLLECTION_FEED', 'STORE_FEED', 'HOME_FEED'],
      },
    },
    {
      key: 'live_stream',
      name: 'Live stream',
      description: 'Live commerce event shell with shoppable products and scheduled launch.',
      schema: {
        type: 'object',
        required: ['title', 'starts_at'],
        properties: {
          title: { type: 'string' },
          starts_at: { type: 'string' },
          stream_url: { type: 'string' },
          description: { type: 'string' },
        },
      },
      uiSchema: { layout: 'live_editor' },
      capabilities: {
        supports_product_tags: true,
        supports_scheduling: true,
        supports_notifications: true,
        moderation_required: true,
        audiences: ['seller'],
      },
      lifecycle: {
        default_channels: ['VIDEO_FEED', 'HOME_FEED', 'STORE_FEED'],
      },
    },
  ];

  for (const definition of contentTypeDefinitions) {
    await prisma.commerceContentTypeDefinition.create({
      data: {
        ...definition,
        schema: definition.schema as Prisma.InputJsonValue,
        uiSchema: definition.uiSchema as Prisma.InputJsonValue,
        capabilities: definition.capabilities as Prisma.InputJsonValue,
        lifecycle: definition.lifecycle as Prisma.InputJsonValue,
      },
    });
  }

  const customerHash = await hash('Password123!');
  const sellerHash = await hash('Seller123!');
  const adminHash = await hash('Admin123!');

  const admin = await prisma.user.create({
    data: {
      name: 'إدارة ريم',
      username: 'reem_admin',
      phone: '+966500000001',
      passwordHash: adminHash,
      passwordSetAt: new Date(),
      role: UserRole.SUPER_ADMIN,
      bio: 'حساب إدارة المنصة',
      location: 'دمشق، سوريا',
      imageUrl: avatarImage('reem_admin'),
      isVerified: true,
      declaredFemale: true,
      declaredFemaleAt: new Date(),
      tier: 'Platinum',
    },
  });

  const sara = await prisma.user.create({
    data: {
      name: 'سارة المنصوري',
      username: 'sara_reem',
      phone: '+966500000002',
      passwordHash: sellerHash,
      passwordSetAt: new Date(),
      role: UserRole.SELLER,
      bio: 'بوتيك أزياء راقية ✨',
      location: 'دمشق، سوريا',
      imageUrl: avatarImage('sara_reem'),
      isVerified: true,
      sellerLevel: SellerLevel.VERIFIED,
      points: 2840,
      lifetimePoints: 5200,
      tier: 'Gold',
    },
  });

  const layla = await prisma.user.create({
    data: {
      name: 'ليلى الخوري',
      username: 'layla_style',
      phone: '+966500000003',
      passwordHash: sellerHash,
      passwordSetAt: new Date(),
      role: UserRole.SELLER,
      bio: 'أناقة محتشمة منتقاة بعناية',
      location: 'حلب، سوريا',
      imageUrl: avatarImage('layla_style'),
      isVerified: true,
      sellerLevel: SellerLevel.VERIFIED,
      points: 1200,
      lifetimePoints: 2100,
      tier: 'Silver',
    },
  });

  const nour = await prisma.user.create({
    data: {
      name: 'نور العبادي',
      username: 'nour_chic',
      phone: '+966500000004',
      passwordHash: sellerHash,
      passwordSetAt: new Date(),
      role: UserRole.SELLER,
      location: 'اللاذقية، سوريا',
      imageUrl: avatarImage('nour_chic'),
      isVerified: false,
      points: 450,
      lifetimePoints: 450,
      tier: 'Bronze',
    },
  });

  const customer = await prisma.user.create({
    data: {
      name: 'مها',
      username: 'maha_shops',
      phone: '+966500000005',
      passwordHash: customerHash,
      passwordSetAt: new Date(),
      role: UserRole.CUSTOMER,
      bio: 'أحب كل ما هو جميل 💕',
      location: 'دمشق، سوريا',
      imageUrl: avatarImage('maha_shops'),
      isVerified: true,
      points: 320,
      lifetimePoints: 900,
      tier: 'Bronze',
    },
  });

  const sellers = [sara, layla, nour];

  const seededUsers = [admin, sara, layla, nour, customer];
  for (const user of seededUsers) {
    const role = await prisma.role.findUnique({ where: { name: user.role } });
    if (role) {
      await prisma.userRoleAssignment.create({
        data: { userId: user.id, roleId: role.id },
      });
    }
  }

  for (const seller of sellers) {
    await prisma.sellerVerification.create({
      data: {
        userId: seller.id,
        status: seller.isVerified
          ? SellerVerificationStatus.APPROVED
          : SellerVerificationStatus.PENDING,
        businessName: `${seller.name} Boutique`,
        legalName: seller.name,
        taxId: `TAX-${seller.username.toUpperCase()}`,
        documentUrls: [`https://example.com/docs/${seller.username}.pdf`],
        reviewedBy: seller.isVerified ? admin.id : null,
        reviewedAt: seller.isVerified ? new Date() : null,
      },
    });
  }

  // Follows: customer follows the three sellers; sellers follow each other a bit.
  const follows: { followerId: string; followingId: string }[] = [
    { followerId: customer.id, followingId: sara.id },
    { followerId: customer.id, followingId: layla.id },
    { followerId: customer.id, followingId: nour.id },
    { followerId: layla.id, followingId: sara.id },
    { followerId: nour.id, followingId: sara.id },
  ];
  for (const f of follows) {
    await prisma.follow.create({ data: f });
  }
  // Maintain denormalised counters.
  for (const seller of sellers) {
    const followersCount = follows.filter((f) => f.followingId === seller.id).length;
    await prisma.user.update({
      where: { id: seller.id },
      data: { followersCount },
    });
  }
  await prisma.user.update({
    where: { id: customer.id },
    data: { followingCount: 3 },
  });
  await prisma.user.update({ where: { id: layla.id }, data: { followingCount: 1 } });
  await prisma.user.update({ where: { id: nour.id }, data: { followingCount: 1 } });

  // ── Platform foundations ────────────────────────────────────────────
  // Q47 P2 — the rate the whole catalog is normalised against. Orders freeze
  // whichever row is live when they are placed.
  await prisma.exchangeRate.create({
    data: {
      base: Currency.USD,
      quote: Currency.SYP,
      rate: new D('130'),
      source: 'seed',
    },
  });

  await prisma.shippingZone.createMany({ data: DEFAULT_SHIPPING_ZONES });

  // ── OTP transport chain ─────────────────────────────────────────────
  // Order is the owner's locked decision: launch the closed beta on the local
  // Syrian SMS aggregator, whose contract cannot be refused for sanctions
  // reasons and which reaches a handset with mobile data switched off, then
  // promote WhatsApp to primary once its Arabic authentication template is
  // approved. Because the chain is a table, that promotion is one PATCH rather
  // than a deploy.
  //
  // Budgets are micros of USD per day and are placeholders for operations to
  // tune from the delivery report — their job is to cap the one line item that
  // can breach the $500/month ceiling, degrading cost before access.
  await prisma.otpTransportRoute.createMany({
    data: [
      {
        transport: OtpTransportKind.SMS_GATEWAY,
        priority: 10,
        dailyBudgetMicros: BigInt(2_000_000),
        note: 'Local Syrian aggregator — beta primary',
      },
      {
        transport: OtpTransportKind.WHATSAPP_CLOUD,
        priority: 20,
        dailyBudgetMicros: BigInt(1_000_000),
        note: 'Promote to priority 5 once the Arabic template is approved',
      },
      {
        transport: OtpTransportKind.VOICE,
        priority: 30,
        dailyBudgetMicros: BigInt(600_000),
        note: 'Last automated resort; also the only channel that works if she cannot read',
      },
      {
        transport: OtpTransportKind.OPS_CONSOLE,
        priority: 100,
        note: 'Closed-beta stopgap — a human reads the code out',
      },
    ],
  });

  // Q18 P1 — commission varies by seller package, not one flat rate.
  await prisma.commissionRule.createMany({
    data: [
      {
        name: 'Standard marketplace commission',
        rateBps: 1000,
        currency: Currency.SYP,
        priority: 100,
      },
      {
        name: 'Verified seller commission',
        rateBps: 800,
        currency: Currency.SYP,
        sellerTier: SellerLevel.VERIFIED,
        priority: 50,
      },
      {
        name: 'Premium seller commission',
        rateBps: 600,
        currency: Currency.SYP,
        sellerTier: SellerLevel.PREMIUM,
        priority: 40,
      },
    ],
  });

  // ── Taxonomy: exactly three levels (Q26 P2) ─────────────────────────
  const clothingSizes = await prisma.sizeChart.create({
    data: {
      slug: 'women-clothing',
      nameAr: 'مقاسات الملابس النسائية',
      nameEn: 'Women clothing sizes',
      columns: ['المقاس', 'الصدر', 'الخصر', 'الأرداف'],
      rows: [
        { label: 'S', bust: '84-88', waist: '66-70', hips: '90-94' },
        { label: 'M', bust: '88-92', waist: '70-74', hips: '94-98' },
        { label: 'L', bust: '92-98', waist: '74-80', hips: '98-104' },
        { label: 'XL', bust: '98-104', waist: '80-86', hips: '104-110' },
      ],
    },
  });

  const shoeSizes = await prisma.sizeChart.create({
    data: {
      slug: 'women-shoes',
      nameAr: 'مقاسات الأحذية',
      nameEn: 'Women shoe sizes',
      columns: ['EU', 'طول القدم (سم)'],
      rows: [
        { label: '36', length: '23.0' },
        { label: '37', length: '23.5' },
        { label: '38', length: '24.5' },
        { label: '39', length: '25.0' },
        { label: '40', length: '25.5' },
      ],
    },
  });

  type LeafSeed = { slug: string; nameAr: string; nameEn: string };
  type ChildSeed = {
    slug: string;
    nameAr: string;
    nameEn: string;
    sizeChartId?: string;
    attributeSchema?: Prisma.InputJsonValue;
    leaves: LeafSeed[];
  };
  type RootSeed = {
    slug: string;
    nameAr: string;
    nameEn: string;
    children: ChildSeed[];
  };

  const tree: RootSeed[] = [
    {
      slug: 'fashion',
      nameAr: 'أزياء',
      nameEn: 'Fashion',
      children: [
        {
          slug: 'clothing',
          nameAr: 'ملابس',
          nameEn: 'Clothing',
          sizeChartId: clothingSizes.id,
          attributeSchema: {
            required: ['material'],
            properties: {
              material: { type: 'string', title: 'الخامة' },
              sleeve_length: { type: 'string', title: 'طول الكم' },
            },
          },
          leaves: [
            { slug: 'dresses', nameAr: 'فساتين', nameEn: 'Dresses' },
            { slug: 'abayas', nameAr: 'عبايات ومحتشم', nameEn: 'Abayas and modest' },
            { slug: 'knitwear', nameAr: 'تريكو', nameEn: 'Knitwear' },
            { slug: 'skirts', nameAr: 'تنانير', nameEn: 'Skirts' },
            { slug: 'activewear', nameAr: 'ملابس رياضية ومنزلية', nameEn: 'Active and loungewear' },
          ],
        },
        {
          slug: 'bags-shoes',
          nameAr: 'حقائب وأحذية',
          nameEn: 'Bags and shoes',
          sizeChartId: shoeSizes.id,
          leaves: [
            { slug: 'handbags', nameAr: 'حقائب يد', nameEn: 'Handbags' },
            { slug: 'shoes', nameAr: 'أحذية', nameEn: 'Shoes' },
          ],
        },
        {
          slug: 'accessories',
          nameAr: 'إكسسوارات',
          nameEn: 'Accessories',
          leaves: [
            { slug: 'jewellery', nameAr: 'مجوهرات', nameEn: 'Jewellery' },
            { slug: 'scarves', nameAr: 'أوشحة', nameEn: 'Scarves' },
          ],
        },
      ],
    },
    {
      slug: 'beauty',
      nameAr: 'جمال وعناية',
      nameEn: 'Beauty and care',
      children: [
        {
          slug: 'makeup',
          nameAr: 'مكياج',
          nameEn: 'Makeup',
          attributeSchema: {
            required: ['shade'],
            properties: {
              shade: { type: 'string', title: 'درجة اللون' },
              skin_type: { type: 'string', title: 'نوع البشرة' },
            },
          },
          leaves: [
            { slug: 'face-makeup', nameAr: 'مكياج الوجه', nameEn: 'Face makeup' },
            { slug: 'lips', nameAr: 'الشفاه', nameEn: 'Lips' },
          ],
        },
        {
          slug: 'skincare',
          nameAr: 'عناية بالبشرة',
          nameEn: 'Skincare',
          leaves: [
            { slug: 'moisturisers', nameAr: 'مرطبات', nameEn: 'Moisturisers' },
            { slug: 'cleansers', nameAr: 'منظفات', nameEn: 'Cleansers' },
          ],
        },
        {
          slug: 'fragrance',
          nameAr: 'عطور',
          nameEn: 'Fragrance',
          leaves: [{ slug: 'perfumes', nameAr: 'عطور نسائية', nameEn: 'Perfumes' }],
        },
      ],
    },
    {
      slug: 'home-gifts',
      nameAr: 'المنزل والهدايا',
      nameEn: 'Home and gifts',
      children: [
        {
          slug: 'flowers-decor',
          nameAr: 'ورود وديكور',
          nameEn: 'Flowers and decor',
          leaves: [
            { slug: 'bouquets', nameAr: 'باقات ورد', nameEn: 'Bouquets' },
            { slug: 'wall-art', nameAr: 'لوحات جدارية', nameEn: 'Wall art' },
          ],
        },
        {
          slug: 'sweets',
          nameAr: 'شوكولا وحلويات',
          nameEn: 'Chocolate and sweets',
          leaves: [
            { slug: 'chocolate', nameAr: 'شوكولا', nameEn: 'Chocolate' },
            { slug: 'candy-boxes', nameAr: 'علب ضيافة', nameEn: 'Candy boxes' },
          ],
        },
        {
          slug: 'occasions',
          nameAr: 'هدايا المناسبات',
          nameEn: 'Occasion gifts',
          leaves: [
            { slug: 'graduation-gifts', nameAr: 'هدايا تخرّج', nameEn: 'Graduation gifts' },
            { slug: 'newborn-gifts', nameAr: 'هدايا مواليد', nameEn: 'Newborn gifts' },
            { slug: 'ramadan-gifts', nameAr: 'هدايا رمضان والأعياد', nameEn: 'Ramadan and eid gifts' },
          ],
        },
        {
          slug: 'stationery',
          nameAr: 'قرطاسية',
          nameEn: 'Stationery',
          leaves: [
            { slug: 'notebooks', nameAr: 'دفاتر ومفكرات', nameEn: 'Notebooks' },
            { slug: 'desk-accessories', nameAr: 'إكسسوارات مكتب', nameEn: 'Desk accessories' },
          ],
        },
      ],
    },
    {
      slug: 'baby',
      nameAr: 'الأم والطفل',
      nameEn: 'Mother and baby',
      children: [
        {
          slug: 'baby-clothing',
          nameAr: 'ملابس أطفال',
          nameEn: 'Baby clothing',
          leaves: [
            { slug: 'baby-sets', nameAr: 'أطقم مواليد', nameEn: 'Baby sets' },
            { slug: 'baby-shoes', nameAr: 'أحذية أطفال', nameEn: 'Baby shoes' },
          ],
        },
        {
          slug: 'baby-care',
          nameAr: 'عناية بالطفل',
          nameEn: 'Baby care',
          leaves: [
            { slug: 'baby-skincare', nameAr: 'عناية ببشرة الطفل', nameEn: 'Baby skincare' },
            { slug: 'baby-essentials', nameAr: 'مستلزمات يومية', nameEn: 'Daily essentials' },
          ],
        },
      ],
    },
  ];

  /**
   * Department artwork. Categories shipped with `imageUrl` null across the
   * board, and the home page only renders departments that have a picture —
   * so "Shop by category" collapsed to nothing on every install. Topics match
   * the leaf photography beneath each department so the tile and the shelf it
   * opens look like they belong together.
   */
  const departmentTopic: Record<string, string> = {
    clothing: 'dress,elegant',
    'bags-shoes': 'handbag,purse',
    accessories: 'jewellery,necklace',
    makeup: 'makeup,cosmetics',
    skincare: 'skincare,cream',
    fragrance: 'perfume,fragrance bottle',
    'flowers-decor': 'flower bouquet,roses',
    sweets: 'chocolate,dessert',
    occasions: 'gift box,ribbon',
    stationery: 'notebook,stationery',
    'baby-clothing': 'baby clothes,newborn',
    'baby-care': 'baby lotion,baby care',
  };
  const rootTopic: Record<string, string> = {
    fashion: 'fashion,boutique',
    beauty: 'cosmetics,beauty',
    'home-gifts': 'gift,home decor',
    baby: 'nursery,baby',
  };

  const leafBySlug = new Map<string, string>();
  const noReturnLeaves = [
    'face-makeup',
    'lips',
    'moisturisers',
    'cleansers',
    'perfumes',
    'chocolate',
    'candy-boxes',
    'baby-skincare',
  ];

  for (const [rootIndex, root] of tree.entries()) {
    const rootRow = await prisma.category.create({
      data: {
        slug: root.slug,
        nameAr: root.nameAr,
        nameEn: root.nameEn,
        level: 0,
        sortOrder: rootIndex,
        imageUrl: rootTopic[root.slug]
          ? categoryImage(rootTopic[root.slug], root.slug)
          : null,
      },
    });
    for (const [childIndex, child] of root.children.entries()) {
      const childRow = await prisma.category.create({
        data: {
          slug: child.slug,
          nameAr: child.nameAr,
          nameEn: child.nameEn,
          level: 1,
          parentId: rootRow.id,
          sortOrder: childIndex,
          imageUrl: departmentTopic[child.slug]
            ? categoryImage(departmentTopic[child.slug], child.slug)
            : null,
          sizeChartId: child.sizeChartId ?? null,
          attributeSchema: child.attributeSchema ?? Prisma.JsonNull,
        },
      });
      for (const [leafIndex, leaf] of child.leaves.entries()) {
        const leafRow = await prisma.category.create({
          data: {
            slug: leaf.slug,
            nameAr: leaf.nameAr,
            nameEn: leaf.nameEn,
            level: 2,
            parentId: childRow.id,
            sortOrder: leafIndex,
            // Q56 P1 — opened cosmetics are out of the change-of-mind window.
            returnsAllowed: !noReturnLeaves.includes(leaf.slug),
          },
        });
        leafBySlug.set(leaf.slug, leafRow.id);
      }
    }
  }

  const brands = await Promise.all(
    [
      { slug: 'reem-atelier', nameAr: 'ريم أتيليه', nameEn: 'Reem Atelier', isVerified: true },
      { slug: 'damas-couture', nameAr: 'دمشق كوتور', nameEn: 'Damas Couture', isVerified: true },
      { slug: 'yasmine', nameAr: 'ياسمين', nameEn: 'Yasmine', isVerified: false },
    ].map((brand) => prisma.brand.create({ data: brand })),
  );

  // ── Canonical catalog + per-seller offers ───────────────────────────
  const productData = [
    {
      title: 'فستان حرير ميدي أنيق',
      description: 'فستان ميدي من الحرير بلون الورد الباهت، مثالي للسهرات.',
      slug: 'silk-midi-dress',
      category: 'dresses',
      brand: 0,
      price: 14500,
      compareAt: 17900,
      image: productImage('dress,elegant', 'silk-midi-dress'),
      featured: true,
      attributes: { material: 'حرير طبيعي', sleeve_length: 'كم طويل' },
    },
    {
      title: 'حقيبة سهرة مطرزة باللؤلؤ',
      description: 'حقيبة مصنوعة يدوياً بتفاصيل من اللؤلؤ وسلسلة ذهبية.',
      slug: 'pearl-clutch',
      category: 'handbags',
      brand: 1,
      price: 9800,
      compareAt: null,
      image: productImage('handbag,clutch', 'pearl-clutch'),
      featured: true,
      attributes: {},
    },
    {
      title: 'كارديجان كشمير',
      description: 'كشمير فائق النعومة بلون اللافندر.',
      slug: 'cashmere-cardigan',
      category: 'knitwear',
      brand: 0,
      price: 22000,
      compareAt: 27500,
      image: productImage('knitwear,cardigan', 'cashmere-cardigan'),
      featured: false,
      attributes: { material: 'كشمير' },
    },
    {
      title: 'حذاء سهرة ساتان',
      description: 'كعب ستيليتو بلون الشامبانيا مع نعل مريح.',
      slug: 'satin-heels',
      category: 'shoes',
      brand: 2,
      price: 16000,
      compareAt: null,
      image: productImage('womens shoes,heels', 'satin-heels'),
      featured: true,
      attributes: {},
    },
    {
      title: 'تنورة ماكسي بنقشة زهور',
      description: 'تنورة خفيفة بنقشة مرسومة يدوياً.',
      slug: 'floral-maxi-skirt',
      category: 'skirts',
      brand: 2,
      price: 8500,
      compareAt: 11000,
      image: productImage('skirt,floral', 'floral-maxi-skirt'),
      featured: false,
      attributes: { material: 'قطن' },
    },
    {
      title: 'عقد متعدد الطبقات',
      description: 'عقد بثلاث طبقات مطلي بالذهب الوردي.',
      slug: 'layered-necklace',
      category: 'jewellery',
      brand: 1,
      price: 6000,
      compareAt: null,
      image: productImage('jewellery,necklace', 'layered-necklace'),
      featured: false,
      attributes: {},
    },
  ];

  const products: {
    id: string;
    title: string;
    media: { url: string }[];
    offerId: string;
    sellerId: string;
    price: number;
  }[] = [];

  for (const [index, d] of productData.entries()) {
    const seller = sellers[index % sellers.length];
    const product = await prisma.product.create({
      data: {
        slug: d.slug,
        title: d.title,
        description: d.description,
        categoryId: leafBySlug.get(d.category)!,
        brandId: brands[d.brand].id,
        attributes: d.attributes as Prisma.InputJsonValue,
        createdBySellerId: seller.id,
        status: ProductStatus.ACTIVE,
        isFeatured: d.featured,
        rating: 4.2 + (index % 5) * 0.15,
        reviewsCount: 12 + index * 7,
        viewsCount: 1200 + index * 340,
        ordersCount: 30 + index * 11,
        favoritesCount: 40 + index * 9,
        media: { create: [{ url: d.image, type: MediaType.image, sortOrder: 0 }] },
        variants:
          index < 2
            ? {
                create: [
                  { name: 'S', attributes: { size: 'S' }, sortOrder: 0 },
                  { name: 'M', attributes: { size: 'M' }, sortOrder: 1 },
                  { name: 'L', attributes: { size: 'L' }, sortOrder: 2 },
                ],
              }
            : undefined,
      },
      include: { media: true, variants: true },
    });

    const variantStock = [8, 12, 5];
    const offer = await prisma.sellerOffer.create({
      data: {
        productId: product.id,
        sellerId: seller.id,
        currency: Currency.SYP,
        price: SYP(d.price),
        priceSyp: SYP(d.price),
        compareAtPrice: d.compareAt ? SYP(d.compareAt) : null,
        stock: 25 + index * 5,
        status: OfferStatus.ACTIVE,
        sku: `REEM-${d.slug.toUpperCase()}`,
        variants: product.variants.length
          ? {
              create: product.variants.map((variant, vIndex) => ({
                variantId: variant.id,
                stock: variantStock[vIndex] ?? 6,
                sku: `REEM-${d.slug.toUpperCase()}-${variant.name}`,
              })),
            }
          : undefined,
      },
    });

    // Q23 P2 — a second seller lists the same canonical product a little
    // cheaper, so price comparison has something real to compare.
    const rival = sellers[(index + 1) % sellers.length];
    if (index < 3 && rival.id !== seller.id) {
      await prisma.sellerOffer.create({
        data: {
          productId: product.id,
          sellerId: rival.id,
          currency: Currency.SYP,
          price: SYP(Math.round(d.price * 0.94)),
          priceSyp: SYP(Math.round(d.price * 0.94)),
          stock: 10 + index,
          status: OfferStatus.ACTIVE,
          handlingDays: 2,
        },
      });
    }

    const liveOffers = await prisma.sellerOffer.findMany({
      where: { productId: product.id, status: OfferStatus.ACTIVE },
      select: { price: true },
    });
    const prices = liveOffers.map((row) => row.price);
    await prisma.product.update({
      where: { id: product.id },
      data: {
        offersCount: liveOffers.length,
        minPriceSyp: prices.reduce((min, price) => (price.lessThan(min) ? price : min), prices[0]),
        maxPriceSyp: prices.reduce((max, price) => (price.greaterThan(max) ? price : max), prices[0]),
      },
    });

    products.push({
      id: product.id,
      title: product.title,
      media: product.media,
      offerId: offer.id,
      sellerId: seller.id,
      price: d.price,
    });
  }

  for (const product of products.slice(0, 3)) {
    await prisma.favorite.create({ data: { userId: customer.id, productId: product.id } });
  }

  for (const product of products) {
    const caption = `أحببنا ${product.title} 💕 تسوّقيه الآن على ريم!`;
    await prisma.commerceContent.create({
      data: {
        authorId: product.sellerId,
        authorKind: CommerceAuthorKind.SELLER,
        authorIsPublic: true,
        contentType: 'product_post',
        body: caption,
        locale: 'ar',
        status: 'PUBLISHED',
        moderationStatus: 'APPROVED',
        publishedAt: new Date(),
        payload: { caption } as Prisma.InputJsonValue,
        publicationTargets: ['HOME_FEED', 'STORE_FEED', 'FOLLOWING_FEED'],
        // Counters only — the demo seed writes the rows behind them, and
        // `reconcile.ts` would otherwise zero these.
        sharesCount: BigInt(5 + Math.floor(Math.random() * 20)),
        productTags: {
          create: [
            { productId: product.id, role: 'featured', sortOrder: 0, basis: 'SELLER_OFFER' },
          ],
        },
      },
    });
  }

  // Q5 P2 — a content-only post, with no product attached at all.
  await prisma.commerceContent.create({
    data: {
      authorId: sellers[0].id,
      authorKind: CommerceAuthorKind.SELLER,
      authorIsPublic: true,
      contentType: 'product_post',
      body: 'ثلاث طرق لتنسيق الفستان الحريري لإطلالة نهارية ☀️',
      locale: 'ar',
      status: 'PUBLISHED',
      moderationStatus: 'APPROVED',
      publishedAt: new Date(),
      payload: {
        caption: 'ثلاث طرق لتنسيق الفستان الحريري لإطلالة نهارية ☀️',
      } as Prisma.InputJsonValue,
      publicationTargets: ['HOME_FEED', 'STORE_FEED'],
    },
  });

  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + 20);
  for (const user of sellers) {
    const url = storyImage('boutique,fashion', `foundation-${user.id}`);
    await prisma.commerceContent.create({
      data: {
        authorId: user.id,
        authorKind: CommerceAuthorKind.SELLER,
        authorIsPublic: true,
        contentType: 'story',
        locale: 'ar',
        status: 'PUBLISHED',
        moderationStatus: 'APPROVED',
        publishedAt: new Date(),
        expiresAt,
        payload: { frames: [{ media_url: url, link: null }] } as Prisma.InputJsonValue,
        publicationTargets: ['STORY_FEED', 'STORE_FEED'],
        media: { create: [{ url, type: MediaType.image, sortOrder: 0 }] },
      },
    });
  }

  // ── Orders: one parent, one sub-order per seller ────────────────────
  const shipping = {
    recipientName: 'مها العميلة',
    recipientPhone: '+966500000005',
    governorate: 'دمشق',
    district: 'المزة',
    city: 'دمشق',
    addressLine: '12 شارع النخيل، بناء 4',
    landmark: 'قرب صيدلية الورد',
  };

  const fxRate = new D('130');

  /** Builds a parent order with per-seller sub-orders — what checkout does. */
  const createOrder = async (input: {
    number: string;
    status: OrderStatus;
    lines: { product: (typeof products)[number]; quantity: number }[];
    shippingFee: number;
    subStatus: SellerOrderStatus;
    payment: { method: PaymentMethodType; status: PaymentStatus; paid: boolean };
    deliveryInstructions?: string;
  }) => {
    const itemsSubtotal = input.lines.reduce(
      (total, line) => total + line.product.price * line.quantity,
      0,
    );
    const grandTotal = itemsSubtotal + input.shippingFee;

    const order = await prisma.order.create({
      data: {
        number: input.number,
        userId: customer.id,
        status: input.status,
        currency: Currency.SYP,
        fxRate,
        fxFrozenAt: new Date(),
        roundingPolicy: RoundingPolicy.NEAREST_10,
        itemsSubtotal: SYP(itemsSubtotal),
        shippingTotal: SYP(input.shippingFee),
        grandTotal: SYP(grandTotal),
        placedAt: new Date(),
        ...shipping,
        deliveryInstructions: input.deliveryInstructions ?? null,
        payment: {
          create: {
            method: input.payment.method,
            status: input.payment.status,
            currency: Currency.SYP,
            amount: SYP(grandTotal),
            capturedAmount: SYP(input.payment.paid ? grandTotal : 0),
            transactionRef: `TXN-${input.number}`,
            paidAt: input.payment.paid ? new Date() : null,
          },
        },
        events: {
          create: [
            {
              title: 'Order created',
              toStatus: OrderStatus.PENDING_PAYMENT,
              actorRole: 'CUSTOMER',
            },
          ],
        },
      },
    });

    const bySeller = new Map<string, typeof input.lines>();
    for (const line of input.lines) {
      const group = bySeller.get(line.product.sellerId) ?? [];
      group.push(line);
      bySeller.set(line.product.sellerId, group);
    }

    let index = 0;
    for (const [sellerId, lines] of bySeller.entries()) {
      index += 1;
      const subtotal = lines.reduce(
        (total, line) => total + line.product.price * line.quantity,
        0,
      );
      const commission = Math.round(subtotal * 0.1);
      const sellerOrder = await prisma.sellerOrder.create({
        data: {
          number: `${input.number}-${index}`,
          orderId: order.id,
          sellerId,
          status: input.subStatus,
          fulfilmentMode: FulfilmentMode.PLATFORM_COURIER,
          currency: Currency.SYP,
          itemsSubtotal: SYP(subtotal),
          shippingCost: SYP(Math.round(input.shippingFee / bySeller.size)),
          commissionBase: SYP(subtotal),
          commissionAmount: SYP(commission),
          sellerNet: SYP(subtotal - commission),
          escrowReleaseAt: new Date(Date.now() + 7 * 864e5),
          confirmedAt: new Date(),
          items: {
            create: lines.map((line) => ({
              offerId: line.product.offerId,
              productId: line.product.id,
              titleSnapshot: line.product.title,
              imageSnapshot: line.product.media[0]?.url ?? null,
              sellerSnapshot:
                sellers.find((seller) => seller.id === sellerId)?.name ?? 'بائعة',
              currency: Currency.SYP,
              unitPrice: SYP(line.product.price),
              lineTotal: SYP(line.product.price * line.quantity),
              quantity: line.quantity,
            })),
          },
          events: {
            create: [
              {
                title: 'Sub-order created',
                toStatus: SellerOrderStatus.NEW,
                actorRole: 'SYSTEM',
              },
            ],
          },
        },
      });

      if (input.subStatus === SellerOrderStatus.DELIVERED) {
        await prisma.shipment.create({
          data: {
            trackingCode: `TRK-${sellerOrder.number}`,
            sellerOrderId: sellerOrder.id,
            status: ShipmentStatus.DELIVERED,
            currency: Currency.SYP,
            deliveredAt: new Date(),
            attemptCount: 1,
          },
        });
      }
    }

    return order;
  };

  await createOrder({
    number: 'REEM-100001',
    status: OrderStatus.DELIVERED,
    lines: [{ product: products[0], quantity: 1 }],
    shippingFee: 150,
    subStatus: SellerOrderStatus.DELIVERED,
    payment: {
      method: PaymentMethodType.SYRIATEL_CASH,
      status: PaymentStatus.PAID,
      paid: true,
    },
  });

  // A basket spanning two sellers — the case the flat model could not express.
  await createOrder({
    number: 'REEM-100002',
    status: OrderStatus.CONFIRMED,
    lines: [
      { product: products[1], quantity: 1 },
      { product: products[2], quantity: 1 },
    ],
    shippingFee: 150,
    subStatus: SellerOrderStatus.PREPARING,
    payment: {
      method: PaymentMethodType.COD,
      status: PaymentStatus.PENDING,
      paid: false,
    },
    deliveryInstructions: 'الرجاء الاتصال قبل التوصيل',
  });

  const chat = await prisma.chat.create({ data: {} });
  await prisma.chatParticipant.createMany({
    data: [
      { chatId: chat.id, userId: customer.id },
      { chatId: chat.id, userId: sara.id },
    ],
  });
  const messages = [
    { senderId: customer.id, content: 'Hi Sara! Is the silk dress still available? 😍' },
    { senderId: sara.id, content: 'Yes! We just restocked the blush rose ✨' },
    { senderId: customer.id, content: 'Perfect, adding it to my cart now 💕' },
  ];
  for (const msg of messages) {
    await prisma.message.create({
      data: { chatId: chat.id, senderId: msg.senderId, content: msg.content },
    });
  }

  await prisma.address.create({
    data: {
      userId: customer.id,
      label: 'المنزل',
      recipientName: customer.name,
      recipientPhone: customer.phone ?? '+963900000000',
      governorate: 'دمشق',
      district: 'المزة',
      city: 'دمشق',
      addressLine: '١٢ شارع النخيل، بناء ٤',
      landmark: 'قرب الحديقة',
      isDefault: true,
    },
  });

  await prisma.coupon.createMany({
    data: [
      {
        code: 'REEM20',
        title: 'خصم 20% على طلبك',
        currency: Currency.SYP,
        discountPercent: new D(20),
        expiresAt: new Date(Date.now() + 30 * 864e5),
      },
      {
        code: 'BLUSH15',
        title: 'خصم 15% على الفساتين',
        currency: Currency.SYP,
        discountPercent: new D(15),
        expiresAt: new Date(Date.now() + 14 * 864e5),
      },
    ],
  });

  await prisma.notification.createMany({
    data: [
      { userId: customer.id, title: 'Order shipped', body: 'Your silk midi dress is on its way!', type: NotificationType.order },
      { userId: sara.id, title: 'New follower', body: 'Maha started following you', type: NotificationType.follow },
      { userId: customer.id, title: 'Flash sale', body: '24h only — extra 10% on featured items', type: NotificationType.promo },
    ],
  });

  await prisma.paymentMethod.create({
    data: { userId: customer.id, brand: 'Visa', last4: '4242', expMonth: 12, expYear: 2028, isDefault: true },
  });

  // The showcase dataset — ~160 products, a full order history, analytics and
  // back-office rows. `SEED_DEMO=false npm run db:seed` stops after the
  // reference data above, which is what CI and contract fixtures want.
  if (process.env.SEED_DEMO !== 'false') {
    console.log('\nSeeding demo dataset...');
    await seedDemo(prisma);
  }

  console.log('\n✅ Seed complete!\n');
  console.log('Demo accounts (phone / password):');
  console.log('  Admin:    +966500000001 / Admin123!');
  console.log('  Seller:   +966500000002 / Seller123!   (سارة المنصوري)');
  console.log('  Seller:   +963931000101 / Seller123!   (رهف الشامي — أتيليه رهف)');
  console.log('  Customer: +966500000005 / Password123! (مها)');
  console.log('  Customer: +963932000201 / Password123! (نور الدين)');
  console.log('\n  Every demo seller uses Seller123!, every shopper Password123!.');
  console.log('  Backend: http://localhost:3000\n');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
