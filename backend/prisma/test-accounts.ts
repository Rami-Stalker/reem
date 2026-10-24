/**
 * Creates (or repairs) four hand-made accounts for manual testing:
 * one SUPER_ADMIN, one approved SELLER, one CUSTOMER and one courier — each
 * with a password that works on the phone+password sign-in path.
 *
 * The courier is here because without one a parcel cannot be delivered, and
 * without a delivery nothing downstream of it — returns, exchanges, escrow,
 * reviews — can be tested at all.
 *
 * Idempotent: re-running resets the password, the role and the flags rather
 * than creating a duplicate.
 */
import {
  CourierKind,
  Currency,
  PrismaClient,
  SellerLevel,
  SellerVerificationStatus,
  UserRole,
} from '@prisma/client';
import * as argon2 from 'argon2';

const prisma = new PrismaClient();

const hash = (plain: string) =>
  argon2.hash(plain, {
    type: argon2.argon2id,
    memoryCost: 64 * 1024,
    timeCost: 3,
    parallelism: 1,
  });

interface AccountSeed {
  label: string;
  name: string;
  username: string;
  phone: string;
  password: string;
  role: UserRole;
  bio: string;
  location: string;
}

const ACCOUNTS: AccountSeed[] = [
  {
    label: 'ADMIN',
    name: 'إدارة أوهارا — تجريبي',
    username: 'reem_owner',
    phone: '+963911111111',
    password: 'OharaAdmin#2026',
    role: UserRole.SUPER_ADMIN,
    bio: 'حساب إدارة المنصة للاختبار',
    location: 'دمشق، سوريا',
  },
  {
    label: 'SELLER',
    name: 'بوتيك أوهارا — تجريبي',
    username: 'reem_boutique',
    phone: '+963922222222',
    password: 'OharaSeller#2026',
    role: UserRole.SELLER,
    bio: 'بوتيك أزياء نسائية راقية ✨',
    location: 'دمشق، سوريا',
  },
  {
    label: 'CUSTOMER',
    name: 'زبونة أوهارا — تجريبي',
    username: 'reem_shopper',
    phone: '+963933333333',
    password: 'OharaBuyer#2026',
    role: UserRole.CUSTOMER,
    bio: 'أتسوّق على أوهارا',
    location: 'دمشق، سوريا',
  },
  {
    label: 'COURIER',
    name: 'مندوب أوهارا — تجريبي',
    username: 'reem_courier',
    phone: '+963944444444',
    password: 'OharaCourier#2026',
    // Deliberately not a privileged role. What makes this account a courier is
    // the `Courier` row attached below, which is the only thing the courier
    // screens check.
    role: UserRole.CUSTOMER,
    bio: 'مندوب توصيل للاختبار',
    location: 'دمشق، سوريا',
  },
];

