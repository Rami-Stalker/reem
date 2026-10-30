import assert from 'node:assert/strict';
import test from 'node:test';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  CommerceAuthorKind,
  CommerceAttributionSource,
  CommerceContentStatus,
  PrismaClient,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { CacheService } from '../../common/cache/cache.service';
import { AuditService } from '../auth/audit.service';
import { ContentAttributionService } from './attribution/content-attribution.service';
import { ContentFeedService } from './feed/content-feed.service';
import { ContentInteractionsService } from './interactions/content-interactions.service';
import { ContentModerationService } from './moderation/content-moderation.service';

/**
 * The social platform against the real database.
 *
 * The unit specs prove the rules in isolation. This proves the ones that are
 * only true when several tables agree — a reshare that stays attached to its
 * original, a takedown that reaches every page the post was added to, a woman
 * whose name leaves a boutique's screen the moment she closes her page.
 *
 * Every case runs inside a transaction that is rolled back, so the seeded shop
 * is unchanged afterwards.
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

function dbTest(name: string, body: (world: World) => Promise<void>): void {
  test(name, async (t) => {
    if (!reachable) {
      t.skip('no database reachable');
      return;
    }
    let failure: unknown;
    try {
      await prisma.$transaction(
        async (tx) => {
          try {
            await body(build(tx));
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

/** Nested transactions flattened onto the one the test rolls back. */
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

interface World {
  db: PrismaService;
  interactions: ContentInteractionsService;
  attribution: ContentAttributionService;
  moderation: ContentModerationService;
  feed: ContentFeedService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const events = new EventEmitter2();
  const attribution = new ContentAttributionService(db);
  return {
    db,
    attribution,
    interactions: new ContentInteractionsService(db, events, attribution),
    moderation: new ContentModerationService(db, new AuditService(db), events, new CacheService()),
    feed: new ContentFeedService(db, new CacheService()),
  };
}

// ── Fixtures ────────────────────────────────────────────────────────────────

const asUser = (id: string, role: UserRole): AuthUser => ({
  id,
  phone: '+963900000000',
  role,
});

/** A boutique post from the seeded shop, and the boutique behind it. */
async function aSellerPost(db: PrismaService) {
  const content = await db.commerceContent.findFirst({
    where: {
      authorKind: CommerceAuthorKind.SELLER,
      contentType: 'product_post',
      status: CommerceContentStatus.PUBLISHED,
      // An open storefront's post. An unverified seller's page stays closed
      // until approval opens it, so her posts reach nobody yet.
      authorIsPublic: true,
    },
    select: { id: true, authorId: true },
  });
  assert.ok(content, 'the seeded shop has no published boutique post');
  return content;
}

async function aShopper(db: PrismaService, authorId: string) {
  const user = await db.user.findFirst({
    where: { role: UserRole.CUSTOMER, id: { not: authorId } },
    select: { id: true, profileIsPublic: true },
  });
  assert.ok(user, 'the seeded shop has no shopper');
  return user;
}

/**
 * A shopper with an open page, opened here rather than looked for.
 *
 * The first version of these tests searched for one and returned early when
 * the seed had none — so on a database seeded before open pages existed, the
 * two cases that matter most passed by not running. A test that is silent
 * about its own fixture being absent is not a test.
 */
async function anOpenShopper(db: PrismaService, authorId: string) {
  const shopper = await aShopper(db, authorId);
  await db.user.update({
    where: { id: shopper.id },
    data: { profileIsPublic: true, profilePublicSince: new Date() },
  });
  return shopper;
}

// ── Reshare ─────────────────────────────────────────────────────────────────

dbTest('a reshare is a pointer, never a copy', async ({ db, interactions }) => {
  const post = await aSellerPost(db);
  const shopper = await aShopper(db, post.authorId);

  const before = await db.commerceContent.count();
  await interactions.reshare(asUser(shopper.id, UserRole.CUSTOMER), post.id, {
    note: 'لقيتها هون',
  });
  const after = await db.commerceContent.count();

  // The whole design in one assertion: adding somebody's post to your page
  // creates an edge, not a second piece of content. If this ever fails, a
  // price correction or a takedown on the original has stopped reaching the
  // pages it was added to.
  assert.equal(after, before, 'resharing created a copy of the content');

  const edge = await db.commerceContentReshare.findUnique({
    where: {
      sourceContentId_resharerId: {
        sourceContentId: post.id,
        resharerId: shopper.id,
      },
    },
  });
  assert.ok(edge);
  assert.equal(edge.sourceAuthorId, post.authorId, 'the boutique lost its credit');
});

