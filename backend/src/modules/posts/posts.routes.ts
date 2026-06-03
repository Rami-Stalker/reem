import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { asyncHandler } from '../../middleware/error-handler.js';
import { requireAuth, type AuthRequest } from '../../middleware/auth.js';
import { validateBody } from '../../middleware/validate.js';
import { serializePost } from '../../utils/serializers.js';
import { NotFoundError } from '../../lib/errors.js';
import { paramId } from '../../utils/params.js';

const productInclude = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
};

const createPostSchema = z.object({
  caption: z.string().min(1).max(2000),
  product_id: z.string().uuid(),
});

export const postsRouter = Router();

postsRouter.get(
  '/feed',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const posts = await prisma.post.findMany({
      orderBy: { createdAt: 'desc' },
      take: 50,
      include: {
        author: true,
        product: { include: productInclude },
        likes: { where: { userId: req.user!.id } },
      },
    });
    res.json(posts.map((p) => serializePost(p, req.user!.id)));
  }),
);

postsRouter.post(
  '/',
  requireAuth,
  validateBody(createPostSchema),
  asyncHandler(async (req: AuthRequest, res) => {
    const { caption, product_id } = req.body;
    const product = await prisma.product.findUnique({ where: { id: product_id } });
    if (!product) throw new NotFoundError('Product not found');

    const post = await prisma.post.create({
      data: {
        authorId: req.user!.id,
        productId: product_id,
        caption,
      },
      include: {
        author: true,
        product: { include: productInclude },
        likes: true,
      },
    });
    res.status(201).json(serializePost(post, req.user!.id));
  }),
);

postsRouter.post(
  '/:id/like',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const postId = paramId(req.params.id);
    const userId = req.user!.id;

    const existing = await prisma.postLike.findUnique({
      where: { postId_userId: { postId, userId } },
    });

    if (existing) {
      await prisma.postLike.delete({ where: { id: existing.id } });
      await prisma.post.update({
        where: { id: postId },
        data: { likesCount: { decrement: 1 } },
      });
    } else {
      await prisma.postLike.create({ data: { postId, userId } });
      await prisma.post.update({
        where: { id: postId },
        data: { likesCount: { increment: 1 } },
      });
    }

    const post = await prisma.post.findUnique({
      where: { id: postId },
      include: {
        author: true,
        product: { include: productInclude },
        likes: { where: { userId } },
      },
    });
    if (!post) throw new NotFoundError('Post not found');
    res.json(serializePost(post, userId));
  }),
);
