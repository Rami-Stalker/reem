import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import {
  CommerceContentStatus,
  MediaType,
  Prisma,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { serializeLegacyStory } from '../../common/serializers';
import {
  AddHighlightItemDto,
  CreateHighlightDto,
  MAX_HIGHLIGHTS_PER_OWNER,
  MAX_ITEMS_PER_HIGHLIGHT,
  ReorderHighlightsDto,
  UpdateHighlightDto,
} from './dto/highlight.dto';


/** The states in which a story may sit on, and be shown from, a highlight. */
const KEEPABLE_STORY_STATUSES: CommerceContentStatus[] = [
  CommerceContentStatus.PUBLISHED,
  CommerceContentStatus.EXPIRED,
];
const storyInclude = {
  author: true,
  media: { orderBy: { sortOrder: 'asc' as const } },
} satisfies Prisma.CommerceContentInclude;

const highlightInclude = {
  items: {
    orderBy: [{ sortOrder: 'asc' as const }, { addedAt: 'asc' as const }],
    take: MAX_ITEMS_PER_HIGHLIGHT,
    include: { content: { include: storyInclude } },
  },
} satisfies Prisma.ProfileHighlightInclude;

type HighlightRecord = Prisma.ProfileHighlightGetPayload<{
  include: typeof highlightInclude;
}>;

/**
 * «الأبرز» — the stories she keeps on her page past their day.
 *
 * A story lasts twenty-four hours, which is the point of a story and the whole
 * problem with one: a boutique's size guide, a customer's «وصلت الطلبية», a
 * salon's before-and-after are each worth more than a day and each vanished.
 * A highlight is the permission to keep one, and a shelf to keep it on.
 *
 * **One implementation for both sides.** A shopper's page and a boutique's
 * storefront are the same object here — everything is keyed on the owner, and
 * the only difference between «إطلالاتي» and «مقاساتنا» is what is in them.
 * The seller-specific version of this feature would have been a second copy of
 * every method, which is how the two halves of a marketplace drift apart.
 *
 * **It points, it does not copy.** An item is a foreign key to the story,
 * cascading on delete, so a takedown, an edit or an author deleting her own
 * post reaches every shelf that carried it. A highlight that could outlive a
 * removed story would be a way to keep moderated content on a public page.
 */
@Injectable()
export class HighlightsService {
  constructor(private readonly prisma: PrismaService) {}

  // ── Reading ──────────────────────────────────────────────────────────────

  /**
   * One person's rail, as [viewerId] may see it.
   *
   * Her own is always visible, empty shelves included — she needs to see the
   * one she just made. Everyone else sees it only if the page is open to
   * them, and sees no empty shelves, because an empty shelf is a note to
   * herself rather than something published.
   */
  async listFor(ownerId: string, viewerId?: string) {
    const isOwner = !!viewerId && viewerId === ownerId;
    if (!isOwner) await this.assertPageVisible(ownerId);

    const highlights = await this.prisma.profileHighlight.findMany({
      where: { ownerId },
      orderBy: [{ sortOrder: 'asc' }, { createdAt: 'asc' }],
      take: MAX_HIGHLIGHTS_PER_OWNER,
      include: highlightInclude,
    });

    return highlights
      .map((highlight) => this.serialize(highlight, { isOwner }))
      .filter((highlight) => isOwner || highlight.items_count > 0);
  }

  /** One shelf and the stories on it, in order. */
  async detail(highlightId: string, viewerId?: string) {
    const highlight = await this.prisma.profileHighlight.findUnique({
      where: { id: highlightId },
      include: highlightInclude,
    });
    if (!highlight) throw new NotFoundException('Highlight not found');

    const isOwner = !!viewerId && viewerId === highlight.ownerId;
    if (!isOwner) await this.assertPageVisible(highlight.ownerId);

    return this.serialize(highlight, { isOwner, withStories: true });
  }

  /**
   * What she can put on a shelf: her own stories, live and expired.
   *
   * Expired ones are the whole reason this endpoint exists — the picker's job
   * is to show her the day she is about to lose, and the stories rail cannot,
   * because it only ever lists what has not expired yet.
   */
  async archive(ownerId: string, limit = 60) {
    const stories = await this.prisma.commerceContent.findMany({
      where: {
        authorId: ownerId,
        contentType: 'story',
        // EXPIRED as well as PUBLISHED: the expiry sweep moves a story to
        // EXPIRED when its day is over, and a picker that listed PUBLISHED
        // only lost every story the moment the sweep reached it — exactly
        // the stories this picker exists to keep.
        status: { in: KEEPABLE_STORY_STATUSES },
        removedAt: null,
      },
      orderBy: { createdAt: 'desc' },
      take: Math.min(Math.max(limit, 1), 200),
      include: storyInclude,
    });
    return stories.map((story) => serializeLegacyStory(story));
  }

  // ── Writing ──────────────────────────────────────────────────────────────

  async create(ownerId: string, dto: CreateHighlightDto) {
    const count = await this.prisma.profileHighlight.count({
      where: { ownerId },
    });
    if (count >= MAX_HIGHLIGHTS_PER_OWNER) {
      throw new BadRequestException(
        `A page may hold at most ${MAX_HIGHLIGHTS_PER_OWNER} highlights`,
      );
    }

    const contentIds = await this.ownedStoryIds(ownerId, dto.content_ids ?? []);

    const highlight = await this.prisma.profileHighlight.create({
      data: {
        ownerId,
        title: dto.title.trim(),
        coverUrl: dto.cover_url?.trim() || null,
        // At the end of the rail. `count` is the next free slot because the
        // reorder endpoint always renumbers from zero.
        sortOrder: count,
        items: {
          create: contentIds.map((contentId, index) => ({
            contentId,
            sortOrder: index,
          })),
        },
      },
      include: highlightInclude,
    });

    return this.serialize(highlight, { isOwner: true });
  }

  async update(ownerId: string, highlightId: string, dto: UpdateHighlightDto) {
    await this.requireOwned(ownerId, highlightId);
    const highlight = await this.prisma.profileHighlight.update({
      where: { id: highlightId },
      data: {
        ...(dto.title !== undefined && { title: dto.title.trim() }),
        // `null` clears a cover back to "use the first story's still", which
        // is a different instruction from "leave it alone".
        ...(dto.cover_url !== undefined && {
          coverUrl: dto.cover_url?.trim() || null,
        }),
        ...(dto.sort_order !== undefined && { sortOrder: dto.sort_order }),
      },
      include: highlightInclude,
    });
    return this.serialize(highlight, { isOwner: true });
  }

  async remove(ownerId: string, highlightId: string) {
    await this.requireOwned(ownerId, highlightId);
    // The items cascade; the stories themselves are untouched, which is the
    // difference between putting a shelf away and burning what was on it.
    await this.prisma.profileHighlight.delete({ where: { id: highlightId } });
    return { message: 'Highlight removed' };
  }

  /**
   * Her whole rail, renumbered from zero in the order she gave.
   *
   * One statement per shelf inside one transaction, rather than a PATCH each:
   * dragging one highlight past another moves both, and two requests leave a
   * visible half-applied order if the second is lost.
   */
  async reorder(ownerId: string, dto: ReorderHighlightsDto) {
    const owned = await this.prisma.profileHighlight.findMany({
      where: { ownerId },
      select: { id: true },
    });
    const ownedIds = new Set(owned.map((row) => row.id));
    const ordered = dto.highlight_ids.filter((id) => ownedIds.has(id));
    if (ordered.length !== dto.highlight_ids.length) {
      throw new ForbiddenException('That highlight is not yours');
    }

    await this.prisma.$transaction(
      ordered.map((id, index) =>
        this.prisma.profileHighlight.update({
          where: { id },
          data: { sortOrder: index },
        }),
      ),
    );
    return this.listFor(ownerId, ownerId);
  }

  async addItem(
    ownerId: string,
    highlightId: string,
    dto: AddHighlightItemDto,
  ) {
    await this.requireOwned(ownerId, highlightId);
    const [contentId] = await this.ownedStoryIds(ownerId, [dto.content_id]);

    const count = await this.prisma.profileHighlightItem.count({
      where: { highlightId },
    });
    if (count >= MAX_ITEMS_PER_HIGHLIGHT) {
      throw new BadRequestException(
        `A highlight may hold at most ${MAX_ITEMS_PER_HIGHLIGHT} stories`,
      );
    }

    // Adding a story that is already on the shelf moves it to the end rather
    // than failing — that is what the gesture means, and the unique index
    // would otherwise turn a harmless double-tap into an error.
    await this.prisma.profileHighlightItem.upsert({
      where: { highlightId_contentId: { highlightId, contentId } },
      create: { highlightId, contentId, sortOrder: count },
      update: { sortOrder: count },
    });
    await this.touch(highlightId);

    return this.detail(highlightId, ownerId);
  }

  async removeItem(ownerId: string, highlightId: string, contentId: string) {
    await this.requireOwned(ownerId, highlightId);
    await this.prisma.profileHighlightItem.deleteMany({
      where: { highlightId, contentId },
    });
    await this.touch(highlightId);
    return this.detail(highlightId, ownerId);
  }

  // ── Internals ────────────────────────────────────────────────────────────

  /**
   * Whether a stranger may look at this page at all.
   *
   * The same rule the content platform enforces with `authorIsPublic`: a
   * boutique is always visible, because a storefront nobody may look at is not
   * a storefront, and a shopper's page is visible only when she has opened it.
   */
  private async assertPageVisible(ownerId: string) {
    const owner = await this.prisma.user.findUnique({
      where: { id: ownerId },
      select: { role: true, profileIsPublic: true, disabledAt: true },
    });
    if (!owner || owner.disabledAt) {
      throw new NotFoundException('Profile not found');
    }
    const isSeller = owner.role === UserRole.SELLER;
    if (!isSeller && !owner.profileIsPublic) {
      throw new ForbiddenException('This page is private');
    }
  }

  private async requireOwned(ownerId: string, highlightId: string) {
    const highlight = await this.prisma.profileHighlight.findUnique({
      where: { id: highlightId },
      select: { ownerId: true },
    });
    if (!highlight) throw new NotFoundException('Highlight not found');
    if (highlight.ownerId !== ownerId) {
      throw new ForbiddenException('That highlight is not yours');
    }
  }

  /**
   * The subset of [contentIds] that are this owner's own published stories.
   *
   * Order is preserved from the request, because it is the order she arranged
   * them in. Anything that is not hers, is not a story, or has been taken down
   * is refused outright rather than silently dropped: a shelf that quietly
   * loses half of what she picked is worse than one that says why.
   */
  private async ownedStoryIds(ownerId: string, contentIds: string[]) {
    if (contentIds.length === 0) return [];
    const unique = [...new Set(contentIds)];
    const rows = await this.prisma.commerceContent.findMany({
      where: {
        id: { in: unique },
        authorId: ownerId,
        contentType: 'story',
        status: { in: KEEPABLE_STORY_STATUSES },
        removedAt: null,
      },
      select: { id: true },
    });
    const found = new Set(rows.map((row) => row.id));
    const missing = unique.filter((id) => !found.has(id));
    if (missing.length > 0) {
      throw new BadRequestException(
        'A highlight may only hold your own published stories',
      );
    }
    return unique;
  }

  /** Keeps `updated_at` honest so the rail can be cached on it. */
  private touch(highlightId: string) {
    return this.prisma.profileHighlight.update({
      where: { id: highlightId },
      data: { updatedAt: new Date() },
    });
  }

  private serialize(
    highlight: HighlightRecord,
    options: { isOwner: boolean; withStories?: boolean },
  ) {
    // A story she deleted, or one a moderator took down, leaves every shelf
    // it was on — a takedown has to reach every page, and a highlight is a
    // page. The item row stays, so a reinstated story comes back to it.
    const items = highlight.items.filter(
      (item) =>
        item.content !== null &&
        item.content.removedAt === null &&
        KEEPABLE_STORY_STATUSES.includes(item.content.status),
    );
    const firstImage = items.find(
      (item) =>
        (item.content.media ?? []).some(
          (media) => media.type === MediaType.image,
        ) || (item.content.media ?? []).length > 0,
    );

    return {
      id: highlight.id,
      owner_id: highlight.ownerId,
      title: highlight.title,
      // Her cover if she picked one; otherwise the first story's still, which
      // is what the rail draws and what she expects without being asked.
      cover_url:
        highlight.coverUrl ??
        (firstImage?.content.media ?? [])[0]?.thumbnailUrl ??
        (firstImage?.content.media ?? [])[0]?.url ??
        null,
      items_count: items.length,
      sort_order: highlight.sortOrder,
      is_mine: options.isOwner,
      created_at: highlight.createdAt.toISOString(),
      updated_at: highlight.updatedAt.toISOString(),
      ...(options.withStories
        ? {
            stories: items.map((item) => serializeLegacyStory(item.content)),
          }
        : {}),
    };
  }
}
