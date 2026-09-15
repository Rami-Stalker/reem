import {
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CommerceContentCommentStatus,
  ModerationStatus,
  ProductComment,
  ProductStatus,
  User,
  UserRole,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { assertCanManage } from '../../common/authz';
import { buildMeta, PaginationDto } from '../../common/dto/pagination.dto';
import { PRODUCT_CARD_INCLUDE } from '../../common/catalog/product-include';
import {
  serializeProduct,
  serializePublicUser,
} from '../../common/serializers';
import { ContentReportReason } from '../commerce-content/moderation/content-moderation.service';

/** What the viewer has done to a product, plus its live tallies. */
export interface ProductEngagement {
  likes_count: number;
  comments_count: number;
  shares_count: number;
  picks_count: number;
  is_liked: boolean;
  is_saved: boolean;
  is_picked: boolean;
}

/** A product a woman can still see on somebody's page. */
const VISIBLE_ON_A_PAGE: ProductStatus[] = [
  ProductStatus.ACTIVE,
  ProductStatus.OUT_OF_STOCK,
];

/**
 * The post gestures, on the catalogue.
 *
 * The client's words: every product in the app, in every shape, should be
 * liked, commented on, shared and added to a page the way a post in «وصل
 * حديثاً» is. A product is not an author's story, so none of this goes through
 * the content platform — there is no author to notify and no moderation
 * lifecycle to join. It is a small, separate ledger keyed on the canonical
 * product.
 *
 * ## Every write is a desired state, not a toggle
 *
 * `like` and `unlike` are two calls, and each is idempotent. The app's outbox
 * replays a tap made in a lift when the signal comes back; a toggle replayed
 * twice undoes itself, a desired state replayed twice is still true.
 *
 * ## Counters move only when a row did
 *
 * `createMany({ skipDuplicates })` and `deleteMany` report how many rows they
 * touched, and the counter moves by exactly that, inside the same
 * transaction. Two phones liking at once cannot count twice, and an unlike of
 * something never liked cannot drive a count negative. (`skipDuplicates` is
 * `ON CONFLICT DO NOTHING`, so a duplicate never raises P2002 inside the
 * transaction and aborts it.)
 */
@Injectable()
export class ProductSocialService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Likes ─────────────────────────────────────────────────────────────────

  async like(userId: string, productId: string) {
    await this.requireProduct(productId);
    return this.prisma.$transaction(async (tx) => {
      const { count } = await tx.productLike.createMany({
        data: [{ productId, userId }],
        skipDuplicates: true,
      });
      const product = await tx.product.update({
        where: { id: productId },
        data: count > 0 ? { likesCount: { increment: count } } : {},
        select: { likesCount: true },
      });
      return { is_liked: true, likes_count: product.likesCount };
    });
  }

  async unlike(userId: string, productId: string) {
    await this.requireProduct(productId);
    return this.prisma.$transaction(async (tx) => {
      const { count } = await tx.productLike.deleteMany({
        where: { productId, userId },
      });
      const product = await tx.product.update({
        where: { id: productId },
        data: count > 0 ? { likesCount: { decrement: count } } : {},
        select: { likesCount: true },
      });
      return { is_liked: false, likes_count: product.likesCount };
    });
  }

  // ── Shares ────────────────────────────────────────────────────────────────

  /**
   * An external share — WhatsApp, a copied link. The app calls this only after
   * the share sheet reports she went through with it.
   */
  async share(productId: string) {
    await this.requireProduct(productId);
    const product = await this.prisma.product.update({
      where: { id: productId },
      data: { sharesCount: { increment: 1 } },
      select: { sharesCount: true },
    });
    return { shares_count: product.sharesCount };
  }

  // ── «أضيفي إلى صفحتي» ─────────────────────────────────────────────────────

  async pick(userId: string, productId: string, note?: string) {
    await this.requireProduct(productId);
    const trimmed = note?.trim() || null;
    return this.prisma.$transaction(async (tx) => {
      const { count } = await tx.productPick.createMany({
        data: [{ productId, userId, note: trimmed }],
        skipDuplicates: true,
      });
      // Picking again with a new note edits the note; it is not a second pick.
      if (count === 0 && note !== undefined) {
        await tx.productPick.updateMany({
          where: { productId, userId },
          data: { note: trimmed },
        });
      }
      const product = await tx.product.update({
        where: { id: productId },
        data: count > 0 ? { picksCount: { increment: count } } : {},
        select: { picksCount: true },
      });
      return { is_picked: true, picks_count: product.picksCount };
    });
  }

  async unpick(userId: string, productId: string) {
    await this.requireProduct(productId);
    return this.prisma.$transaction(async (tx) => {
      const { count } = await tx.productPick.deleteMany({
        where: { productId, userId },
      });
      const product = await tx.product.update({
        where: { id: productId },
        data: count > 0 ? { picksCount: { decrement: count } } : {},
        select: { picksCount: true },
      });
      return { is_picked: false, picks_count: product.picksCount };
    });
  }

  /**
   * The pieces on a woman's page.
   *
   * A customer's page is private until she opens it, and her picks follow the
   * page: a stranger reading a closed page gets `is_private` and nothing else.
   * Decided here, on every read, so closing her page takes effect on the next
   * load rather than whenever a projection is rebuilt.
   */
  async picksOf(ownerId: string, page: PaginationDto, viewerId?: string) {
    const owner = await this.prisma.user.findUnique({
      where: { id: ownerId },
      select: { id: true, role: true, profileIsPublic: true },
    });
    if (!owner) throw new NotFoundException('User not found');

    if (this.isClosedTo(owner, viewerId)) {
      return {
        data: [],
        pagination: buildMeta(page.page, page.limit, 0, 0),
        is_private: true,
      };
    }

    const where = {
      userId: owner.id,
      product: { status: { in: VISIBLE_ON_A_PAGE } },
    };
    const [picks, total] = await Promise.all([
      this.prisma.productPick.findMany({
        where,
        orderBy: [{ createdAt: 'desc' as const }, { id: 'desc' as const }],
        skip: page.skip,
        take: page.limit,
        include: { product: { include: PRODUCT_CARD_INCLUDE } },
      }),
      this.prisma.productPick.count({ where }),
    ]);

    const saved = await this.savedSet(
      viewerId,
      picks.map((pick) => pick.productId),
    );

    return {
      data: picks.map((pick) => ({
        ...serializeProduct(pick.product, {
          isLiked: saved.has(pick.productId),
        }),
        pick: {
          note: pick.note,
          created_at: pick.createdAt.toISOString(),
        },
      })),
      pagination: buildMeta(page.page, page.limit, total, picks.length),
      is_private: false,
    };
  }

  /** How many picks a viewer may see on this page — for the profile header. */
  async visiblePicksCount(
    owner: { id: string; role: UserRole; profileIsPublic: boolean },
    viewerId?: string,
  ) {
    if (this.isClosedTo(owner, viewerId)) return 0;
    return this.prisma.productPick.count({
      where: {
        userId: owner.id,
        product: { status: { in: VISIBLE_ON_A_PAGE } },
      },
    });
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  /**
   * Same wire shape as `/posts/:id/comments`, on purpose: the app's comment
   * sheet reads one shape, so a product thread and a post thread are the same
   * screen with a different address.
   */
  async listComments(productId: string, page: PaginationDto) {
    await this.requireProduct(productId);
    const where = {
      productId,
      status: CommerceContentCommentStatus.VISIBLE,
    };
    const [comments, total] = await Promise.all([
      this.prisma.productComment.findMany({
        where,
        orderBy: [{ createdAt: 'desc' as const }, { id: 'desc' as const }],
        skip: page.skip,
        take: page.limit,
        include: { user: true },
      }),
      this.prisma.productComment.count({ where }),
    ]);
    return {
      data: comments.map(serializeProductComment),
      pagination: buildMeta(page.page, page.limit, total, comments.length),
    };
  }

  async addComment(user: AuthUser, productId: string, content: string) {
    await this.requireProduct(productId);
    const body = content.trim();
    const comment = await this.prisma.$transaction(async (tx) => {
      const created = await tx.productComment.create({
        data: { productId, userId: user.id, body },
        include: { user: true },
      });
      await tx.product.update({
        where: { id: productId },
        data: { commentsCount: { increment: 1 } },
      });
      return created;
    });
    return serializeProductComment(comment);
  }

  /**
   * Her own comment, or a moderator's removal. The row stays, marked REMOVED
   * with who removed it — see the schema for why.
   */
  async removeComment(user: AuthUser, productId: string, commentId: string) {
    const comment = await this.prisma.productComment.findFirst({
      where: { id: commentId, productId },
      select: { id: true, userId: true, status: true },
    });
    if (!comment) throw new NotFoundException('Comment not found');
    if (comment.status !== CommerceContentCommentStatus.VISIBLE) {
      return { message: 'Comment deleted' };
    }
    assertCanManage(comment.userId, user);

    await this.prisma.$transaction(async (tx) => {
      // Conditional on still being visible, so two deletes racing each other
      // decrement the tally once.
      const { count } = await tx.productComment.updateMany({
        where: { id: commentId, status: CommerceContentCommentStatus.VISIBLE },
        data: {
          status: CommerceContentCommentStatus.REMOVED,
          removedById: user.id,
          removalReason: comment.userId === user.id ? 'author' : 'moderator',
        },
      });
      if (count > 0) {
        await tx.product.update({
          where: { id: productId },
          data: { commentsCount: { decrement: count } },
        });
      }
    });
    return { message: 'Comment deleted' };
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  /**
   * Into the same moderation queue as everything else, as a `product` case.
   * Reporting twice is one report — the same guard content has.
   */
  async report(
    user: AuthUser,
    productId: string,
    reason: ContentReportReason,
    detail?: string,
  ) {
    await this.requireProduct(productId);
    const existing = await this.prisma.moderationCase.findFirst({
      where: {
        targetType: 'product',
        targetId: productId,
        reporterId: user.id,
        status: ModerationStatus.OPEN,
      },
      select: { id: true },
    });
    if (existing) return { reported: true, already: true };

    await this.prisma.moderationCase.create({
      data: {
        targetType: 'product',
        targetId: productId,
        reporterId: user.id,
        reason: detail?.trim() ? `${reason}: ${detail.trim()}` : reason,
      },
    });
    return { reported: true, already: false };
  }

  // ── The batch read ────────────────────────────────────────────────────────

  /**
   * Tallies and the viewer's own state for a screen of products, in four
   * queries however many cards are on it.
   *
   * Separate from the card JSON on purpose. Products are serialized by a
   * dozen endpoints — search, departments, the stylist, the closet — and
   * threading a viewer's likes and picks through every one would be a dozen
   * places to forget it. The card carries the tallies it was cached with; this
   * answers what is true now, for her.
   */
  async engagement(
    productIds: string[],
    viewerId?: string,
  ): Promise<Record<string, ProductEngagement>> {
    const ids = [...new Set(productIds)];
    if (ids.length === 0) return {};

    const [products, likes, saves, picks] = await Promise.all([
      this.prisma.product.findMany({
        where: { id: { in: ids } },
        select: {
          id: true,
          likesCount: true,
          commentsCount: true,
          sharesCount: true,
          picksCount: true,
        },
      }),
      viewerId
        ? this.prisma.productLike.findMany({
            where: { userId: viewerId, productId: { in: ids } },
            select: { productId: true },
          })
        : Promise.resolve([]),
      this.savedSet(viewerId, ids),
      viewerId
        ? this.prisma.productPick.findMany({
            where: { userId: viewerId, productId: { in: ids } },
            select: { productId: true },
          })
        : Promise.resolve([]),
    ]);

    const liked = new Set(likes.map((row) => row.productId));
    const picked = new Set(picks.map((row) => row.productId));

    return Object.fromEntries(
      products.map((product) => [
        product.id,
        {
          likes_count: product.likesCount,
          comments_count: product.commentsCount,
          shares_count: product.sharesCount,
          picks_count: product.picksCount,
          is_liked: liked.has(product.id),
          is_saved: saves.has(product.id),
          is_picked: picked.has(product.id),
        },
      ]),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  private isClosedTo(
    owner: { id: string; role: UserRole; profileIsPublic: boolean },
    viewerId?: string,
  ) {
    return (
      owner.role === UserRole.CUSTOMER &&
      !owner.profileIsPublic &&
      viewerId !== owner.id
    );
  }

  private async requireProduct(productId: string) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: { id: true, status: true },
    });
    if (!product) throw new NotFoundException('Product not found');
    // A draft or archived listing is not somewhere a conversation can start.
    if (!VISIBLE_ON_A_PAGE.includes(product.status)) {
      throw new ForbiddenException('This product is not available');
    }
    return product;
  }

  /** The bookmark on a product is a favourite — «المفضّلة». */
  private async savedSet(userId: string | undefined, productIds: string[]) {
    if (!userId || productIds.length === 0) return new Set<string>();
    const rows = await this.prisma.favorite.findMany({
      where: { userId, productId: { in: productIds } },
      select: { productId: true },
    });
    return new Set(rows.map((row) => row.productId));
  }
}

/** The legacy comment shape — see `serializeLegacyComment`. */
export function serializeProductComment(comment: ProductComment & { user: User }) {
  return {
    id: comment.id,
    user: serializePublicUser(comment.user),
    content: comment.body,
    likes_count: 0,
    created_at: comment.createdAt.toISOString(),
  };
}
