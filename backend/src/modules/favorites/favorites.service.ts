import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  Currency,
  NotificationType,
  GuestSavedItemType,
  Prisma,
  User,
  UserRole,
  WishlistItemType,
  WishlistShareVisibility,
} from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import {
  serializeLegacyPost,
  serializeProduct,
  serializePublicUser,
} from '../../common/serializers';
import { Money } from '../../common/money';
import {
  AddWishlistItemDto,
  CreateWishlistCollectionDto,
  ShareWishlistDto,
} from './dto/wishlist.dto';
import {
  PRODUCT_CARD_INCLUDE,
  PURCHASABLE_PRODUCT_WHERE,
} from '../../common/catalog/product-include';

/**
 * A saved post, as a card needs it.
 *
 * `product` became `productTags` when posts moved onto the content platform:
 * one post may now feature several pieces, and the legacy serializer renders
 * the first.
 */
const postInclude = {
  author: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
  productTags: {
    orderBy: { sortOrder: 'asc' as const },
    include: { product: { include: PRODUCT_CARD_INCLUDE } },
  },
} satisfies Prisma.CommerceContentInclude;

const collectionInclude = {
  items: {
    include: {
      product: { include: PRODUCT_CARD_INCLUDE },
      seller: true,
      content: { include: postInclude },
    },
    orderBy: { createdAt: 'desc' as const },
  },
} satisfies Prisma.WishlistCollectionInclude;

@Injectable()
export class FavoritesService {
  constructor(private readonly prisma: PrismaService) {}

  async list(userId: string) {
    const favorites = await this.prisma.favorite.findMany({
      where: { userId },
      include: { product: { include: PRODUCT_CARD_INCLUDE } },
      orderBy: { createdAt: 'desc' },
    });
    return favorites.map((f) => serializeProduct(f.product, { isLiked: true }));
  }

  async listGuest(guestSessionId: string) {
    const favorites = await this.prisma.guestSavedItem.findMany({
      where: {
        guestSessionId,
        type: GuestSavedItemType.PRODUCT,
        productId: { not: null },
      },
      include: { product: { include: PRODUCT_CARD_INCLUDE } },
      orderBy: { createdAt: 'desc' },
    });
    return favorites
      .map((f) => f.product)
      .filter((product): product is NonNullable<typeof product> => !!product)
      .map((product) => serializeProduct(product, { isLiked: true }));
  }

