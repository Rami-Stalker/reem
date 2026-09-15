import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { PrismaService } from '../../../prisma/prisma.service';
import { serializePublicUser } from '../../../common/serializers';

/**
 * The post menu's quiet options: «غير مهتمة» and «إخفاء منشورات هذا الحساب».
 *
 * Both are private to her. Nobody is notified, no counter on the author's
 * content moves, and nothing reaches a moderator — that is what a report is
 * for, and conflating the two would teach women that "not for me" is an
 * accusation. The reading half lives in `ContentFeedService.controlsWhere`.
 *
 * Every write is a desired state, so the app's outbox can replay one safely.
 */
@Injectable()
export class ContentFeedControlsService {
  constructor(private readonly prisma: PrismaService) {}

  async hide(userId: string, contentId: string) {
    await this.requireContent(contentId);
    await this.prisma.contentHide.createMany({
      data: [{ userId, contentId }],
      skipDuplicates: true,
    });
    return { is_hidden: true };
  }

  async unhide(userId: string, contentId: string) {
    await this.prisma.contentHide.deleteMany({ where: { userId, contentId } });
    return { is_hidden: false };
  }

  async mute(muterId: string, mutedId: string) {
    if (muterId === mutedId) {
      throw new BadRequestException('You cannot mute yourself');
    }
    const target = await this.prisma.user.findUnique({
      where: { id: mutedId },
      select: { id: true },
    });
    if (!target) throw new NotFoundException('User not found');

    await this.prisma.userMute.createMany({
      data: [{ muterId, mutedId }],
      skipDuplicates: true,
    });
    return { is_muted: true };
  }

  async unmute(muterId: string, mutedId: string) {
    await this.prisma.userMute.deleteMany({ where: { muterId, mutedId } });
    return { is_muted: false };
  }

  /** The accounts she muted, so a mute is never a one-way door. */
  async muted(muterId: string) {
    const rows = await this.prisma.userMute.findMany({
      where: { muterId },
      orderBy: { createdAt: 'desc' },
      include: { muted: true },
      take: 200,
    });
    return {
      data: rows.map((row) => ({
        user: serializePublicUser(row.muted),
        muted_at: row.createdAt.toISOString(),
      })),
    };
  }

  private async requireContent(contentId: string) {
    const content = await this.prisma.commerceContent.findUnique({
      where: { id: contentId },
      select: { id: true },
    });
    if (!content) throw new NotFoundException('Content not found');
  }
}
