import { randomUUID } from 'crypto';
import { Injectable, Logger, Optional } from '@nestjs/common';
import { Prisma, UserRole } from '@prisma/client';
import { CacheService } from '../../../common/cache/cache.service';
import { decodeCursor, encodeCursor } from '../../../common/dto/cursor-pagination.dto';
import { ScheduledJob } from '../../../common/scheduling/scheduled-job.decorator';
import { utcTimestamp } from '../../../common/sql/utc-timestamp';
import { PrismaService } from '../../../prisma/prisma.service';
import { AdTiersService } from '../../promotions/ad-tiers.service';
import { TIER_ORDER, tierRank } from '../../promotions/ad-plans';
import { commerceContentInclude } from '../commerce-content.repository';
import { contentControlsSql, contentVisibilitySql } from '../feed/content-feed.service';
import {
  CandidateFacts,
  FeedKind,
  RANK_WEIGHTS_SETTING,
  RankReason,
  mergeWeights,
  orderStoryTray,
  rankFeed,
  seededRandom,
} from './feed-rank';

/** Every candidate keeps its place; the pools together stay well under this. */
const SESSION_DEPTH = 1000;
/** How long a session's order is kept, so her next page agrees with the last. */
const SESSION_TTL_MS = 25 * 60_000;
/** The home page's first page re-ranks once its order is this old. */
const HOME_REFRESH_MS = 3 * 60_000;
/** A guest's ranking is the same for every guest; recomputed this often. */
const GUEST_TTL_MS = 2 * 60_000;
/** The look-back for her history with authors and categories. */
const HISTORY_DAYS = 60;
/** A piece served this recently counts as shown. */
const SEEN_DAYS = 7;

/** System setting: `false` turns every ranked feed back to newest-first. */
export const RANKING_ENABLED_SETTING = 'feed.ranking_enabled';

/** A ranked cursor: `r.<session>.<offset>`. Anything else is a keyset cursor. */
const RANKED_PREFIX = 'r.';

export type RankedSurface = 'feed' | 'reels' | 'posts';

interface Session {
  ids: string[];
  reasons: Record<string, RankReason>;
  /** Where the chronological continuation starts once the ranked list ends. */
  oldest: { at: string; id: string } | null;
  rankedAt: number;
}

/**
 * A session as the cache holds it: the ids joined, one letter per reason.
 * Several times smaller than the arrays, which matters with a cache entry
 * per woman scrolling.
 */
interface PackedSession {
  ids: string;
  codes: string;
  oldest: Session['oldest'];
  rankedAt: number;
}

const REASON_CODE: Record<RankReason, string> = {
  following: 'f',
  for_you: 'y',
  trending: 't',
  new_voice: 'n',
  popular: 'p',
};
const CODE_REASON = Object.fromEntries(
  Object.entries(REASON_CODE).map(([reason, code]) => [code, reason as RankReason]),
);

function pack(session: Session): PackedSession {
  return {
    ids: session.ids.join(','),
    codes: session.ids.map((id) => REASON_CODE[session.reasons[id]] ?? 'p').join(''),
    oldest: session.oldest,
    rankedAt: session.rankedAt,
  };
}

function unpackIds(packed: PackedSession): string[] {
  return packed.ids ? packed.ids.split(',') : [];
}

function unpack(packed: PackedSession): Session {
  const ids = unpackIds(packed);
  const reasons: Record<string, RankReason> = {};
  ids.forEach((id, i) => (reasons[id] = CODE_REASON[packed.codes[i]] ?? 'popular'));
  return { ids, reasons, oldest: packed.oldest, rankedAt: packed.rankedAt };
}

interface CandidateRow {
  id: string;
  author_id: string;
  content_type: string;
  published_at: Date;
  age_hours: number;
  impressions: bigint;
  unique_viewers: bigint;
  views: bigint;
  reactions: bigint;
  replies: bigint;
  saves: bigint;
  shares: bigint;
  product_clicks: bigint;
  orders: bigint;
  watch_time_ms: bigint;
  hours_since_engagement: number | null;
  reports: number;
  author_role: UserRole;
  author_rank: number;
  author_ranked: boolean;
  author_verified: boolean;
  categories: string[] | null;
  /** From the fresh pool: the newest, unbroken run. */
  fresh: boolean;
}

