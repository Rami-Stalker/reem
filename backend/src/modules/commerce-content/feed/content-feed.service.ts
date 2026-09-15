import { Injectable, NotFoundException } from '@nestjs/common';
import {
  CommerceAuthorKind,
  CommerceContentPublicationChannel,
  CommerceContentStatus,
  CommerceContentVisibility,
  Prisma,
} from '@prisma/client';
import { PrismaService } from '../../../prisma/prisma.service';
import { CacheService } from '../../../common/cache/cache.service';
import {
  buildCursorMeta,
  Cursor,
  CursorPageDto,
  decodeCursor,
} from '../../../common/dto/cursor-pagination.dto';
import { commerceContentInclude } from '../commerce-content.repository';
import { utcTimestamp } from '../../../common/sql/utc-timestamp';

const FEED_CACHE_PREFIX = 'commerce-content:feed';

export type FeedRowKind = 'OWN' | 'RESHARE';

interface TimelineRow {
  kind: FeedRowKind;
  id: string;
  sortAt: Date;
}

/**
 * Every way of reading the feed, and the one visibility rule they all share.
 *
 * ## Visibility is composed, once
 *
 * Three facts decide whether a viewer may see a piece: the content's own
 * `visibility`, whether the author's page is open, and whether the viewer
 * follows her. The repository used to hard-filter `visibility: PUBLIC`, which
 * meant `FOLLOWERS` was an enum value nothing honoured — content marked
 * followers-only was invisible to everyone including her followers.
 *
 * The rule lives in `visibilityWhere` and `visibilitySql` and nowhere else. Two
 * spellings of one rule is already one more than is safe, and they are kept
 * adjacent so a change to either is obviously a change to both.
 *
 * ## Removed content is gone from every read
 *
 * Not merely hidden from the home feed. A takedown has to reach the boutique
 * page, the following feed, the product rail, the resharer's page and any
 * cursor already issued — which is precisely why the timeline is a live query
 * rather than a materialised list somebody has to remember to update.
 */
