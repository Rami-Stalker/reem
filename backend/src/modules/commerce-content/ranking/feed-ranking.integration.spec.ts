import assert from 'node:assert/strict';
import test from 'node:test';
import { CommerceAuthorKind, CommerceContentStatus, PrismaClient, UserRole } from '@prisma/client';

import { CacheService } from '../../../common/cache/cache.service';
import { PrismaService } from '../../../prisma/prisma.service';
import { FeedRankingService, RANKING_ENABLED_SETTING } from './feed-ranking.service';

/**
 * The ranked feeds against the real database: the facts the kernel scores
 * are gathered from the right tables, her own rules hold, and paging a
 * session never repeats a piece. Every case is rolled back.
 */
const prisma = new PrismaClient();

class Rollback extends Error {}
type Tx = Parameters<Parameters<typeof prisma.$transaction>[0]>[0];

let reachable = false;

test.before(async () => {
  try {
    await prisma.$queryRaw`SELECT 1`;
    reachable = true;
  } catch {
    reachable = false;
  }
});

test.after(() => prisma.$disconnect());

function dbTest(name: string, body: (db: PrismaService, ranking: FeedRankingService) => Promise<void>) {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    let failure: unknown;
    try {
      await prisma.$transaction(
        async (tx) => {
          const db = asPrisma(tx);
          try {
            await body(db, new FeedRankingService(db, new CacheService()));
          } catch (error) {
            failure = error;
          }
          throw new Rollback();
        },
        { timeout: 120_000 },
      );
    } catch (error) {
      if (!(error instanceof Rollback)) throw error;
    }
    if (failure) throw failure;
  });
}

function asPrisma(tx: Tx): PrismaService {
  return new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: unknown) => {
          if (Array.isArray(fn)) return Promise.all(fn);
          return (fn as (inner: Tx) => unknown)(tx);
        };
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
}

/**
 * Two open boutiques' posts made alike — published an hour ago, no
 * engagement — so only what she does with them can tell them apart.
 */
async function twoLikePosts(db: PrismaService) {
  const posts = await db.commerceContent.findMany({
    where: {
      authorKind: CommerceAuthorKind.SELLER,
      contentType: 'product_post',
      status: CommerceContentStatus.PUBLISHED,
      visibility: 'PUBLIC',
      authorIsPublic: true,
    },
    distinct: ['authorId'],
    take: 2,
    select: { id: true, authorId: true },
  });
  assert.equal(posts.length, 2, 'the seed needs two open boutiques with posts');
  const shopper = await db.user.findFirst({
    where: { role: UserRole.CUSTOMER, id: { notIn: posts.map((p) => p.authorId) } },
    select: { id: true },
  });
  assert.ok(shopper);
  await db.$executeRaw`
    UPDATE "commerce_contents" SET
      "published_at" = (now() AT TIME ZONE 'UTC') - interval '1 hour',
      "impressions_count" = 0, "views_count" = 0, "unique_viewers_count" = 0,
      "reactions_count" = 0, "replies_count" = 0, "saves_count" = 0,
      "shares_count" = 0, "product_clicks_count" = 0, "orders_count" = 0,
      "reports_count" = 0, "last_engagement_at" = NULL
    WHERE "id" = ANY(${posts.map((p) => p.id)}::uuid[])`;
  // Same standing, so the boutiques' rank scores do not decide it either.
  await db.user.updateMany({
    where: { id: { in: posts.map((p) => p.authorId) } },
    data: { sellerRankScore: 50 },
  });
  await db.follow.deleteMany({
    where: { followerId: shopper.id, followingId: { in: posts.map((p) => p.authorId) } },
  });
  await db.userMute.deleteMany({
    where: { muterId: shopper.id, mutedId: { in: posts.map((p) => p.authorId) } },
  });
  await db.$executeRaw`DELETE FROM "feed_seen" WHERE "user_id" = ${shopper.id}::uuid`;
  // The seed has her liking and saving posts. One she already liked is sunk
  // on purpose, which would decide the order for a reason no case here is about.
  const ids = posts.map((p) => p.id);
  await db.commerceContentReaction.deleteMany({
    where: { userId: shopper.id, contentId: { in: ids } },
  });
  await db.commerceContentSave.deleteMany({
    where: { userId: shopper.id, contentId: { in: ids } },
  });
  return { a: posts[0], b: posts[1], shopper: shopper.id };
}

