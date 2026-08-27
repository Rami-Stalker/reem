import assert from 'node:assert/strict';
import test from 'node:test';
import { ChatRealtimeGateway } from './chat-realtime.gateway';

/**
 * The socket path, held to the same rules as the HTTP one.
 *
 * A connection is authorised once and then lives for as long as the screen is
 * open, so everything that makes an HTTP request stop working — signing out,
 * revoking a stolen handset, disabling an account — has to be asked again
 * here. These cover that, and the two things an open socket lets a client
 * spend on the server's behalf: memory, and unvalidated rows.
 */

type Stub = Record<string, unknown>;

const build = (prisma: Stub, settings: Record<string, unknown> = {}) =>
  new ChatRealtimeGateway(
    {} as never,
    {} as never,
    {
      get: (key: string) =>
        key in settings ? settings[key] : key === 'jwt.accessSecret' ? 'secret' : '',
    } as never,
    {} as never,
    prisma as never,
  );

const iso = (msFromNow: number) => new Date(Date.now() + msFromNow).toISOString();

/** Enough of Prisma for `principalIsLive`. */
const db = (user: unknown, session: unknown = null): Stub => ({
  user: { findUnique: async () => user },
  session: { findFirst: async () => session },
});

const live = { id: 'user-1', disabledAt: null };
const payload = { sub: 'user-1', sid: 'session-1' } as never;

const isLive = (gateway: ChatRealtimeGateway, claims = payload) =>
  (
    gateway as unknown as {
      principalIsLive(p: unknown): Promise<boolean>;
    }
  ).principalIsLive(claims);

// ── The handshake decides more than the signature ──────────────────────────

test('a live session on a live account connects', async () => {
  const gateway = build(db(live, { id: 'session-1' }));
  assert.equal(await isLive(gateway), true);
});

test('a revoked session is refused', async () => {
  // `findFirst` filters on ACTIVE and on both expiry clocks, so a revoked,
  // expired or idled-out session simply is not found.
  const gateway = build(db(live, null));
  assert.equal(await isLive(gateway), false);
});

test('a disabled account is refused even with a live session', async () => {
  const gateway = build(
    db({ id: 'user-1', disabledAt: new Date() }, { id: 'session-1' }),
  );
  assert.equal(await isLive(gateway), false);
});

test('a deleted account is refused', async () => {
  const gateway = build(db(null, { id: 'session-1' }));
  assert.equal(await isLive(gateway), false);
});

test('a token carrying no session still has its account checked', async () => {
  const gateway = build(db(live));
  assert.equal(await isLive(gateway, { sub: 'user-1' } as never), true);

  const disabled = build(db({ id: 'user-1', disabledAt: new Date() }));
  assert.equal(await isLive(disabled, { sub: 'user-1' } as never), false);
});

test('a database failure denies rather than admits', async () => {
  const gateway = build({
    user: {
      findUnique: async () => {
        throw new Error('connection lost');
      },
    },
    session: { findFirst: async () => null },
  });
  assert.equal(await isLive(gateway), false);
});

// ── Where the credential travels ───────────────────────────────────────────

const bearerFrom = (
  gateway: ChatRealtimeGateway,
  headers: Record<string, string | string[]>,
  query = '',
) => {
  const inner = gateway as unknown as {
    offeredProtocols(r: unknown): string[];
    bearerFrom(r: unknown, offered: string[], url: URL): string;
  };
  const req = { headers };
  const url = new URL(`http://localhost/ws/chats${query}`);
  return inner.bearerFrom(req, inner.offeredProtocols(req), url);
};

test('a bearer header is read', () => {
  const gateway = build(db(live));
  assert.equal(bearerFrom(gateway, { authorization: 'Bearer jwt-1' }), 'jwt-1');
});

