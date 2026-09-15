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
import { UserRole } from '@prisma/client';
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
  serializeContentComment,
  serializeFeedContent,
  serializeTimelineEntry,
  ViewerState,
} from '../../common/serializers';
import { ContentFeedService } from './feed/content-feed.service';
import { ContentFeedControlsService } from './feed/content-feed-controls.service';
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
    const page = await (user || filtered
      ? this.feed.feed(query, {
          viewerId: user?.id,
          channel: query.channel,
          contentType: query.content_type,
          authorId: query.author_id,
          authorKind: query.author_kind,
        })
      : this.feed.publicFeed(query, query.channel));
    return this.renderFeed(page, user?.id);
  }

  @Get('reels')
  @OptionalAuth()
  async reels(
    @CurrentUser() user: AuthUser | undefined,
    @Query() query: CursorPageDto,
  ) {
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
    const tray = await this.feed.storiesTray(user?.id);
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
    @Query() page: PaginationDto,
  ) {
    const result = await this.interactions.listComments(id, page);
    return {
      data: result.roots.map(serializeContentComment),
      pagination: result.meta,
    };
  }

  @Get('comments/:commentId/replies')
  @OptionalAuth()
  async replies(
    @Param('commentId', ParseUUIDPipe) commentId: string,
    @Query() page: PaginationDto,
  ) {
    const result = await this.interactions.listReplies(commentId, page);
    return {
      data: result.items.map(serializeContentComment),
      pagination: result.meta,
    };
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
    if (!userId || contentIds.length === 0) return () => NO_VIEWER;

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