/**
 * The ordered feeds: community, reels, and the posts on the home page.
 *
 * One ranked **session** per visit. The first page ranks a few hundred
 * candidates for her and keeps the order for twenty-five minutes; every
 * further page reads the next slice of that same order through a cursor, so
 * scrolling never reshuffles what she already passed and never shows a piece
 * twice. When the session runs out the feed continues newest-first from where
 * the candidates ended — a feed should never simply stop.
 *
 * Candidates come from four pools: what the people she follows posted this
 * week; what is fresh; what is doing well; and what sits in the categories
 * she shops. Every pool runs under the platform's one visibility rule and her
 * own «غير مهتمة» and mutes. The scoring is the kernel's; this gathers its
 * facts in a handful of batched queries.
 *
 * `feed.ranking_enabled = false` in the console returns every feed to plain
 * newest-first at once — the switch an operator wants within reach the day
 * something about the ranking looks wrong.
 */
@Injectable()
export class FeedRankingService {
  private readonly logger = new Logger(FeedRankingService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly cache: CacheService,
    @Optional() private readonly tiers?: AdTiersService,
  ) {}

  static isRankedCursor(cursor?: string): boolean {
    return !!cursor && cursor.startsWith(RANKED_PREFIX);
  }

  async enabled(): Promise<boolean> {
    const setting = await this.prisma.systemSetting.findUnique({
      where: { key: RANKING_ENABLED_SETTING },
      select: { value: true },
    });
    return setting?.value !== false;
  }

  /**
   * One page of a ranked feed, or null when the request is not a ranked one
   * (ranking switched off, or a keyset cursor continuing past the session) —
   * the caller then serves it newest-first as before.
   */
  async page(
    surface: RankedSurface,
    viewerId: string | undefined,
    request: { cursor?: string; limit: number },
  ) {
    if (request.cursor && !FeedRankingService.isRankedCursor(request.cursor)) return null;
    try {
      if (!(await this.enabled())) return null;
      return await this.rankedPage(surface, viewerId, request);
    } catch (error) {
      // A ranking that fails serves the feed newest-first; it never takes
      // the feed down.
      this.logger.error(`ranked ${surface} feed failed: ${String(error)}`);
      return null;
    }
  }

  private async rankedPage(
    surface: RankedSurface,
    viewerId: string | undefined,
    request: { cursor?: string; limit: number },
  ) {
    // `r.<session>.<offset>` inside the ranked order, `r.<session>.t.<keyset>`
    // in the newest-first tail after it.
    let sessionId: string;
    let offset = 0;
    let tail: string | undefined;
    if (request.cursor) {
      const [, id, at, keyset] = request.cursor.split('.');
      sessionId = id || randomUUID().slice(0, 8);
      if (at === 't') tail = keyset ?? '';
      else offset = Math.max(0, Number(at) || 0);
    } else {
      sessionId = viewerId ? randomUUID().slice(0, 8) : this.guestSession();
    }
    if (!viewerId && !this.isLiveGuestSession(sessionId)) sessionId = this.guestSession();
    const sessionKey = `${viewerId ?? 'guest'}:${sessionId}`;

    if (tail !== undefined) {
      const page = await this.tailPage(surface, viewerId, sessionId, tail, request.limit);
      return {
        ...page,
        reasons: {} as Record<string, RankReason>,
        session: sessionKey,
        // Past the ranked order: always a later page, for the ad slot.
        offset: Number.MAX_SAFE_INTEGER,
      };
    }

    const session = await this.session(surface, viewerId, sessionId);
    const slice = session.ids.slice(offset, offset + request.limit);
    const rows = await this.load(slice, viewerId);

    const end = offset + request.limit;
    this.served(viewerId, rows);
    if (end < session.ids.length) {
      return {
        items: rows,
        reasons: session.reasons,
        meta: {
          limit: request.limit,
          has_next_page: true,
          next_cursor: `${RANKED_PREFIX}${sessionId}.${end}`,
        },
        session: sessionKey,
        offset,
      };
    }

    // The ranked order ends on this page: fill the rest of it from the
    // newest-first tail, so no page comes back short.
    const edge = session.oldest
      ? encodeCursor(new Date(session.oldest.at), session.oldest.id)
      : '';
    const full = rows.length >= request.limit;
    const rest = await this.tailPage(
      surface,
      viewerId,
      sessionId,
      edge,
      full ? 1 : request.limit - rows.length,
      !full,
    );
    return {
      items: full ? rows : [...rows, ...rest.items],
      reasons: session.reasons,
      meta: full
        ? {
            limit: request.limit,
            has_next_page: rest.items.length > 0,
            next_cursor: rest.items.length > 0 ? `${RANKED_PREFIX}${sessionId}.t.${edge}` : null,
          }
        : { ...rest.meta, limit: request.limit },
      /** Where this page sits in its session — the ad slot reads it. */
      session: sessionKey,
      offset,
    };
  }

