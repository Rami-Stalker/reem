import { contentReactionSummaries } from './interactions/reaction-summary';
import {
  Body,
  Controller,
  Delete,
  Get,
  HttpCode,
  HttpStatus,
  Param,
  ParseUUIDPipe,
  Post,
  Query,
} from '@nestjs/common';
import { PromotionPlacement, UserRole } from '@prisma/client';
import { Authorize } from '../../common/decorators/authorize.decorator';
import {
  AuthUser,
  CurrentUser,
} from '../../common/decorators/current-user.decorator';
import { OptionalAuth } from '../../common/decorators/optional-auth.decorator';
import { AppPermission } from '../../common/permissions';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CursorPageDto } from '../../common/dto/cursor-pagination.dto';
import {
  commentIdsOf,
  serializeContentComment,
  serializeFeedContent,
  serializeTimelineEntry,
  ViewerState,
} from '../../common/serializers';
import { ContentFeedService } from './feed/content-feed.service';
import { MAX_FEED_SLOTS, PromotionsService } from '../promotions/promotions.service';
import { ContentFeedControlsService } from './feed/content-feed-controls.service';
import { FeedRankingService } from './ranking/feed-ranking.service';
import { ContentInteractionsService } from './interactions/content-interactions.service';
import { ContentModerationService } from './moderation/content-moderation.service';
import { ProductTagPolicyService } from './tagging/product-tag-policy.service';
import { PrismaService } from '../../prisma/prisma.service';
import {
  ContentFeedQueryDto,
  CreateContentCommentDto,
  ReactToContentDto,
  RemoveCommentDto,
  ReportContentDto,
  ReshareContentDto,
} from './dto/social.dto';

/** Where a later page's sponsored post sits: after a few of her own. */
const INLINE_AD_POSITION = 4;

const NO_VIEWER: ViewerState = {
  is_liked: false,
  my_reaction: null,
  is_saved: false,
  is_reshared: false,
};

/**
 * The reading and reacting half of the social platform.
 *
 * Feeds are `@OptionalAuth`: a guest may browse. That is not a convenience —
 * the whole commerce case rests on a woman being able to follow a link into a
 * look, see the dress and reach the boutique before she has an account. The
 * old `GET /content/feed` was authenticated by omission, which made the
 * platform's own feed unreachable to exactly the visitor it was for.
 *
 * Everything that writes requires a session and `content:interact`.
 */
@Controller('content')
export class ContentSocialController {
  constructor(
    private readonly feed: ContentFeedService,
    private readonly controls: ContentFeedControlsService,
    private readonly interactions: ContentInteractionsService,
    private readonly moderation: ContentModerationService,
    private readonly tagPolicy: ProductTagPolicyService,
    private readonly prisma: PrismaService,
    private readonly promotions: PromotionsService,
    private readonly ranking: FeedRankingService,
  ) {}

  // ── Feeds ─────────────────────────────────────────────────────────────────

  @Get('feed')
  @OptionalAuth()
  async home(
    @CurrentUser() user: AuthUser | undefined,
    @Query() query: ContentFeedQueryDto,
  ) {
    // The anonymous cache is keyed on the page and the channel only, so it
    // may serve the unfiltered feed. A guest asking for one woman's reels —
    // her page, opened from a shared link — is answered live instead, or she
    // would be handed everybody's.
    const filtered = Boolean(
      query.content_type || query.author_id || query.author_kind,
    );

    // The plain feed is ranked for her: following, closeness, her categories,
    // what is doing well, what is new — one session per visit. A channel or
    // a filter is a list she asked for and stays newest-first.
    if (!filtered && !query.channel) {
      const ranked = await this.ranking.page('feed', user?.id, query);
      if (ranked) return this.renderRanked(ranked, user?.id, true);
    }

    const page = await (user || filtered
      ? this.feed.feed(query, {
          viewerId: user?.id,
          channel: query.channel,
          contentType: query.content_type,
          authorId: query.author_id,
          authorKind: query.author_kind,
        })
      : this.feed.publicFeed(query, query.channel));

    // The head of the plain home feed carries one sponsored post, labelled.
    // Never on a channel or a filtered view: an advert on her own boutique's
    // page is noise.
    const head = !query.cursor && !filtered && !query.channel;
    const sponsored = head ? await this.sponsoredHead(user?.id) : [];
    if (sponsored.length === 0) return this.renderFeed(page, user?.id);
    return this.withSponsored(page, sponsored, 0, user?.id);
  }

