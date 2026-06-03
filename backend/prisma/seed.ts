import { PrismaClient, UserRole, OrderStatus, MediaType, NotificationType } from '@prisma/client';
import { hashPassword } from '../src/lib/password.js';

const prisma = new PrismaClient();

const DEMO_PASSWORD = 'Password123!';

async function main() {
  console.log('Seeding database...');

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
  await prisma.refreshToken.deleteMany();
  await prisma.coupon.deleteMany();
  await prisma.user.deleteMany();

  const passwordHash = await hashPassword(DEMO_PASSWORD);
  const adminHash = await hashPassword('Admin123!');

  const admin = await prisma.user.create({
    data: {
      name: 'Reem Admin',
      username: 'reem_admin',
      email: 'admin@reem.shop',
      passwordHash: adminHash,
      role: UserRole.ADMIN,
      bio: 'Platform administrator',
      imageUrl: 'https://i.pravatar.cc/150?u=admin',
      isVerified: true,
      points: 0,
      lifetimePoints: 0,
      tier: 'Platinum',
    },
  });

  const sara = await prisma.user.create({
    data: {
      name: 'Sara Al-Mansouri',
      username: 'sara_reem',
      email: 'sara@reem.shop',
      passwordHash,
      bio: 'Luxury fashion lover ✨',
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
      email: 'layla@reem.shop',
      passwordHash,
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
      email: 'nour@reem.shop',
      passwordHash,
      imageUrl: 'https://i.pravatar.cc/150?u=nour',
      isVerified: false,
      points: 450,
      lifetimePoints: 450,
      tier: 'Bronze',
    },
  });

  const sellers = [sara, layla, nour];

  const productData = [
    {
      title: 'Elegant Silk Midi Dress',
      description: 'Flowing silk midi dress in blush rose — perfect for evenings out.',
      price: 129,
      oldPrice: 159,
      image: 'https://images.unsplash.com/photo-1595777457583-95e059ef4c8e?w=800',
      featured: true,
    },
    {
      title: 'Pearl Embellished Clutch',
      description: 'Hand-finished clutch with pearl details and gold chain.',
      price: 89,
      oldPrice: null,
      image: 'https://images.unsplash.com/photo-1584917865442-de89df76afd3?w=800',
      featured: true,
    },
    {
      title: 'Cashmere Wrap Cardigan',
      description: 'Ultra-soft cashmere blend in lavender mist.',
      price: 198,
      oldPrice: 245,
      image: 'https://images.unsplash.com/photo-1434389677669-e08b4cac3105?w=800',
      featured: false,
    },
    {
      title: 'Satin Evening Heels',
      description: 'Stiletto heels in champagne satin with memory foam insole.',
      price: 145,
      oldPrice: null,
      image: 'https://images.unsplash.com/photo-1543163521-1bf539c55dd2?w=800',
      featured: true,
    },
    {
      title: 'Floral Maxi Skirt',
      description: 'Lightweight maxi with hand-painted floral motif.',
      price: 76,
      oldPrice: 99,
      image: 'https://images.unsplash.com/photo-1583497278209-457e9f0a1e2c?w=800',
      featured: false,
    },
    {
      title: 'Rose Gold Layered Necklace',
      description: 'Three-layer necklace with delicate rose gold plating.',
      price: 54,
      oldPrice: null,
      image: 'https://images.unsplash.com/photo-1515562141207-7a88fb7ce338?w=800',
      featured: false,
    },
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
        price: d.price,
        oldPrice: d.oldPrice,
        isFeatured: d.featured,
        viewsCount: 1200 + i * 340,
        likesCount: 80 + i * 25,
        media: {
          create: [{ url: d.image, type: MediaType.image, sortOrder: 0 }],
        },
      },
      include: { media: true, seller: true },
    });
    products.push(product);
  }

  for (const product of products.slice(0, 3)) {
    await prisma.favorite.create({
      data: { userId: sara.id, productId: product.id },
    });
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
        mediaUrl: `https://images.unsplash.com/photo-1524504388940-b1c1722653e1?w=600&u=${user.id}`,
        mediaType: MediaType.image,
        expiresAt,
      },
    });
  }

  await prisma.order.create({
    data: {
      userId: sara.id,
      status: OrderStatus.DELIVERED,
      total: 129,
      items: {
        create: [{ productId: products[0].id, quantity: 1, price: 129 }],
      },
    },
  });

  await prisma.order.create({
    data: {
      userId: sara.id,
      status: OrderStatus.SHIPPED,
      total: 89,
      items: {
        create: [{ productId: products[1].id, quantity: 1, price: 89 }],
      },
    },
  });

  await prisma.order.create({
    data: {
      userId: layla.id,
      status: OrderStatus.PROCESSING,
      total: 245,
      items: {
        create: [{ productId: products[2].id, quantity: 1, price: 198 }],
      },
    },
  });

  const chat = await prisma.chat.create({ data: {} });
  await prisma.chatParticipant.createMany({
    data: [
      { chatId: chat.id, userId: sara.id },
      { chatId: chat.id, userId: layla.id },
    ],
  });

  const messages = [
    { senderId: layla.id, content: 'Hi Sara! Did you see the new silk dress? 😍' },
    { senderId: sara.id, content: 'Yes! I already added it to my wishlist ✨' },
    { senderId: layla.id, content: 'The blush color is stunning on you!' },
    { senderId: sara.id, content: 'Thank you! Let\'s do a styling live soon 💕' },
  ];

  for (const msg of messages) {
    await prisma.message.create({
      data: { chatId: chat.id, senderId: msg.senderId, content: msg.content },
    });
  }

  await prisma.address.create({
    data: {
      userId: sara.id,
      label: 'Home',
      street: '12 Palm Avenue',
      city: 'Dubai',
      country: 'UAE',
      postalCode: '00000',
      isDefault: true,
    },
  });

  await prisma.coupon.createMany({
    data: [
      {
        code: 'REEM20',
        title: '20% off your order',
        discountPercent: 20,
        expiresAt: new Date(Date.now() + 30 * 24 * 60 * 60 * 1000),
      },
      {
        code: 'BLUSH15',
        title: '15% off dresses',
        discountPercent: 15,
        expiresAt: new Date(Date.now() + 14 * 24 * 60 * 60 * 1000),
      },
    ],
  });

  await prisma.notification.createMany({
    data: [
      {
        userId: sara.id,
        title: 'Order shipped',
        body: 'Your silk midi dress is on its way!',
        type: NotificationType.order,
      },
      {
        userId: sara.id,
        title: 'New follower',
        body: 'Layla started following you',
        type: NotificationType.follow,
      },
      {
        userId: sara.id,
        title: 'Flash sale',
        body: '24h only — extra 10% on featured items',
        type: NotificationType.promo,
        isRead: false,
      },
    ],
  });

  await prisma.paymentMethod.create({
    data: {
      userId: sara.id,
      brand: 'Visa',
      last4: '4242',
      expMonth: 12,
      expYear: 2028,
      isDefault: true,
    },
  });

  console.log('\n✅ Seed complete!\n');
  console.log('Demo accounts:');
  console.log('  User:  sara@reem.shop  / Password123!');
  console.log('  Admin: admin@reem.shop / Admin123!');
  console.log(`  API:   http://localhost:3000/api/v1\n`);
}

main()
  .catch((e) => {
    console.error(e);
    process.exit(1);
  })
  .finally(() => prisma.$disconnect());
