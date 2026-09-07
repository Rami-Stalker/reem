import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  CommerceContentAnalyticsEventType,
  ContentTagBasis,
  MediaType,
  CommerceContentModerationStatus,
  CommerceContentPublicationChannel,
  CommerceContentStatus,
  CommerceContentTypeDefinition,
  CommerceContentVisibility,
  Prisma,
  UserRole,
} from '@prisma/client';
import { CacheService } from '../../common/cache/cache.service';
import { assertCanManage } from '../../common/authz';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { buildMeta } from '../../common/dto/pagination.dto';
import { AppEvent } from '../../common/events/app-events';
import {
  serializeCommerceContent,
  serializeCommerceContentAnalytics,
  serializeCommerceContentType,
} from '../../common/serializers';
import { CommerceContentRepository } from './commerce-content.repository';
import { ContentTypeRegistryService } from './content-type-registry.service';
import {
  CommerceContentMediaInputDto,
  CommerceContentProductTagInputDto,
  CreateCommerceContentDto,
  CommerceFeedQueryDto,
  ModerateCommerceContentDto,
  RecordCommerceContentEventDto,
  SellerContentQueryDto,
  UpdateCommerceContentDto,
} from './dto/commerce-content.dto';
import { RegisterContentTypeDto } from './dto/content-type.dto';
import { ProductTagPolicyService } from './tagging/product-tag-policy.service';
import {
  maxDurationMs,
  maxMedia,
  mayPublish,
  needsPrePublishReview,
  requiresVideo,
  screenText,
} from './content-policy';

const FEED_CACHE_PREFIX = 'commerce-content:feed';

interface ContentSnapshot {
  content_type: string;
  title: string | null;
  body: string | null;
  locale: string;
  visibility: CommerceContentVisibility;
  payload: Prisma.JsonValue;
  metadata: Prisma.JsonValue | null;
  publication_targets: CommerceContentPublicationChannel[];
  scheduled_at: string | null;
  expires_at: string | null;
  pinned_until: string | null;
  media: CommerceContentMediaInputDto[];
  product_tags: CommerceContentProductTagInputDto[];
}

function isAdmin(user: AuthUser): boolean {
  const roles: UserRole[] = [
    UserRole.SUPER_ADMIN,
    UserRole.OPERATIONS_ADMIN,
    UserRole.CONTENT_MODERATOR,
    UserRole.ADMIN,
  ];
  return roles.includes(user.role);
}

@Injectable()
export class CommerceContentService {
  constructor(
    private readonly repo: CommerceContentRepository,
    private readonly registry: ContentTypeRegistryService,
    private readonly events: EventEmitter2,
    private readonly cache: CacheService,
    private readonly tagPolicy: ProductTagPolicyService,
    private readonly config: ConfigService,
  ) {}

  listTypes(includeInactive = false) {
    return this.registry.list(includeInactive);
  }

  registerType(dto: RegisterContentTypeDto) {
    return this.registry.register(dto);
  }