  /**
   * A ranked page: the session's next slice, a sponsored post where one
   * belongs, and each piece's reason — «تتابعينها», «مقترح لكِ», «رائج الآن»,
   * «صوت جديد» — so the app can say why it is there.
   *
   * The first page leads with the paid FEED_TOP post; every later page of
   * the same scroll carries one more, a few places in, and never one this
   * scroll already showed. One in twenty, labelled, never twice.
   */
  private async renderRanked(
    ranked: NonNullable<Awaited<ReturnType<FeedRankingService['page']>>>,
    viewerId: string | undefined,
    withAds: boolean,
  ) {
    let sponsored: Awaited<ReturnType<typeof this.sponsoredHead>> = [];
    let at = 0;
    // A post this scroll already showed as an advert does not come back
    // further down as one of her own.
    const shown = this.ranking.adsShown(ranked.session);
    if (shown.size > 0) ranked = { ...ranked, items: ranked.items.filter((i) => !shown.has(i.id)) };
    if (withAds && ranked.items.length > 0) {
      sponsored = await this.sponsoredHead(viewerId, shown);
      at = ranked.offset === 0 ? 0 : Math.min(INLINE_AD_POSITION, ranked.items.length);
      this.ranking.rememberAds(
        ranked.session,
        sponsored.map((s) => s.row.id),
      );
    }
    const rendered =
      sponsored.length === 0
        ? await this.renderFeed(ranked, viewerId)
        : await this.withSponsored(ranked, sponsored, at, viewerId);
    return {
      ...rendered,
      data: rendered.data.map((item) => {
        const id = (item as { id: string }).id;
        const reason = ranked.reasons[id];
        return reason && !(item as { sponsored?: unknown }).sponsored
          ? { ...item, rank_reason: reason }
          : item;
      }),
    };
  }

  /** The page with the sponsored posts placed at [at], each labelled. */
  private async withSponsored(
    page: { items: { id: string }[]; meta: unknown },
    sponsored: Awaited<ReturnType<typeof this.sponsoredHead>>,
    at: number,
    viewerId?: string,
  ) {
    const pinned = new Set(sponsored.map((s) => s.row.id));
    const organic = page.items.filter((item) => !pinned.has(item.id));
    const rendered = await this.renderFeed(
      {
        items: [
          ...organic.slice(0, at),
          ...sponsored.map((s) => s.row),
          ...organic.slice(at),
        ],
        meta: page.meta,
      },
      viewerId,
    );
    const bySlot = new Map(sponsored.map((s) => [s.row.id, s.slot]));
    return {
      ...rendered,
      data: rendered.data.map((item, index) => {
        const inSlot = index >= at && index < at + sponsored.length;
        const slot = inSlot ? bySlot.get((item as { id: string }).id) : undefined;
        return slot
          ? {
              ...item,
              sponsored: {
                promotion_id: slot.promotionId,
                offer_id: slot.offerId,
                // The placement she paid for, wherever in the scroll it sits:
                // a tap is credited against it.
                placement: 'feed_top',
                store_tier: slot.tier.toLowerCase(),
              },
            }
          : item;
      }),
    };
  }

  /**
   * The paid FEED_TOP slot for this viewer, with its post. A failure here
   * serves the feed without it — a broken ad system must never take the feed
   * down with it.
   */
  private async sponsoredHead(viewerId?: string, skip?: ReadonlySet<string>) {
    try {
      // A few in serving order, so a shop she muted gives way to the next
      // rather than leaving the slot empty.
      const slots = await this.promotions.serve(PromotionPlacement.FEED_TOP, {
        viewerId,
        limit: MAX_FEED_SLOTS + 2,
      });
      const withPost = slots.filter(
        (slot) => slot.contentId && !skip?.has(slot.contentId),
      );
      if (withPost.length === 0) return [];
      const rows = await this.feed.sponsoredRows(
        withPost.map((slot) => slot.contentId!),
        viewerId,
      );
      const slotOf = new Map(withPost.map((slot) => [slot.contentId!, slot]));
      const served = rows
        .slice(0, MAX_FEED_SLOTS)
        .map((row) => ({ row, slot: slotOf.get(row.id)! }));
      if (served.length > 0) {
        void this.promotions
          .recordImpressions(
            served.map((s) => s.slot.offerId),
            PromotionPlacement.FEED_TOP,
            viewerId,
          )
          .catch(() => undefined);
      }
      return served;
    } catch {
      return [];
    }
  }

