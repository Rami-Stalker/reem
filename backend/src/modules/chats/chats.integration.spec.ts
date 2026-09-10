import assert from 'node:assert/strict';
import test from 'node:test';
import { EventEmitter2 } from '@nestjs/event-emitter';
import { ChatContextType, PrismaClient, UserRole } from '@prisma/client';

import { MediaService } from '../media/media.service';
import { NotificationsService } from '../notifications/notifications.service';
import { PrismaService } from '../../prisma/prisma.service';
import { ChatsService } from './chats.service';

/**
 * Buyer-to-seller conversations, which the app could render but could not open.
 *
 * The client had no call to `startConversation` at all, so the three shapes it
 * now sends -- a product, a parcel, a person -- are pinned here: that each
 * finds the right pair of people, that tapping twice lands her in one thread
 * rather than two, and that a stranger cannot read either of them.
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
            await body({ tx, chats: build(tx) });
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

interface World {
  tx: Tx;
  chats: ChatsService;
}

function build(tx: Tx): ChatsService {
  const db = new Proxy(tx as unknown as Record<string, unknown>, {
    get(target, prop, receiver) {
      if (prop === '$transaction') {
        return async (fn: (inner: Tx) => unknown) => fn(tx);
      }
      return Reflect.get(target, prop, receiver);
    },
  }) as unknown as PrismaService;

  // The push fan-out and the media bookkeeping have their own tests; what
  // matters here is that nothing in this service depends on their answers.
  const notifications = {
    dispatch: async () => undefined,
  } as unknown as NotificationsService;
  const media = {
    resolveAssetId: async () => null,
    markAttached: async () => undefined,
  } as unknown as MediaService;

  return new ChatsService(db, new EventEmitter2(), notifications, media);
}

let seq = 0;
const uniq = (tag: string) => `${Date.now()}${(seq += 1)}${tag}`;

async function makeUser(tx: Tx, tag: string, role: UserRole) {
  const u = uniq(tag);
  return tx.user.create({
    data: {
      name: `chat-${tag}`,
      username: `chat_${u}`,
      phone: `+9638${Math.floor(10000000 + Math.random() * 89999999)}`,
      passwordHash: 'x',
      role,
    },
  });
}

/** A catalogue entry with exactly one boutique offering it. */
async function makeProduct(tx: Tx, sellerId: string) {
  const u = uniq('p');
  const category = await tx.category.create({
    data: { nameAr: `cat-${u}`, nameEn: `cat-${u}`, slug: `cat-${u}` },
  });
  const product = await tx.product.create({
    data: {
      title: 'evening dress',
      slug: `prod-${u}`,
      description: 'x',
      categoryId: category.id,
    },
  });
  await tx.sellerOffer.create({
    data: {
      productId: product.id,
      sellerId,
      price: 100,
      stock: 5,
    },
  });
  return product;
}

// -- There is a way in ---------------------------------------------------

dbTest('a shopper can open a conversation about a product', async (world) => {
  const buyer = await makeUser(world.tx, 'a', UserRole.CUSTOMER);
  const seller = await makeUser(world.tx, 'b', UserRole.SELLER);
  const product = await makeProduct(world.tx, seller.id);

  const thread = await world.chats.startConversation(buyer.id, {
    product_id: product.id,
    message: 'is size M in stock?',
  });

  assert.equal(thread.type, ChatContextType.PRODUCT.toLowerCase());
  assert.equal(thread.product_id, product.id);
  assert.equal(thread.seller_id, seller.id);
  // The header the client draws: who she is talking to, named outright.
  assert.equal(thread.peer_id, seller.id);
  assert.equal(thread.peer_name, seller.name);
  assert.equal(thread.last_message, 'is size M in stock?');
});

dbTest('asking twice reopens the thread, it does not fork it', async (world) => {
  const buyer = await makeUser(world.tx, 'c', UserRole.CUSTOMER);
  const seller = await makeUser(world.tx, 'd', UserRole.SELLER);
  const product = await makeProduct(world.tx, seller.id);

  const first = await world.chats.startConversation(buyer.id, {
    product_id: product.id,
  });
  const second = await world.chats.startConversation(buyer.id, {
    product_id: product.id,
  });

  // Two threads about one dress is two half-answered conversations.
  assert.equal(second.id, first.id);
  const mine = await world.chats.threads(buyer.id);
  assert.equal(mine.length, 1);
});

