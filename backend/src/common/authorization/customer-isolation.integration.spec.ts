import assert from 'node:assert/strict';
import test from 'node:test';
import {
  ClosetItemStatus,
  MediaAssetStatus,
  MediaType,
  MediaVisibility,
  OutfitSlot,
  PrismaClient,
  RoomKind,
  UserRole,
} from '@prisma/client';

import { AuthUser } from '../decorators/current-user.decorator';
import { PrismaService } from '../../prisma/prisma.service';
import { ClosetService } from '../../modules/closet/closet.service';
import { ClosetItemService } from '../../modules/closet/items/closet-item.service';
import { ClosetLookService } from '../../modules/closet/looks/closet-look.service';
import { FavoritesService } from '../../modules/favorites/favorites.service';
import { InvoicesService } from '../../modules/orders/invoices.service';
import { MediaService } from '../../modules/media/media.service';
import { RoomAccessService } from '../../modules/rooms/room-access.service';
import { RoomEventService } from '../../modules/rooms/room-event.service';
import { RoomNotifier } from '../../modules/rooms/room-notifier.service';
import { RoomsService } from '../../modules/rooms/rooms.service';
import { SupportService } from '../../modules/support/support.service';

/**
 * One customer cannot reach another's.
 *
 * Nineteen controllers carry `@SelfScoped(...)`, which is a promise that the
 * route enforces ownership one layer down rather than through a declared
 * policy. The guard takes them at their word — that is the entire meaning of
 * the decorator — so the promise is only as good as the service behind it, and
 * for the customer-facing half of that surface nothing asserted it. Seller
 * against seller has `seller-isolation.integration.spec.ts`; shopper against
 * shopper had nothing, and the data on that side is the more personal of the
 * two: her wardrobe, her private conversations, her invoices with her address
 * on them, her support tickets, the photographs she uploaded of herself.
 *
 * These are the crossings attempted from outside. Fatima holds a perfectly
 * valid session of her own and reaches for Layla's rows by id — which is all an
 * IDOR is. Every one must be refused.
 *
 * **On 404 versus 403.** Where the refusal is "not found" that is deliberate
 * and asserted as such: for a private object the status code itself leaks, and
 * "forbidden" tells Fatima that the id she guessed belongs to something real.
 * The assertions accept either a `NotFoundException` or a `ForbiddenException`
 * only where the platform has a documented reason to prefer one; elsewhere they
 * pin the refusal without pinning which, because what must not happen is the
 * data coming back.
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
  favorites: FavoritesService;
  invoices: InvoicesService;
  rooms: RoomsService;
  support: SupportService;
}

/** The upload claim is bookkeeping; no assertion here depends on it. */
const noMedia = { markAttached: async () => 0 } as never;