  /**
   * After the ranked order: everything else, newest first, minus what the
   * session already showed — so the feed goes on without repeating itself.
   * A session that expired meanwhile simply excludes nothing.
   */
  private async tailPage(
    surface: RankedSurface,
    viewerId: string | undefined,
    sessionId: string,
    keyset: string,
    limit: number,
    /** False for a look-ahead whose rows she is not shown. */
    mark = true,
  ) {
    const cursor = decodeCursor(keyset);
    const cached = this.cache.get<PackedSession>(this.sessionKey(surface, viewerId, sessionId));
    const shown = cached ? unpackIds(cached) : [];
    const ids = await this.prisma.$queryRaw<{ id: string; published_at: Date }[]>`
      SELECT c."id", c."published_at" FROM "commerce_contents" c
       WHERE ${this.eligibleSql(surface, viewerId)}
         AND (c."published_at", c."id") < (${utcTimestamp(cursor.at)}, ${cursor.id}::uuid)
         ${shown.length > 0 ? Prisma.sql`AND NOT (c."id" = ANY(${shown}::uuid[]))` : Prisma.empty}
       ORDER BY c."published_at" DESC, c."id" DESC
       LIMIT ${limit + 1}`;
    const page = ids.slice(0, limit);
    const last = page[page.length - 1];
    const next =
      ids.length > limit && last
        ? `${RANKED_PREFIX}${sessionId}.t.${encodeCursor(last.published_at, last.id)}`
        : null;
    const rows = await this.load(page.map((row) => row.id), viewerId);
    if (mark) this.served(viewerId, rows);
    return {
      items: rows,
      meta: { limit, has_next_page: next !== null, next_cursor: next },
    };
  }

  private served(viewerId: string | undefined, rows: { id: string }[]) {
    if (!viewerId || rows.length === 0) return;
    void this.markServed(viewerId, rows.map((row) => row.id)).catch((error) =>
      this.logger.warn(`feed_seen not written: ${String(error)}`),
    );
  }

  /** The sponsored posts this session already showed, so none comes twice. */
  adsShown(session: string): Set<string> {
    return new Set(this.cache.get<string[]>(`feed:ads:${session}`) ?? []);
  }

  rememberAds(session: string, contentIds: string[]): void {
    if (contentIds.length === 0) return;
    const shown = [...this.adsShown(session), ...contentIds];
    this.cache.set(`feed:ads:${session}`, shown, SESSION_TTL_MS);
  }

  /**
   * For `/posts/feed`, which pages by number: the whole ranked order for her
   * home page, as ids. The posts service loads the rows under its own legacy
   * rules and continues newest-first past the end. One session per woman for
   * the home page, so page two agrees with page one.
   */
  async homeOrder(viewerId: string | undefined, firstPage: boolean) {
    if (!(await this.enabled())) return null;
    const sessionId = viewerId ? 'home' : this.guestSession();
    // Her first page after a few minutes is a new visit — a pull to refresh
    // should bring a new order — while page two keeps the one page one used.
    if (viewerId && firstPage) {
      const key = this.sessionKey('posts', viewerId, sessionId);
      const cached = this.cache.get<PackedSession>(key);
      if (cached && Date.now() - cached.rankedAt > HOME_REFRESH_MS) {
        this.cache.invalidate(key);
      }
    }
    const session = await this.session('posts', viewerId, sessionId);
    return { ids: session.ids, reasons: session.reasons };
  }

  // ── The session ──────────────────────────────────────────────────────────

  private sessionKey(surface: RankedSurface, viewerId: string | undefined, sessionId: string) {
    return `feed:rank:${surface}:${viewerId ?? 'guest'}:${sessionId}`;
  }

