import { Injectable, Logger, NotFoundException } from '@nestjs/common';
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
  NotificationCategory,
} from '@prisma/client';
import { createHash } from 'crypto';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import { serializeNotification } from '../../common/serializers';
import { PrismaService } from '../../prisma/prisma.service';
import { ContactPolicyService } from './contact-policy.service';
import { PushOutcome, PushTransport } from './transports/push.transport';
import {
  AppEvent,
  CommerceContentPublishedPayload,
  CommerceContentSubmittedPayload,
  ContentEngagementPayload,
  ContentModeratedPayload,
  CouponIssuedPayload,
  OrderStatusChangedPayload,
  PostPublishedPayload,
  StoryPublishedPayload,
  UserFollowedPayload,
} from '../../common/events/app-events';
import {
  NotificationsRepository,
  PreferencePatch,
  // One definition, in the file that owns the Prisma access. It lived here too
  // until now, and the two copies had drifted: `inAppRooms` shipped as a column
  // and a settings toggle and was missing from both, so muting room activity
  // did nothing at all.
  PreferenceKey as PrefKey,
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


@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  constructor(
    private readonly push: PushTransport,
    private readonly repo: NotificationsRepository,
    private readonly prisma: PrismaService,
    private readonly contactPolicy: ContactPolicyService,
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
      ...(dto.in_app_rooms !== undefined && { inAppRooms: dto.in_app_rooms }),
      ...(dto.in_app_social !== undefined && { inAppSocial: dto.in_app_social }),
      ...(dto.in_app_moderation !== undefined && {
        inAppModeration: dto.in_app_moderation,
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
        // Kept, not just hashed: a push provider's token is the address of a
        // handset, and an address you cannot read is an address you cannot
        // write to.
        token: dto.token,
        provider: dto.provider,
        platform: dto.platform,
      },
      update: {
        userId,
        token: dto.token,
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

  /**
   * Records what happened to one delivery.
   *
   * The delivery is looked up by id *and* owner. Without the owner the route
   * was an open write on anyone's row: a receipt could be posted for a message
   * sent to a different woman, and campaign open- and click-rates are read
   * straight off these rows.
   */
  async trackDelivery(
    userId: string,
    id: string,
    dto: TrackNotificationEventDto,
  ) {
    const delivery = await this.prisma.notificationDelivery.findFirst({
      where: { id, userId },
      select: { id: true },
    });
    if (!delivery) throw new NotFoundException('Notification not found');

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

  /**
   * A seller sent something for review — Q70 P1 puts approving it on the
   * moderators, and until now the event was emitted into silence.
   *
   * Notifies the moderators rather than fanning out to followers: nothing is
   * public yet, and telling a shop's followers about a post awaiting approval
   * would announce content that may never appear.
   */
  @OnEvent(AppEvent.CommerceContentSubmitted)
  async onContentSubmitted(
    payload: CommerceContentSubmittedPayload,
  ): Promise<void> {
    const name = await this.repo.userName(payload.authorId);
    const moderators = await this.prisma.user.findMany({
      where: {
        role: {
          in: [
            UserRole.CONTENT_MODERATOR,
            UserRole.OPERATIONS_ADMIN,
            UserRole.SUPER_ADMIN,
          ],
        },
      },
      select: { id: true },
      take: 20,
    });

    for (const moderator of moderators) {
      await this.safeCreate({
        userId: moderator.id,
        type: NotificationType.system,
        title: 'محتوى بانتظار المراجعة',
        body: `${name} أرسلت ${payload.contentType} للمراجعة`,
        data: { contentId: payload.contentId, authorId: payload.authorId },
      });
    }
  }

  /** And her followers hear about it once it is actually live. */
  @OnEvent(AppEvent.CommerceContentPublished)
  async onContentPublished(
    payload: CommerceContentPublishedPayload,
  ): Promise<void> {
    const name = await this.repo.userName(payload.authorId);
    await this.fanout(
      payload.authorId,
      'inAppPosts',
      NotificationType.post,
      'جديد في متجرها',
      `${name} نشرت ${payload.contentType}`,
      { contentId: payload.contentId },
    );
  }

  // ── The social feed ──────────────────────────────────────────────────────
  //
  // `NotificationType.like`, `.comment` and `.follow` have existed in the enum
  // since the beginning and were emitted by nothing. These are the emitters.

  @OnEvent(AppEvent.ContentLiked)
  async onContentLiked(payload: ContentEngagementPayload): Promise<void> {
    if (payload.actorId === payload.authorId) return;
    if (await this.optedOut(payload.authorId, 'inAppSocial')) return;
    const name = await this.repo.userName(payload.actorId);
    await this.safeCreate({
      userId: payload.authorId,
      type: NotificationType.like,
      title: 'إعجاب جديد',
      body: `${name} أعجبها منشوركِ`,
      data: { contentId: payload.contentId, actorId: payload.actorId },
    });
  }

  @OnEvent(AppEvent.ContentCommented)
  async onContentCommented(payload: ContentEngagementPayload): Promise<void> {
    if (payload.actorId === payload.authorId) return;
    if (await this.optedOut(payload.authorId, 'inAppSocial')) return;
    const name = await this.repo.userName(payload.actorId);
    await this.safeCreate({
      userId: payload.authorId,
      type: NotificationType.comment,
      title: 'تعليق جديد',
      body: `${name} علّقت على منشوركِ`,
      data: {
        contentId: payload.contentId,
        commentId: payload.commentId ?? null,
        actorId: payload.actorId,
      },
    });
  }

  /**
   * Somebody added her post to their own page.
   *
   * This is the notification the whole reshare feature is *for* on the
   * boutique's side: it is how she finds out a customer is carrying her
   * products around, before she goes looking at a dashboard.
   */
  @OnEvent(AppEvent.ContentReshared)
  async onContentReshared(payload: ContentEngagementPayload): Promise<void> {
    if (payload.actorId === payload.authorId) return;
    if (await this.optedOut(payload.authorId, 'inAppSocial')) return;
    const name = await this.repo.userName(payload.actorId);
    await this.safeCreate({
      userId: payload.authorId,
      type: NotificationType.post,
      title: 'أضافت منشوركِ إلى صفحتها',
      body: `${name} شاركت منشوركِ مع متابِعاتها`,
      data: {
        contentId: payload.contentId,
        reshareId: payload.reshareId ?? null,
        actorId: payload.actorId,
      },
    });
  }

  @OnEvent(AppEvent.UserFollowed)
  async onUserFollowed(payload: UserFollowedPayload): Promise<void> {
    if (payload.followerId === payload.userId) return;
    if (await this.optedOut(payload.userId, 'inAppSocial')) return;
    const name = await this.repo.userName(payload.followerId);
    await this.safeCreate({
      userId: payload.userId,
      type: NotificationType.follow,
      title: 'متابِعة جديدة',
      body: `${name} تتابعكِ الآن`,
      data: { followerId: payload.followerId },
    });
  }

  /**
   * Her content was taken down, and she is told why.
   *
   * The requirement is explicit that removal is never silent and that the
   * reason reaches the woman who published it, worded respectfully. Two things
   * follow from that and are easy to get wrong:
   *
   *   - **The reason is in the body, verbatim.** Not a code she cannot read,
   *     and not a generic "violated our policies" that leaves her guessing
   *     which of her three posts is meant.
   *   - **This is not opt-out-able.** `inAppModeration` exists as a preference
   *     and is deliberately not consulted here: a woman who muted social
   *     notifications has muted likes, not the news that her page has changed.
   */
  @OnEvent(AppEvent.ContentRemoved)
  async onContentRemoved(payload: ContentModeratedPayload): Promise<void> {
    await this.safeCreate({
      userId: payload.authorId,
      // Deliberately `system` rather than a new enum value: the shipped client
      // falls back to a plain notice for a type it does not know, so a new one
      // would render unstyled on every handset already out there. It becomes
      // its own type when the client ships support for it.
      type: NotificationType.system,
      title: 'أزلنا أحد منشوراتكِ',
      body: `راجعنا منشوركِ وأزلناه للسبب التالي: ${payload.reason}. إن كنتِ ترين أن هذا خطأ، تواصلي معنا وسنراجعه من جديد.`,
      data: {
        contentId: payload.contentId,
        contentType: payload.contentType,
        reason: payload.reason,
        moderationActionId: payload.moderationActionId,
        kind: 'content_removed',
      },
    });
  }

  @OnEvent(AppEvent.ContentReinstated)
  async onContentReinstated(payload: ContentModeratedPayload): Promise<void> {
    await this.safeCreate({
      userId: payload.authorId,
      type: NotificationType.system,
      title: 'أعدنا منشوركِ',
      body: 'راجعنا القرار وأعدنا نشر منشوركِ. نعتذر عن الإزعاج.',
      data: {
        contentId: payload.contentId,
        contentType: payload.contentType,
        kind: 'content_reinstated',
      },
    });
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
    /**
     * Whether this is something she is waiting for or something the platform
     * wants. Defaults to marketing, deliberately: a caller that has not
     * thought about it is far more likely to be sending a promotion than an
     * order update, and the safe default is the one that gets capped.
     */
    category?: NotificationCategory;
  }) {
    if (input.recipients.length === 0) return 0;
    const category = input.category ?? NotificationCategory.MARKETING;

    const prefs = await this.prisma.notificationPreference.findMany({
      where: { userId: { in: input.recipients } },
    });
    const prefByUser = new Map(prefs.map((pref) => [pref.userId, pref]));

    // The frequency gate, applied here rather than in each campaign.
    //
    // The harm this prevents is cumulative and invisible from any single
    // sender: an abandoned-basket reminder, a win-back, a price drop and a
    // flash-sale announcement are each defensible alone, and four of them on
    // one Tuesday is why she turns notifications off. Only this point can see
    // the total, so this is where it is counted.
    const allowed: string[] = [];
    for (const userId of input.recipients) {
      const decision = await this.contactPolicy.mayContact(userId, {
        category,
        // A scheduled send has already chosen its hour; re-checking the clock
        // here would refuse everything queued the night before.
        ignoreQuietHours: Boolean(input.scheduledAt),
      });
      if (decision.allowed) allowed.push(userId);
    }
    if (allowed.length === 0) return 0;

    const deliveries: Prisma.NotificationDeliveryCreateManyInput[] = [];
    for (const userId of allowed) {
      const pref = prefByUser.get(userId);
      for (const channel of input.channels) {
        if (!this.channelAllowed(channel, input.type, pref)) continue;
        deliveries.push({
          campaignId: input.campaignId,
          userId,
          channel,
          category,
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

        // A push has to actually leave the building before it is called sent.
        // Every channel used to be stamped SENT here, which meant the platform
        // collected device tokens, wrote a delivery row, marked it delivered,
        // and no phone ever rang.
        if (delivery.channel === NotificationChannel.PUSH) {
          const outcome = await this.pushOut(delivery);
          await this.prisma.notificationDelivery.update({
            where: { id: delivery.id },
            data: outcome.delivered
              ? {
                  status: NotificationDeliveryStatus.SENT,
                  sentAt: new Date(),
                  provider: 'push',
                  providerMessageId: outcome.providerMessageId,
                }
              : {
                  // Skipped, not failed: nothing went wrong, there was simply
                  // nowhere to send it. A failure would have a retry chasing
                  // it for ever.
                  status: NotificationDeliveryStatus.SKIPPED,
                  failedAt: new Date(),
                  failureReason: outcome.reason,
                },
          });
          continue;
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

  /**
   * Sends one queued push to every handset the account has registered.
   *
   * Tokens are stored hashed for the *lookup*, so the sendable value lives on
   * the row alongside it; a token that has been disabled — she turned pushes
   * off, or the provider rejected it — is simply not in the list, which is why
   * "no registered device" is a skip rather than an error.
   */
  private async pushOut(delivery: {
    userId: string;
    title: string;
    body: string;
  }): Promise<PushOutcome> {
    if (!this.push.isConfigured()) {
      return { delivered: false, reason: 'No push provider configured' };
    }

    const tokens = await this.prisma.pushToken.findMany({
      where: { userId: delivery.userId, enabled: true },
      select: { token: true },
    });

    return this.push.send({
      tokens: tokens.map((row) => row.token).filter((token) => token.length > 0),
      title: delivery.title,
      body: delivery.body,
    });
  }

  private serializePrefs(pref: NotificationPreference | null) {
    return {
      in_app_posts: pref?.inAppPosts ?? true,
      in_app_stories: pref?.inAppStories ?? true,
      in_app_orders: pref?.inAppOrders ?? true,
      in_app_coupons: pref?.inAppCoupons ?? true,
      in_app_rooms: pref?.inAppRooms ?? true,
      in_app_social: pref?.inAppSocial ?? true,
      in_app_moderation: pref?.inAppModeration ?? true,
      push: pref?.push ?? false,
      email: pref?.email ?? false,
      sms: pref?.sms ?? false,
    };
  }
}
