import assert from 'node:assert/strict';
import test from 'node:test';
import {
  ClosetGapStatus,
  ClosetItemSource,
  ClosetItemStatus,
  OutfitSlot,
  PrismaClient,
} from '@prisma/client';

import { PrismaService } from '../../prisma/prisma.service';
import { StylePreferenceService } from '../ai-stylist/preferences/style-preference.service';
import { ProductRetrievalService } from '../ai-stylist/retrieval/product-retrieval.service';
import { ClosetService } from './closet.service';
import { ClosetGapService } from './gaps/closet-gap.service';
import { ClosetItemService } from './items/closet-item.service';
import { ClosetLookService } from './looks/closet-look.service';
import { ClosetSuggestionService } from './suggestions/closet-suggestion.service';
import { ClosetTodayService } from './today/today.service';

/**
 * The closet against the real catalogue and the real database.
 *
 * The unit tests prove the four kernels in isolation. This proves the claims
 * that only the database can settle:
 *
 *   - a garment Ohara never sold reaches the engine on equal terms with one it
 *     did — the premise the whole feature rests on;
 *   - a gap survives recompute, and a dismissal survives it too;
 *   - a look may hold a slot she cannot fill, and that slot becomes a gap;
 *   - a gap resolves into products a customer can actually buy today.
 *
 * Every case runs inside a transaction that is rolled back, so the shop is
 * unchanged afterwards.
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
        { timeout: 60_000 },
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
  closet: ClosetService;
  items: ClosetItemService;
  looks: ClosetLookService;
  gaps: ClosetGapService;
  suggestions: ClosetSuggestionService;
  today: ClosetTodayService;
}

/** The upload claim is bookkeeping; it has no bearing on any assertion here. */
const noMedia = { markAttached: async () => 0 } as never;

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const closet = new ClosetService(db);
  const items = new ClosetItemService(db, closet, noMedia);
  const looks = new ClosetLookService(db, closet);
  const gaps = new ClosetGapService(db, closet);
  const retrieval = new ProductRetrievalService(db);
  const preferences = new StylePreferenceService(db);
  const suggestions = new ClosetSuggestionService(db, closet, retrieval, preferences);
  const today = new ClosetTodayService(db, closet);
  return { db, closet, items, looks, gaps, suggestions, today };
}

async function someCustomer(db: PrismaService): Promise<string> {
  const user = await db.user.findFirst({
    where: { role: 'CUSTOMER', disabledAt: null },
    select: { id: true },
  });
  assert.ok(user, 'the seeded shop has no customer');
  return user.id;
}

/** A live product in one of the seeded leaf categories. */
async function someProduct(db: PrismaService, slug: string): Promise<string> {
  const product = await db.product.findFirst({
    where: { status: 'ACTIVE', category: { slug } },
    select: { id: true },
  });
  assert.ok(product, `the seeded catalogue has no ${slug}`);
  return product.id;
}

// ── The premise ─────────────────────────────────────────────────────────

dbTest('a garment Ohara never sold is a first-class member of the closet', async (world) => {
  const userId = await someCustomer(world.db);

  const personal = await world.items.addPersonal(userId, {
    title: 'جاكيت جلد أسود من السوق',
    slot: OutfitSlot.OUTERWEAR,
  });

  // The descriptor was derived from her Arabic, not from a catalogue row.
  assert.equal(personal.source, ClosetItemSource.PERSONAL);
  assert.equal(personal.productId, null);
  assert.ok(personal.colours.includes('black'), 'colour read from her own words');
  assert.ok(personal.materials.includes('جلد'));

  // And it reaches the engine exactly as a purchased piece would.
  const snapshot = await world.closet.snapshot(userId);
  const fact = snapshot.items.find((item) => item.id === personal.id);
  assert.ok(fact, 'a personal piece must appear in the engine snapshot');
  assert.equal(fact.slot, OutfitSlot.OUTERWEAR);
});

dbTest('catalog and personal pieces are indistinguishable to the engine', async (world) => {
  const userId = await someCustomer(world.db);
  const productId = await someProduct(world.db, 'dresses');

  const bought = await world.items.addFromCatalog(userId, { productId });
  const owned = await world.items.addPersonal(userId, {
    title: 'فستان أسود',
    slot: OutfitSlot.DRESS,
  });

  const snapshot = await world.closet.snapshot(userId);
  const both = snapshot.items.filter(
    (item) => item.id === bought.id || item.id === owned.id,
  );

  assert.equal(both.length, 2);
  // The fact type carries no provenance at all — which is the design, stated
  // as a test so a later refactor cannot quietly add one.
  for (const fact of both) {
    assert.ok(!('source' in fact), 'the engine must not see where a piece came from');
  }
});

