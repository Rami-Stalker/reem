import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { asyncHandler } from '../../middleware/error-handler.js';
import { requireAuth, type AuthRequest } from '../../middleware/auth.js';
import { validateBody } from '../../middleware/validate.js';
import {
  serializeAddress,
  serializeCoupon,
  serializeNotification,
  serializePaymentMethod,
  serializeUser,
} from '../../utils/serializers.js';

const addressSchema = z.object({
  label: z.string().min(1).max(50).default('Home'),
  street: z.string().min(1),
  city: z.string().min(1),
  country: z.string().min(1),
  postal_code: z.string().optional().nullable(),
  is_default: z.boolean().optional(),
});

export const addressesRouter = Router();
export const couponsRouter = Router();
export const rewardsRouter = Router();
export const notificationsRouter = Router();
export const paymentMethodsRouter = Router();

addressesRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const addresses = await prisma.address.findMany({
      where: { userId: req.user!.id },
      orderBy: { isDefault: 'desc' },
    });
    res.json(addresses.map(serializeAddress));
  }),
);

addressesRouter.post(
  '/',
  requireAuth,
  validateBody(addressSchema),
  asyncHandler(async (req: AuthRequest, res) => {
    const data = req.body;
    if (data.is_default) {
      await prisma.address.updateMany({
        where: { userId: req.user!.id },
        data: { isDefault: false },
      });
    }
    const address = await prisma.address.create({
      data: {
        userId: req.user!.id,
        label: data.label,
        street: data.street,
        city: data.city,
        country: data.country,
        postalCode: data.postal_code,
        isDefault: data.is_default ?? false,
      },
    });
    res.status(201).json(serializeAddress(address));
  }),
);

couponsRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (_req, res) => {
    const coupons = await prisma.coupon.findMany({
      where: { isActive: true, expiresAt: { gt: new Date() } },
    });
    res.json(coupons.map(serializeCoupon));
  }),
);

rewardsRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
    res.json({
      points: user?.points ?? 0,
      lifetime_points: user?.lifetimePoints ?? 0,
      tier: user?.tier ?? 'Bronze',
    });
  }),
);

notificationsRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const notifications = await prisma.notification.findMany({
      where: { userId: req.user!.id },
      orderBy: { createdAt: 'desc' },
      take: 50,
    });
    res.json(notifications.map(serializeNotification));
  }),
);

paymentMethodsRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const methods = await prisma.paymentMethod.findMany({
      where: { userId: req.user!.id },
    });
    res.json(methods.map(serializePaymentMethod));
  }),
);

paymentMethodsRouter.post(
  '/',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const schema = z.object({
      brand: z.string(),
      last4: z.string().length(4),
      exp_month: z.number().int().min(1).max(12),
      exp_year: z.number().int(),
      is_default: z.boolean().optional(),
    });
    const data = schema.parse(req.body);
    if (data.is_default) {
      await prisma.paymentMethod.updateMany({
        where: { userId: req.user!.id },
        data: { isDefault: false },
      });
    }
    const pm = await prisma.paymentMethod.create({
      data: {
        userId: req.user!.id,
        brand: data.brand,
        last4: data.last4,
        expMonth: data.exp_month,
        expYear: data.exp_year,
        isDefault: data.is_default ?? false,
      },
    });
    res.status(201).json(serializePaymentMethod(pm));
  }),
);

// Re-export for users profile update via settings repository
export { serializeUser };
