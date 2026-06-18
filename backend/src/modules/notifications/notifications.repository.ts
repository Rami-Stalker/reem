import { Injectable } from '@nestjs/common';
import { Prisma } from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';

type PreferenceKey =
  | 'inAppPosts'
  | 'inAppStories'
  | 'inAppOrders'
  | 'inAppCoupons';

@Injectable()
export class NotificationsRepository {
  constructor(private readonly prisma: PrismaService) {}

  list(userId: string, where: Prisma.NotificationWhereInput, skip: number, take: number) {
    return this.prisma.notification.findMany({
      where: { userId, ...where },
      orderBy: { createdAt: 'desc' },
      skip,
      take,
    });
  }

  count(userId: string, where: Prisma.NotificationWhereInput = {}) {
    return this.prisma.notification.count({ where: { userId, ...where } });
  }

  create(data: Prisma.NotificationUncheckedCreateInput) {
    return this.prisma.notification.create({ data });
  }

  createMany(data: Prisma.NotificationCreateManyInput[]) {
    if (data.length === 0) return Promise.resolve({ count: 0 });
    return this.prisma.notification.createMany({ data });
  }

  markRead(userId: string, id: string) {
    return this.prisma.notification.updateMany({
      where: { id, userId },
      data: { isRead: true },
    });
  }

  markAllRead(userId: string) {
    return this.prisma.notification.updateMany({
      where: { userId, isRead: false },
      data: { isRead: true },
    });
  }

  async userName(userId: string): Promise<string> {
    const user = await this.prisma.user.findUnique({
      where: { id: userId },
      select: { name: true },
    });
    return user?.name ?? 'A seller you follow';
  }

  /** Ids of users following a seller (notification fan-out targets). */
  async followerIds(sellerId: string): Promise<string[]> {
    const rows = await this.prisma.follow.findMany({
      where: { followingId: sellerId },
      select: { followerId: true },
    });
    return rows.map((r) => r.followerId);
  }

  /**
   * Returns the set of users (among [userIds]) who have DISABLED [key]. Missing
   * preference rows mean "default on", so they are not in the returned set.
   */
  async optedOut(userIds: string[], key: PreferenceKey): Promise<Set<string>> {
    if (userIds.length === 0) return new Set();
    const prefs = await this.prisma.notificationPreference.findMany({
      where: { userId: { in: userIds }, [key]: false },
      select: { userId: true },
    });
    return new Set(prefs.map((p) => p.userId));
  }

  getPreference(userId: string) {
    return this.prisma.notificationPreference.findUnique({ where: { userId } });
  }

  upsertPreference(userId: string, data: PreferencePatch) {
    return this.prisma.notificationPreference.upsert({
      where: { userId },
      create: { userId, ...data },
      update: data,
    });
  }
}

export interface PreferencePatch {
  inAppPosts?: boolean;
  inAppStories?: boolean;
  inAppOrders?: boolean;
  inAppCoupons?: boolean;
  push?: boolean;
  email?: boolean;
  sms?: boolean;
}