dbTest('resharing twice is one row and one number', async ({ db, interactions }) => {
  const post = await aSellerPost(db);
  const shopper = await aShopper(db, post.authorId);
  const actor = asUser(shopper.id, UserRole.CUSTOMER);

  const first = await interactions.reshare(actor, post.id);
  const second = await interactions.reshare(actor, post.id);

  assert.equal(second.id, first.id);
  assert.equal(second.already, true);
  assert.equal(
    await db.commerceContentReshare.count({
      where: { sourceContentId: post.id, resharerId: shopper.id },
    }),
    1,
  );
});

dbTest('a woman cannot reshare her own post', async ({ db, interactions }) => {
  const post = await aSellerPost(db);
  await assert.rejects(
    () =>
      interactions.reshare(asUser(post.authorId, UserRole.SELLER), post.id),
    /CANNOT_RESHARE_OWN_CONTENT/,
  );
});

// ── Attribution ─────────────────────────────────────────────────────────────

dbTest(
  'a reshare credits the boutique whose products are tagged, not only its author',
  async ({ db, interactions, attribution }) => {
    // The case the reshare table cannot answer alone, and the reason the
    // projection exists.
    const post = await aSellerPost(db);
    const shopper = await aShopper(db, post.authorId);

    await interactions.reshare(asUser(shopper.id, UserRole.CUSTOMER), post.id);
    await attribution.rebuild(post.id);

    const rows = await db.commerceContentAttribution.findMany({
      where: { contentId: post.id, source: CommerceAttributionSource.RESHARE },
    });
    assert.ok(rows.length > 0, 'no reshare attribution was written');
    for (const row of rows) {
      assert.equal(row.actorId, shopper.id, 'the promoter was not recorded');
    }
  },
);

dbTest('rebuilding attribution twice does not double the credit', async ({
  db,
  attribution,
}) => {
  const post = await aSellerPost(db);
  await attribution.rebuild(post.id);
  const once = await db.commerceContentAttribution.count({
    where: { contentId: post.id },
  });
  await attribution.rebuild(post.id);
  const twice = await db.commerceContentAttribution.count({
    where: { contentId: post.id },
  });
  assert.equal(twice, once);
});

// ── Interaction counters ────────────────────────────────────────────────────

dbTest('a like is one row and one increment, and toggles back', async ({
  db,
  interactions,
}) => {
  const post = await aSellerPost(db);
  // A shopper who has not liked it yet — the seed has likes, and liking twice
  // is the toggle this test checks second, not first.
  const likedBy = await db.commerceContentReaction.findMany({
    where: { contentId: post.id },
    select: { userId: true },
  });
  const shopper = await db.user.findFirst({
    where: {
      role: UserRole.CUSTOMER,
      id: { notIn: [post.authorId, ...likedBy.map((like) => like.userId)] },
    },
    select: { id: true },
  });
  assert.ok(shopper, 'every seeded shopper already likes this post');
  const actor = asUser(shopper.id, UserRole.CUSTOMER);

  const before = await db.commerceContent.findUnique({
    where: { id: post.id },
    select: { reactionsCount: true },
  });

  await interactions.react(actor, post.id);
  const liked = await db.commerceContent.findUnique({
    where: { id: post.id },
    select: { reactionsCount: true },
  });
  assert.equal(
    Number(liked!.reactionsCount),
    Number(before!.reactionsCount) + 1,
  );

  await interactions.react(actor, post.id);
  const unliked = await db.commerceContent.findUnique({
    where: { id: post.id },
    select: { reactionsCount: true },
  });
  assert.equal(Number(unliked!.reactionsCount), Number(before!.reactionsCount));
  assert.equal(
    await db.commerceContentReaction.count({
      where: { contentId: post.id, userId: shopper.id },
    }),
    0,
  );
});