dbTest('adding the same product twice is one garment', async (world) => {
  const userId = await someCustomer(world.db);
  const productId = await someProduct(world.db, 'dresses');

  const first = await world.items.addFromCatalog(userId, { productId });
  const second = await world.items.addFromCatalog(userId, { productId });

  assert.equal(first.id, second.id);
});

// ── Looks ───────────────────────────────────────────────────────────────

dbTest('a look may hold a slot she cannot fill, and it becomes a gap', async (world) => {
  const userId = await someCustomer(world.db);
  const dressId = await someProduct(world.db, 'dresses');
  const bagId = await someProduct(world.db, 'handbags');

  const dress = await world.items.addFromCatalog(userId, { productId: dressId });

  const look = await world.looks.create(userId, {
    title: 'إطلالة سهرة',
    occasion: 'evening',
    items: [
      { slot: OutfitSlot.DRESS, closetItemId: dress.id },
      // She has chosen the bag; she does not own it.
      { slot: OutfitSlot.BAG, productId: bagId },
    ],
  });

  assert.equal(look.isComplete, false);
  assert.equal(look.items.length, 2);

  const gaps = await world.gaps.recompute(userId);
  const bagGap = gaps.find(
    (gap) => gap.slot === OutfitSlot.BAG && gap.lookId === look.id,
  );
  assert.ok(bagGap, 'the unfilled slot must produce a gap for that look');
  assert.equal(bagGap.kind, 'LOOK_SLOT');
});

dbTest('a look becomes complete when every slot is owned', async (world) => {
  const userId = await someCustomer(world.db);
  const dressId = await someProduct(world.db, 'dresses');

  const dress = await world.items.addFromCatalog(userId, { productId: dressId });
  const shoes = await world.items.addPersonal(userId, {
    title: 'حذاء أسود',
    slot: OutfitSlot.SHOES,
  });

  const look = await world.looks.create(userId, {
    title: 'إطلالة',
    items: [
      { slot: OutfitSlot.DRESS, closetItemId: dress.id },
      { slot: OutfitSlot.SHOES, closetItemId: shoes.id },
    ],
  });

  assert.equal(look.isComplete, true);
  // The palette is rolled up from the pieces so a suggestion for a later slot
  // can be told to harmonise.
  assert.ok(Array.isArray(look.palette));
});

dbTest('a slot naming both an owned piece and a product is refused', async (world) => {
  const userId = await someCustomer(world.db);
  const productId = await someProduct(world.db, 'dresses');
  const dress = await world.items.addFromCatalog(userId, { productId });

  const look = await world.looks.create(userId, { title: 'إطلالة' });

  await assert.rejects(
    () =>
      world.looks.setItems(userId, look.id, [
        { slot: OutfitSlot.DRESS, closetItemId: dress.id, productId },
      ]),
    /exactly one/,
  );
});

dbTest('a look cannot be built from someone else’s wardrobe', async (world) => {
  const userId = await someCustomer(world.db);
  const other = await world.db.user.findFirst({
    where: { role: 'CUSTOMER', disabledAt: null, id: { not: userId } },
    select: { id: true },
  });
  assert.ok(other, 'need a second customer');

  const productId = await someProduct(world.db, 'dresses');
  const hers = await world.items.addFromCatalog(other.id, { productId });
  const look = await world.looks.create(userId, { title: 'إطلالة' });

  await assert.rejects(
    () =>
      world.looks.setItems(userId, look.id, [
        { slot: OutfitSlot.DRESS, closetItemId: hers.id },
      ]),
    /not in your closet/,
  );
});

// ── Wearing ─────────────────────────────────────────────────────────────

dbTest('logging the same wearing twice is one wearing', async (world) => {
  const userId = await someCustomer(world.db);
  const item = await world.items.addPersonal(userId, {
    title: 'بلوزة',
    slot: OutfitSlot.TOP,
  });

  const once = await world.items.logWear(userId, item.id);
  const twice = await world.items.logWear(userId, item.id);

  assert.equal(once.wearCount, 1);
  assert.equal(twice.wearCount, 1);
  assert.ok(twice.lastWornAt);
});