  /** A guest's session is the time bucket she arrived in: `g<bucket>`. */
  private guestSession(): string {
    return `g${Math.floor(Date.now() / GUEST_TTL_MS)}`;
  }

  /**
   * Only a bucket from the last half hour. Anything else in a guest's cursor
   * — a stale link, or someone minting ids to make the server rank — starts
   * from the current one.
   */
  private isLiveGuestSession(id: string): boolean {
    const match = /^g(\d+)$/.exec(id);
    if (!match) return false;
    const age = Math.floor(Date.now() / GUEST_TTL_MS) - Number(match[1]);
    return age >= 0 && age * GUEST_TTL_MS <= SESSION_TTL_MS;
  }

  private async session(
    surface: RankedSurface,
    viewerId: string | undefined,
    sessionId: string,
  ): Promise<Session> {
    // A guest's session is shared by every guest who arrived in the same
    // couple of minutes; computing it per guest would spend a database on
    // people who have not signed up yet. A woman's carries the minute in its
    // seed, so her home page's re-rank is a fresh shuffle.
    const seed = viewerId
      ? `${viewerId}:${sessionId}:${Math.floor(Date.now() / 60_000)}`
      : `guest-${sessionId}`;
    const packed = await this.cache.wrap(
      this.sessionKey(surface, viewerId, sessionId),
      SESSION_TTL_MS,
      async () => pack(await this.rank(surface, viewerId, seed)),
    );
    return unpack(packed);
  }

  /** The ranked order for one woman (or for every guest). */
  async rank(surface: RankedSurface, viewerId: string | undefined, seed: string): Promise<Session> {
    const kind: FeedKind = surface === 'reels' ? 'reels' : 'feed';
    const [setting, interest] = await Promise.all([
      this.prisma.systemSetting.findUnique({
        where: { key: RANK_WEIGHTS_SETTING },
        select: { value: true },
      }),
      viewerId ? this.categoryInterest(viewerId) : Promise.resolve(new Map<string, number>()),
    ]);
    const weights = mergeWeights(kind, setting?.value);

    const rows = await this.candidates(surface, viewerId, [...interest.keys()]);
    if (rows.length === 0) return { ids: [], reasons: {}, oldest: null, rankedAt: Date.now() };

    const authorIds = [...new Set(rows.map((row) => row.author_id))];
    const contentIds = rows.map((row) => row.id);
    const [follows, affinity, served, engaged, exposure] = await Promise.all([
      viewerId ? this.followed(viewerId, authorIds) : Promise.resolve(new Set<string>()),
      viewerId ? this.authorAffinity(viewerId, authorIds) : Promise.resolve(new Map<string, number>()),
      viewerId ? this.servedCounts(viewerId, contentIds) : Promise.resolve(new Map<string, number>()),
      viewerId ? this.alreadyEngaged(viewerId, contentIds) : Promise.resolve(new Set<string>()),
      this.authorExposure(authorIds),
    ]);

    const facts: CandidateFacts[] = rows.map((row) => {
      const categories = row.categories ?? [];
      return {
        id: row.id,
        authorId: row.author_id,
        contentType: row.content_type,
        ageHours: Number(row.age_hours),
        impressions: Number(row.impressions),
        uniqueViewers: Number(row.unique_viewers),
        views: Number(row.views),
        reactions: Number(row.reactions),
        replies: Number(row.replies),
        saves: Number(row.saves),
        shares: Number(row.shares),
        productClicks: Number(row.product_clicks),
        orders: Number(row.orders),
        watchTimeMs: Number(row.watch_time_ms),
        hoursSinceEngagement:
          row.hours_since_engagement === null ? null : Number(row.hours_since_engagement),
        reports: Number(row.reports),
        authorQuality: this.authorQuality(row),
        authorExposure: exposure.get(row.author_id) ?? 0,
        followsAuthor: follows.has(row.author_id),
        authorAffinity: affinity.get(row.author_id) ?? 0,
        interest: categories.reduce((best, c) => Math.max(best, interest.get(c) ?? 0), 0),
        servedCount: served.get(row.id) ?? 0,
        alreadyEngaged: engaged.has(row.id),
        isOwn: viewerId !== undefined && row.author_id === viewerId,
      };
    });

    const ranked = rankFeed(facts, weights, {
      random: seededRandom(seed),
      limit: SESSION_DEPTH,
    });
    // Everything newer than the fresh pool's oldest piece is a candidate, so
    // newest-first from there misses nothing. With nothing fresh at all, the
    // continuation starts below the oldest candidate.
    const fresh = rows.filter((row) => row.fresh);
    const edge = (fresh.length > 0 ? fresh : rows).reduce((a, b) =>
      a.published_at < b.published_at ? a : b,
    );
    return {
      ids: ranked.map((r) => r.id),
      reasons: Object.fromEntries(ranked.map((r) => [r.id, r.reason])),
      oldest: { at: edge.published_at.toISOString(), id: edge.id },
      rankedAt: Date.now(),
    };
  }

