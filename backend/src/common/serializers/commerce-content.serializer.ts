import {
  CommerceContent,
  CommerceContentMedia,
  CommerceContentProductTag,
  CommerceContentTypeDefinition,
  CommerceContentVersion,
  ProductVariant,
  User,
} from '@prisma/client';
import {
  ProductRecord,
  serializeProduct,
  serializeVariant,
} from './product.serializer';
import { serializePublicUser } from './user.serializer';

export type CommerceContentProductTagWithRelations =
  CommerceContentProductTag & {
    product: ProductRecord;
    variant?: ProductVariant | null;
  };

export type CommerceContentWithRelations = CommerceContent & {
  author: User;
  typeDefinition: CommerceContentTypeDefinition;
  media?: CommerceContentMedia[];
  productTags?: CommerceContentProductTagWithRelations[];
  versions?: CommerceContentVersion[];
};

function count(value: bigint | number | null | undefined): number {
  return Number(value ?? 0);
}

function iso(value: Date | null | undefined): string | null {
  return value ? value.toISOString() : null;
}

export type ContentModerationState = 'active' | 'under_review' | 'removed';

/**
 * Active / قيد المراجعة / محذوف.
 *
 * Two enums drive behaviour here — `status` is the publishing lifecycle and
 * `moderationStatus` is the review verdict — and the useful question ("can
 * anyone see this, and if not why") is a function of both. Deriving it once,
 * server-side, is what stops every client recomputing a tri-state from a
 * four-by-nine matrix and getting it subtly different.
 */
export function moderationState(
  content: Pick<CommerceContent, 'status' | 'moderationStatus'>,
): ContentModerationState {
  if (
    content.status === 'REMOVED' ||
    content.moderationStatus === 'REJECTED'
  ) {
    return 'removed';
  }
  if (
    content.status === 'IN_REVIEW' ||
    content.moderationStatus === 'FLAGGED' ||
    content.moderationStatus === 'PENDING'
  ) {
    return 'under_review';
  }
  return 'active';
}

export function serializeCommerceContentType(
  type: CommerceContentTypeDefinition,
) {
  return {
    id: type.id,
    key: type.key,
    name: type.name,
    description: type.description,
    schema: type.schema,
    ui_schema: type.uiSchema,
    capabilities: type.capabilities,
    lifecycle: type.lifecycle,
    active: type.active,
    version: type.version,
    created_at: type.createdAt.toISOString(),
    updated_at: type.updatedAt.toISOString(),
  };
}

export function serializeCommerceContentVersion(
  version: CommerceContentVersion,
) {
  return {
    id: version.id,
    version: version.version,
    snapshot: version.snapshot,
    change_note: version.changeNote,
    created_by_id: version.createdById,
    created_at: version.createdAt.toISOString(),
  };
}

export function serializeCommerceContent(content: CommerceContentWithRelations) {
  return {
    id: content.id,
    author: serializePublicUser(content.author),
    /// What she was when she published it — see `CommerceContent.authorKind`.
    /// A card renders a boutique post and a customer look differently, and it
    /// must not decide that from the author's *current* role.
    author_kind: content.authorKind.toLowerCase(),
    content_type: content.contentType,
    type_definition: serializeCommerceContentType(content.typeDefinition),
    title: content.title,
    body: content.body,
    locale: content.locale,
    status: content.status.toLowerCase(),
    visibility: content.visibility.toLowerCase(),
    moderation_status: content.moderationStatus.toLowerCase(),
    /// The three states a woman and a moderator both reason about, derived
    /// rather than stored so it can never drift from the two enums that
    /// actually drive behaviour. The client must not recompute it.
    moderation_state: moderationState(content),
    removal_reason: content.removalReason,
    removed_at: iso(content.removedAt),
    payload: content.payload,
    metadata: content.metadata,
    publication_targets: content.publicationTargets.map((target) =>
      target.toLowerCase(),
    ),
    scheduled_at: iso(content.scheduledAt),
    published_at: iso(content.publishedAt),
    expires_at: iso(content.expiresAt),
    archived_at: iso(content.archivedAt),
    pinned_until: iso(content.pinnedUntil),
    media: (content.media ?? [])
      .slice()
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map((media) => ({
        id: media.id,
        url: media.url,
        type: media.type,
        thumbnail_url: media.thumbnailUrl,
        streaming_url: media.streamingUrl,
        alt_text: media.altText,
        blur_hash: media.blurHash,
        duration_ms: media.durationMs,
        metadata: media.metadata,
        sort_order: media.sortOrder,
      })),
    product_tags: (content.productTags ?? [])
      .slice()
      .sort((a, b) => a.sortOrder - b.sortOrder)
      .map((tag) => ({
        id: tag.id,
        role: tag.role,
        display_label: tag.displayLabel,
        x: tag.x,
        y: tag.y,
        target_url: tag.targetUrl,
        metadata: tag.metadata,
        sort_order: tag.sortOrder,
        product: serializeProduct(tag.product),
        variant: tag.variant ? serializeVariant(tag.variant) : null,
      })),
    analytics: serializeCommerceContentAnalytics(content),
    versions: (content.versions ?? [])
      .slice()
      .sort((a, b) => b.version - a.version)
      .map(serializeCommerceContentVersion),
    created_at: content.createdAt.toISOString(),
    updated_at: content.updatedAt.toISOString(),
  };
}

export function serializeCommerceContentAnalytics(content: CommerceContent) {
  return {
    impressions: count(content.impressionsCount),
    views: count(content.viewsCount),
    unique_viewers: count(content.uniqueViewersCount),
    engagement: count(content.engagementCount),
    product_clicks: count(content.productClicksCount),
    orders: count(content.ordersCount),
    shares: count(content.sharesCount),
    saves: count(content.savesCount),
    replies: count(content.repliesCount),
    reactions: count(content.reactionsCount),
    watch_time_ms: count(content.watchTimeMs),
    revenue_generated: content.revenueGenerated,
    last_engagement_at: iso(content.lastEngagementAt),
  };
}
