import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { asyncHandler } from '../../middleware/error-handler.js';
import { requireAuth, type AuthRequest } from '../../middleware/auth.js';
import { validateBody } from '../../middleware/validate.js';
import { serializeUser } from '../../utils/serializers.js';
import { NotFoundError } from '../../lib/errors.js';

const updateSchema = z.object({
  name: z.string().min(2).max(100).optional(),
  bio: z.string().max(500).optional().nullable(),
  image_url: z.string().url().optional().nullable(),
});

export const usersRouter = Router();

usersRouter.get(
  '/me',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const user = await prisma.user.findUnique({ where: { id: req.user!.id } });
    if (!user) throw new NotFoundError('User not found');
    res.json(serializeUser(user));
  }),
);

usersRouter.patch(
  '/me',
  requireAuth,
  validateBody(updateSchema),
  asyncHandler(async (req: AuthRequest, res) => {
    const { name, bio, image_url } = req.body;
    const user = await prisma.user.update({
      where: { id: req.user!.id },
      data: {
        ...(name !== undefined && { name }),
        ...(bio !== undefined && { bio }),
        ...(image_url !== undefined && { imageUrl: image_url }),
      },
    });
    res.json(serializeUser(user));
  }),
);
