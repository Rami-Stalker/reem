import assert from 'node:assert/strict';
import test from 'node:test';
import { ConfigService } from '@nestjs/config';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  CommerceAuthorKind,
  CommerceContentModerationStatus,
  CommerceContentStatus,
  CommerceContentVisibility,
  MediaType,
  PrismaClient,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { CacheService } from '../../common/cache/cache.service';
import { AuditService } from '../auth/audit.service';
import { ContentAttributionService } from './attribution/content-attribution.service';
import { CommerceContentRepository } from './commerce-content.repository';
import { CommerceContentService } from './commerce-content.service';
import { ContentTypeRegistryService } from './content-type-registry.service';
import { ContentInteractionsService } from './interactions/content-interactions.service';
import { ContentModerationService } from './moderation/content-moderation.service';
import { ProductTagPolicyService } from './tagging/product-tag-policy.service';

/**
 * Reels and stories through their whole life — publish, edit, report, take
 * down, reinstate — against the real database.
 *
 * Each case is a way the lifecycle could be walked round: republishing a
 * takedown, editing a clean caption into a phone number, stretching a
 * story past its day, liking what one cannot see. Every case runs inside a
 * transaction that is rolled back.
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
  content: CommerceContentService;
  interactions: ContentInteractionsService;
  moderation: ContentModerationService;
}

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const events = new EventEmitter2();
  const config = new ConfigService({});
  const repo = new CommerceContentRepository(db);
  const moderation = new ContentModerationService(
    db,
    new AuditService(db),
    events,
    new CacheService(),
  );
  return {
    db,
    content: new CommerceContentService(
      repo,
      new ContentTypeRegistryService(repo),
      events,
      new CacheService(),
      new ProductTagPolicyService(db, config),
      moderation,
    ),
    interactions: new ContentInteractionsService(
      db,
      events,
      new ContentAttributionService(db),
    ),
    moderation,
  };
}

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

// ── Fixtures ────────────────────────────────────────────────────────────────

const asUser = (id: string, role: UserRole): AuthUser => ({
  id,
  phone: '+963900000000',
  role,
});

/** A verified boutique with an open page, and a shopper who is not her. */
async function cast(db: PrismaService) {
  const sellerContent = await db.commerceContent.findFirst({
    where: { authorKind: CommerceAuthorKind.SELLER, authorIsPublic: true },
    select: { authorId: true },
  });
  assert.ok(sellerContent, 'the seed has no boutique with an open page');
  const shopper = await db.user.findFirst({
    where: { role: UserRole.CUSTOMER, id: { not: sellerContent.authorId } },
    select: { id: true },
  });
  assert.ok(shopper, 'the seed has no shopper');
  const admin = await db.user.findFirst({
    where: { role: UserRole.SUPER_ADMIN },
    select: { id: true },
  });
  assert.ok(admin, 'the seed has no super admin');
  // Not following, so followers-only is a real wall in these cases.
  await db.follow.deleteMany({
    where: { followerId: shopper.id, followingId: sellerContent.authorId },
  });
  return {
    seller: asUser(sellerContent.authorId, UserRole.SELLER),
    shopper: asUser(shopper.id, UserRole.CUSTOMER),
    admin: asUser(admin.id, UserRole.SUPER_ADMIN),
  };
}

const REEL_MEDIA = [
  {
    url: 'https://cdn.example.test/reel.mp4',
    type: MediaType.video,
    duration_ms: 12_000,
  },
];

async function aPublishedReel(
  world: World,
  seller: AuthUser,
  caption = 'إطلالة الربيع',
) {
  const draft = await world.content.create(seller, {
    content_type: 'reel',
    body: caption,
    payload: { caption },
    media: REEL_MEDIA,
  } as never);
  const published = await world.content.publish(seller, draft.id);
  assert.equal(String(published.status).toUpperCase(), CommerceContentStatus.PUBLISHED);
  return draft.id;
}

const REASON = 'مخالف لسياسة المحتوى المعتمدة لدينا.';

// ── Publishing ──────────────────────────────────────────────────────────────