dbTest('wearing a look records a wearing for every piece in it', async (world) => {
  const userId = await someCustomer(world.db);
  const top = await world.items.addPersonal(userId, {
    title: 'بلوزة بيضاء',
    slot: OutfitSlot.TOP,
  });
  const bottom = await world.items.addPersonal(userId, {
    title: 'تنورة كحلية',
    slot: OutfitSlot.BOTTOM,
  });

  const look = await world.looks.create(userId, {
    title: 'إطلالة يومية',
    items: [
      { slot: OutfitSlot.TOP, closetItemId: top.id },
      { slot: OutfitSlot.BOTTOM, closetItemId: bottom.id },
    ],
  });

  await world.looks.logWear(userId, look.id);

  const after = await world.db.closetItem.findMany({
    where: { id: { in: [top.id, bottom.id] } },
    select: { wearCount: true, lastWornAt: true },
  });

  assert.equal(after.length, 2);
  for (const piece of after) {
    assert.equal(piece.wearCount, 1, 'a look wearing fans out to its pieces');
    assert.ok(piece.lastWornAt);
  }
});

// ── Gaps ────────────────────────────────────────────────────────────────

dbTest('recompute is idempotent — the same gap is one row', async (world) => {
  const userId = await someCustomer(world.db);
  for (const title of ['فستان أول', 'فستان تاني', 'فستان تالت']) {
    await world.items.addPersonal(userId, { title, slot: OutfitSlot.DRESS });
  }

  const first = await world.gaps.recompute(userId);
  const second = await world.gaps.recompute(userId);

  assert.ok(first.length > 0, 'a closet of dresses and no shoes needs shoes');
  assert.deepEqual(
    first.map((gap) => gap.fingerprint).sort(),
    second.map((gap) => gap.fingerprint).sort(),
  );

  const closet = await world.closet.findOrCreate(userId);
  const rows = await world.db.closetGap.count({ where: { closetId: closet.id } });
  assert.equal(rows, first.length, 'recompute must upsert, never duplicate');
});

dbTest('a dismissal survives every future recompute', async (world) => {
  const userId = await someCustomer(world.db);
  for (const title of ['فستان أول', 'فستان تاني', 'فستان تالت']) {
    await world.items.addPersonal(userId, { title, slot: OutfitSlot.DRESS });
  }

  const gaps = await world.gaps.recompute(userId);
  const target = gaps[0];
  await world.gaps.dismiss(userId, target.id);

  const after = await world.gaps.recompute(userId);
  assert.ok(
    !after.some((gap) => gap.fingerprint === target.fingerprint),
    'a gap she refused must not come back',
  );

  const row = await world.db.closetGap.findUnique({ where: { id: target.id } });
  assert.equal(row?.status, ClosetGapStatus.DISMISSED);
});

dbTest('adding the missing piece closes the gap it answers', async (world) => {
  const userId = await someCustomer(world.db);
  for (const title of ['فستان أول', 'فستان تاني', 'فستان تالت']) {
    await world.items.addPersonal(userId, { title, slot: OutfitSlot.DRESS });
  }

  const gaps = await world.gaps.recompute(userId);
  const shoeGap = gaps.find((gap) => gap.slot === OutfitSlot.SHOES);
  assert.ok(shoeGap, 'no shoes means a shoe gap');

  const shoes = await world.items.addPersonal(userId, {
    title: 'حذاء أسود',
    slot: OutfitSlot.SHOES,
  });
  await world.gaps.markFilledBy(shoes);

  const closed = await world.db.closetGap.findUnique({ where: { id: shoeGap.id } });
  assert.equal(closed?.status, ClosetGapStatus.FILLED);
  assert.equal(closed?.filledByItemId, shoes.id);
});

dbTest('turning suggestions off actually clears them', async (world) => {
  const userId = await someCustomer(world.db);
  for (const title of ['فستان أول', 'فستان تاني', 'فستان تالت']) {
    await world.items.addPersonal(userId, { title, slot: OutfitSlot.DRESS });
  }
  assert.ok((await world.gaps.recompute(userId)).length > 0);

  await world.closet.updateSettings(userId, { suggestionsEnabled: false });
  assert.deepEqual(await world.gaps.recompute(userId), []);
});