  async create(user: AuthUser, dto: CreateCommerceContentDto) {
    const definition = await this.registry.requireActive(dto.content_type);

    // Who may publish this format is registry data, not a list in code — so
    // the composer builds itself from the same answer the server enforces.
    if (!mayPublish(definition, user.role)) {
      throw new ForbiddenException('CONTENT_TYPE_NOT_AVAILABLE_TO_YOU');
    }
    this.registry.validatePayload(definition, dto.payload);
    this.assertMediaFits(definition, dto.media ?? []);

    const productTags = await this.productTagCreates(user, dto.product_tags ?? []);
    const scheduledAt = this.futureDate(dto.scheduled_at, 'scheduled_at');
    const expiresAt = this.expirationDate(dto.expires_at, definition);
    const moderationStatus = (await this.reviewRequired(user, definition))
      ? CommerceContentModerationStatus.PENDING
      : CommerceContentModerationStatus.APPROVED;

    const author = await this.repo.authorFacts(user.id);
    if (!author) throw new NotFoundException('Author not found');

    const content = await this.repo.createContent({
      author: { connect: { id: user.id } },
      authorKind: author.kind,
      authorIsPublic: author.isPublic,
      typeDefinition: { connect: { key: definition.key } },
      title: dto.title?.trim() ?? null,
      body: dto.body ?? null,
      locale: dto.locale ?? 'en',
      status: scheduledAt
        ? CommerceContentStatus.SCHEDULED
        : CommerceContentStatus.DRAFT,
      visibility: dto.visibility ?? CommerceContentVisibility.PUBLIC,
      moderationStatus,
      payload: dto.payload as Prisma.InputJsonValue,
      metadata: (dto.metadata as Prisma.InputJsonValue) ?? Prisma.JsonNull,
      publicationTargets:
        dto.publication_targets ?? this.registry.defaultChannels(definition),
      scheduledAt,
      expiresAt,
      pinnedUntil: this.optionalDate(dto.pinned_until),
      media: this.mediaCreate(dto.media),
      productTags: productTags.length ? { create: productTags } : undefined,
    });

    await this.saveVersion(user.id, content.id, 'Initial draft');
    this.invalidateFeeds();
    return this.getMine(user, content.id);
  }

  async update(user: AuthUser, id: string, dto: UpdateCommerceContentDto) {
    const current = await this.ownedOrThrow(user, id);
    const lockedStatuses: CommerceContentStatus[] = [
        CommerceContentStatus.ARCHIVED,
        CommerceContentStatus.EXPIRED,
        CommerceContentStatus.DELETED,
    ];
    if (lockedStatuses.includes(current.status)) {
      throw new BadRequestException('Archived or expired content cannot be edited');
    }

    const full = await this.repo.findById(id);
    if (!full) throw new NotFoundException('Content not found');
    if (dto.payload) {
      this.registry.validatePayload(full.typeDefinition, dto.payload);
    }

    const productTags =
      dto.product_tags === undefined
        ? undefined
        : await this.productTagCreates(user, dto.product_tags);

    const content = await this.repo.updateContent(id, {
      ...(dto.title !== undefined && { title: dto.title?.trim() ?? null }),
      ...(dto.body !== undefined && { body: dto.body ?? null }),
      ...(dto.locale !== undefined && { locale: dto.locale }),
      ...(dto.visibility !== undefined && { visibility: dto.visibility }),
      ...(dto.payload !== undefined && {
        payload: dto.payload as Prisma.InputJsonValue,
      }),
      ...(dto.metadata !== undefined && {
        metadata:
          dto.metadata === null
            ? Prisma.JsonNull
            : (dto.metadata as Prisma.InputJsonValue),
      }),
      ...(dto.publication_targets !== undefined && {
        publicationTargets: { set: dto.publication_targets },
      }),
      ...(dto.scheduled_at !== undefined && {
        scheduledAt: this.futureDate(dto.scheduled_at, 'scheduled_at'),
      }),
      ...(dto.expires_at !== undefined && {
        expiresAt: this.optionalDate(dto.expires_at),
      }),
      ...(dto.pinned_until !== undefined && {
        pinnedUntil: this.optionalDate(dto.pinned_until),
      }),
      ...(dto.media !== undefined && {
        media: { deleteMany: {}, create: this.mediaCreateArray(dto.media) },
      }),
      ...(productTags !== undefined && {
        productTags: { deleteMany: {}, create: productTags },
      }),
    });

    await this.saveVersion(user.id, content.id, dto.change_note ?? 'Updated');
    this.invalidateFeeds();
    return this.getMine(user, content.id);
  }

  async listMine(user: AuthUser, query: SellerContentQueryDto) {
    const [items, total] = await Promise.all([
      this.repo.listSeller({
        authorId: user.id,
        skip: query.skip,
        take: query.limit,
        status: query.status,
        contentType: query.content_type,
        q: query.q,
      }),
      this.repo.countSeller({
        authorId: user.id,
        status: query.status,
        contentType: query.content_type,
        q: query.q,
      }),
    ]);
    return {
      data: items.map(serializeCommerceContent),
      pagination: buildMeta(query.page, query.limit, total, items.length),
    };
  }