test('the browser’s subprotocol pair is read', () => {
  // The only channel `new WebSocket(url, protocols)` leaves for a credential.
  const gateway = build(db(live));
  assert.equal(
    bearerFrom(gateway, { 'sec-websocket-protocol': 'reem.auth.bearer, jwt-2' }),
    'jwt-2',
  );
});

test('a token in the query string is refused with no transition running', () => {
  // The regression this guards: a query string is written into the access log
  // of every proxy on the way, and this is the whole access token.
  const gateway = build(db(live));
  assert.equal(bearerFrom(gateway, {}, '?token=jwt-4'), '');
});

// ── The transitional deadline ──────────────────────────────────────────────

test('a running transition accepts the query string again', () => {
  // What makes a staged rollout possible: the old client keeps connecting
  // while the new one ships.
  const gateway = build(db(live), {
    'security.wsQueryTokenUntil': iso(60 * 60 * 1000),
  });
  assert.equal(bearerFrom(gateway, {}, '?token=jwt-5'), 'jwt-5');
});

test('an elapsed deadline stops accepting it, with no restart', () => {
  // Read per handshake, not cached at boot — a window that needs someone to
  // remember to restart the process is a window that outlives its reason.
  const gateway = build(db(live), {
    'security.wsQueryTokenUntil': iso(-1000),
  });
  assert.equal(bearerFrom(gateway, {}, '?token=jwt-6'), '');
});

test('an unparseable deadline reads as closed, not as open', () => {
  const gateway = build(db(live), {
    'security.wsQueryTokenUntil': 'sometime next week',
  });
  assert.equal(bearerFrom(gateway, {}, '?token=jwt-7'), '');
});

test('headers still win over the query string during the transition', () => {
  // Otherwise a rolled-forward client would be dragged back onto the old path
  // for as long as the window is open.
  const gateway = build(db(live), {
    'security.wsQueryTokenUntil': iso(60 * 60 * 1000),
  });
  assert.equal(
    bearerFrom(gateway, { authorization: 'Bearer jwt-8' }, '?token=jwt-9'),
    'jwt-8',
  );
  assert.equal(
    bearerFrom(
      gateway,
      { 'sec-websocket-protocol': 'reem.auth.bearer, jwt-10' },
      '?token=jwt-9',
    ),
    'jwt-10',
  );
});

test('a marker with nothing after it yields no token', () => {
  const gateway = build(db(live));
  assert.equal(
    bearerFrom(gateway, { 'sec-websocket-protocol': 'reem.auth.bearer' }),
    '',
  );
});

test('an unrelated subprotocol is not mistaken for a token', () => {
  const gateway = build(db(live));
  assert.equal(bearerFrom(gateway, { 'sec-websocket-protocol': 'graphql-ws' }), '');
});

const accept = (gateway: ChatRealtimeGateway, offered: string[]) =>
  (
    gateway as unknown as {
      acceptResponse(key: string, offered: string[]): string;
    }
  ).acceptResponse('dGhlIHNhbXBsZSBub25jZQ==', offered);

test('the 101 selects the subprotocol the browser offered', () => {
  // A browser that offers subprotocols and is answered with none of them fails
  // the connection outright, so the echo is not decoration.
  const gateway = build(db(live));
  const response = accept(gateway, ['reem.auth.bearer', 'jwt-3']);
  assert.match(response, /Sec-WebSocket-Protocol: reem\.auth\.bearer/);
  // Never the token: that would put the credential in a response header.
  assert.equal(response.includes('jwt-3'), false);
});

test('a handshake that offered nothing gets no protocol header', () => {
  const gateway = build(db(live));
  assert.equal(accept(gateway, []).includes('Sec-WebSocket-Protocol'), false);
});

// ── What one connection may make the server hold ───────────────────────────

const decode = (gateway: ChatRealtimeGateway, buffer: Buffer) =>
  (
    gateway as unknown as {
      decodeFrames(b: Buffer): { frames: unknown[]; remaining: Buffer };
    }
  ).decodeFrames(buffer);