  // ── Candidates ───────────────────────────────────────────────────────────

  private async candidates(
    surface: RankedSurface,
    viewerId: string | undefined,
    interestCategories: string[],
  ): Promise<CandidateRow[]> {
    const base = this.eligibleSql(surface, viewerId);
    const now = Prisma.sql`(now() AT TIME ZONE 'UTC')`;
    const engagement = Prisma.sql`(c."reactions_count" + 2 * c."replies_count" + 3 * c."saves_count" + 3 * c."shares_count")`;

    const pools: Prisma.Sql[] = [
      // Fresh: the newest of the last three days.
      Prisma.sql`(SELECT c."id", true AS fresh FROM "commerce_contents" c
                  WHERE ${base} AND c."published_at" > ${now} - interval '3 days'
                  ORDER BY c."published_at" DESC, c."id" DESC LIMIT 150)`,
      // Doing well: the most engaged of the last week.
      Prisma.sql`(SELECT c."id", false FROM "commerce_contents" c
                  WHERE ${base} AND c."published_at" > ${now} - interval '7 days'
                  ORDER BY ${engagement} DESC, c."published_at" DESC LIMIT 150)`,
      // Evergreen: the best of the month, for a quiet week.
      Prisma.sql`(SELECT c."id", false FROM "commerce_contents" c
                  WHERE ${base} AND c."published_at" > ${now} - interval '30 days'
                  ORDER BY ${engagement} DESC LIMIT 60)`,
    ];
    if (viewerId) {
      pools.push(
        // Everyone she follows, this week.
        Prisma.sql`(SELECT c."id", false FROM "commerce_contents" c
                    WHERE ${base} AND c."published_at" > ${now} - interval '7 days'
                      AND c."author_id" IN (SELECT f."following_id" FROM "follows" f
                                             WHERE f."follower_id" = ${viewerId}::uuid)
                    ORDER BY c."published_at" DESC LIMIT 200)`,
      );
    }
    if (interestCategories.length > 0) {
      pools.push(
        // Her categories, the last three weeks.
        Prisma.sql`(SELECT DISTINCT ON (c."id") c."id", false FROM "commerce_contents" c
                    JOIN "commerce_content_product_tags" t ON t."content_id" = c."id"
                    JOIN "products" p ON p."id" = t."product_id"
                    WHERE ${base} AND c."published_at" > ${now} - interval '21 days'
                      AND p."category_id" = ANY(${interestCategories.slice(0, 12)}::uuid[])
                    ORDER BY c."id" LIMIT 150)`,
      );
    }

    return this.prisma.$queryRaw<CandidateRow[]>`
      WITH pooled (id, fresh) AS (${Prisma.join(pools, ' UNION ALL ')}),
           cand AS (SELECT id, bool_or(fresh) AS fresh FROM pooled GROUP BY id)
      SELECT c."id", cand."fresh", c."author_id", c."content_type", c."published_at",
             EXTRACT(EPOCH FROM (${now} - c."published_at")) / 3600 AS age_hours,
             c."impressions_count" AS impressions, c."unique_viewers_count" AS unique_viewers,
             c."views_count" AS views, c."reactions_count" AS reactions,
             c."replies_count" AS replies, c."saves_count" AS saves,
             c."shares_count" AS shares, c."product_clicks_count" AS product_clicks,
             c."orders_count" AS orders, c."watch_time_ms" AS watch_time_ms,
             CASE WHEN c."last_engagement_at" IS NULL THEN NULL
                  ELSE EXTRACT(EPOCH FROM (${now} - c."last_engagement_at")) / 3600 END
               AS hours_since_engagement,
             c."reports_count" AS reports,
             u."role" AS author_role, u."seller_rank_score" AS author_rank,
             (u."seller_rank_scored_at" IS NOT NULL) AS author_ranked,
             (u."seller_verified_at" IS NOT NULL) AS author_verified,
             (SELECT array_agg(DISTINCT p."category_id"::text)
                FROM "commerce_content_product_tags" t
                JOIN "products" p ON p."id" = t."product_id"
               WHERE t."content_id" = c."id") AS categories
        FROM cand
        JOIN "commerce_contents" c ON c."id" = cand."id"
        JOIN "users" u ON u."id" = c."author_id"`;
  }