  async getMine(user: AuthUser, id: string) {
    await this.ownedOrThrow(user, id);
    const content = await this.repo.findById(id);
    if (!content) throw new NotFoundException('Content not found');
    return serializeCommerceContent(content);
  }

  async publish(user: AuthUser, id: string) {
    const owner = await this.ownedOrThrow(user, id);
    const content = await this.repo.findById(id);
    if (!content) throw new NotFoundException('Content not found');

    if (content.status === CommerceContentStatus.ARCHIVED) {
      throw new BadRequestException('Archived content cannot be published');
    }
    if (content.status === CommerceContentStatus.REJECTED) {
      throw new BadRequestException('Rejected content must be edited before publishing');
    }

    const flagged = screenText(content.title, content.body);
    const moderationRequired =
      flagged.length > 0 ||
      (await this.reviewRequired(user, content.typeDefinition));
    if (
      moderationRequired &&
      owner.moderationStatus !== CommerceContentModerationStatus.APPROVED
    ) {
      const submitted = await this.repo.updateContent(id, {
        status: CommerceContentStatus.IN_REVIEW,
        moderationStatus: CommerceContentModerationStatus.PENDING,
      });
      this.events.emit(AppEvent.CommerceContentSubmitted, {
        authorId: user.id,
        contentId: id,
        contentType: submitted.contentType,
      });
      return serializeCommerceContent(submitted);
    }

    const now = new Date();
    const scheduledForFuture = content.scheduledAt && content.scheduledAt > now;
    const updated = await this.repo.updateContent(id, {
      status: scheduledForFuture
        ? CommerceContentStatus.SCHEDULED
        : CommerceContentStatus.PUBLISHED,
      moderationStatus: CommerceContentModerationStatus.APPROVED,
      publishedAt: scheduledForFuture ? null : now,
    });

    if (!scheduledForFuture) {
      this.events.emit(AppEvent.CommerceContentPublished, {
        authorId: updated.authorId,
        contentId: updated.id,
        contentType: updated.contentType,
        channels: updated.publicationTargets,
      });
    }

    this.invalidateFeeds();
    return serializeCommerceContent(updated);
  }

  async archive(user: AuthUser, id: string) {
    await this.ownedOrThrow(user, id);
    const content = await this.repo.updateContent(id, {
      status: CommerceContentStatus.ARCHIVED,
      archivedAt: new Date(),
    });
    this.invalidateFeeds();
    return serializeCommerceContent(content);
  }

  async rollback(user: AuthUser, id: string, versionNumber: number) {
    await this.ownedOrThrow(user, id);
    const version = await this.repo.findVersion(id, versionNumber);
    if (!version) throw new NotFoundException('Content version not found');
    const snapshot = this.snapshotOrThrow(version.snapshot);
    const productTags = await this.productTagCreates(user, snapshot.product_tags);

    const content = await this.repo.updateContent(id, {
      title: snapshot.title,
      body: snapshot.body,
      locale: snapshot.locale,
      visibility: snapshot.visibility,
      payload: snapshot.payload as Prisma.InputJsonValue,
      metadata:
        snapshot.metadata === null
          ? Prisma.JsonNull
          : (snapshot.metadata as Prisma.InputJsonValue),
      publicationTargets: { set: snapshot.publication_targets },
      scheduledAt: this.optionalDate(snapshot.scheduled_at),
      expiresAt: this.optionalDate(snapshot.expires_at),
      pinnedUntil: this.optionalDate(snapshot.pinned_until),
      status: CommerceContentStatus.DRAFT,
      publishedAt: null,
      archivedAt: null,
      media: { deleteMany: {}, create: this.mediaCreateArray(snapshot.media) },
      productTags: { deleteMany: {}, create: productTags },
    });

    await this.saveVersion(user.id, id, `Rolled back to v${versionNumber}`);
    this.invalidateFeeds();
    return serializeCommerceContent(content);
  }

