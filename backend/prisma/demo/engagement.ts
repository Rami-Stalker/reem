import {
  ChatContextType,
  ChatParticipantRole,
  ChatReportReason,
  Currency,
  MessageDeliveryStatus,
  NotificationType,
  Prisma,
  WishlistItemType,
  WishlistShareVisibility,
} from '@prisma/client';
import { CHAT_THREADS, NOTIFICATIONS, SEARCH_QUERIES } from './data';
import { DemoContext } from './context';

const D = Prisma.Decimal;

/**
 * Saved items: product favourites, saved boutiques, saved posts and the named
 * wishlist collections (with one shared by link, so the public share route has
 * something to resolve).
 */
export async function seedSavedItems(
  ctx: DemoContext,
  postIds: string[],
  communityIds: string[],
): Promise<void> {
  const { prisma, rng } = ctx;

  const collectionNames = [
    'قائمتي المفضلة',
    'تجهيزات العرس',
    'هدايا للأصدقاء',
    'أشتريه لاحقاً',
  ];

  for (const customer of ctx.customers) {
    const favourites = rng.sample(ctx.products, rng.int(4, 14));
    for (const product of favourites) {
      await prisma.favorite.create({
        data: {
          userId: customer.id,
          productId: product.id,
          createdAt: rng.pastDate(120),
        },
      });
    }

    for (const seller of rng.sample(ctx.sellers, rng.int(1, 4))) {
      await prisma.sellerFavorite.create({
        data: { userId: customer.id, sellerId: seller.id },
      });
    }

    for (const postId of rng.sample(postIds, rng.int(0, 6))) {
      await prisma.postFavorite.create({
        data: { userId: customer.id, postId },
      });
    }

    // Wishlist collections — the "save into a list" flow, not the flat heart.
    for (const name of rng.sample(collectionNames, rng.int(1, 2))) {
      const shared = rng.bool(0.35);
      const collection = await prisma.wishlistCollection.create({
        data: {
          userId: customer.id,
          name,
          description: 'قائمة جمعتها لنفسي 💕',
          visibility: shared
            ? WishlistShareVisibility.LINK
            : WishlistShareVisibility.PRIVATE,
          shareSlug: shared
            ? `${customer.id.slice(0, 8)}-${name.length}-${rng.int(1000, 9999)}`
            : null,
          createdAt: rng.pastDate(150),
        },
      });

      for (const product of rng.sample(favourites, rng.int(2, 6))) {
        const cheapest = product.offers[0];
        await prisma.wishlistCollectionItem.create({
          data: {
            collectionId: collection.id,
            type: WishlistItemType.PRODUCT,
            productId: product.id,
            priceCurrency: Currency.SYP,
            priceWhenSaved: cheapest ? new D(cheapest.priceSyp) : null,
            note: rng.bool(0.3) ? 'أنتظر نزول السعر' : null,
            createdAt: rng.pastDate(100),
          },
        });
      }

      if (shared) {
        await prisma.wishlistShare.create({
          data: {
            collectionId: collection.id,
            userId: customer.id,
            token: `share-${collection.id.slice(0, 12)}`,
            expiresAt: rng.futureDate(60, 10),
          },
        });
      }
    }
  }

  // Community accounts only heart things — no lists, no orders.
  for (const userId of communityIds) {
    for (const product of rng.sample(ctx.products, rng.int(0, 6))) {
      await prisma.favorite.create({ data: { userId, productId: product.id } });
    }
  }
}

/** Live baskets, so the cart badge and checkout are not empty on first launch. */
export async function seedCarts(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  for (const customer of rng.sample(ctx.customers, 6)) {
    const chosen = rng.sample(
      ctx.products.filter((product) => product.offers.length > 0),
      rng.int(1, 4),
    );

    for (const product of chosen) {
      const offer = product.offers[0];
      const variant = offer.variants.length ? rng.pick(offer.variants) : null;
      await prisma.cartItem.create({
        data: {
          userId: customer.id,
          offerId: offer.id,
          offerVariantId: variant?.id ?? null,
          quantity: rng.int(1, 3),
          createdAt: rng.pastDate(10),
        },
      });
    }
  }
}