  async overview(userId: string) {
    const [products, sellers, posts, collections] = await Promise.all([
      this.list(userId),
      this.prisma.sellerFavorite.findMany({
        where: { userId },
        include: { seller: true },
        orderBy: { createdAt: 'desc' },
      }),
      // `postSave`, not `postFavorite`. The platform had grown two tables for
      // one gesture: the bookmark on a feed card wrote `post_saves` through
      // `/posts/:id/save`, while this screen read `post_favorites`. So every
      // post a shopper saved from the feed went somewhere she could not reach,
      // and «منشورات محفوظة» stayed empty however many she bookmarked. One
      // table now, and it is the one the card writes.
      this.prisma.commerceContentSave.findMany({
        where: { userId },
        include: { content: { include: postInclude } },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.wishlistCollection.findMany({
        where: { userId },
        include: collectionInclude,
        orderBy: { updatedAt: 'desc' },
      }),
    ]);

    return {
      products,
      sellers: sellers.map((row) => this.serializeSavedSeller(row.seller, row.createdAt)),
      posts: posts.map((row) => ({
        saved_at: row.createdAt.toISOString(),
        post: serializeLegacyPost(row.content, {
          liked: new Set<string>(),
          saved: new Set([row.contentId]),
          viewed: new Set<string>(),
          reactions: new Map<string, string | null>(),
        }),
      })),
      collections: collections.map((collection) =>
        this.serializeCollection(collection, userId),
      ),
    };
  }

  async overviewGuest(guestSessionId: string) {
    const [products, sellers, posts] = await Promise.all([
      this.listGuest(guestSessionId),
      this.prisma.guestSavedItem.findMany({
        where: {
          guestSessionId,
          type: GuestSavedItemType.SELLER,
          sellerId: { not: null },
        },
        include: { seller: true },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.guestSavedItem.findMany({
        where: {
          guestSessionId,
          type: GuestSavedItemType.POST,
          contentId: { not: null },
        },
        include: { content: { include: postInclude } },
        orderBy: { createdAt: 'desc' },
      }),
    ]);

    return {
      products,
      sellers: sellers
        .map((row) => row.seller)
        .filter((seller): seller is User => !!seller)
        .map((seller) => this.serializeSavedSeller(seller, new Date())),
      posts: posts
        .filter((row) => !!row.content)
        .map((row) => ({
          saved_at: row.createdAt.toISOString(),
          post: serializeLegacyPost(row.content!),
        })),
      collections: [],
    };
  }

  async add(userId: string, productId: string) {
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new NotFoundException('Product not found');

    const existing = await this.prisma.favorite.findUnique({
      where: { userId_productId: { userId, productId } },
    });
    if (!existing) {
      await this.prisma.$transaction([
        this.prisma.favorite.create({ data: { userId, productId } }),
        this.prisma.product.update({
          where: { id: productId },
          data: { favoritesCount: { increment: 1 } },
        }),
      ]);
    }
    return { message: 'Added to favorites' };
  }

  async addGuest(guestSessionId: string, productId: string) {
    const product = await this.prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new NotFoundException('Product not found');
    await this.createGuestSavedOnce(guestSessionId, {
      type: GuestSavedItemType.PRODUCT,
      productId,
    });
    return { message: 'Saved temporarily' };
  }

  async remove(userId: string, productId: string) {
    const existing = await this.prisma.favorite.findUnique({
      where: { userId_productId: { userId, productId } },
    });
    if (existing) {
      await this.prisma.$transaction([
        this.prisma.favorite.delete({ where: { id: existing.id } }),
        this.prisma.product.update({
          where: { id: productId },
          data: { favoritesCount: { decrement: 1 } },
        }),
      ]);
    }
    return { message: 'Removed from favorites' };
  }

  async removeGuest(guestSessionId: string, productId: string) {
    await this.prisma.guestSavedItem.deleteMany({
      where: {
        guestSessionId,
        type: GuestSavedItemType.PRODUCT,
        productId,
      },
    });
    return { message: 'Removed from temporary saves' };
  }

  async saveSeller(userId: string, sellerId: string) {
    if (userId === sellerId) {
      throw new BadRequestException('You cannot save your own seller profile');
    }
    const seller = await this.prisma.user.findUnique({ where: { id: sellerId } });
    if (!seller || seller.role !== UserRole.SELLER) {
      throw new NotFoundException('Seller not found');
    }
    await this.prisma.sellerFavorite.upsert({
      where: { userId_sellerId: { userId, sellerId } },
      update: {},
      create: { userId, sellerId },
    });
    return { message: 'Seller saved' };
  }

  async saveSellerGuest(guestSessionId: string, sellerId: string) {
    const seller = await this.prisma.user.findUnique({ where: { id: sellerId } });
    if (!seller || seller.role !== UserRole.SELLER) {
      throw new NotFoundException('Seller not found');
    }
    await this.createGuestSavedOnce(guestSessionId, {
      type: GuestSavedItemType.SELLER,
      sellerId,
    });
    return { message: 'Seller saved temporarily' };
  }

  async removeSeller(userId: string, sellerId: string) {
    await this.prisma.sellerFavorite.deleteMany({ where: { userId, sellerId } });
    return { message: 'Seller removed from favorites' };
  }

  async removeSellerGuest(guestSessionId: string, sellerId: string) {
    await this.prisma.guestSavedItem.deleteMany({
      where: { guestSessionId, type: GuestSavedItemType.SELLER, sellerId },
    });
    return { message: 'Seller removed from temporary saves' };
  }

  async savePost(userId: string, postId: string) {
    const post = await this.prisma.commerceContent.findUnique({
      where: { id: postId },
    });
    if (!post) throw new NotFoundException('Post not found');
    const existing = await this.prisma.commerceContentSave.findUnique({
      where: { contentId_userId: { contentId: postId, userId } },
    });
    if (!existing) {
      await this.prisma.$transaction([
        this.prisma.commerceContentSave.create({
          data: { userId, contentId: postId },
        }),
        this.prisma.commerceContent.update({
          where: { id: postId },
          data: { savesCount: { increment: 1 } },
        }),
      ]);
    }
    return { message: 'Post saved' };
  }

  async savePostGuest(guestSessionId: string, postId: string) {
    const post = await this.prisma.commerceContent.findUnique({
      where: { id: postId },
    });
    if (!post) throw new NotFoundException('Post not found');
    await this.createGuestSavedOnce(guestSessionId, {
      type: GuestSavedItemType.POST,
      postId,
    });
    return { message: 'Post saved temporarily' };
  }

  async removePost(userId: string, postId: string) {
    const deleted = await this.prisma.commerceContentSave.deleteMany({
      where: { userId, contentId: postId },
    });
    if (deleted.count > 0) {
      await this.prisma.commerceContent.update({
        where: { id: postId },
        data: { savesCount: { decrement: 1 } },
      });
    }
    return { message: 'Post removed from favorites' };
  }

  async removePostGuest(guestSessionId: string, postId: string) {
    await this.prisma.guestSavedItem.deleteMany({
      where: { guestSessionId, type: GuestSavedItemType.POST, contentId: postId },
    });
    return { message: 'Post removed from temporary saves' };
  }

  async collections(userId: string) {
    const collections = await this.prisma.wishlistCollection.findMany({
      where: { userId },
      include: collectionInclude,
      orderBy: { updatedAt: 'desc' },
    });
    return collections.map((collection) => this.serializeCollection(collection, userId));
  }

  async createCollection(userId: string, dto: CreateWishlistCollectionDto) {
    const visibility = dto.visibility ?? WishlistShareVisibility.PRIVATE;
    const collection = await this.prisma.wishlistCollection.create({
      data: {
        userId,
        name: dto.name.trim(),
        description: dto.description?.trim() || null,
        visibility,
        shareSlug:
          visibility === WishlistShareVisibility.PRIVATE
            ? null
            : this.generateToken('wl'),
      },
      include: collectionInclude,
    });
    return this.serializeCollection(collection, userId);
  }

  async addItem(userId: string, collectionId: string, dto: AddWishlistItemDto) {
    await this.ensureCollectionOwner(userId, collectionId);
    const target = await this.resolveTarget(dto);
    const existing = await this.prisma.wishlistCollectionItem.findFirst({
      where: {
        collectionId,
        ...(target.productId ? { productId: target.productId } : {}),
        ...(target.sellerId ? { sellerId: target.sellerId } : {}),
        ...(target.postId ? { postId: target.postId } : {}),
      },
    });

    const item = existing
      ? await this.prisma.wishlistCollectionItem.update({
          where: { id: existing.id },
          data: {
            note: dto.note?.trim() || null,
            notifyPriceDrop: dto.notify_price_drop ?? existing.notifyPriceDrop,
            notifyBackInStock:
              dto.notify_back_in_stock ?? existing.notifyBackInStock,
          },
          include: {
            product: { include: PRODUCT_CARD_INCLUDE },
            seller: true,
            content: { include: postInclude },
          },
        })
      : await this.prisma.wishlistCollectionItem.create({
          data: {
            collectionId,
            type: dto.type,
            productId: target.productId,
            sellerId: target.sellerId,
            contentId: target.postId,
            priceWhenSaved: target.priceWhenSaved,
            note: dto.note?.trim() || null,
            notifyPriceDrop: dto.notify_price_drop ?? true,
            notifyBackInStock: dto.notify_back_in_stock ?? true,
          },
          include: {
            product: { include: PRODUCT_CARD_INCLUDE },
            seller: true,
            content: { include: postInclude },
          },
        });

    await this.prisma.wishlistCollection.update({
      where: { id: collectionId },
      data: { updatedAt: new Date() },
    });
    return this.serializeItem(item, userId);
  }

  async removeItem(userId: string, collectionId: string, itemId: string) {
    await this.ensureCollectionOwner(userId, collectionId);
    await this.prisma.wishlistCollectionItem.deleteMany({
      where: { id: itemId, collectionId },
    });
    return { message: 'Wishlist item removed' };
  }

  async share(userId: string, collectionId: string, dto: ShareWishlistDto) {
    await this.ensureCollectionOwner(userId, collectionId);
    const token = this.generateToken('share');
    const expiresAt = dto.expires_at ? new Date(dto.expires_at) : null;
    const share = await this.prisma.$transaction(async (tx) => {
      await tx.wishlistCollection.update({
        where: { id: collectionId },
        data: { visibility: WishlistShareVisibility.LINK },
      });
      return tx.wishlistShare.create({
        data: { collectionId, userId, token, expiresAt },
      });
    });
    return {
      token: share.token,
      expires_at: share.expiresAt?.toISOString() ?? null,
      share_url: `/favorites/shared/${share.token}`,
    };
  }

  async publicShare(token: string) {
    const share = await this.prisma.wishlistShare.findUnique({
      where: { token },
      include: {
        collection: {
          include: {
            user: true,
            ...collectionInclude,
          },
        },
      },
    });
    if (!share || (share.expiresAt && share.expiresAt < new Date())) {
      throw new NotFoundException('Wishlist share not found');
    }
    return {
      owner: serializePublicUser(share.collection.user),
      collection: this.serializeCollection(share.collection, share.userId),
    };
  }

  /**
   * Q18 P2 — "منتج بمفضلتك نزل سعره". Prices are Decimal now, so the
   * comparison and the message both go through Money rather than raw numbers,
   * and the currency travels with the figures instead of being guessed at
   * render time.
   */
  async notifyPriceDrop(
    productId: string,
    oldPrice: Prisma.Decimal,
    newPrice: Prisma.Decimal,
    currency: Currency = Currency.SYP,
  ) {
    const before = Money.of(oldPrice, currency);
    const after = Money.of(newPrice, currency);
    if (!after.lessThan(before)) return { recipients: 0 };

    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { id: true, title: true },
    });
    if (!product) return { recipients: 0 };

    const recipients = await this.productNotificationRecipients(productId, {
      priceDrop: true,
    });
    await this.createNotifications(recipients, {
      title: 'Price drop',
      body: `${product.title} dropped from ${before.toString()} to ${after.toString()}.`,
      type: NotificationType.promo,
      data: {
        product_id: product.id,
        old_price: before.toJSON(),
        new_price: after.toJSON(),
      },
    });
    return { recipients: recipients.length };
  }

  async notifyBackInStock(productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { id: true, title: true },
    });
    if (!product) return { recipients: 0 };

    const recipients = await this.productNotificationRecipients(productId, {
      backInStock: true,
    });
    await this.createNotifications(recipients, {
      title: 'Back in stock',
      body: `${product.title} is available again.`,
      type: NotificationType.system,
      data: { product_id: product.id },
    });
    return { recipients: recipients.length };
  }