  @Get('reels')
  @OptionalAuth()
  async reels(
    @CurrentUser() user: AuthUser | undefined,
    @Query() query: CursorPageDto,
  ) {
    // Ranked like the feed, with watch time counting most: a reel she
    // watches to the end says more than a heart.
    const ranked = await this.ranking.page('reels', user?.id, query);
    if (ranked) return this.renderRanked(ranked, user?.id, false);
    const page = await this.feed.feed(query, {
      viewerId: user?.id,
      contentType: 'reel',
    });
    return this.renderFeed(page, user?.id);
  }

  @Get('following')
  @Authorize({
    action: 'read',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  async following(
    @CurrentUser() user: AuthUser,
    @Query() query: CursorPageDto,
  ) {
    const page = await this.feed.followingFeed(user.id, query);
    return this.renderTimeline(page, user.id);
  }

  @Get('stories')
  @OptionalAuth()
  async stories(@CurrentUser() user: AuthUser | undefined) {
    // In the order she would open them: her own ring, then the ones with
    // something new — closest people first — then the ones she finished.
    const tray = await this.ranking
      .orderTray(
        user?.id,
        (await this.feed.storiesTray(user?.id)).map((group) => ({
          ...group,
          authorId: group.author.id,
          allSeen: group.all_seen,
          newestAt: group.stories[group.stories.length - 1].createdAt,
        })),
      );
    const viewer = await this.viewerStates(
      tray.flatMap((group) => group.stories.map((story) => story.id)),
      user?.id,
    );
    return tray.map((group) => ({
      author: serializeFeedContent(group.stories[0]).author,
      all_seen: group.all_seen,
      stories: group.stories.map((story) =>
        serializeFeedContent(story, viewer(story.id)),
      ),
    }));
  }

  @Get('saved')
  @Authorize({
    action: 'read',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  async saved(@CurrentUser() user: AuthUser, @Query() query: CursorPageDto) {
    const page = await this.feed.saved(user.id, query);
    return this.renderFeed(page, user.id);
  }

  /** A woman's page: what she published, and what she added to it. */
  @Get('users/:userId')
  @OptionalAuth()
  async userPage(
    @Param('userId', ParseUUIDPipe) userId: string,
    @CurrentUser() user: AuthUser | undefined,
    @Query() query: CursorPageDto,
  ) {
    const page = await this.feed.userTimeline(userId, query, user?.id);
    return this.renderTimeline(page, user?.id);
  }

  /**
   * One woman's live stories — the ring on her avatar and the stories tab on
   * her page. The same visibility rule as the tray, scoped to her.
   */
  @Get('users/:userId/stories')
  @OptionalAuth()
  async userStories(
    @Param('userId', ParseUUIDPipe) userId: string,
    @CurrentUser() user: AuthUser | undefined,
  ) {
    const tray = await this.feed.storiesTray(user?.id, userId);
    const viewer = await this.viewerStates(
      tray.flatMap((group) => group.stories.map((story) => story.id)),
      user?.id,
    );
    return tray.map((group) => ({
      author: serializeFeedContent(group.stories[0]).author,
      all_seen: group.all_seen,
      stories: group.stories.map((story) =>
        serializeFeedContent(story, viewer(story.id)),
      ),
    }));
  }

  /** «نساء يرتدينها» — what shoppers have posted wearing this product. */
  @Get('products/:productId')
  @OptionalAuth()
  async byProduct(
    @Param('productId', ParseUUIDPipe) productId: string,
    @CurrentUser() user: AuthUser | undefined,
    @Query() query: CursorPageDto,
  ) {
    const page = await this.feed.feed(query, {
      viewerId: user?.id,
      productId,
    });
    return this.renderFeed(page, user?.id);
  }

  /** What she may tag, for the composer. */
  @Get('taggable-products')
  @Authorize({
    action: 'author',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentAuthor],
  })
  taggable(@CurrentUser() user: AuthUser, @Query() page: PaginationDto) {
    return this.tagPolicy.listTaggable(user, page);
  }

  // ── Interactions ──────────────────────────────────────────────────────────

  @Post(':id/like')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  like(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReactToContentDto,
  ) {
    return this.interactions.react(user, id, dto.emoji);
  }

  @Post(':id/save')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  save(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.interactions.toggleSave(user, id);
  }

  @Post(':id/share')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  share(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.interactions.recordExternalShare(user, id);
  }

  /** «أضيفي إلى صفحتي» */
  @Post(':id/reshare')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  reshare(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReshareContentDto,
  ) {
    return this.interactions.reshare(user, id, {
      note: dto.note,
      viaReshareId: dto.via_reshare_id,
    });
  }

  @Delete(':id/reshare')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  unreshare(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.interactions.unreshare(user, id);
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  @Get(':id/comments')
  @OptionalAuth()
  async comments(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser | undefined,
    @Query() page: PaginationDto,
  ) {
    const result = await this.interactions.listComments(id, page, user?.id);
    const reactions = await this.interactions.commentReactions(
      commentIdsOf(result.roots),
      user?.id,
    );
    return {
      data: result.roots.map((comment) =>
        serializeContentComment(comment, reactions),
      ),
      pagination: result.meta,
    };
  }

  @Get('comments/:commentId/replies')
  @OptionalAuth()
  async replies(
    @Param('commentId', ParseUUIDPipe) commentId: string,
    @CurrentUser() user: AuthUser | undefined,
    @Query() page: PaginationDto,
  ) {
    const result = await this.interactions.listReplies(commentId, page);
    const reactions = await this.interactions.commentReactions(
      commentIdsOf(result.items),
      user?.id,
    );
    return {
      data: result.items.map((comment) =>
        serializeContentComment(comment, reactions),
      ),
      pagination: result.meta,
    };
  }

  @Post('comments/:commentId/react')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  reactToComment(
    @CurrentUser() user: AuthUser,
    @Param('commentId', ParseUUIDPipe) commentId: string,
    @Body() dto: ReactToContentDto,
  ) {
    return this.interactions.reactToComment(user, commentId, dto.emoji);
  }

  @Post(':id/comments')
  @HttpCode(HttpStatus.CREATED)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  async comment(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: CreateContentCommentDto,
  ) {
    const comment = await this.interactions.comment(
      user,
      id,
      dto.body,
      dto.parent_id,
    );
    return serializeContentComment({ ...comment, replies: [] });
  }

  @Delete('comments/:commentId')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  removeComment(
    @CurrentUser() user: AuthUser,
    @Param('commentId', ParseUUIDPipe) commentId: string,
    @Body() dto: RemoveCommentDto,
  ) {
    return this.interactions.removeComment(user, commentId, dto.reason);
  }

  // ── Her audience ──────────────────────────────────────────────────────────

  /** «شوهدت من قبل» — who watched her own story or reel. Owner only. */
  @Get(':id/viewers')
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  viewers(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.interactions.audience(user, id);
  }

  // ── Reporting ─────────────────────────────────────────────────────────────

  @Post(':id/report')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  report(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
    @Body() dto: ReportContentDto,
  ) {
    return this.moderation.report(user, id, dto.reason, dto.detail);
  }

  @Post('comments/:commentId/report')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  reportComment(
    @CurrentUser() user: AuthUser,
    @Param('commentId', ParseUUIDPipe) commentId: string,
    @Body() dto: ReportContentDto,
  ) {
    return this.moderation.reportComment(user, commentId, dto.reason, dto.detail);
  }

  // ── Her feed, tuned by her ────────────────────────────────────────────────

  /** «غير مهتمة» */
  @Post(':id/hide')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  hide(@CurrentUser() user: AuthUser, @Param('id', ParseUUIDPipe) id: string) {
    return this.controls.hide(user.id, id);
  }

  @Delete(':id/hide')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  unhide(
    @CurrentUser() user: AuthUser,
    @Param('id', ParseUUIDPipe) id: string,
  ) {
    return this.controls.unhide(user.id, id);
  }

  /** «إخفاء منشورات هذا الحساب» */
  @Post('authors/:userId/mute')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  mute(
    @CurrentUser() user: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.controls.mute(user.id, userId);
  }

  @Delete('authors/:userId/mute')
  @HttpCode(HttpStatus.OK)
  @Authorize({
    action: 'interact',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  unmute(
    @CurrentUser() user: AuthUser,
    @Param('userId', ParseUUIDPipe) userId: string,
  ) {
    return this.controls.unmute(user.id, userId);
  }

  @Get('muted')
  @Authorize({
    action: 'read',
    resource: 'content',
    roles: [UserRole.CUSTOMER, UserRole.SELLER],
    permissions: [AppPermission.contentInteract],
  })
  muted(@CurrentUser() user: AuthUser) {
    return this.controls.muted(user.id);
  }

  // ── One piece ───────────────────────────────────────────────

  /**
   * What a shared link opens: `/p/<id>` on the web, `/content/<id>` in the app.
   *
   * `@OptionalAuth`, for the same reason the feeds are — a woman follows a
   * link from WhatsApp into a look and has to be able to see the dress before
   * she has an account.
   *
   * **Declared last among the GETs, and that is load-bearing.** `:id` matches
   * one segment, so declaring it any earlier would have shadowed `feed`,
   * `reels`, `stories`, `saved`, `mine` and `muted` — each of which would then
   * have been answered by a UUID lookup that could only ever 404.
   */
  @Get(':id')
  @OptionalAuth()
  async byId(
    @Param('id', ParseUUIDPipe) id: string,
    @CurrentUser() user: AuthUser | undefined,
  ) {
    const content = await this.feed.byId(id, user?.id);
    const viewer = await this.viewerStates([content.id], user?.id);
    return serializeFeedContent(content as never, viewer(content.id));
  }

  // ── Rendering ─────────────────────────────────────────────────────────────

  /**
   * The viewer's own state for a page of content, in two queries rather than
   * two per card.
   *
   * A feed of twenty cards each asking "have I liked this" is forty round
   * trips; both indexes here are `(user_id, content_id)`, added for exactly
   * this read.
   */
  private async viewerStates(contentIds: string[], userId?: string) {
    if (contentIds.length === 0) return () => NO_VIEWER;
    // Everyone's reactions, for the «❤️😍🔥» beside the counter — a guest
    // sees them too.
    const summaries = await contentReactionSummaries(this.prisma, contentIds);
    if (!userId) {
      return (contentId: string): ViewerState => ({
        ...NO_VIEWER,
        reaction_summary: summaries.get(contentId) ?? [],
      });
    }

    const [reactions, saves, reshares] = await Promise.all([
      this.prisma.commerceContentReaction.findMany({
        where: { userId, contentId: { in: contentIds } },
        select: { contentId: true, emoji: true },
      }),
      this.prisma.commerceContentSave.findMany({
        where: { userId, contentId: { in: contentIds } },
        select: { contentId: true },
      }),
      this.prisma.commerceContentReshare.findMany({
        where: { resharerId: userId, sourceContentId: { in: contentIds } },
        select: { sourceContentId: true },
      }),
    ]);

    const liked = new Map(reactions.map((row) => [row.contentId, row.emoji]));
    const saved = new Set(saves.map((row) => row.contentId));
    const reshared = new Set(reshares.map((row) => row.sourceContentId));

    return (contentId: string): ViewerState => ({
      is_liked: liked.has(contentId),
      my_reaction: liked.get(contentId) ?? null,
      reaction_summary: summaries.get(contentId) ?? [],
      is_saved: saved.has(contentId),
      is_reshared: reshared.has(contentId),
    });
  }

  private async renderFeed(
    page: { items: { id: string }[]; meta: unknown },
    userId?: string,
  ) {
    const viewer = await this.viewerStates(
      page.items.map((item) => item.id),
      userId,
    );
    return {
      data: page.items.map((item) =>
        serializeFeedContent(item as never, viewer(item.id)),
      ),
      pagination: page.meta,
    };
  }

  private async renderTimeline(
    page: { items: unknown[]; meta: unknown },
    userId?: string,
  ) {
    const entries = page.items as (
      | { kind: 'own'; content: { id: string } }
      | { kind: 'reshare'; reshare: { sourceContent: { id: string } } }
    )[];
    const ids = entries.map((entry) =>
      entry.kind === 'own' ? entry.content.id : entry.reshare.sourceContent.id,
    );
    const viewer = await this.viewerStates(ids, userId);
    return {
      data: entries.map((entry) =>
        serializeTimelineEntry(entry as never, viewer),
      ),
      pagination: page.meta,
    };
  }
}
