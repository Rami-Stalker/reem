import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

@Injectable()
export class StoriesRepository {
  constructor(private readonly prisma: PrismaService) {}

  /**
   * `userId` is absent for a signed-out visitor. The per-viewer relations are
   * then dropped with `take: 0`: `where: { userId: undefined }` is "no filter"
   * to Prisma, which would load every view and reaction on every live story
   * just to compute `is_viewed: false`.
   */
  activeForViewer(userId?: string) {
    const viewerScope = userId ? { where: { userId } } : { take: 0 };
    return this.prisma.story.findMany({
      where: { expiresAt: { gt: new Date() } },
      orderBy: { createdAt: 'desc' },
      include: {
        user: true,
        views: viewerScope,
        reactions: viewerScope,
      },
    });
  }

  findOwner(id: string) {
    return this.prisma.story.findUnique({
      where: { id },
      // `link` is here for the trend signal: a story pointing at a product is
      // discovery for that product, and the view path already loads this row.
      select: {
        id: true,
        userId: true,
        expiresAt: true,
        createdAt: true,
        link: true,
      },
    });
  }

  create(data: Prisma.StoryCreateInput) {
    return this.prisma.story.create({
      data,
      include: { user: true, views: true, reactions: true },
    });
  }

  delete(id: string) {
    return this.prisma.story.delete({ where: { id } });
  }

  upsertView(storyId: string, userId: string) {
    return this.prisma.storyView.upsert({
      where: { storyId_userId: { storyId, userId } },
      create: { storyId, userId },
      update: {},
    });
  }

  upsertReaction(storyId: string, userId: string, emoji: string) {
    return this.prisma.storyReaction.upsert({
      where: { storyId_userId: { storyId, userId } },
      create: { storyId, userId, emoji },
      update: { emoji },
    });
  }

  deleteReaction(storyId: string, userId: string) {
    return this.prisma.storyReaction.deleteMany({ where: { storyId, userId } });
  }

  countViews(storyId: string) {
    return this.prisma.storyView.count({ where: { storyId } });
  }

  viewers(storyId: string) {
    return this.prisma.storyView.findMany({
      where: { storyId },
      include: { user: true },
      orderBy: { viewedAt: 'desc' },
    });
  }

  reactionsFor(storyId: string) {
    return this.prisma.storyReaction.findMany({ where: { storyId } });
  }

  deleteExpired() {
    return this.prisma.story.deleteMany({
      where: { expiresAt: { lt: new Date() } },
    });
  }
}