dbTest('a story published the way the composer sends it gets its frames', async (world) => {
  const { seller } = await cast(world.db);
  // The composer sends a caption and media, like every other format — no
  // `frames`, which the story schema requires. This used to be a 400.
  const draft = await world.content.create(seller, {
    content_type: 'story',
    body: 'وصلت التشكيلة',
    payload: { caption: 'وصلت التشكيلة' },
    media: [{ url: 'https://cdn.example.test/story.jpg', type: MediaType.image }],
  } as never);
  const published = await world.content.publish(seller, draft.id);
  assert.equal(String(published.status).toUpperCase(), CommerceContentStatus.PUBLISHED);

  const row = await world.db.commerceContent.findUnique({
    where: { id: draft.id },
    select: { payload: true, expiresAt: true },
  });
  const frames = (row?.payload as { frames?: unknown[] }).frames;
  assert.equal(frames?.length, 1, 'the frames were not derived from the media');
  assert.ok(row?.expiresAt, 'a story was published without an expiry');
});

dbTest('publishing twice does not bump the piece back to the top', async (world) => {
  const { seller } = await cast(world.db);
  const id = await aPublishedReel(world, seller);
  const first = await world.db.commerceContent.findUnique({
    where: { id },
    select: { publishedAt: true },
  });
  await new Promise((resolve) => setTimeout(resolve, 20));
  await world.content.publish(seller, id);
  const second = await world.db.commerceContent.findUnique({
    where: { id },
    select: { publishedAt: true },
  });
  assert.equal(second?.publishedAt?.getTime(), first?.publishedAt?.getTime());
});

// ── Editing ─────────────────────────────────────────────────────────────────

dbTest('a reel cannot be edited into having no video', async (world) => {
  const { seller } = await cast(world.db);
  const id = await aPublishedReel(world, seller);
  await assert.rejects(
    () =>
      world.content.update(seller, id, {
        media: [{ url: 'https://cdn.example.test/still.jpg', type: MediaType.image }],
      } as never),
    /VIDEO_REQUIRED/,
  );
});

/** Open automatic (word-screen) cases against one piece. */
function autoCases(world: World, contentId: string) {
  return world.db.moderationCase.count({
    where: {
      targetType: 'commerce_content',
      targetId: contentId,
      reporterId: null,
      status: 'OPEN',
      reason: { startsWith: 'auto_flag' },
    },
  });
}

dbTest('a clean caption edited into a phone number stays live and is flagged once', async (world) => {
  const { seller } = await cast(world.db);
  const id = await aPublishedReel(world, seller);

  await world.content.update(seller, id, {
    body: 'للطلب راسلوني على واتساب',
  } as never);
  await world.content.update(seller, id, {
    body: 'للطلب راسلوني على واتساب الآن',
  } as never);

  const row = await world.db.commerceContent.findUnique({
    where: { id },
    select: { status: true, moderationStatus: true, reportsCount: true },
  });
  assert.equal(row?.status, CommerceContentStatus.PUBLISHED);
  assert.equal(row?.moderationStatus, CommerceContentModerationStatus.APPROVED);
  assert.equal(row?.reportsCount, 1);
  assert.equal(await autoCases(world, id), 1);
});

dbTest("a shopper's very first post goes straight to the feed", async (world) => {
  const { shopper } = await cast(world.db);
  const draft = await world.content.create(shopper, {
    content_type: 'reel',
    body: 'أول إطلالة لي',
    payload: { caption: 'أول إطلالة لي' },
    media: REEL_MEDIA,
  } as never);
  const published = await world.content.publish(shopper, draft.id);
  assert.equal(String(published.status).toUpperCase(), CommerceContentStatus.PUBLISHED);
});

dbTest('a story can be shortened but never stretched past its day', async (world) => {
  const { seller } = await cast(world.db);
  const draft = await world.content.create(seller, {
    content_type: 'story',
    payload: {},
    media: [{ url: 'https://cdn.example.test/story.jpg', type: MediaType.image }],
  } as never);
  await world.content.publish(seller, draft.id);

  const twoDays = new Date(Date.now() + 48 * 60 * 60_000).toISOString();
  await assert.rejects(
    () => world.content.update(seller, draft.id, { expires_at: twoDays } as never),
    /EXPIRY_BEYOND_24H/,
  );
  await assert.rejects(
    () => world.content.update(seller, draft.id, { expires_at: null } as never),
    /EXPIRY_REQUIRED_FOR_FORMAT/,
  );
  const inAnHour = new Date(Date.now() + 60 * 60_000).toISOString();
  await world.content.update(seller, draft.id, { expires_at: inAnHour } as never);
});

