import { Injectable, NotFoundException } from '@nestjs/common';
import {
  CommerceContentCommentStatus,
  CommerceContentStatus,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { PRODUCT_CARD_INCLUDE as PRODUCT_INCLUDE } from '../../common/catalog/product-include';
import { TrendSignalService } from '../trends/collection/trend-signal.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import {
  LegacyViewerState,
  NO_LEGACY_VIEWER,
  serializeLegacyComment,
  serializeLegacyPost,
} from '../../common/serializers';
import { ContentInteractionsService } from '../commerce-content/interactions/content-interactions.service';

/**
 * `/posts/*` — the same contract, over the content platform.
 *
 * The `posts`, `post_likes`, `post_saves` and `comments` tables are gone as a
 * source of truth. This module is now an **adapter**: it answers exactly what
 * it always answered, reading `commerce_contents` and writing through
 * `ContentInteractionsService`, so the shipped Flutter app keeps working while
 * the client migrates to `/content/*`.
 *
 * Why an adapter and not a straight deletion: there are handsets in Syria
 * running a build that calls these paths, and they do not update because the
 * backend did. The contract tests in `test/contract/social_contract_test.dart`
 * are the proof — the fixtures were captured from the old implementation and
 * must decode identically against this one.
 *
 * The one thing that is genuinely different, and deliberately so: engagement
 * written here lands in the same tables as engagement written through
 * `/content/*`. Two doors, one room. That was the entire point of the merge.
 */
