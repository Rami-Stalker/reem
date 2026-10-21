import { Injectable, Logger, NotFoundException } from '@nestjs/common';
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
import {
  PushDevice,
  PushOutcome,
  PushTransport,
} from './transports/push.transport';
import {
  channelFor,
  collapseKeyFor,
  deepLinkFor,
  ttlFor,
  urgencyFor,
} from './notification-routing';
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
import { ScheduledJob } from '../../common/scheduling/scheduled-job.decorator';
import { ConfigService } from '@nestjs/config';


@Injectable()
export class NotificationsService {
  private readonly logger = new Logger(NotificationsService.name);

  /** How many times a transient push failure is retried before giving up. */
  private readonly maxAttempts: number;

  constructor(
    private readonly push: PushTransport,
    private readonly repo: NotificationsRepository,
    private readonly prisma: PrismaService,
    private readonly contactPolicy: ContactPolicyService,
    config?: ConfigService,
  ) {
    this.maxAttempts = config?.get<number>('push.maxAttempts') ?? 5;
  }

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

  /**
   * A handset says where it can be reached.
   *
   * Called by the client every time it starts and every time the provider
   * rotates the token, so this has to be idempotent and cheap. Three things
   * happen here that are easy to leave out and expensive to leave out:
   *
   *  - **The handset's previous token is retired.** A push token is not
   *    stable: it is reissued after a reinstall, a restore from backup, or a
   *    long idle spell, and the old one keeps answering for a while. Without
   *    this, a woman who reinstalls twice has three live rows and receives
   *    every notification three times.
   *  - **Her push preference is created switched on.** The client only gets
   *    this far after the operating system has asked her and she has said yes.
   *    That is a clearer answer than the column's default of `false` — without
   *    this, every push she agreed to would be filtered out one layer later,
   *    which is exactly the kind of bug that looks like a broken provider. An
   *    *existing* preference is left alone; see below.
   *  - **A previously disabled token row is revived.** The handset may have
   *    been signed out of, or had one push refused against it.
   */
  async registerPushToken(userId: string, dto: RegisterPushTokenDto) {
    const tokenHash = createHash('sha256').update(dto.token).digest('hex');

    await this.prisma.$transaction(async (tx) => {
      if (dto.device_id) {
        // Same phone, different address. Retire whatever it used to be,
        // whoever it used to belong to — a shared handset that has been signed
        // out of must stop receiving the previous account's notifications.
        await tx.pushToken.updateMany({
          where: { deviceId: dto.device_id, tokenHash: { not: tokenHash } },
          data: {
            enabled: false,
            disabledAt: new Date(),
            lastFailureReason: 'Replaced by a newer token on the same device',
          },
        });
      }

      await tx.pushToken.upsert({
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
          deviceId: dto.device_id,
          appVersion: dto.app_version,
          locale: dto.locale,
        },
        update: {
          userId,
          token: dto.token,
          provider: dto.provider,
          platform: dto.platform,
          deviceId: dto.device_id,
          appVersion: dto.app_version,
          locale: dto.locale,
          enabled: true,
          disabledAt: null,
          failureCount: 0,
          lastFailureReason: null,
          lastSeenAt: new Date(),
        },
      });

      await tx.notificationPreference.upsert({
        where: { userId },
        create: { userId, push: true },
        // Deliberately empty. Creating the row with `push: true` is right —
        // the client only reaches this endpoint after the operating system
        // has asked her and she has said yes, which is a clearer answer than
        // the column's default of `false`. *Updating* it to true would not be:
        // a woman who turned push off in the settings screen would have it
        // silently turned back on the next time the app started and
        // re-registered its token, which is the kind of thing an app gets
        // uninstalled for.
        update: {},
      });
    });

