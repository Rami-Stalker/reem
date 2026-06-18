import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  NotificationType,
  Prisma,
  User,
  UserRole,
  WishlistItemType,
  WishlistShareVisibility,
} from '@prisma/client';
import { randomBytes } from 'crypto';
import { PrismaService } from '../../prisma/prisma.service';
import { serializePost, serializeProduct, serializeUser } from '../../common/serializers';
import {
  AddWishlistItemDto,
  CreateWishlistCollectionDto,
  ShareWishlistDto,
} from './dto/wishlist.dto';

const productInclude = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
  variants: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.ProductInclude;

const postInclude = {
  author: true,
  product: { include: productInclude },
} satisfies Prisma.PostInclude;

const collectionInclude = {
  items: {
    include: {
      product: { include: productInclude },
      seller: true,
      post: { include: postInclude },
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
      include: { product: { include: productInclude } },
      orderBy: { createdAt: 'desc' },
    });
    return favorites.map((f) => serializeProduct(f.product, { isLiked: true }));
  }

  async overview(userId: string) {
    const [products, sellers, posts, collections] = await Promise.all([
      this.list(userId),
      this.prisma.sellerFavorite.findMany({
        where: { userId },
        include: { seller: true },
        orderBy: { createdAt: 'desc' },
      }),
      this.prisma.postFavorite.findMany({
        where: { userId },
        include: { post: { include: postInclude } },
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
        post: serializePost(row.post, userId),
      })),
      collections: collections.map((collection) =>
        this.serializeCollection(collection, userId),
      ),
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

  async removeSeller(userId: string, sellerId: string) {
    await this.prisma.sellerFavorite.deleteMany({ where: { userId, sellerId } });
    return { message: 'Seller removed from favorites' };
  }

  async savePost(userId: string, postId: string) {
    const post = await this.prisma.post.findUnique({ where: { id: postId } });
    if (!post) throw new NotFoundException('Post not found');
    const existing = await this.prisma.postFavorite.findUnique({
      where: { userId_postId: { userId, postId } },
    });
    if (!existing) {
      await this.prisma.$transaction([
        this.prisma.postFavorite.create({ data: { userId, postId } }),
        this.prisma.post.update({
          where: { id: postId },
          data: { savesCount: { increment: 1 } },
        }),
      ]);
    }
    return { message: 'Post saved' };
  }

  async removePost(userId: string, postId: string) {
    const deleted = await this.prisma.postFavorite.deleteMany({
      where: { userId, postId },
    });
    if (deleted.count > 0) {
      await this.prisma.post.update({
        where: { id: postId },
        data: { savesCount: { decrement: 1 } },
      });
    }
    return { message: 'Post removed from favorites' };
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
            product: { include: productInclude },
            seller: true,
            post: { include: postInclude },
          },
        })
      : await this.prisma.wishlistCollectionItem.create({
          data: {
            collectionId,
            type: dto.type,
            productId: target.productId,
            sellerId: target.sellerId,
            postId: target.postId,
            priceWhenSaved: target.priceWhenSaved,
            note: dto.note?.trim() || null,
            notifyPriceDrop: dto.notify_price_drop ?? true,
            notifyBackInStock: dto.notify_back_in_stock ?? true,
          },
          include: {
            product: { include: productInclude },
            seller: true,
            post: { include: postInclude },
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
      owner: serializeUser(share.collection.user),
      collection: this.serializeCollection(share.collection, share.userId),
    };
  }

  async notifyPriceDrop(productId: string, oldPrice: number, newPrice: number) {
    if (newPrice >= oldPrice) return { recipients: 0 };
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
      body: `${product.title} dropped from ${oldPrice} to ${newPrice}.`,
      type: NotificationType.promo,
      data: { product_id: product.id, old_price: oldPrice, new_price: newPrice },
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
        select: { id: true, price: true },
      });
      if (!product) throw new NotFoundException('Product not found');
      return { productId: product.id, priceWhenSaved: product.price };
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
    const post = await this.prisma.post.findUnique({
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
        product: { include: typeof productInclude };
        seller: true;
        post: { include: typeof postInclude };
      };
    }>,
    currentUserId: string,
  ) {
    return {
      id: item.id,
      type: item.type.toLowerCase(),
      product: item.product ? serializeProduct(item.product, { isLiked: true }) : null,
      seller: item.seller ? serializeUser(item.seller) : null,
      post: item.post ? serializePost(item.post, currentUserId) : null,
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
      seller: serializeUser(seller),
    };
  }

  private generateToken(prefix: string) {
    return `${prefix}_${randomBytes(18).toString('base64url')}`;
  }
}
