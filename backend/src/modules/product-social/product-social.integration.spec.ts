import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CommerceContentStatus,
  PrismaClient,
  ProductStatus,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { AuthUser } from '../../common/decorators/current-user.decorator';
import { CacheService } from '../../common/cache/cache.service';
import { PaginationDto } from '../../common/dto/pagination.dto';
import { CursorPageDto } from '../../common/dto/cursor-pagination.dto';
import { ContentFeedService } from '../commerce-content/feed/content-feed.service';
import { ContentFeedControlsService } from '../commerce-content/feed/content-feed-controls.service';
import { ProductSocialService } from './product-social.service';

/**
 * Product likes, picks and comments, and the feed controls behind the post
 * menu — against the real database, each case rolled back.
 *
 * What these pin is the part a unit test cannot: that a counter on `products`
 * and the rows beneath it agree after a replay, a race-shaped double call, or
 * a removal; and that a woman's «غير مهتمة» reaches the feed query itself.
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

interface World {
  db: PrismaService;
  social: ProductSocialService;
  feed: ContentFeedService;
  controls: ContentFeedControlsService;
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
          const db = asPrisma(tx);
          try {
            await body({
              db,
              social: new ProductSocialService(db),
              feed: new ContentFeedService(db, new CacheService()),
              controls: new ContentFeedControlsService(db),
            });
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

const asUser = (id: string, role: UserRole): AuthUser => ({
  id,
  phone: '+963900000000',
  role,
});

function page(limit = 20): PaginationDto {
  return Object.assign(new PaginationDto(), { page: 1, limit });
}

async function aProduct(db: PrismaService) {
  const product = await db.product.findFirst({
    where: { status: ProductStatus.ACTIVE },
    select: {
      id: true,
      likesCount: true,
      commentsCount: true,
      picksCount: true,
    },
  });
  assert.ok(product, 'the seeded shop has no active product');
  return product;
}

async function twoShoppers(db: PrismaService) {
  const users = await db.user.findMany({
    where: { role: UserRole.CUSTOMER },
    select: { id: true },
    take: 2,
  });
  assert.equal(users.length, 2, 'the seeded shop needs two shoppers');
  return users;
}

// ── Likes ───────────────────────────────────────────────────────────────────

dbTest('a replayed like counts once, and unlike returns the count', async ({
  db,
  social,
}) => {
  const product = await aProduct(db);
  const [shopper] = await twoShoppers(db);

  const first = await social.like(shopper.id, product.id);
  const replay = await social.like(shopper.id, product.id);
  assert.equal(first.likes_count, product.likesCount + 1);
  // The outbox replays a tap made offline. A desired state replayed is still
  // the same state — not a second like.
  assert.equal(replay.likes_count, product.likesCount + 1);

  const undone = await social.unlike(shopper.id, product.id);
  const undoneAgain = await social.unlike(shopper.id, product.id);
  assert.equal(undone.likes_count, product.likesCount);
  assert.equal(undoneAgain.likes_count, product.likesCount, 'unlike drove the count below its rows');

  const liked = await db.productLike.count({
    where: { productId: product.id, userId: shopper.id },
  });
  const stored = await db.product.findUniqueOrThrow({
    where: { id: product.id },
    select: { likesCount: true },
  });
  assert.equal(liked, 0);
  assert.equal(stored.likesCount, product.likesCount, 'counter and rows disagree');
});

// ── Picks ───────────────────────────────────────────────────────────────────

dbTest('a closed page hides her picks from a stranger, not from her', async ({
  db,
  social,
}) => {
  const product = await aProduct(db);
  const [owner, stranger] = await twoShoppers(db);
  await db.user.update({
    where: { id: owner.id },
    data: { profileIsPublic: false },
  });

  const picked = await social.pick(owner.id, product.id, 'لبستها بعرس أختي');
  assert.equal(picked.picks_count, product.picksCount + 1);

  const toStranger = await social.picksOf(owner.id, page(), stranger.id);
  assert.equal(toStranger.is_private, true);
  assert.equal(toStranger.data.length, 0, 'a closed page leaked a pick');

  const toGuest = await social.picksOf(owner.id, page(), undefined);
  assert.equal(toGuest.data.length, 0, 'a closed page leaked a pick to a guest');

  const toHer = await social.picksOf(owner.id, page(), owner.id);
  assert.ok(toHer.data.some((row) => row.id === product.id));
  assert.equal(
    toHer.data.find((row) => row.id === product.id)?.pick.note,
    'لبستها بعرس أختي',
  );

  // Opening the page is enough — nothing to rebuild.
  await db.user.update({
    where: { id: owner.id },
    data: { profileIsPublic: true },
  });
  const opened = await social.picksOf(owner.id, page(), stranger.id);
  assert.ok(opened.data.some((row) => row.id === product.id));
});

dbTest('picking again edits the note and is not a second pick', async ({
  db,
  social,
}) => {
  const product = await aProduct(db);
  const [owner] = await twoShoppers(db);

  await social.pick(owner.id, product.id, 'first');
  const again = await social.pick(owner.id, product.id, 'second');
  assert.equal(again.picks_count, product.picksCount + 1);

  const row = await db.productPick.findUniqueOrThrow({
    where: { userId_productId: { userId: owner.id, productId: product.id } },
  });
  assert.equal(row.note, 'second');
});

// ── Comments ────────────────────────────────────────────────────────────────

dbTest('a comment moves the tally, and a removal moves it back once', async ({
  db,
  social,
}) => {
  const product = await aProduct(db);
  const [author, other] = await twoShoppers(db);

  const comment = await social.addComment(
    asUser(author.id, UserRole.CUSTOMER),
    product.id,
    '  متوفر مقاس M؟  ',
  );
  assert.equal(comment.content, 'متوفر مقاس M؟');

  const listed = await social.listComments(product.id, page());
  assert.equal(listed.data[0].id, comment.id);

  // Somebody else may not remove it.
  await assert.rejects(
    social.removeComment(asUser(other.id, UserRole.CUSTOMER), product.id, comment.id),
  );

  await social.removeComment(asUser(author.id, UserRole.CUSTOMER), product.id, comment.id);
  await social.removeComment(asUser(author.id, UserRole.CUSTOMER), product.id, comment.id);

  const stored = await db.product.findUniqueOrThrow({
    where: { id: product.id },
    select: { commentsCount: true },
  });
  assert.equal(stored.commentsCount, product.commentsCount, 'a double removal decremented twice');

  // The row stays, as evidence.
  const row = await db.productComment.findUniqueOrThrow({ where: { id: comment.id } });
  assert.equal(row.status, 'REMOVED');
});

// ── The batch read ──────────────────────────────────────────────────────────

dbTest('the batch read answers for this viewer only', async ({ db, social }) => {
  const product = await aProduct(db);
  const [her, stranger] = await twoShoppers(db);

  await social.like(her.id, product.id);
  await social.pick(her.id, product.id);

  const mine = await social.engagement([product.id], her.id);
  assert.equal(mine[product.id].is_liked, true);
  assert.equal(mine[product.id].is_picked, true);

  const theirs = await social.engagement([product.id], stranger.id);
  assert.equal(theirs[product.id].is_liked, false);
  assert.equal(theirs[product.id].is_picked, false);
  assert.equal(theirs[product.id].likes_count, mine[product.id].likes_count);

  const guest = await social.engagement([product.id]);
  assert.equal(guest[product.id].is_liked, false);
});

// ── Feed controls ───────────────────────────────────────────────────────────

dbTest('«غير مهتمة» and a mute leave her feed, not the page', async ({
  db,
  feed,
  controls,
}) => {
  const post = await db.commerceContent.findFirst({
    where: {
      status: CommerceContentStatus.PUBLISHED,
      visibility: 'PUBLIC',
      authorIsPublic: true,
      contentType: 'product_post',
    },
    select: { id: true, authorId: true },
  });
  assert.ok(post, 'the seeded shop has no public post');
  const viewer = await db.user.findFirstOrThrow({
    where: { role: UserRole.CUSTOMER, id: { not: post.authorId } },
    select: { id: true },
  });

  const cursor = Object.assign(new CursorPageDto(), { limit: 50 });
  const ids = async () =>
    (await feed.feed(cursor, { viewerId: viewer.id, contentType: 'product_post' })).items.map(
      (item) => item.id,
    );

  await controls.hide(viewer.id, post.id);
  assert.ok(!(await ids()).includes(post.id), 'a hidden post stayed in her feed');

  await controls.unhide(viewer.id, post.id);
  await controls.mute(viewer.id, post.authorId);
  const afterMute = await feed.feed(cursor, {
    viewerId: viewer.id,
    contentType: 'product_post',
  });
  assert.ok(
    afterMute.items.every((item) => item.authorId !== post.authorId),
    'a muted account stayed in her feed',
  );

  // Visiting the page is deliberate, and a mute does not lock it.
  const page = await feed.feed(cursor, {
    viewerId: viewer.id,
    authorId: post.authorId,
  });
  assert.ok(page.items.some((item) => item.id === post.id), 'a mute hid the page itself');
});
