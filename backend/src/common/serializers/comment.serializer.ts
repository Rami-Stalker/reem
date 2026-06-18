import { Comment, User } from '@prisma/client';
import { serializeUser } from './user.serializer';

export type CommentWithUser = Comment & { user: User };

export function serializeComment(comment: CommentWithUser) {
  return {
    id: comment.id,
    user: serializeUser(comment.user),
    content: comment.content,
    likes_count: 0,
    created_at: comment.createdAt.toISOString(),
  };
}
