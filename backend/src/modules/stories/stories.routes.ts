import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { asyncHandler } from '../../middleware/error-handler.js';
import { requireAuth, type AuthRequest } from '../../middleware/auth.js';
import { validateBody } from '../../middleware/validate.js';
import { serializeStory } from '../../utils/serializers.js';

const createStorySchema = z.object({
  media_url: z.string().url(),
  link: z.string().url().optional().nullable(),
  type: z.enum(['image', 'video']).optional(),
});

export const storiesRouter = Router();

storiesRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const now = new Date();
    const stories = await prisma.story.findMany({
      where: { expiresAt: { gt: now } },
      orderBy: { createdAt: 'desc' },
      include: {
        user: true,
        views: { where: { userId: req.user!.id } },
      },
    });
    res.json(stories.map((s) => serializeStory(s, req.user!.id)));
  }),
);

storiesRouter.post(
  '/',
  requireAuth,
  validateBody(createStorySchema),
  asyncHandler(async (req: AuthRequest, res) => {
    const { media_url, link, type } = req.body;
    const expiresAt = new Date();
    expiresAt.setHours(expiresAt.getHours() + 24);

    const story = await prisma.story.create({
      data: {
        userId: req.user!.id,
        mediaUrl: media_url,
        mediaType: type ?? 'image',
        link: link ?? null,
        expiresAt,
      },
      include: { user: true, views: true },
    });
    res.status(201).json(serializeStory(story, req.user!.id));
  }),
);