/** A client frame: masked, as the protocol requires of one. */
function frame(payloadBytes: Buffer): Buffer {
  const mask = Buffer.from([1, 2, 3, 4]);
  const masked = Buffer.from(payloadBytes);
  for (let i = 0; i < masked.length; i += 1) masked[i] ^= mask[i % 4];

  let header: Buffer;
  if (payloadBytes.length < 126) {
    header = Buffer.from([0x81, 0x80 | payloadBytes.length]);
  } else {
    header = Buffer.alloc(4);
    header[0] = 0x81;
    header[1] = 0x80 | 126;
    header.writeUInt16BE(payloadBytes.length, 2);
  }
  return Buffer.concat([header, mask, masked]);
}

test('an ordinary frame still decodes', () => {
  const gateway = build(db(live));
  const decoded = decode(gateway, frame(Buffer.from('{"event":"typing"}')));
  assert.equal(decoded.frames.length, 1);
  assert.equal(decoded.remaining.length, 0);
});

test('a frame declaring more than the ceiling is refused before it arrives', () => {
  // The point of the check: the header alone is enough to refuse. Waiting for
  // the bytes is what an attacker wants — the server holds every one of them
  // in memory for a frame that is never going to complete.
  const gateway = build(db(live));
  const header = Buffer.alloc(10);
  header[0] = 0x81;
  header[1] = 127;
  header.writeBigUInt64BE(BigInt(8 * 1024 * 1024 * 1024), 2);

  assert.throws(() => decode(gateway, header), /WS_FRAME_TOO_LARGE/);
});

test('a 64-bit length beyond a safe integer is refused', () => {
  const gateway = build(db(live));
  const header = Buffer.alloc(10);
  header[0] = 0x81;
  header[1] = 127;
  header.writeBigUInt64BE(2n ** 63n, 2);

  assert.throws(() => decode(gateway, header), /WS_FRAME_TOO_LARGE/);
});

// ── The bounds the HTTP route gets from the validation pipe ─────────────────

const parseAttachments = (gateway: ChatRealtimeGateway, value: unknown) =>
  (
    gateway as unknown as {
      parseAttachments(v: unknown): { url: string }[] | undefined;
    }
  ).parseAttachments(value);

const parseText = (gateway: ChatRealtimeGateway, value: unknown, max: number) =>
  (
    gateway as unknown as { parseText(v: unknown, m: number): string }
  ).parseText(value, max);

test('message content is held to the length the DTO states', () => {
  const gateway = build(db(live));
  assert.equal(parseText(gateway, 'x'.repeat(20_000), 5000).length, 5000);
  assert.equal(parseText(gateway, { not: 'a string' }, 5000), '');
});

test('attachments are validated rather than passed straight through', () => {
  const gateway = build(db(live));

  const parsed = parseAttachments(gateway, [
    { kind: 'image', url: 'https://api.reem.sy/media/files/2026/08/a.jpg', width: 800 },
    // No kind — nothing to store it as.
    { url: 'https://api.reem.sy/media/files/2026/08/b.jpg' },
    // Not an object at all.
    'https://api.reem.sy/media/files/2026/08/c.jpg',
  ]);

  assert.equal(parsed?.length, 1);
  assert.equal(parsed?.[0].url.endsWith('a.jpg'), true);
});

test('a flood of attachments is capped', () => {
  const gateway = build(db(live));
  const many = Array.from({ length: 500 }, (_, i) => ({
    kind: 'IMAGE',
    url: `https://api.reem.sy/media/files/2026/08/${i}.jpg`,
  }));
  assert.equal(parseAttachments(gateway, many)?.length, 10);
});

test('a non-array attachments field is dropped, not coerced', () => {
  const gateway = build(db(live));
  assert.equal(parseAttachments(gateway, { url: 'x' }), undefined);
  assert.equal(parseAttachments(gateway, undefined), undefined);
});
