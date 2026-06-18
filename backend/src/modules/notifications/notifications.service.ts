import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { OnEvent } from '@nestjs/event-emitter';
import {
  NotificationCampaignStatus,
  NotificationChannel,
  NotificationDeliveryStatus,
  NotificationPreference,
  NotificationType,
  Prisma,
  UserRole,
} from '@prisma/client';
import { createHash } from 'crypto';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import { serializeNotification } from '../../common/serializers';
import { PrismaService } from '../../prisma/prisma.service';
import {
  AppEvent,
  CouponIssuedPayload,
  OrderStatusChangedPayload,
  PostPublishedPayload,
  StoryPublishedPayload,
} from '../../common/events/app-events';
import {
  NotificationsRepository,
  PreferencePatch,
} from './notifications.repository';
import { UpdatePreferencesDto } from './dto/update-preferences.dto';
import {
  CreateCampaignDto,
  DispatchNotificationDto,
  NotificationSegmentDto,
  RegisterPushTokenDto,
  TrackNotificationEventDto,
  UpdateCampaignStatusDto,
} from './dto/notification-engine.dto';

type PrefKey = 'inAppPosts' | 'inAppStories' | 'inAppOrders' | 'inAppCoupons';

@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly repo: NotificationsRepository,
    private readonly prisma: PrismaService,
  ) {}

  // ── Reads / mutations ────────────────────────────────────────────────────

  async list(userId: string, page: PaginationDto, unreadOnly: boolean) {
    const where: Prisma.NotificationWhereInput = unreadOnly
      ? { isRead: false }
      : {};
    const [items, total, unread] = await Promise.all([
      this.repo.list(userId, where, page.skip, page.limit),
      this.repo.count(userId, where),
      this.repo.count(userId, { isRead: false }),
    ]);
    return {
      data: items.map(serializeNotification),
      unread_count: unread,
      pagination: buildMeta(page.page, page.limit, total, items.length),
    };
  }

  async unreadCount(userId: string) {
    return { count: await this.repo.count(userId, { isRead: false }) };
  }

  async markRead(userId: string, id: string) {
    await this.repo.markRead(userId, id);
    return { message: 'Marked as read' };
  }

  async markAllRead(userId: string) {
    const result = await this.repo.markAllRead(userId);
    return { message: 'All notifications marked as read', updated: result.count };
  }

  async getPreferences(userId: string) {
    return this.serializePrefs(await this.repo.getPreference(userId));
  }

  async updatePreferences(userId: string, dto: UpdatePreferencesDto) {
    const patch: PreferencePatch = {
      ...(dto.in_app_posts !== undefined && { inAppPosts: dto.in_app_posts }),
      ...(dto.in_app_stories !== undefined && {
        inAppStories: dto.in_app_stories,
      }),
      ...(dto.in_app_orders !== undefined && { inAppOrders: dto.in_app_orders }),
      ...(dto.in_app_coupons !== undefined && {
        inAppCoupons: dto.in_app_coupons,
      }),
      ...(dto.push !== undefined && { push: dto.push }),
      ...(dto.email !== undefined && { email: dto.email }),
      ...(dto.sms !== undefined && { sms: dto.sms }),
    };
    return this.serializePrefs(await this.repo.upsertPreference(userId, patch));
  }

  async registerPushToken(userId: string, dto: RegisterPushTokenDto) {
    const tokenHash = createHash('sha256').update(dto.token).digest('hex');
    await this.prisma.pushToken.upsert({
      where: { tokenHash },
      create: {
        userId,
        tokenHash,
        provider: dto.provider,
        platform: dto.platform,
      },
      update: {
        userId,
        provider: dto.provider,
        platform: dto.platform,
        enabled: true,
        lastSeenAt: new Date(),
      },
    });
    return { message: 'Push token registered' };
  }

  async dispatch(actorId: string, dto: DispatchNotificationDto) {
    const recipients = dto.user_ids?.length
      ? dto.user_ids
      : await this.recipientsFor(dto.segment ?? {});

    const queued = await this.enqueueForRecipients({
      recipients,
      channels: dto.channels,
      title: dto.title,
      body: dto.body,
      type: dto.type ?? NotificationType.system,
      payload: dto.payload,
      scheduledAt: new Date(),
    });

    await this.processDueDeliveries(500);
    return { queued, recipients: recipients.length, actor_id: actorId };
  }

  async createCampaign(actorId: string, dto: CreateCampaignDto) {
    const scheduledAt = dto.scheduled_at ? new Date(dto.scheduled_at) : null;
    const campaign = await this.prisma.notificationCampaign.create({
      data: {
        name: dto.name,
        description: dto.description,
        status: scheduledAt
          ? NotificationCampaignStatus.SCHEDULED
          : NotificationCampaignStatus.DRAFT,
        channels: dto.channels,
        segment: {
          ...(dto.segment ?? {}),
          ...(dto.user_ids?.length ? { user_ids: dto.user_ids } : {}),
        } as Prisma.InputJsonValue,
        title: dto.title,
        body: dto.body,
        deepLink: dto.deep_link,
        scheduledAt,
        createdBy: actorId,
      },
    });
    return this.serializeCampaign(campaign, 0);
  }

  async listCampaigns() {
    const campaigns = await this.prisma.notificationCampaign.findMany({
      orderBy: { createdAt: 'desc' },
      take: 100,
      include: { _count: { select: { deliveries: true } } },
    });
    return campaigns.map((campaign) =>
      this.serializeCampaign(campaign, campaign._count.deliveries),
    );
  }

  async updateCampaignStatus(id: string, dto: UpdateCampaignStatusDto) {
    const campaign = await this.prisma.notificationCampaign.update({
      where: { id },
      data: { status: dto.status },
      include: { _count: { select: { deliveries: true } } },
    });
    return this.serializeCampaign(campaign, campaign._count.deliveries);
  }

  async runCampaign(id: string) {
    const campaign = await this.prisma.notificationCampaign.findUnique({
      where: { id },
    });
    if (!campaign) return { queued: 0, recipients: 0 };

    await this.prisma.notificationCampaign.update({
      where: { id },
      data: {
        status: NotificationCampaignStatus.RUNNING,
        startedAt: new Date(),
      },
    });

    const segment = campaign.segment as Record<string, unknown>;
    const recipients = Array.isArray(segment.user_ids)
      ? segment.user_ids.map(String)
      : await this.recipientsFor(segment);
    const queued = await this.enqueueForRecipients({
      campaignId: campaign.id,
      recipients,
      channels: campaign.channels,
      title: campaign.title,
      body: campaign.body,
      type: NotificationType.promo,
      payload: { campaign_id: campaign.id, deep_link: campaign.deepLink },
      scheduledAt: new Date(),
    });

    await this.prisma.notificationCampaign.update({
      where: { id },
      data: {
        status: NotificationCampaignStatus.COMPLETED,
        completedAt: new Date(),
      },
    });
    return { queued, recipients: recipients.length };
  }

  async analytics() {
    const [deliveries, campaigns, unread, events] = await Promise.all([
      this.prisma.notificationDelivery.groupBy({
        by: ['channel', 'status'],
        _count: { _all: true },
      }),
      this.prisma.notificationCampaign.groupBy({
        by: ['status'],
        _count: { _all: true },
      }),
      this.prisma.notification.count({ where: { isRead: false } }),
      this.prisma.notificationEvent.groupBy({
        by: ['event'],
        _count: { _all: true },
      }),
    ]);
    return {
      unread_in_app: unread,
      deliveries: deliveries.map((row) => ({
        channel: row.channel.toLowerCase(),
        status: row.status.toLowerCase(),
        count: row._count._all,
      })),
      campaigns: campaigns.map((row) => ({
        status: row.status.toLowerCase(),
        count: row._count._all,
      })),
      events: events.map((row) => ({ event: row.event, count: row._count._all })),
    };
  }

  async trackDelivery(id: string, dto: TrackNotificationEventDto) {
    const now = new Date();
    await this.prisma.$transaction([
      this.prisma.notificationEvent.create({
        data: {
          deliveryId: id,
          event: dto.event,
          metadata: dto.metadata as Prisma.InputJsonValue,
        },
      }),
      this.prisma.notificationDelivery.update({
        where: { id },
        data: {
          ...(dto.event === 'opened' && { openedAt: now }),
          ...(dto.event === 'clicked' && { clickedAt: now }),
          ...(dto.event === 'failed' && {
            status: NotificationDeliveryStatus.FAILED,
            failedAt: now,
          }),
        },
      }),
    ]);
    return { tracked: true };
  }

  @Cron('0 * * * * *')
  async processScheduled(): Promise<void> {
    const dueCampaigns = await this.prisma.notificationCampaign.findMany({
      where: {
        status: NotificationCampaignStatus.SCHEDULED,
        scheduledAt: { lte: new Date() },
      },
      select: { id: true },
      take: 20,
    });
    for (const campaign of dueCampaigns) {
      await this.runCampaign(campaign.id);
    }
    await this.processDueDeliveries(500);
  }

  // ── Event-driven fan-out ─────────────────────────────────────────────────

  @OnEvent(AppEvent.OrderStatusChanged)
  async onOrderStatus(payload: OrderStatusChangedPayload): Promise<void> {
    if (await this.optedOut(payload.userId, 'inAppOrders')) return;
    await this.safeCreate({
      userId: payload.userId,
      type: NotificationType.order,
      title: `Order ${payload.orderNumber}`,
      body: this.orderBody(payload.status),
      data: { orderId: payload.orderId, status: payload.status },
    });
  }

  @OnEvent(AppEvent.PostPublished)
  async onPostPublished(payload: PostPublishedPayload): Promise<void> {
    const name = await this.repo.userName(payload.sellerId);
    await this.fanout(
      payload.sellerId,
      'inAppPosts',
      NotificationType.post,
      'New post',
      `${name} shared a new post`,
      { postId: payload.postId },
    );
  }

  @OnEvent(AppEvent.StoryPublished)
  async onStoryPublished(payload: StoryPublishedPayload): Promise<void> {
    const name = await this.repo.userName(payload.sellerId);
    await this.fanout(
      payload.sellerId,
      'inAppStories',
      NotificationType.story,
      'New story',
      `${name} added a new story`,
      { storyId: payload.storyId },
    );
  }

  @OnEvent(AppEvent.CouponIssued)
  async onCouponIssued(payload: CouponIssuedPayload): Promise<void> {
    if (await this.optedOut(payload.userId, 'inAppCoupons')) return;
    await this.safeCreate({
      userId: payload.userId,
      type: NotificationType.coupon,
      title: 'New coupon 🎁',
      body: `${payload.title} — use code ${payload.couponCode}`,
      data: { code: payload.couponCode },
    });
  }

  // ── internals ────────────────────────────────────────────────────────────

  private async fanout(
    sellerId: string,
    key: PrefKey,
    type: NotificationType,
    title: string,
    body: string,
    data: Prisma.InputJsonValue,
  ): Promise<void> {
    const followers = await this.repo.followerIds(sellerId);
    if (followers.length === 0) return;
    const optedOut = await this.repo.optedOut(followers, key);
    const recipients = followers.filter((id) => !optedOut.has(id));
    // Heavy write — in production this is the natural queue (BullMQ) boundary.
    await this.repo.createMany(
      recipients.map((userId) => ({ userId, type, title, body, data })),
    );
  }

  private async recipientsFor(segment: NotificationSegmentDto | Record<string, unknown>) {
    const roles = Array.isArray(segment.roles)
      ? segment.roles.map((role) => role.toString().toUpperCase() as UserRole)
      : undefined;
    const minPoints =
      typeof segment.min_points === 'number' ? segment.min_points : undefined;
    const verifiedSellers =
      typeof segment.verified_sellers === 'boolean'
        ? segment.verified_sellers
        : undefined;
    const inactiveDays =
      typeof segment.inactive_days === 'number'
        ? segment.inactive_days
        : undefined;

    const users = await this.prisma.user.findMany({
      where: {
        ...(roles?.length && { role: { in: roles } }),
        ...(minPoints !== undefined && { points: { gte: minPoints } }),
        ...(verifiedSellers !== undefined && {
          role: UserRole.SELLER,
          isVerified: verifiedSellers,
        }),
        ...(inactiveDays !== undefined && {
          OR: [
            { lastLoginAt: null },
            {
              lastLoginAt: {
                lt: new Date(Date.now() - inactiveDays * 24 * 60 * 60_000),
              },
            },
          ],
        }),
        disabledAt: null,
      },
      select: { id: true },
      take: 100_000,
    });
    return users.map((user) => user.id);
  }

  private async enqueueForRecipients(input: {
    campaignId?: string;
    recipients: string[];
    channels: NotificationChannel[];
    title: string;
    body: string;
    type: NotificationType;
    payload?: unknown;
    scheduledAt?: Date;
  }) {
    if (input.recipients.length === 0) return 0;
    const prefs = await this.prisma.notificationPreference.findMany({
      where: { userId: { in: input.recipients } },
    });
    const prefByUser = new Map(prefs.map((pref) => [pref.userId, pref]));

    const deliveries: Prisma.NotificationDeliveryCreateManyInput[] = [];
    for (const userId of input.recipients) {
      const pref = prefByUser.get(userId);
      for (const channel of input.channels) {
        if (!this.channelAllowed(channel, input.type, pref)) continue;
        deliveries.push({
          campaignId: input.campaignId,
          userId,
          channel,
          title: input.title,
          body: input.body,
          payload: {
            ...(typeof input.payload === 'object' && input.payload !== null
              ? (input.payload as Record<string, unknown>)
              : {}),
            type: input.type,
          } as Prisma.InputJsonValue,
          scheduledAt: input.scheduledAt ?? new Date(),
        });
      }
    }

    if (deliveries.length === 0) return 0;
    const result = await this.prisma.notificationDelivery.createMany({
      data: deliveries,
    });
    return result.count;
  }

  private async processDueDeliveries(limit: number) {
    const deliveries = await this.prisma.notificationDelivery.findMany({
      where: {
        status: NotificationDeliveryStatus.QUEUED,
        OR: [{ scheduledAt: null }, { scheduledAt: { lte: new Date() } }],
      },
      take: limit,
      orderBy: { createdAt: 'asc' },
    });

    for (const delivery of deliveries) {
      try {
        let notificationId: string | undefined;
        if (delivery.channel === NotificationChannel.IN_APP) {
          const notification = await this.repo.create({
            userId: delivery.userId,
            type: (delivery.payload as { type?: NotificationType } | null)?.type ??
              NotificationType.system,
            title: delivery.title,
            body: delivery.body,
            data: delivery.payload as Prisma.InputJsonValue,
          });
          notificationId = notification.id;
        }

        await this.prisma.notificationDelivery.update({
          where: { id: delivery.id },
          data: {
            status: NotificationDeliveryStatus.SENT,
            sentAt: new Date(),
            notificationId,
            provider: delivery.channel.toLowerCase(),
            providerMessageId: `${delivery.channel.toLowerCase()}-${delivery.id}`,
          },
        });
      } catch (error) {
        await this.prisma.notificationDelivery.update({
          where: { id: delivery.id },
          data: {
            status: NotificationDeliveryStatus.FAILED,
            failedAt: new Date(),
            failureReason:
              error instanceof Error ? error.message : 'Unknown delivery error',
          },
        });
      }
    }
  }

  private channelAllowed(
    channel: NotificationChannel,
    type: NotificationType,
    pref?: NotificationPreference,
  ) {
    if (!pref) return channel === NotificationChannel.IN_APP;
    if (channel === NotificationChannel.PUSH) return pref.push;
    if (channel === NotificationChannel.EMAIL) return pref.email;
    if (channel === NotificationChannel.SMS) return pref.sms;
    if (type === NotificationType.post) return pref.inAppPosts;
    if (type === NotificationType.story) return pref.inAppStories;
    if (type === NotificationType.order) return pref.inAppOrders;
    if (type === NotificationType.coupon || type === NotificationType.promo) {
      return pref.inAppCoupons;
    }
    return true;
  }

  private serializeCampaign(
    campaign: {
      id: string;
      name: string;
      description: string | null;
      status: NotificationCampaignStatus;
      channels: NotificationChannel[];
      segment: Prisma.JsonValue;
      title: string;
      body: string;
      scheduledAt: Date | null;
      createdAt: Date;
    },
    deliveriesCount: number,
  ) {
    return {
      id: campaign.id,
      name: campaign.name,
      description: campaign.description,
      status: campaign.status.toLowerCase(),
      channels: campaign.channels.map((channel) => channel.toLowerCase()),
      segment: campaign.segment,
      title: campaign.title,
      body: campaign.body,
      scheduled_at: campaign.scheduledAt?.toISOString() ?? null,
      created_at: campaign.createdAt.toISOString(),
      deliveries_count: deliveriesCount,
    };
  }

  private async safeCreate(
    data: Prisma.NotificationUncheckedCreateInput,
  ): Promise<void> {
    try {
      await this.repo.create(data);
    } catch (error) {
      this.logger.error('Failed to create notification', error as Error);
    }
  }

  private async optedOut(userId: string, key: PrefKey): Promise<boolean> {
    const pref = await this.repo.getPreference(userId);
    return pref ? pref[key] === false : false;
  }

  private orderBody(status: string): string {
    switch (status) {
      case 'pending_payment':
        return 'Your order is awaiting payment.';
      case 'paid':
        return 'Payment received — thank you!';
      case 'processing':
        return 'We are preparing your order.';
      case 'shipped':
        return 'Your order is on its way! 🚚';
      case 'delivered':
        return 'Your order has been delivered. Enjoy! 💕';
      case 'cancelled':
        return 'Your order was cancelled.';
      case 'refunded':
        return 'Your refund has been issued.';
      default:
        return 'Your order status was updated.';
    }
  }

  private serializePrefs(pref: NotificationPreference | null) {
    return {
      in_app_posts: pref?.inAppPosts ?? true,
      in_app_stories: pref?.inAppStories ?? true,
      in_app_orders: pref?.inAppOrders ?? true,
      in_app_coupons: pref?.inAppCoupons ?? true,
      push: pref?.push ?? false,
      email: pref?.email ?? false,
      sms: pref?.sms ?? false,
    };
  }
}
