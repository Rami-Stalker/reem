import 'reflect-metadata';
import assert from 'node:assert/strict';
import test from 'node:test';
import { createServer, Server } from 'node:http';
import { AddressInfo } from 'node:net';
import { ConfigService } from '@nestjs/config';
import { HttpAdapterHost } from '@nestjs/core';
import { JwtService } from '@nestjs/jwt';

import { PrismaService } from '../../prisma/prisma.service';
import { ChatRealtimeGateway } from './chat-realtime.gateway';
import { ChatsService } from './chats.service';

/**
 * What each side of a conversation receives over the socket.
 *
 * Two real WebSocket clients, one per participant, against a real HTTP server.
 * The chat service and the database are stubs; what is pinned is the gateway:
 *
 *  - a new message reaches each participant with `is_mine` answered *for
 *    them* — it used to carry the sender's answer to everyone, so the
 *    recipient's app drew the other side's message as her own;
 *  - reaching a connected recipient is what makes a message "delivered";
 *  - a failure says which send failed, and never relays an internal error.
 */

const SECRET = 'spec-access-secret-that-is-long-enough-000';
const BUYER = '3f4a9c1e-1b2d-4e5f-8a90-abcdef012345';
const SELLER = '7c1d2e3f-4a5b-4c6d-8e9f-0a1b2c3d4e5f';
const CHAT = '11111111-2222-4333-8444-555555555555';

async function harness(overrides: Partial<Record<string, unknown>> = {}) {
  const server: Server = createServer();
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = (server.address() as AddressInfo).port;

  const delivered: Array<{ chatId: string; userId: string; ids: string[] }> = [];
  const prisma = {
    user: { findUnique: async ({ where }: { where: { id: string } }) => ({ id: where.id, disabledAt: null }) },
    session: { findFirst: async () => ({ id: 'session' }) },
    userPresence: { updateMany: async () => ({ count: 0 }) },
  } as unknown as PrismaService;
  const chats = {
    setPresence: async () => ({}),
    participantIds: async () => [BUYER, SELLER],
    visiblePeerIds: async () => [],
    assertMember: async () => undefined,
    acknowledgeDelivery: async (chatId: string, userId: string, ids: string[]) => {
      delivered.push({ chatId, userId, ids });
    },
    ...overrides,
  } as unknown as ChatsService;
  const jwt = new JwtService({ secret: SECRET });
  const gateway = new ChatRealtimeGateway(
    { httpAdapter: { getHttpServer: () => server } } as unknown as HttpAdapterHost,
    jwt,
    new ConfigService({ jwt: { accessSecret: SECRET } }),
    chats,
    prisma,
  );
  gateway.onModuleInit();

  const tokenFor = (sub: string) => jwt.signAsync({ sub }, { secret: SECRET });
  const url = `ws://127.0.0.1:${port}/ws/chats`;
  const close = async () => {
    await gateway.beforeApplicationShutdown();
    await new Promise((resolve) => server.close(resolve));
  };
  return { gateway, url, tokenFor, delivered, close };
}

interface Peer {
  ws: WebSocket;
  next(event: string): Promise<Record<string, unknown>>;
}

function connect(url: string, token: string): Promise<Peer> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url, ['reem.auth.bearer', token]);
    const inbox: Record<string, unknown>[] = [];
    const waiters: Array<{ event: string; done: (v: Record<string, unknown>) => void }> = [];
    const next = (event: string) =>
      new Promise<Record<string, unknown>>((done) => {
        const at = inbox.findIndex((m) => m.event === event);
        if (at !== -1) {
          done(inbox.splice(at, 1)[0]);
          return;
        }
        waiters.push({ event, done });
      });
    ws.addEventListener('message', (raw) => {
      const message = JSON.parse(String(raw.data)) as Record<string, unknown>;
      if (message.event === 'connection.ready') {
        resolve({ ws, next });
        return;
      }
      const at = waiters.findIndex((w) => w.event === message.event);
      if (at !== -1) waiters.splice(at, 1)[0].done(message);
      else inbox.push(message);
    });
    ws.addEventListener('error', () => reject(new Error('handshake failed')));
  });
}