// ── Takedowns ───────────────────────────────────────────────────────────────

dbTest('an author cannot publish, edit, roll back or delete her way round a takedown', async (world) => {
  const { seller, admin } = await cast(world.db);
  const id = await aPublishedReel(world, seller);
  await world.moderation.remove(admin, id, REASON);

  await assert.rejects(() => world.content.publish(seller, id), /CONTENT_REMOVED/);
  await assert.rejects(
    () => world.content.update(seller, id, { body: 'نسخة جديدة' } as never),
    /CONTENT_REMOVED/,
  );
  await assert.rejects(() => world.content.rollback(seller, id, 1), /CONTENT_REMOVED/);
  await assert.rejects(() => world.content.archive(seller, id), /CONTENT_REMOVED/);
  await assert.rejects(() => world.content.deleteOwn(seller, id), /CONTENT_REMOVED/);

  const row = await world.db.commerceContent.findUnique({
    where: { id },
    select: { status: true },
  });
  assert.equal(row?.status, CommerceContentStatus.REMOVED);
});

dbTest('a reinstated draft comes back a draft, not onto the feed', async (world) => {
  const { seller, admin } = await cast(world.db);
  const draft = await world.content.create(seller, {
    content_type: 'reel',
    body: 'مسودة',
    payload: { caption: 'مسودة' },
    media: REEL_MEDIA,
  } as never);
  await world.moderation.remove(admin, draft.id, REASON);
  const result = await world.moderation.reinstate(admin, draft.id, REASON);

  assert.equal(result.status, CommerceContentStatus.DRAFT);
  const row = await world.db.commerceContent.findUnique({
    where: { id: draft.id },
    select: { status: true },
  });
  assert.equal(row?.status, CommerceContentStatus.DRAFT);
});

dbTest('a published reel comes back published', async (world) => {
  const { seller, admin } = await cast(world.db);
  const id = await aPublishedReel(world, seller);
  await world.moderation.remove(admin, id, REASON);
  const result = await world.moderation.reinstate(admin, id, REASON);
  assert.equal(result.status, CommerceContentStatus.PUBLISHED);
});

// ── Reporting ───────────────────────────────────────────────────────────────

dbTest('she cannot report her own reel', async (world) => {
  const { seller } = await cast(world.db);
  const id = await aPublishedReel(world, seller);
  await assert.rejects(
    () => world.moderation.report(seller, id, 'spam'),
    /CANNOT_REPORT_OWN_CONTENT/,
  );
});

dbTest('reporting twice is one report', async (world) => {
  const { seller, shopper } = await cast(world.db);
  const id = await aPublishedReel(world, seller);
  const first = await world.moderation.report(shopper, id, 'spam');
  const second = await world.moderation.report(shopper, id, 'spam');
  assert.equal(first.already, false);
  assert.equal(second.already, true);
  const row = await world.db.commerceContent.findUnique({
    where: { id },
    select: { reportsCount: true },
  });
  assert.equal(row?.reportsCount, 1);
});

// ── Visibility on the write paths ───────────────────────────────────────────

dbTest('a stranger cannot like or comment on a followers-only reel by its id', async (world) => {
  const { seller, shopper } = await cast(world.db);
  const id = await aPublishedReel(world, seller);
  await world.db.commerceContent.update({
    where: { id },
    data: { visibility: CommerceContentVisibility.FOLLOWERS },
  });

  await assert.rejects(() => world.interactions.react(shopper, id), /not found/i);
  await assert.rejects(
    () => world.interactions.comment(shopper, id, 'جميلة'),
    /not found/i,
  );

  // Following her opens it.
  await world.db.follow.create({
    data: { followerId: shopper.id, followingId: seller.id },
  });
  const state = await world.interactions.react(shopper, id);
  assert.equal(state.is_liked, true);
});