dbTest('the counter equals the rows behind it', async ({ db, interactions }) => {
  // The invariant that catches the double-counting failure: two writers on one
  // counter is invisible until somebody counts.
  const post = await aSellerPost(db);
  const shopper = await aShopper(db, post.authorId);

  await interactions.react(asUser(shopper.id, UserRole.CUSTOMER), post.id);

  const [content, rows] = await Promise.all([
    db.commerceContent.findUnique({
      where: { id: post.id },
      select: { reactionsCount: true },
    }),
    db.commerceContentReaction.count({ where: { contentId: post.id } }),
  ]);
  assert.equal(Number(content!.reactionsCount), rows);
});

dbTest('a reply is re-parented to the thread root, never deeper', async ({
  db,
  interactions,
}) => {
  const post = await aSellerPost(db);
  const shopper = await aShopper(db, post.authorId);
  const actor = asUser(shopper.id, UserRole.CUSTOMER);

  const root = await interactions.comment(actor, post.id, 'حلوة كتير');
  const reply = await interactions.comment(actor, post.id, 'فعلاً', root.id);
  const deeper = await interactions.comment(actor, post.id, 'وأنا كمان', reply.id);

  assert.equal(reply.parentId, root.id);
  assert.equal(
    deeper.parentId,
    root.id,
    'a reply to a reply was allowed to nest a third level',
  );
});

// ── Moderation ──────────────────────────────────────────────────────────────

dbTest('a takedown demands a reason', async ({ db, moderation }) => {
  const post = await aSellerPost(db);
  const admin = await db.user.findFirst({
    where: { role: UserRole.SUPER_ADMIN },
    select: { id: true },
  });
  assert.ok(admin);

  await assert.rejects(
    () =>
      moderation.remove(asUser(admin.id, UserRole.SUPER_ADMIN), post.id, 'no'),
    /REMOVAL_REASON_REQUIRED/,
  );
});

dbTest('a takedown is a state, a trail and an audit row — never a delete', async ({
  db,
  moderation,
}) => {
  const post = await aSellerPost(db);
  const admin = await db.user.findFirst({
    where: { role: UserRole.SUPER_ADMIN },
    select: { id: true },
  });
  assert.ok(admin);
  const reason = 'الصورة لا تلتزم بسياسة المحتوى المعتمدة لدينا.';

  await moderation.remove(asUser(admin.id, UserRole.SUPER_ADMIN), post.id, reason);

  const after = await db.commerceContent.findUnique({
    where: { id: post.id },
    select: { status: true, removalReason: true, removedById: true },
  });
  assert.ok(after, 'the content was deleted rather than removed');
  assert.equal(after.status, CommerceContentStatus.REMOVED);
  assert.equal(after.removalReason, reason);
  assert.equal(after.removedById, admin.id);

  const action = await db.commerceContentModerationAction.findFirst({
    where: { contentId: post.id },
    orderBy: { createdAt: 'desc' },
  });
  assert.equal(action?.reason, reason);

  const audit = await db.auditLog.findFirst({
    where: { action: 'content_removed', actorId: admin.id },
    orderBy: { createdAt: 'desc' },
  });
  assert.ok(audit, 'the takedown was not audited');
});

dbTest('removed content cannot be interacted with', async ({
  db,
  moderation,
  interactions,
}) => {
  const post = await aSellerPost(db);
  const shopper = await aShopper(db, post.authorId);
  const admin = await db.user.findFirst({
    where: { role: UserRole.SUPER_ADMIN },
    select: { id: true },
  });
  assert.ok(admin);

  await moderation.remove(
    asUser(admin.id, UserRole.SUPER_ADMIN),
    post.id,
    'مخالف لسياسة المحتوى لدينا.',
  );

  // A woman holding a stale card must not be able to like something that has
  // been taken down.
  await assert.rejects(
    () => interactions.react(asUser(shopper.id, UserRole.CUSTOMER), post.id),
    /CONTENT_REMOVED/,
  );
});