const settle = () => new Promise((resolve) => setTimeout(resolve, 50));

test('each participant is told whether the new message is theirs', async () => {
  const h = await harness();
  try {
    const buyer = await connect(h.url, await h.tokenFor(BUYER));
    const seller = await connect(h.url, await h.tokenFor(SELLER));

    // Serialised once, for the sender — exactly what ChatsService emits.
    h.gateway.handleCreated({
      chatId: CHAT,
      participantIds: [BUYER, SELLER],
      senderId: BUYER,
      message: { id: 'm-1', sender_id: BUYER, content: 'هل المقاس M متوفر؟', is_mine: true },
    });

    const mine = (await buyer.next('message.created')).message as Record<string, unknown>;
    const theirs = (await seller.next('message.created')).message as Record<string, unknown>;
    assert.equal(mine.is_mine, true, 'the sender sees her own message as hers');
    assert.equal(theirs.is_mine, false, 'the seller sees it as the buyer’s');
    assert.equal(theirs.content, 'هل المقاس M متوفر؟');

    buyer.ws.close();
    seller.ws.close();
  } finally {
    await h.close();
  }
});

test('a recipient with an open socket has the message delivered at once', async () => {
  const h = await harness();
  try {
    const seller = await connect(h.url, await h.tokenFor(SELLER));

    h.gateway.handleCreated({
      chatId: CHAT,
      participantIds: [BUYER, SELLER],
      senderId: BUYER,
      message: { id: 'm-2', sender_id: BUYER, is_mine: true },
    });
    await seller.next('message.created');
    await settle();

    // Only the recipient who was reached; never the sender, and nobody who
    // was offline — the buyer here has no socket at all.
    assert.deepEqual(h.delivered, [{ chatId: CHAT, userId: SELLER, ids: ['m-2'] }]);
    seller.ws.close();
  } finally {
    await h.close();
  }
});

test('the sender hears about delivery, the recipient does not hear about herself', async () => {
  const h = await harness();
  try {
    const buyer = await connect(h.url, await h.tokenFor(BUYER));
    const seller = await connect(h.url, await h.tokenFor(SELLER));

    h.gateway.handleDelivered({
      chatId: CHAT,
      userId: SELLER,
      messageIds: ['m-3'],
      deliveredAt: new Date().toISOString(),
    });

    const event = await buyer.next('messages.delivered');
    assert.deepEqual(event.message_ids, ['m-3']);
    assert.equal(event.user_id, SELLER);

    // Give a stray frame time to arrive before saying none did.
    let echoed = false;
    void seller.next('messages.delivered').then(() => (echoed = true));
    await settle();
    assert.equal(echoed, false);

    buyer.ws.close();
    seller.ws.close();
  } finally {
    await h.close();
  }
});

test('a malformed chat id is refused without reaching the database', async () => {
  let reached = false;
  const h = await harness({
    assertMember: async () => {
      reached = true;
    },
  });
  try {
    const buyer = await connect(h.url, await h.tokenFor(BUYER));
    buyer.ws.send(JSON.stringify({ event: 'conversation.join', chat_id: "x' OR 1=1" }));
    const error = await buyer.next('error');
    assert.match(String(error.message), /valid chat_id/);
    assert.equal(reached, false);
    buyer.ws.close();
  } finally {
    await h.close();
  }
});

test('a failed send names itself and does not leak the internal error', async () => {
  const h = await harness({
    send: async () => {
      throw new Error('Invalid `prisma.message.create()` invocation: column "x"');
    },
  });
  try {
    const buyer = await connect(h.url, await h.tokenFor(BUYER));
    buyer.ws.send(
      JSON.stringify({
        event: 'message.send',
        chat_id: CHAT,
        client_id: 'local-42',
        content: 'مرحبا',
      }),
    );
    const error = await buyer.next('error');
    assert.equal(error.message, 'Realtime error');
    assert.equal(error.client_id, 'local-42', 'the app can mark the right bubble failed');
    assert.equal(error.source_event, 'message.send');
    buyer.ws.close();
  } finally {
    await h.close();
  }
});