  async moderate(user: AuthUser, id: string, dto: ModerateCommerceContentDto) {
    if (!isAdmin(user)) {
      throw new ForbiddenException('Only content moderators can review content');
    }
    const content = await this.repo.findById(id);
    if (!content) throw new NotFoundException('Content not found');

    const nextStatus = this.statusAfterModeration(content.scheduledAt, dto.status);
    const updated = await this.repo.updateContent(id, {
      moderationStatus: dto.status,
      status: nextStatus,
      ...(nextStatus === CommerceContentStatus.PUBLISHED && {
        publishedAt: new Date(),
      }),
    });
    await this.repo.createModerationAction({
      content: { connect: { id } },
      moderator: { connect: { id: user.id } },
      fromStatus: content.moderationStatus,
      toStatus: dto.status,
      reason: dto.reason,
      metadata: (dto.metadata as Prisma.InputJsonValue) ?? Prisma.JsonNull,
    });

    if (nextStatus === CommerceContentStatus.PUBLISHED) {
      this.events.emit(AppEvent.CommerceContentPublished, {
        authorId: updated.authorId,
        contentId: updated.id,
        contentType: updated.contentType,
        channels: updated.publicationTargets,
      });
    }

    this.invalidateFeeds();
    return serializeCommerceContent(updated);
  }

  async feed(query: CommerceFeedQueryDto) {
    const cacheKey = [
      FEED_CACHE_PREFIX,
      query.page,
      query.limit,
      query.channel ?? 'all',
      query.content_type ?? 'all',
      query.author_id ?? 'all',
    ].join(':');
    return this.cache.wrap(cacheKey, 15_000, async () => {
      const [items, total] = await Promise.all([
        this.repo.feed({
          skip: query.skip,
          take: query.limit,
          channel: query.channel,
          contentType: query.content_type,
          authorId: query.author_id,
        }),
        this.repo.countFeed({
          channel: query.channel,
          contentType: query.content_type,
          authorId: query.author_id,
        }),
      ]);
      return {
        data: items.map(serializeCommerceContent),
        pagination: buildMeta(query.page, query.limit, total, items.length),
      };
    });
  }

  async recordEvent(
    userId: string | undefined,
    id: string,
    dto: RecordCommerceContentEventDto,
  ) {
    const content = await this.repo.findPublished(id);
    if (!content) throw new NotFoundException('Published content not found');
    if (
      dto.product_id &&
      !content.productTags?.some((tag) => tag.productId === dto.product_id)
    ) {
      throw new BadRequestException('Product is not tagged in this content');
    }

    const viewer = userId
      ? await this.repo.findViewer(id, userId)
      : null;
    await this.repo.recordEvent({
      contentId: id,
      actorId: userId,
      type: dto.type,
      productId: dto.product_id,
      value: dto.value,
      watchTimeMs: dto.watch_time_ms,
      metadata: dto.metadata as Prisma.InputJsonValue,
      contentUpdate: this.eventCounterUpdate(dto, viewer === null && !!userId),
      viewerUpdate:
        dto.type === CommerceContentAnalyticsEventType.VIEW && userId
          ? viewer
            ? 'update'
            : 'create'
          : undefined,
    });

    const updated = await this.repo.findById(id);
    return {
      tracked: true,
      analytics: updated ? serializeCommerceContentAnalytics(updated) : null,
    };
  }

  analytics(user: AuthUser, id: string) {
    return this.getMine(user, id).then((content) => content.analytics);
  }

  async processDueContent(limit = 500) {
    const [published, expired] = await Promise.all([
      this.repo.publishDue(limit),
      this.repo.expireDue(limit),
    ]);
    if (published.count || expired.count) this.invalidateFeeds();
    return { published: published.count, expired: expired.count };
  }