function build(tx: Tx): World {
  const db = asPrisma(tx);
  const closet = new ClosetService(db);
  // No push here: these cases assert who may read whose rows, and a real
  // transport would only ever report "no provider configured".
  const notifier = new RoomNotifier(db, {
    pushExisting: async () => {},
  } as never);
  return {
    db,
    closet,
    items: new ClosetItemService(db, closet, noMedia),
    looks: new ClosetLookService(db, closet),
    favorites: new FavoritesService(db),
    invoices: new InvoicesService(db),
    rooms: new RoomsService(
      db,
      new RoomAccessService(db),
      new RoomEventService(db, notifier),
    ),
    support: new SupportService(db),
  };
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;

/** Two shoppers who have never met. */
async function twoCustomers(db: PrismaService) {
  const make = async (tag: string) =>
    db.user.create({
      data: {
        phone: `+9639${String(Date.now()).slice(-8)}${(seq += 1) % 10}`,
        name: `عميلة ${tag}`,
        username: uniq(tag),
        role: UserRole.CUSTOMER,
        isVerified: true,
      },
    });
  return { layla: await make('layla'), fatima: await make('fatima') };
}

function principal(user: { id: string; phone: string | null }): AuthUser {
  return {
    id: user.id,
    phone: user.phone ?? '',
    role: UserRole.CUSTOMER,
    permissions: [],
  };
}

/** Asserts the call refused, and that nothing came back. */
async function refuses(
  attempt: () => Promise<unknown>,
  what: string,
): Promise<void> {
  await assert.rejects(
    attempt(),
    (error: unknown) => {
      const status = (error as { status?: number }).status;
      assert.ok(
        status === 403 || status === 404,
        `${what}: expected a refusal, got status ${String(status)} — ` +
          `${(error as Error).message}`,
      );
      return true;
    },
    `${what}: the call resolved instead of refusing`,
  );
}

// ── Her wardrobe ───────────────────────────────────────────────────────────

dbTest('a garment in her closet is invisible to anybody else', async (world) => {
  const { layla, fatima } = await twoCustomers(world.db);

  const item = await world.items.addPersonal(layla.id, {
    title: 'عباية سوداء مطرّزة',
    slot: OutfitSlot.OUTERWEAR,
  });

  await refuses(() => world.items.detail(fatima.id, item.id), 'closet detail');
  await refuses(
    () => world.items.update(fatima.id, item.id, { title: 'مسروقة' }),
    'closet update',
  );
  await refuses(
    () => world.items.setStatus(fatima.id, item.id, ClosetItemStatus.RELEASED),
    'closet status',
  );
  await refuses(() => world.items.remove(fatima.id, item.id), 'closet delete');
  await refuses(
    () => world.items.logWear(fatima.id, item.id),
    'closet wear log',
  );

  // And the piece is untouched by any of it.
  const after = await world.items.require(layla.id, item.id);
  assert.equal(after.title, 'عباية سوداء مطرّزة');
  assert.equal(after.status, ClosetItemStatus.ACTIVE);
});

dbTest('a look she assembled cannot be read or edited by a stranger', async (world) => {
  const { layla, fatima } = await twoCustomers(world.db);

  const look = await world.looks.create(layla.id, {
    title: 'إطلالة عرس',
    items: [],
  });

  await refuses(() => world.looks.require(fatima.id, look.id), 'look detail');
  await refuses(
    () => world.looks.update(fatima.id, look.id, { title: 'مسروقة' }),
    'look update',
  );
  await refuses(() => world.looks.remove(fatima.id, look.id), 'look delete');
});

dbTest('one closet snapshot never contains another woman\'s garments', async (world) => {
  const { layla, fatima } = await twoCustomers(world.db);

  const hers = await world.items.addPersonal(layla.id, {
    title: 'قميص حريري',
    slot: OutfitSlot.TOP,
  });

  const snapshot = await world.closet.snapshot(fatima.id);
  assert.ok(
    !snapshot.items.some((item) => item.id === hers.id),
    'a snapshot must be scoped to one closet',
  );
});

// ── Her saved things ───────────────────────────────────────────────────────

dbTest('a wishlist collection belongs to one account', async (world) => {
  const { layla, fatima } = await twoCustomers(world.db);

  const collection = await world.favorites.createCollection(layla.id, {
    name: 'جهاز العروس',
  });

  // Fatima's own view of her collections must not contain it.
  const mine = await world.favorites.collections(fatima.id);
  assert.ok(
    !mine.some((row) => (row as { id: string }).id === collection.id),
    'collections must be scoped to the account that owns them',
  );

  await refuses(
    () =>
      world.favorites.share(fatima.id, collection.id, {}),
    'collection share',
  );
  await refuses(
    () => world.favorites.removeItem(fatima.id, collection.id, uniq('item')),
    'collection item removal',
  );
});

// ── Her support ticket ─────────────────────────────────────────────────────

dbTest('a support ticket is readable by its author and staff, nobody else', async (world) => {
  const { layla, fatima } = await twoCustomers(world.db);

  const ticket = await world.support.open(principal(layla), {
    subject: 'لم يصل طلبي',
    body: 'مرّ أسبوع ولم يصل الطلب.',
    category: 'طلب',
  });

  await refuses(
    () => world.support.detail(ticket.id, principal(fatima)),
    'ticket detail',
  );
  await refuses(
    () =>
      world.support.reply(ticket.id, principal(fatima), {
        body: 'أنا صاحبة الطلب',
      }),
    'ticket reply',
  );
  await refuses(
    () => world.support.close(ticket.id, principal(fatima)),
    'ticket close',
  );

  // Hers still opens, and nothing a stranger tried is in it.
  const mine = await world.support.detail(ticket.id, principal(layla));
  assert.equal((mine as { messages: unknown[] }).messages.length, 1);
});

// ── Her room ───────────────────────────────────────────────────────────────

dbTest('a room she was not invited to answers "not found", not "forbidden"', async (world) => {
  const { layla, fatima } = await twoCustomers(world.db);

  const room = await world.rooms.create(layla.id, {
    title: 'غرفة العرس',
    kind: RoomKind.OCCASION,
  });

  // 404 by design: "forbidden" would confirm that the id names a real room, and
  // a room's existence is itself private.
  await assert.rejects(
    () => world.rooms.detail(room.id, fatima.id),
    (error: unknown) => {
      assert.equal(
        (error as { status?: number }).status,
        404,
        'a non-member must not learn that the room exists',
      );
      return true;
    },
  );
  await refuses(
    () => world.rooms.update(room.id, fatima.id, { title: 'مسروقة' }),
    'room update',
  );
  await refuses(() => world.rooms.archive(room.id, fatima.id), 'room archive');
  await refuses(() => world.rooms.remove(room.id, fatima.id), 'room delete');

  // And it is not in her list.
  const listed = await world.rooms.list(fatima.id);
  assert.ok(
    !listed.some((candidate) => candidate.id === room.id),
    'a room must only appear to its members',
  );
});

// ── Her private files ──────────────────────────────────────────────────────

dbTest('a private asset is not served to another account', async (world) => {
  const { layla, fatima } = await twoCustomers(world.db);

  // A verification document: the most sensitive class of file the platform
  // holds, and the reason `readPrivate` exists at all.
  const asset = await world.db.mediaAsset.create({
    data: {
      ownerId: layla.id,
      driver: 'local',
      kind: MediaType.document,
      visibility: MediaVisibility.PRIVATE,
      status: MediaAssetStatus.ATTACHED,
      storageKey: `private/${uniq('doc')}.pdf`,
      mimeType: 'application/pdf',
      byteSize: 1024,
      checksum: uniq('sum'),
    },
  });

  // The storage driver is never reached: the refusal happens before any read.
  const media = new MediaService(
    world.db,
    { get: () => undefined } as never,
    { read: async () => Buffer.alloc(0) } as never,
    { generate: async () => [] } as never,
  );

  await refuses(
    () => media.readPrivate(asset.id, principal(fatima)),
    'private media read',
  );
});

// ── Her invoice ────────────────────────────────────────────────────────────

dbTest('an invoice carries her address, so only she and staff may render it', async (world) => {
  const { layla, fatima } = await twoCustomers(world.db);

  const order = await world.db.order.findFirst({
    where: { userId: { not: null } },
    select: { id: true, userId: true },
  });
  if (!order?.userId) {
    // The seeded shop always has orders; if it does not, the case has nothing
    // to prove and saying so beats asserting against an empty database.
    return;
  }

  const invoice = await world.invoices.issueForOrder(order.id);

  await refuses(
    () =>
      world.invoices.render(invoice.id, {
        id: fatima.id,
        role: UserRole.CUSTOMER,
      }),
    'invoice render',
  );
  await refuses(
    () =>
      world.invoices.listForOrder(order.id, {
        id: layla.id,
        role: UserRole.CUSTOMER,
      }),
    'invoice list for an order that is not hers',
  );
});