  /** What may appear on this surface for her, as a `c.` predicate. */
  private eligibleSql(surface: RankedSurface, viewerId: string | undefined): Prisma.Sql {
    const typeFilter =
      surface === 'reels'
        ? Prisma.sql`c."content_type" = 'reel'`
        : surface === 'posts'
          ? Prisma.sql`c."content_type" = 'product_post' AND c."visibility" = 'PUBLIC' AND c."author_is_public"`
          : // Stories live in the tray, not in the feed.
            Prisma.sql`c."content_type" <> 'story'`;
    return Prisma.sql`
      c."published_at" IS NOT NULL
      AND ${typeFilter}
      AND ${contentVisibilitySql('c', viewerId)}
      ${viewerId ? Prisma.sql`AND ${contentControlsSql('c', viewerId)}` : Prisma.empty}`;
  }

  /** A boutique's standing; a shopper's look sits at a neutral middle. */
  private authorQuality(row: CandidateRow): number {
    if (row.author_role !== UserRole.SELLER) return 0.5;
    const rank = row.author_ranked ? Number(row.author_rank) / 100 : 0.5;
    return Math.min(1, rank * 0.85 + (row.author_verified ? 0.15 : 0));
  }

  // ── Her signals ──────────────────────────────────────────────────────────

  private async followed(viewerId: string, authorIds: string[]) {
    const rows = await this.prisma.follow.findMany({
      where: { followerId: viewerId, followingId: { in: authorIds } },
      select: { followingId: true },
    });
    return new Set(rows.map((row) => row.followingId));
  }

  /**
   * Her history with each author, 0–1: likes, comments, saves, reshares and
   * product taps on the author's posts, and orders from the boutique — each
   * weighted by what it cost her to do.
   */
  async authorAffinity(viewerId: string, authorIds: string[]) {
    const out = new Map<string, number>();
    if (authorIds.length === 0) return out;
    const since = Prisma.sql`(now() AT TIME ZONE 'UTC') - make_interval(days => ${HISTORY_DAYS}::int)`;
    const rows = await this.prisma.$queryRaw<{ author_id: string; points: number }[]>`
      SELECT author_id, SUM(points)::float AS points FROM (
        SELECT c."author_id", 1.0 AS points FROM "commerce_content_reactions" r
          JOIN "commerce_contents" c ON c."id" = r."content_id"
         WHERE r."user_id" = ${viewerId}::uuid AND r."created_at" > ${since}
           AND c."author_id" = ANY(${authorIds}::uuid[])
        UNION ALL
        SELECT c."author_id", 2.0 FROM "commerce_content_saves" s
          JOIN "commerce_contents" c ON c."id" = s."content_id"
         WHERE s."user_id" = ${viewerId}::uuid AND s."created_at" > ${since}
           AND c."author_id" = ANY(${authorIds}::uuid[])
        UNION ALL
        SELECT c."author_id", 2.0 FROM "commerce_content_comments" m
          JOIN "commerce_contents" c ON c."id" = m."content_id"
         WHERE m."user_id" = ${viewerId}::uuid AND m."removed_at" IS NULL AND m."created_at" > ${since}
           AND c."author_id" = ANY(${authorIds}::uuid[])
        UNION ALL
        SELECT c."author_id", 1.5 FROM "commerce_content_events" e
          JOIN "commerce_contents" c ON c."id" = e."content_id"
         WHERE e."actor_id" = ${viewerId}::uuid AND e."type" = 'PRODUCT_CLICK'
           AND e."created_at" > ${since} AND c."author_id" = ANY(${authorIds}::uuid[])
        UNION ALL
        SELECT so."seller_id", 5.0 FROM "seller_orders" so
          JOIN "orders" o ON o."id" = so."order_id"
         WHERE o."user_id" = ${viewerId}::uuid AND so."created_at" > ${since}
           AND so."seller_id" = ANY(${authorIds}::uuid[])
      ) x GROUP BY author_id`;
    for (const row of rows) {
      out.set(row.author_id, 1 - Math.exp(-Number(row.points) / 6));
    }
    return out;
  }