  /**
   * Her own deletion.
   *
   * `DELETED`, never `REMOVED`: the second is a moderator's word and the two
   * answer different questions — "did she change her mind" and "did we
   * intervene". Conflating them would put her own tidying into the moderation
   * trail and make a takedown look like a change of heart.
   */
  async deleteOwn(user: AuthUser, id: string) {
    await this.ownedOrThrow(user, id);
    const content = await this.repo.updateContent(id, {
      status: CommerceContentStatus.DELETED,
      archivedAt: new Date(),
    });
    this.invalidateFeeds();
    return { deleted: true, id: content.id };
  }

  /**
   * Whether this piece has to be looked at before anybody else sees it.
   *
   * The count is of her *approved* pieces, so the gate lifts itself once she
   * has shown what she posts — nobody has to remember to lift it, and nobody
   * has to be trusted in advance.
   */
  private async reviewRequired(
    user: AuthUser,
    definition: CommerceContentTypeDefinition,
  ): Promise<boolean> {
    const approvedCount = await this.repo.approvedCountFor(user.id);
    return needsPrePublishReview({
      definition,
      role: user.role,
      approvedCount,
      reviewFreeAfter: this.config.get<number>('content.reviewFreeAfter') ?? 3,
    });
  }

  /**
   * What the format will carry.
   *
   * A reel without a video is not a reel; a story with nine frames is not the
   * format the viewer will be shown. Both are refused here rather than
   * rendered wrongly later, because the second failure is invisible to the
   * woman who published it.
   */
  private assertMediaFits(
    definition: CommerceContentTypeDefinition,
    media: CommerceContentMediaInputDto[],
  ) {
    const limit = maxMedia(definition);
    if (limit !== null && media.length > limit) {
      throw new BadRequestException(`TOO_MANY_MEDIA_MAX_${limit}`);
    }

    if (!requiresVideo(definition)) return;

    const video = media.find((item) => item.type === MediaType.video);
    if (!video) throw new BadRequestException('VIDEO_REQUIRED');

    const ceiling = maxDurationMs(definition);
    // Only when the client told us. The duration is measured on the handset —
    // reading it server-side would mean parsing an MP4 box tree for a number
    // the recorder already knows exactly, which is the trade `MessageAttachment`
    // already made for voice notes.
    if (ceiling !== null && video.duration_ms && video.duration_ms > ceiling) {
      throw new BadRequestException(
        `VIDEO_TOO_LONG_MAX_${Math.round(ceiling / 1000)}S`,
      );
    }
  }

  private async ownedOrThrow(user: AuthUser, id: string) {
    const owner = await this.repo.findOwner(id);
    if (!owner) throw new NotFoundException('Content not found');
    assertCanManage(owner.authorId, user);
    return owner;
  }

  private mediaCreate(media?: CommerceContentMediaInputDto[]) {
    const rows = this.mediaCreateArray(media ?? []);
    return rows.length ? { create: rows } : undefined;
  }

  private mediaCreateArray(media: CommerceContentMediaInputDto[]) {
    return media.map((item, index) => ({
      url: item.url,
      type: item.type,
      thumbnailUrl: item.thumbnail_url,
      streamingUrl: item.streaming_url,
      altText: item.alt_text,
      blurHash: item.blur_hash,
      durationMs: item.duration_ms,
      metadata: (item.metadata as Prisma.InputJsonValue) ?? Prisma.JsonNull,
      sortOrder: item.sort_order ?? index,
    }));
  }