dbTest('an expired story cannot be reacted to before the sweep reaches it', async (world) => {
  const { seller, shopper } = await cast(world.db);
  const draft = await world.content.create(seller, {
    content_type: 'story',
    payload: {},
    media: [{ url: 'https://cdn.example.test/story.jpg', type: MediaType.image }],
  } as never);
  await world.content.publish(seller, draft.id);
  // Still PUBLISHED — the expiry job has not run — but past its day.
  await world.db.commerceContent.update({
    where: { id: draft.id },
    data: { expiresAt: new Date(Date.now() - 1_000) },
  });
  await assert.rejects(
    () => world.interactions.react(shopper, draft.id, '🔥'),
    /CONTENT_EXPIRED/,
  );
});

// ── Her audience ────────────────────────────────────────────────────────────

dbTest('the owner sees who watched her story, and nobody else may', async (world) => {
  const { seller, shopper } = await cast(world.db);
  const draft = await world.content.create(seller, {
    content_type: 'story',
    payload: {},
    media: [{ url: 'https://cdn.example.test/story.jpg', type: MediaType.image }],
  } as never);
  await world.content.publish(seller, draft.id);
  await world.db.commerceContentViewer.create({
    data: { contentId: draft.id, userId: shopper.id },
  });
  await world.interactions.react(shopper, draft.id, '😍');

  const audience = await world.interactions.audience(seller, draft.id);
  assert.equal(audience.viewers.length, 1);
  assert.equal(audience.viewers[0].user.id, shopper.id);
  assert.equal(audience.viewers[0].reaction, '😍');
  assert.equal(audience.reaction_breakdown['😍'], 1);

  await assert.rejects(() => world.interactions.audience(shopper, draft.id));
});

dbTest('a flagged caption is published at once and put in front of a moderator', async (world) => {
  const { seller } = await cast(world.db);
  const draft = await world.content.create(seller, {
    content_type: 'reel',
    body: 'للطلب على واتساب',
    payload: { caption: 'للطلب على واتساب' },
    media: REEL_MEDIA,
  } as never);

  const published = await world.content.publish(seller, draft.id);
  assert.equal(String(published.status).toUpperCase(), CommerceContentStatus.PUBLISHED);
  // A second tap is not a second flag.
  await world.content.publish(seller, draft.id);
  assert.equal(await autoCases(world, draft.id), 1);
});

dbTest('keeping a reported piece clears it from the queue and leaves a trail', async (world) => {
  const { seller, shopper, admin } = await cast(world.db);
  const id = await aPublishedReel(world, seller);
  await world.moderation.report(shopper, id, 'spam');

  const result = await world.moderation.dismissReports(admin, id);
  assert.equal(result.cases_closed, 1);

  const row = await world.db.commerceContent.findUnique({
    where: { id },
    select: { status: true, reportsCount: true },
  });
  assert.equal(row?.status, CommerceContentStatus.PUBLISHED);
  assert.equal(row?.reportsCount, 0);
  const history = await world.moderation.history(admin, id);
  assert.equal(history.length, 1);
});

dbTest('a reinstated piece leaves the reported queue', async (world) => {
  const { seller, shopper, admin } = await cast(world.db);
  const id = await aPublishedReel(world, seller);
  await world.moderation.report(shopper, id, 'spam');
  await world.moderation.remove(admin, id, REASON);
  await world.moderation.reinstate(admin, id, REASON);

  const row = await world.db.commerceContent.findUnique({
    where: { id },
    select: { status: true, reportsCount: true },
  });
  assert.equal(row?.status, CommerceContentStatus.PUBLISHED);
  assert.equal(row?.reportsCount, 0);
});

dbTest('a piece its author deleted cannot be removed and so never reinstated', async (world) => {
  const { seller, admin } = await cast(world.db);
  const id = await aPublishedReel(world, seller);
  await world.db.commerceContent.update({
    where: { id },
    data: { status: CommerceContentStatus.DELETED },
  });
  await assert.rejects(
    () => world.moderation.remove(admin, id, REASON),
    /ALREADY_DELETED_BY_AUTHOR/,
  );
});