export async function seedSearchHistory(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  for (const customer of ctx.customers) {
    for (const query of rng.sample(SEARCH_QUERIES, rng.int(2, 7))) {
      await prisma.searchHistory.create({
        data: { userId: customer.id, query, createdAt: rng.pastDate(45) },
      });
    }
  }
}

/**
 * Buyer ↔ seller conversations, including one reported thread and one block,
 * so the moderation surfaces in the admin app are not empty.
 */
export async function seedChats(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;

  const pairs = rng.sample(ctx.customers, 8).map((customer, index) => ({
    customer,
    seller: ctx.sellers[index % ctx.sellers.length],
  }));

  for (const [index, pair] of pairs.entries()) {
    const thread = CHAT_THREADS[index % CHAT_THREADS.length];
    const product = rng.pick(ctx.products);
    const startedAt = rng.pastDate(30, 1);

    const chat = await prisma.chat.create({
      data: {
        type: ChatContextType.PRODUCT,
        productId: product.id,
        buyerId: pair.customer.id,
        sellerId: pair.seller.id,
        title: product.title,
        createdAt: startedAt,
      },
    });

    await prisma.chatParticipant.createMany({
      data: [
        {
          chatId: chat.id,
          userId: pair.customer.id,
          role: ChatParticipantRole.BUYER,
          joinedAt: startedAt,
        },
        {
          chatId: chat.id,
          userId: pair.seller.id,
          role: ChatParticipantRole.SELLER,
          joinedAt: startedAt,
        },
      ],
    });

    const turns = Math.max(thread.buyer.length, thread.seller.length);
    let cursor = startedAt.getTime();
    let lastMessageId: string | null = null;

    for (let turn = 0; turn < turns; turn += 1) {
      for (const [role, lines] of [
        ['buyer', thread.buyer] as const,
        ['seller', thread.seller] as const,
      ]) {
        const content = lines[turn];
        if (!content) continue;
        cursor += rng.int(2, 40) * 60_000;
        const senderId =
          role === 'buyer' ? pair.customer.id : pair.seller.id;
        const message = await prisma.message.create({
          data: {
            chatId: chat.id,
            senderId,
            content,
            status: MessageDeliveryStatus.READ,
            deliveredAt: new Date(cursor + 1000),
            readAt: new Date(cursor + 60_000),
            createdAt: new Date(cursor),
          },
        });
        lastMessageId = message.id;

        await prisma.messageReadReceipt.create({
          data: {
            messageId: message.id,
            userId:
              role === 'buyer' ? pair.seller.id : pair.customer.id,
            deliveredAt: new Date(cursor + 1000),
            readAt: new Date(cursor + 60_000),
          },
        });
      }
    }

    if (lastMessageId) {
      await prisma.chatParticipant.updateMany({
        where: { chatId: chat.id },
        data: { lastReadMessageId: lastMessageId, lastReadAt: new Date(cursor) },
      });
    }

    // One thread ends badly — the support queue needs a real case.
    if (index === 0) {
      await prisma.chatReport.create({
        data: {
          chatId: chat.id,
          reporterId: pair.customer.id,
          reportedUserId: pair.seller.id,
          reason: ChatReportReason.SPAM,
          description: 'رسائل ترويجية متكررة خارج موضوع الطلب.',
          createdAt: rng.pastDate(10),
        },
      });
      await prisma.chatBlock.create({
        data: {
          blockerId: pair.customer.id,
          blockedId: pair.seller.id,
          reason: 'إزعاج',
        },
      });
    }
  }
}

export async function seedNotifications(ctx: DemoContext): Promise<void> {
  const { prisma, rng } = ctx;
  const recipients = [
    ...ctx.customers.map((c) => c.id),
    ...ctx.sellers.map((s) => s.id),
  ];

  for (const userId of recipients) {
    for (const template of rng.sample(NOTIFICATIONS, rng.int(3, 7))) {
      await prisma.notification.create({
        data: {
          userId,
          title: template.title,
          body: template.body,
          type: NotificationType[template.type],
          isRead: rng.bool(0.45),
          createdAt: rng.pastDate(30),
        },
      });
    }
  }
}