  /**
   * Turns requested tags into rows, refusing the ones she is not entitled to.
   *
   * The entitlement question moved to `ProductTagPolicyService`, which answers
   * it for a boutique (a live offer) and for a shopper (a delivered line)
   * with one rule, and records *which* on the row. What stays here is the
   * shape work: existence, variant coherence, ordering.
   */
  private async productTagCreates(
    user: AuthUser,
    tags: CommerceContentProductTagInputDto[],
  ) {
    if (tags.length === 0) return [];
    const productIds = [...new Set(tags.map((tag) => tag.product_id))];
    const variantIds = [
      ...new Set(tags.map((tag) => tag.variant_id).filter(Boolean) as string[]),
    ];
    const [products, variants, verdicts] = await Promise.all([
      this.repo.productsForTags(productIds),
      this.repo.variantsForTags(variantIds),
      this.tagPolicy.assert(user, productIds),
    ]);
    const productById = new Map(products.map((product) => [product.id, product]));
    const variantById = new Map(variants.map((variant) => [variant.id, variant]));

    for (const tag of tags) {
      if (!productById.has(tag.product_id)) {
        throw new NotFoundException('Tagged product not found');
      }
      if (tag.variant_id) {
        const variant = variantById.get(tag.variant_id);
        if (!variant || variant.productId !== tag.product_id) {
          throw new BadRequestException('Tagged variant does not belong to product');
        }
      }
    }

    // One delivered line justifies one tag per post — the unique index on
    // (content_id, source_order_item_id) enforces it — so a post tagging the
    // same product twice must not carry the proof twice.
    const claimed = new Set<string>();

    return tags.map((tag, index) => {
      const verdict = verdicts.get(tag.product_id);
      const orderItemId = verdict?.sourceOrderItemId;
      const proof =
        orderItemId && !claimed.has(orderItemId) ? orderItemId : undefined;
      if (proof) claimed.add(proof);

      return {
        product: { connect: { id: tag.product_id } },
        ...(tag.variant_id
          ? { variant: { connect: { id: tag.variant_id } } }
          : {}),
        role: tag.role ?? 'featured',
        displayLabel: tag.display_label,
        x: tag.x,
        y: tag.y,
        targetUrl: tag.target_url,
        metadata: (tag.metadata as Prisma.InputJsonValue) ?? Prisma.JsonNull,
        sortOrder: tag.sort_order ?? index,
        basis: verdict?.basis ?? ContentTagBasis.SELLER_OFFER,
        ...(proof
          ? { sourceOrderItem: { connect: { id: proof } } }
          : {}),
      };
    });
  }

  private futureDate(value: string | null | undefined, field: string) {
    const date = this.optionalDate(value);
    if (date && date <= new Date()) {
      throw new BadRequestException(`${field} must be in the future`);
    }
    return date;
  }

  private optionalDate(value: string | null | undefined) {
    if (value === undefined) return undefined;
    if (value === null) return null;
    return new Date(value);
  }

  private expirationDate(
    value: string | undefined,
    definition: CommerceContentTypeDefinition,
  ) {
    if (value) return this.futureDate(value, 'expires_at');
    const hours = this.registry.expiresAfterHours(definition);
    if (!hours) return undefined;
    return new Date(Date.now() + hours * 60 * 60_000);
  }

  private eventCounterUpdate(
    dto: RecordCommerceContentEventDto,
    uniqueViewer: boolean,
  ): Prisma.CommerceContentUpdateInput {
    const now = new Date();
    switch (dto.type) {
      case CommerceContentAnalyticsEventType.IMPRESSION:
        return { impressionsCount: { increment: 1 } };
      case CommerceContentAnalyticsEventType.VIEW:
        return {
          viewsCount: { increment: 1 },
          ...(uniqueViewer && { uniqueViewersCount: { increment: 1 } }),
        };
      case CommerceContentAnalyticsEventType.WATCH_TIME:
        return { watchTimeMs: { increment: dto.watch_time_ms ?? 0 } };
      case CommerceContentAnalyticsEventType.PRODUCT_CLICK:
        return {
          productClicksCount: { increment: 1 },
          engagementCount: { increment: 1 },
          lastEngagementAt: now,
        };
      case CommerceContentAnalyticsEventType.PURCHASE:
        return {
          ordersCount: { increment: 1 },
          revenueGenerated: { increment: dto.value ?? 0 },
          engagementCount: { increment: 1 },
          lastEngagementAt: now,
        };
      // SHARE, SAVE, REPLY and REACTION deliberately do NOT touch their
      // totals here any more.
      //
      // Real interaction rows exist now — `commerce_content_reactions`,
      // `_saves`, `_comments`, `_reshares` — and `ContentInteractionsService`
      // increments the four counters inside the same transaction that writes
      // the row. This endpoint is client-driven, so leaving both paths live
      // meant one like counted twice and the boutique's dashboard was quietly
      // and permanently wrong, with nothing to notice it by.
      //
      // The ledger row is still written by the caller: "she liked it at 14:02"
      // is exactly what a ledger is for. Only the totals moved.
      case CommerceContentAnalyticsEventType.SHARE:
      case CommerceContentAnalyticsEventType.SAVE:
      case CommerceContentAnalyticsEventType.REPLY:
      case CommerceContentAnalyticsEventType.REACTION:
        return { lastEngagementAt: now };
      case CommerceContentAnalyticsEventType.ADD_TO_CART:
      case CommerceContentAnalyticsEventType.ENGAGEMENT:
      default:
        return {
          engagementCount: { increment: 1 },
          lastEngagementAt: now,
        };
    }
  }

