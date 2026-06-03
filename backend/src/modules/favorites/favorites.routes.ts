import { Router } from 'express';
import { prisma } from '../../lib/prisma.js';
import { asyncHandler } from '../../middleware/error-handler.js';
import { requireAuth, type AuthRequest } from '../../middleware/auth.js';
import { serializeProduct } from '../../utils/serializers.js';
import { NotFoundError } from '../../lib/errors.js';
import { paramId } from '../../utils/params.js';

const productInclude = {
  seller: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
};

export const favoritesRouter = Router();

favoritesRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const favorites = await prisma.favorite.findMany({
      where: { userId: req.user!.id },
      include: { product: { include: productInclude } },
      orderBy: { createdAt: 'desc' },
    });
    res.json(
      favorites.map((f) => serializeProduct(f.product, { isLiked: true })),
    );
  }),
);

favoritesRouter.post(
  '/:productId',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const productId = paramId(req.params.productId);
    const userId = req.user!.id;

    const product = await prisma.product.findUnique({ where: { id: productId } });
    if (!product) throw new NotFoundError('Product not found');

    await prisma.favorite.upsert({
      where: { userId_productId: { userId, productId } },
      create: { userId, productId },
      update: {},
    });

    res.status(201).json({ message: 'Added to favorites' });
  }),
);

favoritesRouter.delete(
  '/:productId',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    await prisma.favorite.deleteMany({
      where: {
        userId: req.user!.id,
        productId: paramId(req.params.productId),
      },
    });
    res.json({ message: 'Removed from favorites' });
  }),
);