// ── Suggestions ─────────────────────────────────────────────────────────

dbTest('a gap resolves into products a customer can buy today', async (world) => {
  const userId = await someCustomer(world.db);
  for (const title of ['فستان أول', 'فستان تاني', 'فستان تالت']) {
    await world.items.addPersonal(userId, { title, slot: OutfitSlot.DRESS });
  }

  const gaps = await world.gaps.recompute(userId);
  const shoeGap = gaps.find((gap) => gap.slot === OutfitSlot.SHOES);
  assert.ok(shoeGap);

  const suggestions = await world.suggestions.forGap(userId, shoeGap, { limit: 5 });
  assert.ok(suggestions.length > 0, 'the seeded shop sells shoes');

  for (const suggestion of suggestions) {
    // The guarantee the whole integration buys: retrieval is the stylist's, so
    // a closet suggestion cannot reach a product nobody can buy.
    assert.equal(suggestion.product.status, 'ACTIVE');
    assert.ok(
      suggestion.product.offers.length > 0,
      'every suggestion must carry a live offer',
    );
    assert.equal(suggestion.product.category.slug, 'shoes');
  }
});

dbTest('the product page can answer "does this go with my closet?"', async (world) => {
  const userId = await someCustomer(world.db);
  const dressId = await someProduct(world.db, 'dresses');
  const bagId = await someProduct(world.db, 'handbags');

  await world.items.addFromCatalog(userId, { productId: dressId });

  const pairing = await world.suggestions.pairingFor(userId, bagId);
  assert.ok(pairing, 'a live product must return a pairing');
  assert.equal(pairing.slot, OutfitSlot.BAG);
  assert.equal(pairing.alreadyOwned, 0);

  // And it recognises a piece she already owns, which is the one thing a shop
  // has no incentive to tell her.
  const owned = await world.suggestions.pairingFor(userId, dressId);
  assert.equal(owned?.alreadyOwned, 1);
});

// ── Today ───────────────────────────────────────────────────────────────

dbTest('a closet with no saved looks still answers "what can I wear?"', async (world) => {
  const userId = await someCustomer(world.db);
  await world.items.addPersonal(userId, {
    title: 'فستان أسود',
    slot: OutfitSlot.DRESS,
  });
  await world.items.addPersonal(userId, {
    title: 'حذاء أسود',
    slot: OutfitSlot.SHOES,
  });

  const { outfits } = await world.today.today(userId);

  assert.ok(outfits.length > 0, 'day one must not be empty');
  assert.equal(outfits[0].origin, 'COMPOSED');
  // Hydrated to real rows, so the client draws without a second lookup.
  assert.ok(outfits[0].pieceItems.every((item) => item.title.length > 0));
});

// ── Roll-ups ────────────────────────────────────────────────────────────

dbTest('the overview counts what the engine counts', async (world) => {
  const userId = await someCustomer(world.db);
  await world.items.addPersonal(userId, { title: 'بلوزة', slot: OutfitSlot.TOP });
  await world.items.addPersonal(userId, { title: 'تنورة', slot: OutfitSlot.BOTTOM });
  await world.items.addPersonal(userId, { title: 'حذاء', slot: OutfitSlot.SHOES });

  const overview = await world.closet.overview(userId);

  assert.equal(overview.itemsCount, 3);
  // One top and one bottom pair into one outfit, and the shoes make it
  // wearable — the same arithmetic the COVERAGE gaps are prioritised by.
  assert.equal(overview.outfitCapacity, 1);
  assert.equal(overview.closet.itemsCount, 3, 'the roll-up column must agree');
});

dbTest('an archived piece leaves the rotation without leaving the closet', async (world) => {
  const userId = await someCustomer(world.db);
  const item = await world.items.addPersonal(userId, {
    title: 'معطف شتوي',
    slot: OutfitSlot.OUTERWEAR,
  });

  await world.items.setStatus(userId, item.id, ClosetItemStatus.ARCHIVED);

  const snapshot = await world.closet.snapshot(userId);
  assert.ok(
    !snapshot.items.some((fact) => fact.id === item.id),
    'archived pieces must not be proposed',
  );

  const overview = await world.closet.overview(userId);
  assert.equal(overview.archivedCount, 1, 'but it is still hers');
});