@Injectable()
export class ContentFeedService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
  ) {}

  // ── The rule ──────────────────────────────────────────────────────────────

  /**
   * Prisma spelling. `viewerId` undefined means a signed-out visitor, who sees
   * only what is public from an open page.
   */
  private visibilityWhere(viewerId?: string): Prisma.CommerceContentWhereInput {
    const live: Prisma.CommerceContentWhereInput = {
      status: CommerceContentStatus.PUBLISHED,
      moderationStatus: { not: 'REJECTED' },
      OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
    };

    const publicBranch: Prisma.CommerceContentWhereInput = {
      visibility: CommerceContentVisibility.PUBLIC,
      authorIsPublic: true,
    };

    if (!viewerId) return { AND: [live, publicBranch] };

    return {
      AND: [
        live,
        {
          OR: [
            // Her own, always — including while it is only visible to her.
            { authorId: viewerId },
            publicBranch,
            {
              visibility: CommerceContentVisibility.FOLLOWERS,
              authorIsPublic: true,
              author: { followers: { some: { followerId: viewerId } } },
            },
          ],
        },
      ],
    };
  }

  /**
   * SQL spelling, for the two feeds that need a UNION the query builder cannot
   * express. `alias` is the content table's alias in the surrounding query.
   */
  private visibilitySql(alias: string, viewerId?: string): Prisma.Sql {
    const a = Prisma.raw(`"${alias}"`);
    const live = Prisma.sql`
      ${a}."status" = 'PUBLISHED'
      AND ${a}."moderation_status" <> 'REJECTED'
      AND (${a}."expires_at" IS NULL OR ${a}."expires_at" > now())`;

    if (!viewerId) {
      return Prisma.sql`${live}
        AND ${a}."visibility" = 'PUBLIC' AND ${a}."author_is_public"`;
    }

    return Prisma.sql`${live} AND (
        ${a}."author_id" = ${viewerId}::uuid
        OR (${a}."visibility" = 'PUBLIC' AND ${a}."author_is_public")
        OR (${a}."visibility" = 'FOLLOWERS' AND ${a}."author_is_public"
            AND EXISTS (SELECT 1 FROM "follows" f
                        WHERE f."follower_id" = ${viewerId}::uuid
                          AND f."following_id" = ${a}."author_id"))
      )`;
  }

  // ── Her own controls ──────────────────────────────────────────────────────

  /**
   * What she asked not to see: pieces marked «غير مهتمة» and accounts she
   * muted.
   *
   * Applied to **feeds** only — home, reels, following, stories. Not to a page
   * she deliberately opens: muting an account quiets it, it does not make the
   * boutique unreachable, and a woman who taps into a page she muted should
   * find it there. Same two spellings as the visibility rule, same reason.
   */
  private controlsWhere(viewerId?: string): Prisma.CommerceContentWhereInput[] {
    if (!viewerId) return [];
    return [
      { hiddenBy: { none: { userId: viewerId } } },
      { author: { mutesReceived: { none: { muterId: viewerId } } } },
    ];
  }

  private controlsSql(alias: string, viewerId: string): Prisma.Sql {
    const a = Prisma.raw(`"${alias}"`);
    return Prisma.sql`
      NOT EXISTS (SELECT 1 FROM "content_hides" h
                  WHERE h."user_id" = ${viewerId}::uuid AND h."content_id" = ${a}."id")
      AND NOT EXISTS (SELECT 1 FROM "user_mutes" m
                      WHERE m."muter_id" = ${viewerId}::uuid AND m."muted_id" = ${a}."author_id")`;
  }

  // ── The simple feeds ──────────────────────────────────────────────────────

  /**
   * Home, discover, reels, a boutique's page, a product's rail — all the same
   * shape: one indexed scan over `commerce_contents`, keyset-ordered.
   */
  async feed(
    page: CursorPageDto,
    filters: {
      viewerId?: string;
      channel?: CommerceContentPublicationChannel;
      contentType?: string;
      authorId?: string;
      authorKind?: CommerceAuthorKind;
      productId?: string;
    } = {},
  ) {
    const cursor = decodeCursor(page.cursor);

    const where: Prisma.CommerceContentWhereInput = {
      AND: [
        this.visibilityWhere(filters.viewerId),
        this.keysetWhere(cursor),
        ...(filters.channel
          ? [{ publicationTargets: { has: filters.channel } }]
          : []),
        ...(filters.contentType ? [{ contentType: filters.contentType }] : []),
        ...(filters.authorId ? [{ authorId: filters.authorId }] : []),
        ...(filters.authorKind ? [{ authorKind: filters.authorKind }] : []),
        ...(filters.productId
          ? [{ productTags: { some: { productId: filters.productId } } }]
          : []),
        // A page or a product rail is somewhere she went on purpose; a feed is
        // something handed to her, and only a feed honours her mutes.
        ...(filters.authorId || filters.productId
          ? []
          : this.controlsWhere(filters.viewerId)),
      ],
    };

    // One extra row is how we know there is a next page without a COUNT — and
    // a COUNT over a feed is the query that makes the feed slow.
    const rows = await this.prisma.commerceContent.findMany({
      where,
      orderBy: [{ publishedAt: 'desc' }, { id: 'desc' }],
      take: page.limit + 1,
      include: commerceContentInclude,
    });

    return this.pageOf(rows, page.limit);
  }

  /**
   * The anonymous home feed, cached briefly.
   *
   * Only this one. A viewer-scoped feed must never share a cache key with
   * another account's — the previous implementation cached on page and channel
   * alone, which was harmless while every feed was public and would leak one
   * woman's followers-only content to a stranger the moment it was not.
   */
  async publicFeed(page: CursorPageDto, channel?: CommerceContentPublicationChannel) {
    const key = [FEED_CACHE_PREFIX, 'anon', page.cursor ?? 'head', page.limit, channel ?? 'all'].join(':');
    return this.cache.wrap(key, 15_000, () => this.feed(page, { channel }));
  }

  /** Live stories, grouped by the woman who posted them. */
  async storiesTray(viewerId?: string, authorId?: string) {
    const rows = await this.prisma.commerceContent.findMany({
      where: {
        AND: [
          this.visibilityWhere(viewerId),
          { contentType: 'story' },
          { expiresAt: { gt: new Date() } },
          // One woman's stories, for her page's ring — or the whole tray,
          // minus the accounts she muted.
          ...(authorId ? [{ authorId }] : this.controlsWhere(viewerId)),
        ],
      },
      orderBy: [{ createdAt: 'asc' }],
      include: commerceContentInclude,
    });

    // Live stories are bounded — a couple of dozen boutiques times a handful
    // each — so grouping in memory is correct here and paging would be
    // pretending otherwise. The contract has never had pagination.
    const byAuthor = new Map<string, typeof rows>();
    for (const row of rows) {
      const bucket = byAuthor.get(row.authorId);
      if (bucket) bucket.push(row);
      else byAuthor.set(row.authorId, [row]);
    }

    const seen = viewerId
      ? new Set(
          (
            await this.prisma.commerceContentViewer.findMany({
              where: {
                userId: viewerId,
                contentId: { in: rows.map((row) => row.id) },
              },
              select: { contentId: true },
            })
          ).map((view) => view.contentId),
        )
      : new Set<string>();

    return [...byAuthor.values()].map((stories) => ({
      author: stories[0].author,
      stories,
      // Her ring is unbroken until every one has been watched.
      all_seen: stories.every((story) => seen.has(story.id)),
    }));
  }

  // ── The two feeds that need a UNION ───────────────────────────────────────

  /**
   * A woman's page: what she published, and what she added to it.
   *
   * Two sources, one order, one cursor. Done as a `UNION ALL` returning ids
   * rather than a materialised timeline table, and the deciding argument is not
   * speed — it is that a takedown must vanish from every page the post was
   * added to. Here that is automatic, because the visibility predicate is
   * re-read on every page load. With a projection it would be a fan-out to N
   * rows, and one missed row leaves removed content on somebody's page.
   *
   * A reshare sorts by **its own** timestamp, not the original's: adding a
   * year-old look to her page should put it at the top, where she put it.
   */
  async userTimeline(ownerId: string, page: CursorPageDto, viewerId?: string) {
    const owner = await this.prisma.user.findUnique({
      where: { id: ownerId },
      select: { id: true, profileIsPublic: true },
    });
    if (!owner) throw new NotFoundException('User not found');

    const cursor = decodeCursor(page.cursor);
    const take = page.limit + 1;

    const rows = await this.prisma.$queryRaw<TimelineRow[]>`
      (
        SELECT 'OWN'::text AS kind, c."id", COALESCE(c."published_at", c."created_at") AS "sortAt"
        FROM "commerce_contents" c
        WHERE c."author_id" = ${ownerId}::uuid
          AND ${this.visibilitySql('c', viewerId)}
          AND (COALESCE(c."published_at", c."created_at"), c."id") < (${utcTimestamp(cursor.at)}, ${cursor.id}::uuid)
        ORDER BY "sortAt" DESC, c."id" DESC
        LIMIT ${take}
      )
      UNION ALL
      (
        SELECT 'RESHARE'::text AS kind, r."id", r."created_at" AS "sortAt"
        FROM "commerce_content_reshares" r
        JOIN "commerce_contents" c ON c."id" = r."source_content_id"
        WHERE r."resharer_id" = ${ownerId}::uuid
          AND (r."resharer_is_public" OR r."resharer_id" = ${viewerId ?? null}::uuid)
          AND ${this.visibilitySql('c', viewerId)}
          AND (r."created_at", r."id") < (${utcTimestamp(cursor.at)}, ${cursor.id}::uuid)
        ORDER BY r."created_at" DESC, r."id" DESC
        LIMIT ${take}
      )
      ORDER BY "sortAt" DESC, "id" DESC
      LIMIT ${take}`;

    return this.hydrate(rows, page.limit);
  }

  /** Everything the women she follows have published or added to their pages. */
  async followingFeed(viewerId: string, page: CursorPageDto) {
    const follows = await this.prisma.follow.findMany({
      where: { followerId: viewerId },
      select: { followingId: true },
      orderBy: { createdAt: 'desc' },
      // Capped deliberately. A follow graph is unbounded and an `IN` list is
      // not; the five hundred most recent is the window the feed reads, and
      // saying so here is better than discovering the ceiling in production.
      take: 500,
    });
    if (follows.length === 0) {
      return { items: [], meta: buildCursorMeta(page.limit, false, null) };
    }

    const ids = follows.map((follow) => follow.followingId);
    const cursor = decodeCursor(page.cursor);
    const take = page.limit + 1;

    const rows = await this.prisma.$queryRaw<TimelineRow[]>`
      (
        SELECT 'OWN'::text AS kind, c."id", COALESCE(c."published_at", c."created_at") AS "sortAt"
        FROM "commerce_contents" c
        WHERE c."author_id" = ANY(${ids}::uuid[])
          AND ${this.visibilitySql('c', viewerId)}
          AND ${this.controlsSql('c', viewerId)}
          AND (COALESCE(c."published_at", c."created_at"), c."id") < (${utcTimestamp(cursor.at)}, ${cursor.id}::uuid)
        ORDER BY "sortAt" DESC, c."id" DESC
        LIMIT ${take}
      )
      UNION ALL
      (
        SELECT 'RESHARE'::text AS kind, r."id", r."created_at" AS "sortAt"
        FROM "commerce_content_reshares" r
        JOIN "commerce_contents" c ON c."id" = r."source_content_id"
        WHERE r."resharer_id" = ANY(${ids}::uuid[])
          AND r."resharer_is_public"
          AND ${this.visibilitySql('c', viewerId)}
          AND ${this.controlsSql('c', viewerId)}
          AND NOT EXISTS (SELECT 1 FROM "user_mutes" m
                          WHERE m."muter_id" = ${viewerId}::uuid AND m."muted_id" = r."resharer_id")
          AND (r."created_at", r."id") < (${utcTimestamp(cursor.at)}, ${cursor.id}::uuid)
        ORDER BY r."created_at" DESC, r."id" DESC
        LIMIT ${take}
      )
      ORDER BY "sortAt" DESC, "id" DESC
      LIMIT ${take}`;

    return this.hydrate(rows, page.limit);
  }

  /** Her saved shelf. */
  async saved(viewerId: string, page: CursorPageDto) {
    const cursor = decodeCursor(page.cursor);
    const saves = await this.prisma.commerceContentSave.findMany({
      where: {
        userId: viewerId,
        OR: [
          { createdAt: { lt: cursor.at } },
          { createdAt: cursor.at, id: { lt: cursor.id } },
        ],
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      take: page.limit + 1,
      select: { id: true, createdAt: true, contentId: true },
    });

    const hasMore = saves.length > page.limit;
    const window = hasMore ? saves.slice(0, page.limit) : saves;

    const contents = await this.prisma.commerceContent.findMany({
      where: {
        id: { in: window.map((save) => save.contentId) },
        // A saved post that was later taken down leaves her shelf. She saved a
        // dress, not a removal notice.
        status: { not: CommerceContentStatus.REMOVED },
      },
      include: commerceContentInclude,
    });
    const byId = new Map(contents.map((content) => [content.id, content]));

    return {
      items: window
        .map((save) => byId.get(save.contentId))
        .filter((content): content is NonNullable<typeof content> => Boolean(content)),
      meta: buildCursorMeta(
        page.limit,
        hasMore,
        window.length > 0
          ? { at: window[window.length - 1].createdAt, id: window[window.length - 1].id }
          : null,
      ),
    };
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  private keysetWhere(cursor: Cursor): Prisma.CommerceContentWhereInput {
    return {
      OR: [
        { publishedAt: { lt: cursor.at } },
        { publishedAt: cursor.at, id: { lt: cursor.id } },
      ],
    };
  }

  private pageOf<T extends { id: string; publishedAt: Date | null; createdAt: Date }>(
    rows: T[],
    limit: number,
  ) {
    const hasMore = rows.length > limit;
    const items = hasMore ? rows.slice(0, limit) : rows;
    const last = items[items.length - 1];
    return {
      items,
      meta: buildCursorMeta(
        limit,
        hasMore,
        last ? { at: last.publishedAt ?? last.createdAt, id: last.id } : null,
      ),
    };
  }

  /**
   * Ids and kinds from the union, back into full rows.
   *
   * Two queries rather than one join, and re-ordered in memory to the order the
   * union already decided — a second ORDER BY over the hydrating query would be
   * a second chance to disagree with the first.
   */
  private async hydrate(rows: TimelineRow[], limit: number) {
    const hasMore = rows.length > limit;
    const window = hasMore ? rows.slice(0, limit) : rows;
    if (window.length === 0) {
      return { items: [], meta: buildCursorMeta(limit, false, null) };
    }

    const ownIds = window.filter((row) => row.kind === 'OWN').map((row) => row.id);
    const reshareIds = window
      .filter((row) => row.kind === 'RESHARE')
      .map((row) => row.id);

    const [own, reshares] = await Promise.all([
      ownIds.length
        ? this.prisma.commerceContent.findMany({
            where: { id: { in: ownIds } },
            include: commerceContentInclude,
          })
        : Promise.resolve([]),
      reshareIds.length
        ? this.prisma.commerceContentReshare.findMany({
            where: { id: { in: reshareIds } },
            include: {
              resharer: true,
              sourceContent: { include: commerceContentInclude },
            },
          })
        : Promise.resolve([]),
    ]);

    const ownById = new Map(own.map((row) => [row.id, row]));
    const reshareById = new Map(reshares.map((row) => [row.id, row]));

    const items = window
      .map((row) =>
        row.kind === 'OWN'
          ? ownById.get(row.id) && { kind: 'own' as const, content: ownById.get(row.id)! }
          : reshareById.get(row.id) && {
              kind: 'reshare' as const,
              reshare: reshareById.get(row.id)!,
            },
      )
      .filter(Boolean);

    const last = window[window.length - 1];
    return {
      items,
      meta: buildCursorMeta(limit, hasMore, { at: last.sortAt, id: last.id }),
    };
  }
}