  private async ensureCollectionOwner(userId: string, collectionId: string) {
    const collection = await this.prisma.wishlistCollection.findUnique({
      where: { id: collectionId },
      select: { userId: true },
    });
    if (!collection) throw new NotFoundException('Wishlist collection not found');
    if (collection.userId !== userId) {
      throw new ForbiddenException('You cannot edit this wishlist collection');
    }
    return collection;
  }

  private async resolveTarget(dto: AddWishlistItemDto) {
    const targetCount = [dto.product_id, dto.seller_id, dto.post_id].filter(Boolean).length;
    if (targetCount !== 1) {
      throw new BadRequestException('Exactly one wishlist target is required');
    }
    if (dto.type === WishlistItemType.PRODUCT) {
      if (!dto.product_id) throw new BadRequestException('product_id is required');
      const product = await this.prisma.product.findUnique({
        where: { id: dto.product_id },
        select: {
          id: true,
          offers: {
            where: { isActive: true },
            orderBy: { price: 'asc' },
            take: 1,
            select: { price: true, currency: true },
          },
        },
      });
      if (!product) throw new NotFoundException('Product not found');
      // Snapshot the cheapest live offer, so "price dropped since you saved
      // it" compares against something that was actually purchasable.
      const cheapest = product.offers[0];
      return {
        productId: product.id,
        priceWhenSaved: cheapest?.price ?? null,
        priceCurrency: cheapest?.currency ?? null,
      };
    }
    if (dto.type === WishlistItemType.SELLER) {
      if (!dto.seller_id) throw new BadRequestException('seller_id is required');
      const seller = await this.prisma.user.findUnique({
        where: { id: dto.seller_id },
        select: { id: true, role: true },
      });
      if (!seller || seller.role !== UserRole.SELLER) {
        throw new NotFoundException('Seller not found');
      }
      return { sellerId: seller.id };
    }
    if (!dto.post_id) throw new BadRequestException('post_id is required');
    const post = await this.prisma.commerceContent.findUnique({
      where: { id: dto.post_id },
      select: { id: true },
    });
    if (!post) throw new NotFoundException('Post not found');
    return { postId: post.id };
  }