  /**
   * Her categories, 0–1 against her favourite: what she saved, viewed, put
   * in her bag and bought, and the posts of pieces she liked.
   */
  async categoryInterest(viewerId: string) {
    const since = Prisma.sql`(now() AT TIME ZONE 'UTC') - make_interval(days => ${HISTORY_DAYS}::int)`;
    const rows = await this.prisma.$queryRaw<{ category_id: string; points: number }[]>`
      SELECT category_id, SUM(points)::float AS points FROM (
        SELECT p."category_id", 3.0 AS points FROM "favorites" f
          JOIN "products" p ON p."id" = f."product_id"
         WHERE f."user_id" = ${viewerId}::uuid AND f."created_at" > ${since}
        UNION ALL
        SELECT p."category_id",
               CASE e."type" WHEN 'CART_ADD' THEN 2.0 WHEN 'PRODUCT_FAVORITE' THEN 3.0 ELSE 1.0 END
          FROM "analytics_events" e JOIN "products" p ON p."id" = e."product_id"
         WHERE e."user_id" = ${viewerId}::uuid AND e."occurred_at" > ${since}
           AND e."type" IN ('PRODUCT_VIEW', 'CART_ADD', 'PRODUCT_FAVORITE')
        UNION ALL
        SELECT p."category_id", 5.0 FROM "order_items" oi
          JOIN "seller_orders" so ON so."id" = oi."seller_order_id"
          JOIN "orders" o ON o."id" = so."order_id"
          JOIN "products" p ON p."id" = oi."product_id"
         WHERE o."user_id" = ${viewerId}::uuid AND so."created_at" > ${since}
        UNION ALL
        SELECT p."category_id", 1.0 FROM "commerce_content_reactions" r
          JOIN "commerce_content_product_tags" t ON t."content_id" = r."content_id"
          JOIN "products" p ON p."id" = t."product_id"
         WHERE r."user_id" = ${viewerId}::uuid AND r."created_at" > ${since}
      ) x GROUP BY category_id ORDER BY 2 DESC LIMIT 20`;
    const out = new Map<string, number>();
    const top = rows.length > 0 ? Number(rows[0].points) : 0;
    if (top <= 0) return out;
    for (const row of rows) out.set(row.category_id, Number(row.points) / top);
    return out;
  }

  private async servedCounts(viewerId: string, contentIds: string[]) {
    const since = new Date(Date.now() - SEEN_DAYS * 86_400_000);
    const rows = await this.prisma.feedSeen.findMany({
      where: { userId: viewerId, contentId: { in: contentIds }, lastServedAt: { gt: since } },
      select: { contentId: true, servedCount: true },
    });
    return new Map(rows.map((row) => [row.contentId, row.servedCount]));
  }

  private async alreadyEngaged(viewerId: string, contentIds: string[]) {
    const [reactions, saves] = await Promise.all([
      this.prisma.commerceContentReaction.findMany({
        where: { userId: viewerId, contentId: { in: contentIds } },
        select: { contentId: true },
      }),
      this.prisma.commerceContentSave.findMany({
        where: { userId: viewerId, contentId: { in: contentIds } },
        select: { contentId: true },
      }),
    ]);
    return new Set([...reactions, ...saves].map((row) => row.contentId));
  }

  /** How often the feed has shown each author lately, to anyone. */
  private async authorExposure(authorIds: string[]) {
    const rows = await this.prisma.$queryRaw<{ author_id: string; n: bigint }[]>`
      SELECT c."author_id", COUNT(*)::bigint AS n
        FROM "feed_seen" fs JOIN "commerce_contents" c ON c."id" = fs."content_id"
       WHERE c."author_id" = ANY(${authorIds}::uuid[])
         AND fs."last_served_at" > (now() AT TIME ZONE 'UTC') - interval '14 days'
       GROUP BY c."author_id"`;
    return new Map(rows.map((row) => [row.author_id, Number(row.n)]));
  }