  private async saveVersion(
    userId: string,
    contentId: string,
    changeNote: string,
  ) {
    const [latest, content] = await Promise.all([
      this.repo.latestVersion(contentId),
      this.repo.findById(contentId),
    ]);
    if (!content) throw new NotFoundException('Content not found');
    await this.repo.createVersion({
      content: { connect: { id: contentId } },
      createdBy: { connect: { id: userId } },
      version: (latest._max.version ?? 0) + 1,
      changeNote,
      snapshot: this.snapshot(content) as unknown as Prisma.InputJsonValue,
    });
  }

  private snapshot(
    content: Awaited<ReturnType<CommerceContentRepository['findById']>>,
  ): ContentSnapshot {
    if (!content) throw new NotFoundException('Content not found');
    return {
      content_type: content.contentType,
      title: content.title,
      body: content.body,
      locale: content.locale,
      visibility: content.visibility,
      payload: content.payload,
      metadata: content.metadata,
      publication_targets: content.publicationTargets,
      scheduled_at: content.scheduledAt?.toISOString() ?? null,
      expires_at: content.expiresAt?.toISOString() ?? null,
      pinned_until: content.pinnedUntil?.toISOString() ?? null,
      media: (content.media ?? []).map((media) => ({
        url: media.url,
        type: media.type,
        thumbnail_url: media.thumbnailUrl ?? undefined,
        streaming_url: media.streamingUrl ?? undefined,
        alt_text: media.altText ?? undefined,
        blur_hash: media.blurHash ?? undefined,
        duration_ms: media.durationMs ?? undefined,
        metadata: (media.metadata as Record<string, unknown>) ?? undefined,
        sort_order: media.sortOrder,
      })),
      product_tags: (content.productTags ?? []).map((tag) => ({
        product_id: tag.productId,
        variant_id: tag.variantId ?? undefined,
        role: tag.role,
        display_label: tag.displayLabel ?? undefined,
        x: tag.x ?? undefined,
        y: tag.y ?? undefined,
        target_url: tag.targetUrl ?? undefined,
        metadata: (tag.metadata as Record<string, unknown>) ?? undefined,
        sort_order: tag.sortOrder,
      })),
    };
  }

  private snapshotOrThrow(value: Prisma.JsonValue): ContentSnapshot {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      throw new BadRequestException('Stored content version is not restorable');
    }
    return value as unknown as ContentSnapshot;
  }

  private statusAfterModeration(
    scheduledAt: Date | null,
    moderationStatus: CommerceContentModerationStatus,
  ) {
    if (moderationStatus === CommerceContentModerationStatus.REJECTED) {
      return CommerceContentStatus.REJECTED;
    }
    if (moderationStatus === CommerceContentModerationStatus.FLAGGED) {
      return CommerceContentStatus.IN_REVIEW;
    }
    if (moderationStatus === CommerceContentModerationStatus.PENDING) {
      return CommerceContentStatus.IN_REVIEW;
    }
    return scheduledAt && scheduledAt > new Date()
      ? CommerceContentStatus.SCHEDULED
      : CommerceContentStatus.PUBLISHED;
  }

  private invalidateFeeds() {
    this.cache.invalidate(FEED_CACHE_PREFIX);
  }
}