dbTest('a shopper can open a conversation with a boutique directly', async (world) => {
  const buyer = await makeUser(world.tx, 'e', UserRole.CUSTOMER);
  const seller = await makeUser(world.tx, 'f', UserRole.SELLER);

  const thread = await world.chats.startConversation(buyer.id, {
    participant_id: seller.id,
  });

  assert.equal(thread.type, ChatContextType.DIRECT.toLowerCase());
  assert.equal(thread.buyer_id, buyer.id);
  assert.equal(thread.seller_id, seller.id);
});

dbTest('two shoppers cannot open a conversation with each other', async (world) => {
  const one = await makeUser(world.tx, 'g', UserRole.CUSTOMER);
  const two = await makeUser(world.tx, 'h', UserRole.CUSTOMER);

  // Reem is a marketplace, not a social network: the only conversation it
  // brokers is the one between a woman and the boutique she is buying from.
  await assert.rejects(
    world.chats.startConversation(one.id, { participant_id: two.id }),
    /buyers and sellers/i,
  );
});

// -- One conversation, addressed correctly -------------------------------

dbTest('the thread endpoint names the peer for each side', async (world) => {
  const buyer = await makeUser(world.tx, 'i', UserRole.CUSTOMER);
  const seller = await makeUser(world.tx, 'j', UserRole.SELLER);
  const opened = await world.chats.startConversation(buyer.id, {
    participant_id: seller.id,
  });

  const asBuyer = await world.chats.thread(opened.id, buyer.id);
  const asSeller = await world.chats.thread(opened.id, seller.id);

  // The header is "whoever is not me" -- the old client hard-coded one name
  // and showed it to everybody.
  assert.equal(asBuyer.peer_id, seller.id);
  assert.equal(asSeller.peer_id, buyer.id);
});

dbTest('a stranger cannot read a conversation she is not in', async (world) => {
  const buyer = await makeUser(world.tx, 'k', UserRole.CUSTOMER);
  const seller = await makeUser(world.tx, 'l', UserRole.SELLER);
  const stranger = await makeUser(world.tx, 'm', UserRole.CUSTOMER);
  const opened = await world.chats.startConversation(buyer.id, {
    participant_id: seller.id,
  });

  await assert.rejects(
    world.chats.thread(opened.id, stranger.id),
    /not a member/i,
  );
});

dbTest('the inbox counts unread per conversation in one pass', async (world) => {
  // The list used to call the single-thread counter per row, and that helper
  // runs two queries of its own — so drawing the inbox cost `1 + 2N`, fired
  // concurrently at the pool. The counts now come from one grouped query, and
  // the property that has to survive that change is this one: each row carries
  // *its own* cutoff, so two conversations read at different times must not
  // borrow each other's number.
  const seller = await makeUser(world.tx, 'p1', UserRole.SELLER);
  const first = await makeUser(world.tx, 'p2', UserRole.CUSTOMER);
  const second = await makeUser(world.tx, 'p3', UserRole.CUSTOMER);

  const quiet = await world.chats.startConversation(first.id, {
    participant_id: seller.id,
    message: 'مرحبا',
  });
  const busy = await world.chats.startConversation(second.id, {
    participant_id: seller.id,
    message: 'عندك مقاس M؟',
  });
  await world.chats.send(busy.id, second.id, { content: 'وبلونين؟' });

  // The seller reads one of them and leaves the other.
  await world.chats.markRead(quiet.id, seller.id, {});

  const inbox = await world.chats.threads(seller.id);
  const byId = new Map(inbox.map((thread) => [thread.id, thread]));

  assert.equal(byId.get(quiet.id)?.unread_count, 0, 'the one she read');
  assert.equal(byId.get(busy.id)?.unread_count, 2, 'the one she did not');

  // A conversation with nothing unread does not come back from the grouped
  // query at all, so the zero above is the caller's default rather than a row —
  // which is exactly the case a per-thread loop could not get wrong and this
  // one can.
  assert.ok(byId.has(quiet.id), 'a read conversation still appears in the list');
});

dbTest('unread counts only the other side, and clears on read', async (world) => {
  const buyer = await makeUser(world.tx, 'n', UserRole.CUSTOMER);
  const seller = await makeUser(world.tx, 'o', UserRole.SELLER);
  const opened = await world.chats.startConversation(buyer.id, {
    participant_id: seller.id,
    message: 'hello',
  });
  await world.chats.send(opened.id, seller.id, { content: 'welcome' });

  // Her own message is not news to her.
  assert.equal((await world.chats.thread(opened.id, buyer.id)).unread_count, 1);
  assert.equal((await world.chats.thread(opened.id, seller.id)).unread_count, 1);

  await world.chats.markRead(opened.id, buyer.id, {});
  assert.equal((await world.chats.thread(opened.id, buyer.id)).unread_count, 0);
});
