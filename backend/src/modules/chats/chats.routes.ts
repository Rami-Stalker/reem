import { Router } from 'express';
import { z } from 'zod';
import { prisma } from '../../lib/prisma.js';
import { asyncHandler } from '../../middleware/error-handler.js';
import { requireAuth, type AuthRequest } from '../../middleware/auth.js';
import { validateBody } from '../../middleware/validate.js';
import { serializeChatThread, serializeMessage } from '../../utils/serializers.js';
import { ForbiddenError } from '../../lib/errors.js';
import { paramId } from '../../utils/params.js';

const messageSchema = z.object({
  content: z.string().min(1).max(5000),
  type: z.string().optional(),
});

export const chatsRouter = Router();

chatsRouter.get(
  '/',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const userId = req.user!.id;
    const participations = await prisma.chatParticipant.findMany({
      where: { userId },
      include: {
        chat: {
          include: {
            participants: { include: { user: true } },
            messages: {
              orderBy: { createdAt: 'desc' },
              take: 1,
            },
          },
        },
      },
      orderBy: { chat: { updatedAt: 'desc' } },
    });

    const threads = participations.map((p) =>
      serializeChatThread(p.chat, userId),
    );
    res.json(threads);
  }),
);

chatsRouter.get(
  '/:id/messages',
  requireAuth,
  asyncHandler(async (req: AuthRequest, res) => {
    const chatId = paramId(req.params.id);
    const userId = req.user!.id;

    const participant = await prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });
    if (!participant) throw new ForbiddenError('Not a member of this chat');

    const messages = await prisma.message.findMany({
      where: { chatId },
      orderBy: { createdAt: 'asc' },
      take: 100,
    });

    res.json(messages.map((m) => serializeMessage(m, userId)));
  }),
);

chatsRouter.post(
  '/:id/messages',
  requireAuth,
  validateBody(messageSchema),
  asyncHandler(async (req: AuthRequest, res) => {
    const chatId = paramId(req.params.id);
    const userId = req.user!.id;

    const participant = await prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId, userId } },
    });
    if (!participant) throw new ForbiddenError('Not a member of this chat');

    const message = await prisma.message.create({
      data: {
        chatId,
        senderId: userId,
        content: req.body.content,
      },
    });

    await prisma.chat.update({
      where: { id: chatId },
      data: { updatedAt: new Date() },
    });

    res.status(201).json(serializeMessage(message, userId));
  }),
);
