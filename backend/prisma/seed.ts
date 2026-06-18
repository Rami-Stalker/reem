import {
  PrismaClient,
  UserRole,
  OrderStatus,
  DeliveryStatus,
  PaymentMethodType,
  PaymentStatus,
  MediaType,
  NotificationType,
  ProductStatus,
  SellerVerificationStatus,
} from '@prisma/client';
import * as bcrypt from 'bcryptjs';

const prisma = new PrismaClient();

const hash = (plain: string) => bcrypt.hash(plain, 12);

async function main() {
  console.log('Seeding database...');

  // Clean (respecting FK order).
  await prisma.auditLog.deleteMany();
  await prisma.loginAttempt.deleteMany();
  await prisma.sellerVerification.deleteMany();
  await prisma.userRoleAssignment.deleteMany();
  await prisma.rolePermission.deleteMany();
  await prisma.permission.deleteMany();
  await prisma.role.deleteMany();
  await prisma.linkedAccount.deleteMany();
  await prisma.otpRequest.deleteMany();
  await prisma.message.deleteMany();
  await prisma.chatParticipant.deleteMany();
  await prisma.chat.deleteMany();
  await prisma.postLike.deleteMany();
  await prisma.post.deleteMany();
  await prisma.storyView.deleteMany();
  await prisma.story.deleteMany();
  await prisma.orderItem.deleteMany();
  await prisma.order.deleteMany();
  await prisma.favorite.deleteMany();
  await prisma.notification.deleteMany();
  await prisma.paymentMethod.deleteMany();
  await prisma.address.deleteMany();
  await prisma.productMedia.deleteMany();
  await prisma.product.deleteMany();
  await prisma.follow.deleteMany();
  await prisma.refreshToken.deleteMany();
  await prisma.session.deleteMany();
  await prisma.device.deleteMany();
  await prisma.coupon.deleteMany();
  await prisma.user.deleteMany();

  const permissionKeys = [
    'account:read',
    'account:write',
    'session:manage',
    'device:manage',
    'seller_verification:submit',
    'seller_verification:review',
    'product:manage',
    'post:manage',
    'story:manage',
    'order:manage',
    'user:manage',
    'audit:read',
  ];
  for (const key of permissionKeys) {
    await prisma.permission.create({ data: { key } });
  }

  const roleDefinitions: Record<UserRole, string[]> = {
    [UserRole.SUPER_ADMIN]: permissionKeys,
    [UserRole.ADMIN]: permissionKeys,
    [UserRole.SUPPORT]: [
      'account:read',
      'session:manage',
      'seller_verification:review',
      'order:manage',
      'user:manage',
      'audit:read',
    ],
    [UserRole.SELLER]: [
      'account:read',
      'account:write',
      'session:manage',
      'device:manage',
      'seller_verification:submit',
      'product:manage',
      'post:manage',
      'story:manage',
    ],
    [UserRole.CUSTOMER]: [
      'account:read',
      'account:write',
      'session:manage',
      'device:manage',
      'seller_verification:submit',
    ],
  };

  for (const [name, keys] of Object.entries(roleDefinitions)) {
    const role = await prisma.role.create({
      data: {
        name,
        description: `${name.toLowerCase().replace('_', ' ')} permissions`,
      },
    });
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

  const customerHash = await hash('Password123!');
  const sellerHash = await hash('Seller123!');
  const adminHash = await hash('Admin123!');

  const admin = await prisma.user.create({
    data: {
      name: 'Reem Admin',
      username: 'reem_admin',
      phone: '+966500000001',
      passwordHash: adminHash,
      role: UserRole.ADMIN,
      bio: 'Platform administrator',
      location: 'Riyadh, SA',
      imageUrl: 'https://i.pravatar.cc/150?u=admin',
      isVerified: true,
      tier: 'Platinum',
    },
  });

  const sara = await prisma.user.create({
    data: {
      name: 'Sara Al-Mansouri',
      username: 'sara_reem',
      phone: '+966500000002',
      passwordHash: sellerHash,
      role: UserRole.SELLER,
      bio: 'Luxury fashion boutique ✨',
      location: 'Dubai, UAE',
      imageUrl: 'https://i.pravatar.cc/150?u=sara',
      isVerified: true,
      points: 2840,
      lifetimePoints: 5200,
      tier: 'Gold',
    },
  });

  const layla = await prisma.user.create({
    data: {
      name: 'Layla Khoury',
      username: 'layla_style',
      phone: '+966500000003',
      passwordHash: sellerHash,
      role: UserRole.SELLER,
      bio: 'Curated modest elegance',
      location: 'Beirut, LB',
      imageUrl: 'https://i.pravatar.cc/150?u=layla',
      isVerified: true,
      points: 1200,
      lifetimePoints: 2100,
      tier: 'Silver',
    },
  });

  const nour = await prisma.user.create({
    data: {
      name: 'Nour Abadi',
      username: 'nour_chic',
      phone: '+966500000004',
      passwordHash: sellerHash,
      role: UserRole.SELLER,
      imageUrl: 'https://i.pravatar.cc/150?u=nour',
      isVerified: false,
      points: 450,
      lifetimePoints: 450,
      tier: 'Bronze',
    },
  });

  const customer = await prisma.user.create({
    data: {
      name: 'Maha Customer',
      username: 'maha_shops',
      phone: '+966500000005',
      passwordHash: customerHash,
      role: UserRole.CUSTOMER,
      bio: 'Lover of beautiful things 💕',
      location: 'Jeddah, SA',
      imageUrl: 'https://i.pravatar.cc/150?u=maha',
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

  const productData = [
    { title: 'Elegant Silk Midi Dress', description: 'Flowing silk midi dress in blush rose — perfect for evenings out.', price: 129, oldPrice: 159, category: 'dresses', image: 'https://images.unsplash.com/photo-1595777457583-95e059ef4c8e?w=800', featured: true },
    { title: 'Pearl Embellished Clutch', description: 'Hand-finished clutch with pearl details and gold chain.', price: 89, oldPrice: null, category: 'bags', image: 'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=800', featured: true },
    { title: 'Cashmere Wrap Cardigan', description: 'Ultra-soft cashmere blend in lavender mist.', price: 198, oldPrice: 245, category: 'knitwear', image: 'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=800', featured: false },
    { title: 'Satin Evening Heels', description: 'Stiletto heels in champagne satin with memory foam insole.', price: 145, oldPrice: null, category: 'shoes', image: 'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=800', featured: true },
    { title: 'Floral Maxi Skirt', description: 'Lightweight maxi with hand-painted floral motif.', price: 76, oldPrice: 99, category: 'skirts', image: 'https://images.unsplash.com/photo-1583497278209-457e9f0a1e2c?w=800', featured: false },
    { title: 'Rose Gold Layered Necklace', description: 'Three-layer necklace with delicate rose gold plating.', price: 54, oldPrice: null, category: 'jewellery', image: 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=800', featured: false },
  ];

  const products = [];
  for (let i = 0; i < productData.length; i++) {
    const d = productData[i];
    const seller = sellers[i % sellers.length];
    const product = await prisma.product.create({
      data: {
        sellerId: seller.id,
        title: d.title,
        description: d.description,
        category: d.category,
        price: d.price,
        oldPrice: d.oldPrice,
        stock: 25 + i * 5,
        status: ProductStatus.ACTIVE,
        isFeatured: d.featured,
        rating: 4.2 + (i % 5) * 0.15,
        reviewsCount: 12 + i * 7,
        viewsCount: 1200 + i * 340,
        likesCount: 80 + i * 25,
        ordersCount: 30 + i * 11,
        favoritesCount: 40 + i * 9,
        media: { create: [{ url: d.image, type: MediaType.image, sortOrder: 0 }] },
        variants: i < 2
          ? {
              create: [
                { name: 'Small', sku: `SKU-${i}-S`, stock: 8, sortOrder: 0 },
                { name: 'Medium', sku: `SKU-${i}-M`, stock: 12, sortOrder: 1 },
                { name: 'Large', sku: `SKU-${i}-L`, stock: 5, sortOrder: 2 },
              ],
            }
          : undefined,
      },
      include: { media: true, seller: true },
    });
    products.push(product);
  }

  for (const product of products.slice(0, 3)) {
    await prisma.favorite.create({ data: { userId: customer.id, productId: product.id } });
  }

  for (const product of products) {
    await prisma.post.create({
      data: {
        authorId: product.sellerId,
        productId: product.id,
        caption: `In love with our ${product.title} 💕 Shop now on Reem!`,
        likesCount: 120 + Math.floor(Math.random() * 200),
        commentsCount: 10 + Math.floor(Math.random() * 40),
        sharesCount: 5 + Math.floor(Math.random() * 20),
      },
    });
  }

  const expiresAt = new Date();
  expiresAt.setHours(expiresAt.getHours() + 20);
  for (const user of sellers) {
    await prisma.story.create({
      data: {
        userId: user.id,
        mediaUrl: `https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=600`,
        mediaType: MediaType.image,
        expiresAt,
      },
    });
  }

  const shipping = {
    recipientName: 'Maha Customer',
    recipientPhone: '+966500000005',
    governorate: 'Damascus',
    city: 'Damascus',
    addressLine: '12 Palm Avenue, Building 4',
    landmark: 'Near Rose Pharmacy',
  };

  await prisma.order.create({
    data: {
      number: 'REEM-100001',
      userId: customer.id,
      status: OrderStatus.DELIVERED,
      deliveryStatus: DeliveryStatus.DELIVERED,
      subtotal: 129,
      deliveryFee: 5,
      total: 134,
      ...shipping,
      items: {
        create: [
          {
            productId: products[0].id,
            titleSnapshot: products[0].title,
            imageSnapshot: products[0].media[0]?.url ?? null,
            quantity: 1,
            price: 129,
          },
        ],
      },
      payment: {
        create: {
          method: PaymentMethodType.VISA,
          status: PaymentStatus.PAID,
          amount: 134,
          transactionRef: 'TXN-VISA-100001',
          paidAt: new Date(),
        },
      },
      events: {
        create: [
          { title: 'Order created', description: 'Order placed successfully' },
          { title: 'Payment received', description: 'Visa payment confirmed' },
          { title: 'Out for delivery' },
          { title: 'Delivered', description: 'Enjoy your order!' },
        ],
      },
    },
  });

  await prisma.order.create({
    data: {
      number: 'REEM-100002',
      userId: customer.id,
      status: OrderStatus.PENDING_PAYMENT,
      deliveryStatus: DeliveryStatus.CREATED,
      subtotal: 89,
      deliveryFee: 5,
      total: 94,
      ...shipping,
      deliveryInstructions: 'Call before delivery',
      items: {
        create: [
          {
            productId: products[1].id,
            titleSnapshot: products[1].title,
            imageSnapshot: products[1].media[0]?.url ?? null,
            quantity: 1,
            price: 89,
          },
        ],
      },
      payment: {
        create: {
          method: PaymentMethodType.COD,
          status: PaymentStatus.PENDING,
          amount: 94,
        },
      },
      events: {
        create: [{ title: 'Order created', description: 'Cash on delivery' }],
      },
    },
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
      label: 'Home',
      street: '12 Palm Avenue',
      city: 'Jeddah',
      country: 'SA',
      postalCode: '23456',
      isDefault: true,
    },
  });

  await prisma.coupon.createMany({
    data: [
      { code: 'REEM20', title: '20% off your order', discountPercent: 20, expiresAt: new Date(Date.now() + 30 * 864e5) },
      { code: 'BLUSH15', title: '15% off dresses', discountPercent: 15, expiresAt: new Date(Date.now() + 14 * 864e5) },
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

  console.log('\n✅ Seed complete!\n');
  console.log('Demo accounts (phone / password):');
  console.log('  Admin:    +966500000001 / Admin123!');
  console.log('  Seller:   +966500000002 / Seller123!  (Sara)');
  console.log('  Customer: +966500000005 / Password123! (Maha)');
  console.log('  API:      http://localhost:5432\n');
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
