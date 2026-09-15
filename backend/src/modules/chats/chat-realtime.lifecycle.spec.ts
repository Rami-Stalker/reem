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
 * The chat socket's lifecycle against a real HTTP server and a real WebSocket
 * client — the parts a deploy exercises and no unit of logic shows:
 *
 *  - a forged token is refused at the handshake;
 *  - shutdown closes every socket with 1001, so apps reconnect to the new
 *    instance at once, and marks their owners offline;
 *  - a connection flooding frames is closed with 1008.
 *
 * Database and chat services are stubs: what is under test is the socket.
 */

const SECRET = 'spec-access-secret-that-is-long-enough-000';
const USER = '3f4a9c1e-1b2d-4e5f-8a90-abcdef012345';

async function harness() {
  const server: Server = createServer();
  await new Promise<void>((resolve) => server.listen(0, '127.0.0.1', resolve));
  const port = (server.address() as AddressInfo).port;

  const presence: Array<{ userId?: string; status: string }> = [];
  const prisma = {
    user: { findUnique: async () => ({ id: USER, disabledAt: null }) },
    session: { findFirst: async () => ({ id: 'session' }) },
    userPresence: {
      updateMany: async (args: { where: { userId?: { in: string[] } }; data: { status: string } }) => {
        presence.push({ userId: args.where.userId?.in?.[0], status: args.data.status });
        return { count: 1 };
      },
    },
  } as unknown as PrismaService;
  const chats = {
    setPresence: async () => ({}),
    participantIds: async () => [USER],
    visiblePeerIds: async () => [],
    assertMember: async () => undefined,
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

  const token = await jwt.signAsync({ sub: USER }, { secret: SECRET });
  const url = `ws://127.0.0.1:${port}/ws/chats`;

  const close = async () => {
    await gateway.beforeApplicationShutdown();
    await new Promise((resolve) => server.close(resolve));
  };
  return { gateway, url, token, presence, close };
}

function open(url: string, token: string): Promise<{ ws: WebSocket; closed: Promise<number> }> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url, ['reem.auth.bearer', token]);
    const closed = new Promise<number>((done) => ws.addEventListener('close', (e) => done(e.code)));
    ws.addEventListener('message', (event) => {
      if (String(event.data).includes('connection.ready')) resolve({ ws, closed });
    });
    ws.addEventListener('error', () => reject(new Error('handshake failed')));
  });
}

test('a forged token never gets a socket', async () => {
  const h = await harness();
  try {
    await assert.rejects(open(h.url, 'not-a-token'), /handshake failed/);
  } finally {
    await h.close();
  }
});

test('shutdown closes open sockets with 1001 and marks their owners offline', async () => {
  const h = await harness();
  const { closed } = await open(h.url, h.token);
  await h.gateway.beforeApplicationShutdown();
  assert.equal(await closed, 1001);
  assert.ok(h.presence.some((p) => p.userId === USER && p.status === 'OFFLINE'));
  await h.close();
});

test('a connection that floods frames is closed with 1008', async () => {
  const h = await harness();
  try {
    const { ws, closed } = await open(h.url, h.token);
    for (let i = 0; i < 200; i += 1) {
      if (ws.readyState !== WebSocket.OPEN) break;
      ws.send(JSON.stringify({ event: 'presence.ping' }));
    }
    assert.equal(await closed, 1008);
  } finally {
    await h.close();
  }
});
