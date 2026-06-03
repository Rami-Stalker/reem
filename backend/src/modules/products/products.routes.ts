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

export const productsRouter = Router();

productsRouter.get(
  '/trending',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const products = await prisma.product.findMany({
      where: { isAvailable: true },
      orderBy: [{ likesCount: 'desc' }, { viewsCount: 'desc' }],
      take: 20,
      include: productInclude,
    });
    const favorites = await prisma.favorite.findMany({
      where: { userId: req.user!.id },
      select: { productId: true },
    });
    const favSet = new Set(favorites.map((f) => f.productId));
    res.json(
      products.map((p) => serializeProduct(p, { isLiked: favSet.has(p.id) })),
    );
  }),
);

productsRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const page = Math.max(1, parseInt(String(req.query.page ?? '1'), 10));
    const limit = Math.min(50, parseInt(String(req.query.limit ?? '20'), 10));
    const skip = (page - 1) * limit;

    const products = await prisma.product.findMany({
      where: { isAvailable: true },
      orderBy: { createdAt: 'desc' },
      skip,
      take: limit,
      include: productInclude,
    });
    res.json(products.map((p) => serializeProduct(p)));
  }),
);

productsRouter.get(
  '/:id',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const id = paramId(req.params.id);
    const product = await prisma.product.findUnique({
      where: { id },
      include: productInclude,
    });
    if (!product) throw new NotFoundError('Product not found');

    await prisma.product.update({
      where: { id },
      data: { viewsCount: { increment: 1 } },
    });

    const favorite = await prisma.favorite.findUnique({
      where: {
        userId_productId: {
          userId: req.user!.id,
          productId: product.id,
        },
      },
    });

    res.json(serializeProduct(product, { isLiked: !!favorite }));
  }),
);