  // ── Loading and marking ──────────────────────────────────────────────────

  /**
   * Full rows for a slice, in ranked order, re-checked against the rules: a
   * piece removed or muted after the session was ranked does not come back.
   */
  private async load(ids: string[], viewerId?: string) {
    if (ids.length === 0) return [];
    const allowed = await this.prisma.$queryRaw<{ id: string }[]>`
      SELECT c."id" FROM "commerce_contents" c
       WHERE c."id" = ANY(${ids}::uuid[])
         AND ${contentVisibilitySql('c', viewerId)}
         ${viewerId ? Prisma.sql`AND ${contentControlsSql('c', viewerId)}` : Prisma.empty}`;
    const keep = new Set(allowed.map((row) => row.id));
    const rows = await this.prisma.commerceContent.findMany({
      where: { id: { in: ids.filter((id) => keep.has(id)) } },
      include: commerceContentInclude,
    });
    const byId = new Map(rows.map((row) => [row.id, row]));
    return ids.map((id) => byId.get(id)).filter((row) => row !== undefined);
  }

  /** What she was shown, so the next session brings something new. */
  async markServed(viewerId: string, contentIds: string[]): Promise<void> {
    if (contentIds.length === 0) return;
    await this.prisma.$executeRaw`
      INSERT INTO "feed_seen" ("user_id", "content_id", "served_count", "last_served_at")
      SELECT ${viewerId}::uuid, id, 1, (now() AT TIME ZONE 'UTC')
        FROM unnest(${contentIds}::uuid[]) AS id
      ON CONFLICT ("user_id", "content_id") DO UPDATE
        SET "served_count" = "feed_seen"."served_count" + 1,
            "last_served_at" = EXCLUDED."last_served_at"`;
  }

  // ── Stories ──────────────────────────────────────────────────────────────

  /**
   * The tray in the order she would open it: her own ring, then the rings
   * with something new, closest people first, then the ones she finished.
   */
  async orderTray<T extends { authorId: string; allSeen: boolean; newestAt: Date }>(
    viewerId: string | undefined,
    groups: T[],
  ): Promise<T[]> {
    if (groups.length <= 1) return groups;
    try {
      return await this.orderTrayOrThrow(viewerId, groups);
    } catch (error) {
      // The tray in creation order beats no tray.
      this.logger.warn(`story tray not ordered: ${String(error)}`);
      return groups;
    }
  }

  private async orderTrayOrThrow<T extends { authorId: string; allSeen: boolean; newestAt: Date }>(
    viewerId: string | undefined,
    groups: T[],
  ): Promise<T[]> {
    const authorIds = groups.map((g) => g.authorId);
    const [follows, affinity, tiers] = await Promise.all([
      viewerId ? this.followed(viewerId, authorIds) : new Set<string>(),
      viewerId ? this.authorAffinity(viewerId, authorIds) : new Map<string, number>(),
      // A broken plan lookup orders the tray without it, never fails it.
      this.tiers?.tiersOf(authorIds).catch(() => undefined),
    ]);
    const top = TIER_ORDER.length - 1;
    const now = Date.now();
    const facts = groups.map((g) => ({
      group: g,
      authorId: g.authorId,
      isOwn: viewerId !== undefined && g.authorId === viewerId,
      allSeen: g.allSeen,
      followsAuthor: follows.has(g.authorId),
      affinity: affinity.get(g.authorId) ?? 0,
      newestAgeHours: (now - g.newestAt.getTime()) / 3_600_000,
      promoted: tiers?.has(g.authorId) ? tierRank(tiers.get(g.authorId)!) / top : 0,
    }));
    return orderStoryTray(facts).map((f) => f.group);
  }

  // ── Housekeeping ─────────────────────────────────────────────────────────

  /** Served rows older than a fortnight say nothing the ranker still reads. */
  @ScheduledJob({ cron: '0 10 4 * * *', staleAfterMinutes: 1440 })
  async sweepSeen(): Promise<void> {
    const deleted = await this.prisma.$executeRaw`
      DELETE FROM "feed_seen"
       WHERE "last_served_at" < (now() AT TIME ZONE 'UTC') - interval '14 days'`;
    if (deleted > 0) this.logger.log(`Swept ${deleted} served-feed rows`);
  }
}