@Injectable()
export class PostsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly signals: TrendSignalService,
    private readonly interactions: ContentInteractionsService,
  ) {}

  /**
   * What a legacy post is, expressed as a query.
   *
   * `product_post` only. A reel or a story surfacing in `/posts/feed` would be
   * a card the old client cannot render — it has no video player and no story
   * viewer on that screen.
   */
  private get legacyPostWhere(): Prisma.CommerceContentWhereInput {
    return {
      contentType: 'product_post',
      status: CommerceContentStatus.PUBLISHED,
      visibility: 'PUBLIC',
      authorIsPublic: true,
    };
  }

  private readonly legacyInclude = {
    author: true,
    media: { orderBy: { sortOrder: 'asc' as const } },
    productTags: {
      orderBy: { sortOrder: 'asc' as const },
      include: { product: { include: PRODUCT_INCLUDE }, variant: true },
    },
  };

  /** `userId` is absent for a signed-out visitor — see the controller. */
  async feed(userId: string | undefined, page: PaginationDto) {
    // Her «غير مهتمة» and her mutes reach this feed too — it is the home
    // page's «وصل حديثاً», the first feed she ever sees.
    const where: Prisma.CommerceContentWhereInput = userId
      ? {
          ...this.legacyPostWhere,
          hiddenBy: { none: { userId } },
          author: { mutesReceived: { none: { muterId: userId } } },
        }
      : this.legacyPostWhere;
    const [posts, total] = await Promise.all([
      this.prisma.commerceContent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
        include: this.legacyInclude,
      }),
      this.prisma.commerceContent.count({ where }),
    ]);
    const viewer = await this.viewerState(posts.map((p) => p.id), userId);
    return {
      data: posts.map((p) => serializeLegacyPost(p, viewer)),
      pagination: buildMeta(page.page, page.limit, total, posts.length),
    };
  }

  async bySeller(
    sellerId: string,
    userId: string | undefined,
    page: PaginationDto,
  ) {
    const where = { ...this.legacyPostWhere, authorId: sellerId };
    const [posts, total] = await Promise.all([
      this.prisma.commerceContent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
        include: this.legacyInclude,
      }),
      this.prisma.commerceContent.count({ where }),
    ]);
    const viewer = await this.viewerState(posts.map((p) => p.id), userId);
    return {
      data: posts.map((p) => serializeLegacyPost(p, viewer)),
      pagination: buildMeta(page.page, page.limit, total, posts.length),
    };
  }

  async saved(userId: string, page: PaginationDto) {
    const where = {
      ...this.legacyPostWhere,
      saves: { some: { userId } },
    };
    const [posts, total] = await Promise.all([
      this.prisma.commerceContent.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
        include: this.legacyInclude,
      }),
      this.prisma.commerceContent.count({ where }),
    ]);
    const viewer = await this.viewerState(posts.map((p) => p.id), userId);
    return {
      data: posts.map((p) => serializeLegacyPost(p, viewer)),
      pagination: buildMeta(page.page, page.limit, total, posts.length),
    };
  }

  async single(id: string, userId?: string) {
    const post = await this.prisma.commerceContent.findFirst({
      where: { id, contentType: 'product_post' },
      include: this.legacyInclude,
    });
    if (!post) throw new NotFoundException('Post not found');
    const viewer = await this.viewerState([post.id], userId);
    return serializeLegacyPost(post, viewer);
  }

  async toggleLike(user: AuthUser, postId: string) {
    const userId = user.id;
    const post = await this.ensureExists(postId);
    const before = await this.prisma.commerceContentReaction.findUnique({
      where: { contentId_userId: { contentId: postId, userId } },
      select: { id: true },
    });

    await this.interactions.react(user, postId);

    // A like on a post that carries a product is demand for the product. Only
    // on the way in — un-liking is a correction, not negative demand, and
    // counting it as one would let a double-tap swing a trend.
    if (!before) await this.recordProductEngagement(post.id, userId);
    return this.single(postId, userId);
  }

  private async recordProductEngagement(
    contentId: string,
    userId: string,
  ): Promise<void> {
    const tag = await this.prisma.commerceContentProductTag
      .findFirst({
        where: { contentId },
        orderBy: { sortOrder: 'asc' },
        select: { productId: true },
      })
      .catch(() => null);
    if (!tag?.productId) return;
    this.signals.recordContentEngagement({
      productId: tag.productId,
      kind: 'post',
      userId,
    });
  }

  async toggleSave(user: AuthUser, postId: string) {
    await this.ensureExists(postId);
    await this.interactions.toggleSave(user, postId);
    return this.single(postId, user.id);
  }

  async share(user: AuthUser, postId: string) {
    await this.ensureExists(postId);
    await this.interactions.recordExternalShare(user, postId);
    return this.single(postId, user.id);
  }

  async listComments(postId: string, page: PaginationDto) {
    await this.ensureExists(postId);
    // Flat, as this contract always was. The platform threads replies; the old
    // client renders a list, so replies are folded into it in time order
    // rather than hidden — a reply she can see in the new app and not in the
    // old one is worse than one shown without its indent.
    const where = {
      contentId: postId,
      status: CommerceContentCommentStatus.VISIBLE,
    };
    const [comments, total] = await Promise.all([
      this.prisma.commerceContentComment.findMany({
        where,
        orderBy: { createdAt: 'desc' },
        skip: page.skip,
        take: page.limit,
        include: { user: true },
      }),
      this.prisma.commerceContentComment.count({ where }),
    ]);
    return {
      data: comments.map(serializeLegacyComment),
      pagination: buildMeta(page.page, page.limit, total, comments.length),
    };
  }

  async addComment(user: AuthUser, postId: string, content: string) {
    await this.ensureExists(postId);
    const comment = await this.interactions.comment(user, postId, content);
    return serializeLegacyComment(comment);
  }

  async deleteComment(user: AuthUser, postId: string, commentId: string) {
    const comment = await this.prisma.commerceContentComment.findFirst({
      where: { id: commentId, contentId: postId },
      select: { id: true },
    });
    if (!comment) throw new NotFoundException('Comment not found');
    await this.interactions.removeComment(user, commentId);
    return { message: 'Comment deleted' };
  }

  /**
   * The viewer's own state for a page of posts, in three queries rather than
   * three per post. Both indexes are `(user_id, content_id)`.
   */
  private async viewerState(
    contentIds: string[],
    userId?: string,
  ): Promise<LegacyViewerState> {
    if (!userId || contentIds.length === 0) return NO_LEGACY_VIEWER;
    const [reactions, saves] = await Promise.all([
      this.prisma.commerceContentReaction.findMany({
        where: { userId, contentId: { in: contentIds } },
        select: { contentId: true, emoji: true },
      }),
      this.prisma.commerceContentSave.findMany({
        where: { userId, contentId: { in: contentIds } },
        select: { contentId: true },
      }),
    ]);
    return {
      liked: new Set(reactions.map((r) => r.contentId)),
      saved: new Set(saves.map((s) => s.contentId)),
      viewed: new Set(),
      reactions: new Map(reactions.map((r) => [r.contentId, r.emoji])),
    };
  }

  private async ensureExists(postId: string) {
    const post = await this.prisma.commerceContent.findFirst({
      where: { id: postId, contentType: 'product_post' },
      select: { id: true, authorId: true },
    });
    if (!post) throw new NotFoundException('Post not found');
    return post;
  }
}