  private async productNotificationRecipients(
    productId: string,
    options: { priceDrop?: boolean; backInStock?: boolean },
  ) {
    const [favoriteRows, collectionRows] = await Promise.all([
      this.prisma.favorite.findMany({
        where: { productId },
        select: { userId: true },
      }),
      this.prisma.wishlistCollectionItem.findMany({
        where: {
          productId,
          ...(options.priceDrop ? { notifyPriceDrop: true } : {}),
          ...(options.backInStock ? { notifyBackInStock: true } : {}),
        },
        select: { collection: { select: { userId: true } } },
      }),
    ]);
    return [
      ...new Set([
        ...favoriteRows.map((row) => row.userId),
        ...collectionRows.map((row) => row.collection.userId),
      ]),
    ];
  }

  private async createNotifications(
    userIds: string[],
    input: {
      title: string;
      body: string;
      type: NotificationType;
      data: Prisma.InputJsonValue;
    },
  ) {
    if (userIds.length === 0) return;
    await this.prisma.notification.createMany({
      data: userIds.map((userId) => ({
        userId,
        title: input.title,
        body: input.body,
        type: input.type,
        data: input.data,
      })),
    });
  }

  private async createGuestSavedOnce(
    guestSessionId: string,
    target: {
      type: GuestSavedItemType;
      productId?: string;
      sellerId?: string;
      postId?: string;
    },
  ) {
    const existing = await this.prisma.guestSavedItem.findFirst({
      where: {
        guestSessionId,
        type: target.type,
        ...(target.productId ? { productId: target.productId } : {}),
        ...(target.sellerId ? { sellerId: target.sellerId } : {}),
        ...(target.postId ? { postId: target.postId } : {}),
      },
      select: { id: true },
    });
    if (existing) return;
    await this.prisma.guestSavedItem.create({
      data: {
        guestSessionId,
        type: target.type,
        productId: target.productId,
        sellerId: target.sellerId,
        contentId: target.postId,
      },
    });
  }

