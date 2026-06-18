import { Post, User } from '@prisma/client';
import { serializeUser } from './user.serializer';
import { ProductWithRelations, serializeProduct } from './product.serializer';

export type PostWithRelations = Post & {
  author: User;
  product: ProductWithRelations;
  likes?: { userId: string }[];
  saves?: { userId: string }[];
};

export function serializePost(post: PostWithRelations, currentUserId?: string) {
  const isLiked =
    currentUserId && post.likes
      ? post.likes.some((l) => l.userId === currentUserId)
      : false;
  const isSaved =
    currentUserId && post.saves
      ? post.saves.some((s) => s.userId === currentUserId)
      : false;

  return {
    id: post.id,
    author: serializeUser(post.author),
    product: serializeProduct(post.product),
    caption: post.caption,
    likes_count: post.likesCount,
    comments_count: post.commentsCount,
    shares_count: post.sharesCount,
    saves_count: post.savesCount,
    is_liked: isLiked,
    is_saved: isSaved,
    created_at: post.createdAt.toISOString(),
  };
}