dbTest('a non-moderator cannot take anything down', async ({ db, moderation }) => {
  const post = await aSellerPost(db);
  const shopper = await aShopper(db, post.authorId);
  await assert.rejects(
    () =>
      moderation.remove(
        asUser(shopper.id, UserRole.CUSTOMER),
        post.id,
        'أنا ما بحبها هالصورة أبداً.',
      ),
    /moderators/,
  );
});

// ── Visibility ──────────────────────────────────────────────────────────────

dbTest('a private page keeps its content out of a stranger\'s feed', async ({
  db,
  feed,
}) => {
  const author = await db.user.findFirst({
    where: { role: UserRole.CUSTOMER },
    select: { id: true },
  });
  const stranger = await db.user.findFirst({
    where: { role: UserRole.CUSTOMER, id: { not: author!.id } },
    select: { id: true },
  });
  assert.ok(author && stranger);

  const content = await db.commerceContent.create({
    data: {
      authorId: author.id,
      authorKind: CommerceAuthorKind.CUSTOMER,
      // Fails closed: a page nobody has opened publishes nothing.
      authorIsPublic: false,
      contentType: 'product_post',
      body: 'إطلالة اليوم',
      status: CommerceContentStatus.PUBLISHED,
      moderationStatus: 'APPROVED',
      publishedAt: new Date(),
      payload: { caption: 'إطلالة اليوم' },
      publicationTargets: ['HOME_FEED'],
    },
  });

  const strangerFeed = await feed.feed(
    { limit: 50 } as never,
    { viewerId: stranger.id },
  );
  assert.ok(
    !strangerFeed.items.some((item) => item.id === content.id),
    'a private page reached a stranger',
  );

  // And she can always see her own.
  const ownFeed = await feed.feed({ limit: 50 } as never, { viewerId: author.id });
  assert.ok(ownFeed.items.some((item) => item.id === content.id));
});

dbTest('her page timeline carries what she published and what she added', async ({
  db,
  feed,
  interactions,
}) => {
  const post = await aSellerPost(db);
  const shopper = await anOpenShopper(db, post.authorId);

  await interactions.reshare(asUser(shopper.id, UserRole.CUSTOMER), post.id);

  const timeline = await feed.userTimeline(
    shopper.id,
    { limit: 50 } as never,
    shopper.id,
  );
  const reshared = timeline.items.find(
    (entry) => (entry as { kind: string }).kind === 'reshare',
  ) as { reshare: { sourceContent: { id: string; authorId: string } } } | undefined;

  assert.ok(reshared, 'the reshare did not appear on her page');
  assert.equal(reshared.reshare.sourceContent.id, post.id);
  assert.equal(
    reshared.reshare.sourceContent.authorId,
    post.authorId,
    'the boutique was not credited on her page',
  );
});

dbTest('a takedown reaches every page the post was added to', async ({
  db,
  feed,
  interactions,
  moderation,
}) => {
  // The argument that decided the timeline design: with a live query this is
  // automatic; with a materialised timeline it is a fan-out, and one missed
  // row leaves removed content on somebody's page.
  const post = await aSellerPost(db);
  const shopper = await anOpenShopper(db, post.authorId);
  const admin = await db.user.findFirst({
    where: { role: UserRole.SUPER_ADMIN },
    select: { id: true },
  });
  assert.ok(admin);

  await interactions.reshare(asUser(shopper.id, UserRole.CUSTOMER), post.id);
  const before = await feed.userTimeline(
    shopper.id,
    { limit: 50 } as never,
    shopper.id,
  );
  assert.ok(before.items.length > 0);

  await moderation.remove(
    asUser(admin.id, UserRole.SUPER_ADMIN),
    post.id,
    'أزلناه بعد مراجعة البلاغات الواردة.',
  );

  const after = await feed.userTimeline(
    shopper.id,
    { limit: 50 } as never,
    shopper.id,
  );
  const stillThere = after.items.some((entry) => {
    const e = entry as { kind: string; reshare?: { sourceContent: { id: string } } };
    return e.kind === 'reshare' && e.reshare?.sourceContent.id === post.id;
  });
  assert.equal(stillThere, false, 'removed content survived on a resharer page');
});