dbTest('a boutique she follows comes before a like one she does not', async (db, ranking) => {
  const { a, b, shopper } = await twoLikePosts(db);
  await db.follow.create({ data: { followerId: shopper, followingId: a.authorId } });

  const session = await ranking.rank('feed', shopper, 'test');
  assert.ok(session.ids.includes(a.id) && session.ids.includes(b.id), 'both posts are candidates');
  // Compare where each boutique first appears, not these two posts. Following
  // lifts every post of hers, so another of them can lead and this one then
  // gives way to the same-author spacing — which is the feed working.
  const authors = await db.commerceContent.findMany({
    where: { id: { in: session.ids } },
    select: { id: true, authorId: true },
  });
  const authorOf = new Map(authors.map((row) => [row.id, row.authorId]));
  const firstOf = (authorId: string) => session.ids.findIndex((id) => authorOf.get(id) === authorId);
  const ia = firstOf(a.authorId);
  const ib = firstOf(b.authorId);
  assert.ok(ia < ib, `followed first at ${ia}, other first at ${ib}`);
  assert.equal(session.reasons[a.id], 'following');
});

dbTest('what she was already shown gives way to what she was not', async (db, ranking) => {
  const { a, b, shopper } = await twoLikePosts(db);
  for (let i = 0; i < 3; i++) await ranking.markServed(shopper, [a.id]);
  const served = await db.feedSeen.findUnique({
    where: { userId_contentId: { userId: shopper, contentId: a.id } },
  });
  assert.equal(served?.servedCount, 3);

  const session = await ranking.rank('feed', shopper, 'test');
  assert.ok(session.ids.indexOf(b.id) < session.ids.indexOf(a.id));
});

dbTest('a muted boutique never reaches her ranked feed', async (db, ranking) => {
  const { a, shopper } = await twoLikePosts(db);
  await db.userMute.create({ data: { muterId: shopper, mutedId: a.authorId } });
  const session = await ranking.rank('feed', shopper, 'test');
  const authors = await db.commerceContent.findMany({
    where: { id: { in: session.ids } },
    select: { authorId: true },
  });
  assert.ok(authors.every((row) => row.authorId !== a.authorId));
});

dbTest('paging a session never shows a piece twice, and never stops early', async (db, ranking) => {
  const { shopper } = await twoLikePosts(db);
  const seen = new Set<string>();
  let cursor: string | undefined;
  for (let page = 0; page < 30; page++) {
    const result = await ranking.page('feed', shopper, { cursor, limit: 7 });
    assert.ok(result, 'ranking is on');
    for (const item of result.items) {
      assert.ok(!seen.has(item.id), `repeated ${item.id} on page ${page}`);
      seen.add(item.id);
    }
    if (!result.meta.has_next_page) break;
    cursor = result.meta.next_cursor ?? undefined;
    assert.ok(cursor?.startsWith('r.'), 'every cursor stays in the session');
  }
  assert.ok(seen.size > 7, 'more than one page');
});

dbTest('stories: her closest unseen rings first, finished rings last', async (db, ranking) => {
  const { a, b, shopper } = await twoLikePosts(db);
  await db.follow.create({ data: { followerId: shopper, followingId: b.authorId } });
  const other = await db.user.findFirst({
    where: { id: { notIn: [shopper, a.authorId, b.authorId] } },
    select: { id: true },
  });
  assert.ok(other);
  const now = new Date();
  const order = await ranking.orderTray(shopper, [
    { authorId: a.authorId, allSeen: false, newestAt: now },
    { authorId: other.id, allSeen: true, newestAt: now },
    { authorId: b.authorId, allSeen: false, newestAt: new Date(now.getTime() - 10 * 3_600_000) },
  ]);
  assert.deepEqual(
    order.map((g) => g.allSeen),
    [false, false, true],
  );
  assert.equal(order[0].authorId, b.authorId, 'the one she follows leads, though older');
});

dbTest('the console switch turns ranking off', async (db, ranking) => {
  await db.systemSetting.upsert({
    where: { key: RANKING_ENABLED_SETTING },
    create: { key: RANKING_ENABLED_SETTING, value: false },
    update: { value: false },
  });
  assert.equal(await ranking.page('feed', undefined, { limit: 5 }), null);
  assert.equal(await ranking.homeOrder(undefined, true), null);
});
