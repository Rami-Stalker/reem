import { Product, ProductMedia, ProductVariant, User } from '@prisma/client';
import { serializeUser } from './user.serializer';

export type ProductWithRelations = Product & {
  seller: User;
  media: ProductMedia[];
  variants?: ProductVariant[];
};

export function serializeVariant(v: ProductVariant) {
  return {
    id: v.id,
    name: v.name,
    sku: v.sku,
    price: v.price,
    stock: v.stock,
    attributes: v.attributes ?? null,
    sort_order: v.sortOrder,
  };
}

export function serializeProduct(
  product: ProductWithRelations,
  options?: { isLiked?: boolean },
) {
  return {
    id: product.id,
    seller: serializeUser(product.seller),
    title: product.title,
    description: product.description,
    category: product.category,
    price: product.price,
    old_price: product.oldPrice,
    stock: product.stock,
    status: product.status.toLowerCase(),
    media: [...product.media]
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map((m) => ({ url: m.url, type: m.type })),
    variants: (product.variants ?? [])
      .slice()
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map(serializeVariant),
    is_available: product.isAvailable,
    is_featured: product.isFeatured,
    show_in_feed: product.showInFeed,
    rating: product.rating,
    reviews_count: product.reviewsCount,
    views_count: product.viewsCount,
    likes_count: product.likesCount,
    orders_count: product.ordersCount,
    favorites_count: product.favoritesCount,
    created_at: product.createdAt.toISOString(),
    ...(options?.isLiked !== undefined ? { is_liked: options.isLiked } : {}),
  };
}
