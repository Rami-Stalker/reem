import { Router } from 'express';
import { prisma } from '../../lib/prisma.js';
import { asyncHandler } from '../../middleware/error-handler.js';
import { requireAuth, type AuthRequest } from '../../middleware/auth.js';
import { serializeOrder } from '../../utils/serializers.js';

export const ordersRouter = Router();

ordersRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const orders = await prisma.order.findMany({
      where: { userId: req.user!.id },
      orderBy: { createdAt: 'desc' },
      include: { items: true },
    });
    res.json(orders.map(serializeOrder));
  }),
);