async function main() {
  const now = new Date();

  for (const seed of ACCOUNTS) {
    const passwordHash = await hash(seed.password);

    const shared = {
      name: seed.name,
      username: seed.username,
      passwordHash,
      passwordSetAt: now,
      role: seed.role,
      bio: seed.bio,
      location: seed.location,
      imageUrl: `https://i.pravatar.cc/300?u=${encodeURIComponent(seed.username)}`,
      // Phone-verified: the account exists as if a code had already been
      // completed, so nothing refuses the sign-in for an unverified number.
      isVerified: true,
      phoneVerifiedAt: now,
      declaredFemale: true,
      declaredFemaleAt: now,
      // Cleared so a stale lockout from an earlier run cannot block a test.
      failedLoginCount: 0,
      lockedUntil: null,
      disabledAt: null,
      ...(seed.role === UserRole.SELLER && {
        sellerLevel: SellerLevel.VERIFIED,
        sellerVerifiedAt: now,
      }),
    };

    const user = await prisma.user.upsert({
      where: { phone: seed.phone },
      update: shared,
      create: { phone: seed.phone, tier: 'Platinum', ...shared },
    });

    // The role table drives permission lookups alongside `user.role`.
    const role = await prisma.role.findUnique({ where: { name: seed.role } });
    if (role) {
      await prisma.userRoleAssignment.deleteMany({ where: { userId: user.id } });
      await prisma.userRoleAssignment.create({
        data: { userId: user.id, roleId: role.id },
      });
    }

    // A wallet exists for every account so the money screens have something
    // real to read.
    await prisma.wallet.upsert({
      where: { userId_currency: { userId: user.id, currency: Currency.SYP } },
      update: {},
      create: { userId: user.id, currency: Currency.SYP, balance: 0 },
    });

    if (seed.role === UserRole.SELLER) {
      const admin = await prisma.user.findFirst({
        where: { role: { in: [UserRole.SUPER_ADMIN, UserRole.ADMIN] } },
        orderBy: { createdAt: 'asc' },
      });
      const verification = {
        status: SellerVerificationStatus.APPROVED,
        businessName: 'بوتيك أوهارا',
        legalName: 'بوتيك أوهارا للأزياء',
        businessCategory: 'fashion',
        storeDescription: seed.bio,
        storeLogoUrl: `https://i.pravatar.cc/300?u=${seed.username}`,
        contactPhone: seed.phone,
        businessAddress: 'دمشق - المزة',
        warehouseAddress: 'دمشق - المزة',
        commercialRegistration: 'CR-REEM-BOUTIQUE',
        taxId: 'TAX-REEM-BOUTIQUE',
        bankName: 'بنك بيمو السعودي الفرنسي',
        accountHolder: 'بوتيك أوهارا للأزياء',
        iban: 'SY350000123456',
        shippingMethods: ['PLATFORM_COURIER', 'SELLER_SHIPS'],
        returnPolicy: 'الاستبدال والإرجاع خلال ٧ أيام من الاستلام.',
        productCategories: ['fashion'],
        yearsExperience: 5,
        documentUrls: [],
        reviewedBy: admin?.id ?? null,
        reviewedAt: now,
      };
      await prisma.sellerVerification.upsert({
        where: { userId: user.id },
        update: verification,
        create: { userId: user.id, submittedAt: now, ...verification },
      });
    }

    if (seed.label === 'COURIER') {
      // Attach the account to a courier the fleet already has — the demo seed
      // ships four — and only invent one if the table is empty. Whichever it
      // is, this account is now the rider `requireCourier` resolves.
      const existing = await prisma.courier.findUnique({
        where: { userId: user.id },
      });
      if (!existing) {
        const unclaimed = await prisma.courier.findFirst({
          where: { userId: null, isActive: true },
          orderBy: { createdAt: 'asc' },
        });
        if (unclaimed) {
          await prisma.courier.update({
            where: { id: unclaimed.id },
            data: { userId: user.id },
          });
        } else {
          await prisma.courier.create({
            data: {
              userId: user.id,
              kind: CourierKind.PLATFORM_STAFF,
              displayName: 'فريق أوهارا للتوصيل',
              phone: seed.phone,
              governorates: [],
              isActive: true,
            },
          });
        }
      }
    }

    if (seed.label === 'CUSTOMER') {
      const existing = await prisma.address.findFirst({
        where: { userId: user.id },
      });
      if (!existing) {
        await prisma.address.create({
          data: {
            userId: user.id,
            label: 'المنزل',
            recipientName: seed.name,
            recipientPhone: seed.phone,
            governorate: 'دمشق',
            district: 'المزة',
            city: 'دمشق',
            addressLine: 'شارع الجلاء - بناء ٢٤',
            isDefault: true,
          },
        });
      }
    }

    console.log(
      `${seed.label.padEnd(9)} ${seed.phone}  ${seed.password}  (${user.username}, ${user.id})`,
    );
  }
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => prisma.$disconnect());
