import assert from 'node:assert/strict';
import test from 'node:test';
import {
  CommerceAuthorKind,
  CommerceContentStatus,
  MediaType,
  PrismaClient,
  UserRole,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { HighlightsService } from './highlights.service';

/**
 * «الأبرز» — the shelf a story survives on.
 *
 * What is pinned here is the part that is not obvious from the schema: that a
 * highlight outlives the twenty-four hours its story does not, that a stranger
 * sees a private woman's rail not at all and a boutique's always, that nothing
 * belonging to anybody else can be put on a shelf, and that a story taken down
 * leaves every shelf that carried it rather than living on in one.
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

interface World {
  tx: Tx;
  highlights: HighlightsService;
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
            await body({ tx, highlights: build(tx) });
          } catch (error) {
            failure = error;
          }
          throw new Rollback();
        },
        { timeout: 60_000 },
      );
    } catch (error) {
      if (!(error instanceof Rollback)) throw error;
    }
    if (failure) throw failure;
  });
}

function build(tx: Tx): HighlightsService {
  const db = new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (arg: unknown) =>
          typeof arg === 'function'
            ? (arg as (inner: Tx) => unknown)(tx)
            : Promise.all(arg as Promise<unknown>[]);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;
  return new HighlightsService(db);
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;

async function makeUser(
  tx: Tx,
  tag: string,
  role: UserRole,
  profileIsPublic = false,
) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `hl-${tag}`,
      username: `hl_${u}`,
      phone: `+9638${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role,
      profileIsPublic,
    },
  });
}

/** A published story, expired unless told otherwise. */
async function makeStory(
  tx: Tx,
  authorId: string,
  options: { expired?: boolean; role?: UserRole } = {},
) {
  const url = `https://media.reem.sy/${uniq('s')}.jpg`;
  const expiresAt = new Date(
    Date.now() + (options.expired === false ? 3_600_000 : -3_600_000),
  );
  return tx.commerceContent.create({
    data: {
      authorId,
      authorKind:
        options.role === UserRole.SELLER
          ? CommerceAuthorKind.SELLER
          : CommerceAuthorKind.CUSTOMER,
      authorIsPublic: true,
      contentType: 'story',
      locale: 'ar',
      status: CommerceContentStatus.PUBLISHED,
      moderationStatus: 'APPROVED',
      publishedAt: new Date(),
      expiresAt,
      payload: { frames: [{ media_url: url, link: null }], legacy: 'story' },
      publicationTargets: ['STORY_FEED'],
      media: { create: [{ url, type: MediaType.image, sortOrder: 0 }] },
    },
  });
}

// ── The point of the feature ───────────────────────────────────────────────

dbTest('a highlight keeps a story past the day it expired', async (world) => {
  const seller = await makeUser(world.tx, 'a', UserRole.SELLER);
  const story = await makeStory(world.tx, seller.id, {
    expired: true,
    role: UserRole.SELLER,
  });

  const created = await world.highlights.create(seller.id, {
    title: 'مقاساتنا',
    content_ids: [story.id],
  });
  assert.equal(created.items_count, 1);

  // Expired an hour ago, and still on the shelf — which is the whole feature.
  const detail = await world.highlights.detail(created.id, seller.id);
  assert.equal(detail.stories?.length, 1);
  assert.equal(detail.stories?.[0].id, story.id);
});

dbTest('the cover falls back to the first story when none is set', async (world) => {
  const seller = await makeUser(world.tx, 'b', UserRole.SELLER);
  const story = await makeStory(world.tx, seller.id, { role: UserRole.SELLER });
  const media = await world.tx.commerceContentMedia.findFirst({
    where: { contentId: story.id },
  });

  const created = await world.highlights.create(seller.id, {
    title: 'إطلالات',
    content_ids: [story.id],
  });
  assert.equal(created.cover_url, media?.url);

  // And a cover she picks wins over it.
  const updated = await world.highlights.update(seller.id, created.id, {
    cover_url: 'https://media.reem.sy/cover.jpg',
  });
  assert.equal(updated.cover_url, 'https://media.reem.sy/cover.jpg');
});

// ── Whose stories, and whose shelves ───────────────────────────────────────

dbTest('a shelf holds only its owner’s own stories', async (world) => {
  const mine = await makeUser(world.tx, 'c', UserRole.SELLER);
  const hers = await makeUser(world.tx, 'd', UserRole.SELLER);
  const herStory = await makeStory(world.tx, hers.id, {
    role: UserRole.SELLER,
  });

  await assert.rejects(
    world.highlights.create(mine.id, {
      title: 'سرقة',
      content_ids: [herStory.id],
    }),
    /your own published stories/i,
  );
});

dbTest('somebody else’s shelf cannot be edited or emptied', async (world) => {
  const owner = await makeUser(world.tx, 'e', UserRole.SELLER);
  const stranger = await makeUser(world.tx, 'f', UserRole.CUSTOMER);
  const created = await world.highlights.create(owner.id, { title: 'خاص' });

  await assert.rejects(
    world.highlights.update(stranger.id, created.id, { title: 'مو إلها' }),
    /not yours/i,
  );
  await assert.rejects(
    world.highlights.remove(stranger.id, created.id),
    /not yours/i,
  );
});

// ── Who may look ───────────────────────────────────────────────────────────

dbTest('a private page shows its rail to nobody but her', async (world) => {
  const her = await makeUser(world.tx, 'g', UserRole.CUSTOMER, false);
  const story = await makeStory(world.tx, her.id);
  const created = await world.highlights.create(her.id, {
    title: 'يومي',
    content_ids: [story.id],
  });
  const stranger = await makeUser(world.tx, 'h', UserRole.CUSTOMER);

  const own = await world.highlights.listFor(her.id, her.id);
  assert.equal(own.length, 1);

  await assert.rejects(
    world.highlights.listFor(her.id, stranger.id),
    /private/i,
  );
  await assert.rejects(
    world.highlights.detail(created.id, stranger.id),
    /private/i,
  );
});

dbTest('a boutique’s rail is open even to a signed-out visitor', async (world) => {
  // A storefront nobody may look at is not a storefront — `profileIsPublic`
  // is false here on purpose, and the seller role is what decides.
  const seller = await makeUser(world.tx, 'i', UserRole.SELLER, false);
  const story = await makeStory(world.tx, seller.id, {
    role: UserRole.SELLER,
  });
  await world.highlights.create(seller.id, {
    title: 'الجديد',
    content_ids: [story.id],
  });

  const seen = await world.highlights.listFor(seller.id);
  assert.equal(seen.length, 1);
  assert.equal(seen[0].is_mine, false);
});

dbTest('an empty shelf is hers to see and nobody else’s', async (world) => {
  const seller = await makeUser(world.tx, 'j', UserRole.SELLER);
  await world.highlights.create(seller.id, { title: 'لسا فاضية' });

  assert.equal((await world.highlights.listFor(seller.id, seller.id)).length, 1);
  // A shelf with nothing on it is a note to herself, not something published.
  assert.equal((await world.highlights.listFor(seller.id)).length, 0);
});

// ── Housekeeping ───────────────────────────────────────────────────────────

dbTest('adding the same story twice moves it rather than duplicating it', async (world) => {
  const seller = await makeUser(world.tx, 'k', UserRole.SELLER);
  const first = await makeStory(world.tx, seller.id, { role: UserRole.SELLER });
  const second = await makeStory(world.tx, seller.id, { role: UserRole.SELLER });

  const created = await world.highlights.create(seller.id, {
    title: 'تكرار',
    content_ids: [first.id, second.id],
  });
  const after = await world.highlights.addItem(seller.id, created.id, {
    content_id: first.id,
  });

  assert.equal(after.items_count, 2);
  // It moved to the end, which is what tapping it again means.
  assert.deepEqual(
    after.stories?.map((story) => story.id),
    [second.id, first.id],
  );
});

dbTest('a story taken down leaves every shelf that carried it', async (world) => {
  const seller = await makeUser(world.tx, 'l', UserRole.SELLER);
  const story = await makeStory(world.tx, seller.id, { role: UserRole.SELLER });
  const created = await world.highlights.create(seller.id, {
    title: 'مراجعة',
    content_ids: [story.id],
  });

  // A highlight points at content; it never copies it, so this cascades.
  await world.tx.commerceContent.delete({ where: { id: story.id } });

  const after = await world.highlights.detail(created.id, seller.id);
  assert.equal(after.items_count, 0);
});

dbTest('the archive offers her expired stories, which the tray cannot', async (world) => {
  const seller = await makeUser(world.tx, 'm', UserRole.SELLER);
  const gone = await makeStory(world.tx, seller.id, {
    expired: true,
    role: UserRole.SELLER,
  });
  const live = await makeStory(world.tx, seller.id, {
    expired: false,
    role: UserRole.SELLER,
  });
  const someoneElse = await makeUser(world.tx, 'n', UserRole.SELLER);
  await makeStory(world.tx, someoneElse.id, { role: UserRole.SELLER });

  const archive = await world.highlights.archive(seller.id);
  const ids = archive.map((story) => story.id).sort();
  assert.deepEqual(ids, [gone.id, live.id].sort());
});

dbTest('reordering renumbers her rail and refuses a shelf that is not hers', async (world) => {
  const seller = await makeUser(world.tx, 'o', UserRole.SELLER);
  const stranger = await makeUser(world.tx, 'p', UserRole.SELLER);
  const first = await world.highlights.create(seller.id, { title: 'أ' });
  const second = await world.highlights.create(seller.id, { title: 'ب' });
  const theirs = await world.highlights.create(stranger.id, { title: 'ج' });

  const reordered = await world.highlights.reorder(seller.id, {
    highlight_ids: [second.id, first.id],
  });
  assert.deepEqual(
    reordered.map((highlight) => highlight.title),
    ['ب', 'أ'],
  );

  await assert.rejects(
    world.highlights.reorder(seller.id, {
      highlight_ids: [first.id, theirs.id],
    }),
    /not yours/i,
  );
});