    return { message: 'Push token registered' };
  }

  /**
   * A handset says to stop.
   *
   * Signing out, or revoking the permission in the system settings. The row is
   * disabled rather than deleted so a support question about why a woman
   * stopped receiving notifications has an answer.
   *
   * Her `push` preference is deliberately *not* turned off here: signing out
   * on one phone must not mute the other one she is still signed in on. The
   * preference is a decision about her account; the token is a fact about a
   * device.
   */
  async unregisterPushToken(userId: string, token: string) {
    const tokenHash = createHash('sha256').update(token).digest('hex');
    const result = await this.prisma.pushToken.updateMany({
      // Scoped to the caller: a token is an address, and an unauthenticated
      // guess at one must not be able to silence somebody else's phone.
      where: { tokenHash, userId },
      data: {
        enabled: false,
        disabledAt: new Date(),
        lastFailureReason: 'Unregistered by the device',
      },
    });
    return { message: 'Push token unregistered', updated: result.count };
  }

  /**
   * Pushes a notification row somebody else already wrote.
   *
   * The seam for the modules that keep their own notification-writing logic
   * because the *shape* of what they write is domain knowledge — `RoomNotifier`
   * being the one that exists: it coalesces a room's activity into a single
   * line that it rewrites in place, and that rule belongs with rooms rather
   * than here.
   *
   * What those callers were missing is only the second half. They wrote a row
   * and nothing rang, so an invitation into a shopping room — the one
   * notification whose entire purpose is to pull somebody who is not in the
   * app into it — reached nobody who was not already looking.
   *
   * Callers are expected to invoke this for a row they have *created* and not
   * for one they coalesced into an existing line, which is what keeps a room's
   * fourth vote in an hour from being a fourth buzz.
   */
  async pushExisting(
    notification: {
      id: string;
      userId: string;
      type: NotificationType;
      title: string;
      body: string;
      data?: unknown;
    },
    category: NotificationCategory = NotificationCategory.TRANSACTIONAL,
  ): Promise<void> {
    try {
      await this.pushFor({
        userId: notification.userId,
        type: notification.type,
        title: notification.title,
        body: notification.body,
        data: notification.data,
        notificationId: notification.id,
        category,
      });
    } catch (error) {
      this.logger.warn(
        `Failed to push notification ${notification.id}: ${(error as Error).message}`,
      );
    }
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
      // The caller's answer, not the default.
      //
      // This was dropped on the floor, and the consequence was specific and
      // bad: chat messages come through here marked TRANSACTIONAL, the
      // category fell back to MARKETING, and the frequency cap allows one
      // marketing message a day. So a woman received a push for the first
      // message anyone sent her each day and silence for the rest — while the
      // delivery table recorded the others as correctly suppressed.
      category: dto.category,
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

  @ScheduledJob({ cron: '0 * * * * *', staleAfterMinutes: 10 })
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

    const title = 'محتوى بانتظار المراجعة';
    const body = `${name} أرسلت ${payload.contentType} للمراجعة`;
    const data = { contentId: payload.contentId, authorId: payload.authorId };

    for (const moderator of moderators) {
      // `push: false` here, and queued in bulk below instead. Twenty
      // moderators sent one at a time is twenty sequential round-trips to the
      // push provider inside one event handler — several seconds of a worker
      // spent on a queue that can carry them together.
      await this.safeCreate(
        { userId: moderator.id, type: NotificationType.system, title, body, data },
        { push: false },
      );
    }

    await this.queuePushes({
      recipients: moderators.map((moderator) => moderator.id),
      type: NotificationType.system,
      title,
      body,
      data,
      // A moderation queue filling up is work waiting for somebody, not a
      // promotion: it is not held for quiet hours and not capped.
      category: NotificationCategory.TRANSACTIONAL,
    });
    await this.processDueDeliveries(50);
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

  /**
   * Tells a shop's followers something, in the app and on their phones.
   *
   * The push half is queued in bulk and left for the delivery worker rather
   * than sent inline, which is the one deliberate difference from
   * [safeCreate]. A boutique with four hundred followers publishing a post is
   * four hundred provider round-trips; doing them inside the request that
   * created the post would make publishing feel broken. Up to a minute late is
   * the right latency for "a shop you follow has something new" — and exactly
   * the wrong one for "your order is out for delivery", which is why the two
   * paths differ.
   */
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
    if (recipients.length === 0) return;

    // Heavy write — in production this is the natural queue (BullMQ) boundary.
    await this.repo.createMany(
      recipients.map((userId) => ({ userId, type, title, body, data })),
    );

    await this.queuePushes({
      recipients,
      type,
      title,
      body,
      data,
      // A shop she follows has posted. She asked for this by following, but it
      // is still the platform choosing the moment rather than something
      // happening to her — so it is held for quiet hours and counted.
      category: NotificationCategory.MARKETING,
    });
  }

  /**
   * Queues push rows for many recipients at once, for the worker to send.
   *
   * Narrowed to the women who can actually receive one before anything is
   * written: push turned on, at least one live handset, and the contact policy
   * satisfied. Writing a row for everyone and filtering at send time is the
   * version that fills the queue with permanent skips — at a few hundred a day
   * they become the queue, and the sends that matter wait behind them.
   */
  private async queuePushes(input: {
    recipients: string[];
    type: NotificationType;
    title: string;
    body: string;
    data: Prisma.InputJsonValue;
    category: NotificationCategory;
  }): Promise<number> {
    if (!this.push.isConfigured() || input.recipients.length === 0) return 0;

    const reachable = await this.prisma.pushToken.groupBy({
      by: ['userId'],
      where: {
        userId: { in: input.recipients },
        enabled: true,
        token: { not: '' },
      },
    });
    if (reachable.length === 0) return 0;

    const candidates = reachable.map((row) => row.userId);
    const muted = await this.prisma.notificationPreference.findMany({
      where: { userId: { in: candidates }, push: false },
      select: { userId: true },
    });
    const mutedIds = new Set(muted.map((row) => row.userId));

    const allowed: string[] = [];
    for (const userId of candidates) {
      if (mutedIds.has(userId)) continue;
      const decision = await this.contactPolicy.mayContact(userId, {
        category: input.category,
      });
      if (decision.allowed) allowed.push(userId);
    }
    if (allowed.length === 0) return 0;

    const payload = {
      ...(typeof input.data === 'object' && input.data !== null
        ? (input.data as Record<string, unknown>)
        : {}),
      type: input.type,
    } as Prisma.InputJsonValue;

    const result = await this.prisma.notificationDelivery.createMany({
      data: allowed.map((userId) => ({
        userId,
        channel: NotificationChannel.PUSH,
        category: input.category,
        title: input.title,
        body: input.body,
        payload,
        scheduledAt: new Date(),
      })),
    });
    return result.count;
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

  /**
   * Hands queued deliveries to their channel.
   *
   * Runs on the minute from the scheduler, and directly after anything that
   * enqueues something she is waiting for. Both matter: the cron is what
   * catches a scheduled campaign and a retry, and the direct call is why a
   * message arrives on her phone in a second rather than in a minute.
   */
  private async processDueDeliveries(limit: number, ids?: string[]) {
    const now = new Date();
    const deliveries = await this.prisma.notificationDelivery.findMany({
      where: {
        ...(ids?.length ? { id: { in: ids } } : {}),
        status: NotificationDeliveryStatus.QUEUED,
        OR: [{ scheduledAt: null }, { scheduledAt: { lte: now } }],
        // A row that failed transiently is not due again until its backoff
        // has elapsed. Without this the worker spends every pass replaying
        // the same refusal and starves the deliveries behind it.
        AND: [{ OR: [{ nextAttemptAt: null }, { nextAttemptAt: { lte: now } }] }],
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
          await this.attemptPush(delivery);
          continue;
        }

        await this.prisma.notificationDelivery.update({
          where: { id: delivery.id },
          data: {
            status: NotificationDeliveryStatus.SENT,
            sentAt: new Date(),
            attempts: { increment: 1 },
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
            attempts: { increment: 1 },
            failureReason:
              error instanceof Error ? error.message : 'Unknown delivery error',
          },
        });
      }
    }
  }

  /**
   * One push attempt, and what the row says afterwards.
   *
   * Three endings rather than two, and the distinction is the whole point of
   * having a retry at all:
   *
   *  - **SENT.** At least one of her handsets took it.
   *  - **SKIPPED.** There was nowhere to send it — no provider contracted, no
   *    registered device, every token dead. Nothing went wrong, so a retry
   *    would chase it for ever.
   *  - **QUEUED again, later.** The provider was rate-limiting or broken.
   *    This is the case that used to be lost outright: a ninety-second FCM
   *    outage permanently dropped every order-shipped message sent during it.
   */
  private async attemptPush(delivery: {
    id: string;
    userId: string;
    title: string;
    body: string;
    payload: Prisma.JsonValue;
    category: NotificationCategory;
    attempts: number;
  }) {
    const outcome = await this.pushOut(delivery);
    const attempts = delivery.attempts + 1;

    if (outcome.delivered) {
      await this.prisma.notificationDelivery.update({
        where: { id: delivery.id },
        data: {
          status: NotificationDeliveryStatus.SENT,
          sentAt: new Date(),
          attempts,
          nextAttemptAt: null,
          provider: this.push.providerName(),
          providerMessageId: outcome.providerMessageId,
          // Kept even on success: "three of her four phones failed" is worth
          // seeing before it becomes four of four.
          failureReason: outcome.reason,
        },
      });
      return;
    }

    if (outcome.retryable && attempts < this.maxAttempts) {
      // Exponential, from half a minute: 30s, 1m, 2m, 4m. Long enough to sit
      // out an ordinary blip, short enough that a chat message still arrives
      // while it is about something.
      const delayMs = 30_000 * 2 ** (attempts - 1);
      await this.prisma.notificationDelivery.update({
        where: { id: delivery.id },
        data: {
          status: NotificationDeliveryStatus.QUEUED,
          attempts,
          nextAttemptAt: new Date(Date.now() + delayMs),
          failureReason: outcome.reason,
        },
      });
      return;
    }

    await this.prisma.notificationDelivery.update({
      where: { id: delivery.id },
      data: {
        // Skipped when there was nowhere to send it; failed when we ran out of
        // attempts. Both are terminal, and the analytics panel reads them
        // differently — one is a customer without a phone registered, the
        // other is a provider problem worth somebody's attention.
        status: outcome.retryable
          ? NotificationDeliveryStatus.FAILED
          : NotificationDeliveryStatus.SKIPPED,
        failedAt: new Date(),
        attempts,
        nextAttemptAt: null,
        failureReason: outcome.reason,
      },
    });
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

  /**
   * Tells one woman one thing — in the app, and on her phone.
   *
   * This is the method every domain event goes through, and it is where the
   * feature was missing. The whole event fan-out — an order shipped, somebody
   * wrote to her, a post of hers was taken down, a new follower — used to
   * write a `Notification` row and stop. That row is only visible to a woman
   * who has already opened the app, which means the notifications with the
   * most reason to exist were precisely the ones that never reached anybody:
   * the entire point of "your order is out for delivery" is that she is not
   * looking at her phone when it happens.
   *
   * The in-app row is still written first and directly rather than through the
   * delivery queue, because the inbox is expected to be instantaneous and a
   * push that fails must not take the record with it. The push is queued
   * behind it and sent immediately.
   */
  /**
   * Tells one account one thing that happened to it.
   *
   * The public door onto `safeCreate`, for the modules that have something
   * transactional to say and no event worth declaring — a verification
   * decision, a claim returned for more information. Marked TRANSACTIONAL
   * because it is a consequence of something she did, so it is not held for
   * quiet hours and not counted against a marketing cap.
   */
  async notifyAccount(input: {
    userId: string;
    type?: NotificationType;
    title: string;
    body: string;
    data?: Prisma.InputJsonValue;
  }): Promise<void> {
    await this.safeCreate(
      {
        userId: input.userId,
        type: input.type ?? NotificationType.system,
        title: input.title,
        body: input.body,
        data: input.data,
      },
      { category: NotificationCategory.TRANSACTIONAL },
    );
  }

  private async safeCreate(
    data: Prisma.NotificationUncheckedCreateInput,
    options: { category?: NotificationCategory; push?: boolean } = {},
  ): Promise<void> {
    let notificationId: string | undefined;
    try {
      const created = await this.repo.create(data);
      notificationId = created.id;
    } catch (error) {
      this.logger.error('Failed to create notification', error as Error);
      return;
    }

    if (options.push === false) return;

    try {
      await this.pushFor({
        userId: data.userId,
        type: data.type ?? NotificationType.system,
        title: data.title,
        body: data.body,
        data: data.data,
        notificationId,
        // Event-driven notifications are things that happened to her, not
        // things the platform wants — so they are not held for quiet hours
        // and not counted against a marketing cap. A campaign passes
        // MARKETING explicitly and is.
        category: options.category ?? NotificationCategory.TRANSACTIONAL,
      });
    } catch (error) {
      // A push that could not be queued must never cost her the in-app row,
      // and must never fail the order, comment or takedown that caused it.
      this.logger.warn(
        `Failed to queue push notification: ${(error as Error).message}`,
      );
    }
  }

  /**
   * Queues the push half, and sends it now.
   *
   * Everything is checked before a row is written rather than after: her
   * channel preference, whether she has a handset registered at all, and the
   * contact policy. A delivery row for a woman with no phone is a SKIPPED row
   * the worker has to walk past on every pass for ever, and at a few hundred a
   * day that is the whole queue.
   */
  private async pushFor(input: {
    userId: string;
    type: NotificationType;
    title: string;
    body: string;
    data?: unknown;
    notificationId?: string;
    category: NotificationCategory;
  }): Promise<void> {
    if (!this.push.isConfigured()) return;

    const [pref, devices] = await Promise.all([
      this.repo.getPreference(input.userId),
      this.prisma.pushToken.count({
        where: { userId: input.userId, enabled: true, token: { not: '' } },
      }),
    ]);
    if (devices === 0) return;
    if (pref && !pref.push) return;

    const decision = await this.contactPolicy.mayContact(input.userId, {
      category: input.category,
    });
    if (!decision.allowed) return;

    const delivery = await this.prisma.notificationDelivery.create({
      data: {
        userId: input.userId,
        notificationId: input.notificationId,
        channel: NotificationChannel.PUSH,
        category: input.category,
        title: input.title,
        body: input.body,
        payload: {
          ...(typeof input.data === 'object' && input.data !== null
            ? (input.data as Record<string, unknown>)
            : {}),
          type: input.type,
          ...(input.notificationId
            ? { notificationId: input.notificationId }
            : {}),
        } as Prisma.InputJsonValue,
        scheduledAt: new Date(),
      },
      select: { id: true },
    });

    // Now, not on the next minute boundary. The cron is the safety net for
    // scheduled sends and retries; a woman waiting on a reply should not.
    await this.processDueDeliveries(1, [delivery.id]);
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
   *
   * Everything that makes the notification *land* rather than merely be sent
   * is assembled here: the channel it belongs in, the route it opens, what it
   * replaces on the lock screen, the badge, and how long it is worth. All of
   * it derives from the type and payload already on the delivery row, so a
   * caller cannot forget to pass it.
   */
  private async pushOut(delivery: {
    userId: string;
    title: string;
    body: string;
    payload: Prisma.JsonValue;
    category: NotificationCategory;
  }): Promise<PushOutcome> {
    if (!this.push.isConfigured()) {
      return {
        delivered: false,
        reason: 'No push provider configured',
        devices: [],
      };
    }

    const rows = await this.prisma.pushToken.findMany({
      where: { userId: delivery.userId, enabled: true, token: { not: '' } },
      select: { id: true, token: true, platform: true },
    });
    if (rows.length === 0) {
      return { delivered: false, reason: 'No registered device', devices: [] };
    }

    const payload = (delivery.payload ?? {}) as Record<string, unknown>;
    const type =
      (payload.type as NotificationType | undefined) ?? NotificationType.system;

    // The count she will see on the icon. Read now rather than written into
    // the payload at enqueue time, because between queuing and sending she may
    // have read everything — and a badge that says 3 over an empty inbox is
    // the kind of small wrongness that makes people stop trusting the number.
    const badge = await this.repo.count(delivery.userId, { isRead: false });

    const devices: PushDevice[] = rows.map((row) => ({
      id: row.id,
      token: row.token,
      platform: row.platform,
    }));

    const outcome = await this.push.send({
      devices,
      title: delivery.title,
      body: delivery.body,
      deepLink: deepLinkFor(type, payload),
      channelId: channelFor(type),
      collapseKey: collapseKeyFor(type, payload),
      ttlSeconds: ttlFor(type),
      urgent: urgencyFor(delivery.category),
      badge,
      data: this.pushData(type, payload),
    });

    await this.reconcileTokens(outcome);
    return outcome;
  }

  /**
   * The routing information the client gets, over and above the sentence.
   *
   * Kept small on purpose. This travels unencrypted through Google's
   * infrastructure and sits in the notification centre of a phone that may be
   * handed to somebody else, so it carries ids and never content: no message
   * text beyond what is already on the visible line, no names, no amounts.
   */
  private pushData(
    type: NotificationType,
    payload: Record<string, unknown>,
  ): Record<string, string> {
    const data: Record<string, string> = { type };
    for (const key of [
      'orderId',
      'order_id',
      'chatId',
      'chat_id',
      'contentId',
      'content_id',
      'roomId',
      'room_id',
      'followerId',
      'follower_id',
      'notificationId',
      'campaign_id',
      'kind',
    ]) {
      const value = payload[key];
      if (typeof value === 'string' && value.length > 0) data[key] = value;
    }
    return data;
  }

  /**
   * Retires the addresses that no longer answer.
   *
   * Without this the table only grows: every uninstall leaves a token behind
   * that is politely refused for ever, so reaching one woman's one phone
   * gradually costs four requests, three of which are guaranteed to fail —
   * and her delivery rows fill with failures that are nobody's problem.
   *
   * A transient refusal is counted rather than acted on. Three in a row with
   * no success in between is a handset that is gone whether or not the
   * provider ever says so; one is Google having a bad minute.
   */
  private async reconcileTokens(outcome: PushOutcome): Promise<void> {
    const dead = outcome.devices.filter((device) => device.invalidToken);
    const flaky = outcome.devices.filter(
      (device) => !device.ok && !device.invalidToken,
    );
    const alive = outcome.devices.filter((device) => device.ok);

    if (dead.length > 0) {
      await this.prisma.pushToken.updateMany({
        where: { id: { in: dead.map((device) => device.deviceId) } },
        data: {
          enabled: false,
          disabledAt: new Date(),
          lastFailureReason: dead[0].reason,
        },
      });
    }

    for (const device of flaky) {
      await this.prisma.pushToken.updateMany({
        where: { id: device.deviceId },
        data: {
          failureCount: { increment: 1 },
          lastFailureReason: device.reason,
        },
      });
    }

    if (flaky.length > 0) {
      await this.prisma.pushToken.updateMany({
        where: {
          id: { in: flaky.map((device) => device.deviceId) },
          failureCount: { gte: 3 },
        },
        data: {
          enabled: false,
          disabledAt: new Date(),
          lastFailureReason: 'Three consecutive delivery failures',
        },
      });
    }

    if (alive.length > 0) {
      await this.prisma.pushToken.updateMany({
        where: { id: { in: alive.map((device) => device.deviceId) } },
        data: {
          failureCount: 0,
          lastFailureReason: null,
          lastSeenAt: new Date(),
        },
      });
    }
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