  private serializeCollection(
    collection: Prisma.WishlistCollectionGetPayload<{
      include: typeof collectionInclude;
    }>,
    currentUserId: string,
  ) {
    return {
      id: collection.id,
      name: collection.name,
      description: collection.description,
      visibility: collection.visibility.toLowerCase(),
      share_slug: collection.shareSlug,
      items_count: collection.items.length,
      items: collection.items.map((item) => this.serializeItem(item, currentUserId)),
      created_at: collection.createdAt.toISOString(),
      updated_at: collection.updatedAt.toISOString(),
    };
  }

  private serializeItem(
    item: Prisma.WishlistCollectionItemGetPayload<{
      include: {
        product: { include: typeof PRODUCT_CARD_INCLUDE };
        seller: true;
        content: { include: typeof postInclude };
      };
    }>,
    currentUserId: string,
  ) {
    return {
      id: item.id,
      type: item.type.toLowerCase(),
      product: item.product ? serializeProduct(item.product, { isLiked: true }) : null,
      seller: item.seller ? serializePublicUser(item.seller) : null,
      post: item.content ? serializeLegacyPost(item.content) : null,
      price_when_saved: item.priceWhenSaved,
      notify_price_drop: item.notifyPriceDrop,
      notify_back_in_stock: item.notifyBackInStock,
      note: item.note,
      created_at: item.createdAt.toISOString(),
    };
  }

  private serializeSavedSeller(seller: User, createdAt: Date) {
    return {
      saved_at: createdAt.toISOString(),
      seller: serializePublicUser(seller),
    };
  }

  private generateToken(prefix: string) {
    return `${prefix}_${randomBytes(18).toString('base64url')}`;
  }
}
