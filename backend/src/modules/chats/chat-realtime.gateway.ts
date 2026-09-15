import {
  BeforeApplicationShutdown,
  Injectable,
  Logger,
  OnModuleInit,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpAdapterHost } from '@nestjs/core';
import { OnEvent } from '@nestjs/event-emitter';
import { JwtService } from '@nestjs/jwt';
import { MessageKind, PresenceStatus, SessionStatus } from '@prisma/client';
import { createHash, randomUUID } from 'crypto';
import { IncomingMessage } from 'http';
import { Socket } from 'net';
import { URL } from 'url';
import { PrismaService } from '../../prisma/prisma.service';
import { JwtPayload } from '../auth/interfaces/jwt-payload.interface';
import { ChatsService } from './chats.service';

/**
 * A socket is authorised once at the handshake and then held open for as long
 * as the woman keeps the conversation on screen — so unlike an HTTP request,
 * the decision has to be taken again while the connection is still alive.
 * Signing out, revoking a stolen handset's session and disabling an account
 * are the three things this platform can do about a compromise, and every one
 * of them was invisible to this gateway.
 */
const SESSION_RECHECK_MS = 60_000;

/**
 * Ceilings on what one connection may make the server hold.
 *
 * The decoder buffers until a frame is complete, and a frame header may
 * declare a 64-bit length, so without these a single client — any account, and
 * accounts are free — sends a header claiming a gigabyte and then dribbles
 * bytes, and the server holds every one of them in memory waiting for an end
 * that never comes.
 */
const MAX_FRAME_BYTES = 64 * 1024;
const MAX_BUFFERED_BYTES = 256 * 1024;

/**
 * Heartbeat. The server pings every connection on this interval and closes any
 * that has sent nothing back — not even the automatic pong — within
 * `DEAD_AFTER_MS`.
 *
 * Two failures this closes, both invisible until it existed:
 *
 *  - **A phone that loses signal does not say goodbye.** No close frame, no
 *    FIN; the TCP connection simply stops. Node enables no keep-alive on its
 *    own, so the socket stayed in the table — and her presence stayed
 *    "online" to everyone she talks to — for as long as the kernel took to
 *    notice, which is hours.
 *  - **Hosting proxies close idle WebSockets**, typically after 60–100 s
 *    without a frame. A conversation left open on screen with nobody typing
 *    was cut every minute or so. A ping every 25 s keeps it under every common
 *    timeout, without depending on one host's particular number.
 */
const PING_INTERVAL_MS = 25_000;
const DEAD_AFTER_MS = 65_000;

/**
 * Frames one connection may send in a window before it is closed.
 *
 * A person typing, reading and sending produces a few frames a second at
 * most. HTTP routes are throttled per IP; a socket, once open, was not
 * throttled at all, so one account could send messages in a loop as fast as
 * the database accepted them.
 */
const FRAME_WINDOW_MS = 10_000;
const MAX_FRAMES_PER_WINDOW = 120;

/**
 * The subprotocol a client names to say "my next value is a bearer token".
 *
 * A browser cannot put a header on a WebSocket — `WebSocket` takes a URL and a
 * subprotocol list and nothing else — which is why tokens end up in query
 * strings across the industry. A query string is the one part of a request
 * that is written into the access log of every proxy between the handset and
 * this process, and it is the whole access token: replayable until it expires,
 * against HTTP as readily as against this socket. `Sec-WebSocket-Protocol` is
 * a header, is not written into the request line, and is the only channel the
 * browser's WebSocket API leaves open for a credential.
 */
const AUTH_SUBPROTOCOL = 'reem.auth.bearer';

/** Mirrors `SendMessageDto`; the HTTP route gets these from the global pipe. */
const MAX_CONTENT_CHARS = 5000;
const MAX_ATTACHMENTS = 10;

interface RealtimeClient {
  id: string;
  userId: string;
  sessionId?: string;
  socket: Socket;
  rooms: Set<string>;
  buffer: Buffer;
  recheck?: NodeJS.Timeout;
  /** Last time any byte arrived — a frame, a pong. */
  lastSeenAt: number;
  windowStartedAt: number;
  framesInWindow: number;
}

interface DecodedFrame {
  opcode: number;
  payload: Buffer;
}

interface ChatMessageCreatedEvent {
  chatId: string;
  participantIds: string[];
  senderId: string;
  message: unknown;
}

interface ChatReadEvent {
  chatId: string;
  userId: string;
  messageId: string;
  readAt: string;
}

interface PresenceEvent {
  userId: string;
  status: string;
  lastSeenAt: string;
}

@Injectable()
export class ChatRealtimeGateway implements OnModuleInit, BeforeApplicationShutdown {
  private readonly logger = new Logger(ChatRealtimeGateway.name);
  private readonly clients = new Map<string, RealtimeClient>();
  /** Transition telemetry for the retired `?token=`; see `warnLegacyHandshake`. */
  private legacyHandshakes = 0;
  private lastLegacyWarnAt = 0;
  private readonly userClients = new Map<string, Set<string>>();
  private heartbeat?: NodeJS.Timeout;
  private closing = false;

  constructor(
    private readonly adapterHost: HttpAdapterHost,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly chats: ChatsService,
    private readonly prisma: PrismaService,
  ) {}

  onModuleInit() {
    const server = this.adapterHost.httpAdapter.getHttpServer() as {
      on(event: 'upgrade', listener: (req: IncomingMessage, socket: Socket, head: Buffer) => void): void;
    };
    server.on('upgrade', (req, socket, head) => {
      void this.handleUpgrade(req, socket, head);
    });

    this.heartbeat = setInterval(() => this.sweepConnections(), PING_INTERVAL_MS);
    this.heartbeat.unref();

    // Presence rows outlive the process that wrote them. After a crash or a
    // deploy every "online" row points at a socket that no longer exists, and
    // stays that way until its owner happens to reconnect — so clear them.
    // Right for the single realtime instance this gateway supports (it has no
    // cross-instance pub/sub); anyone genuinely connected reconnects within
    // seconds and is marked online again.
    void this.prisma.userPresence
      .updateMany({
        where: { status: PresenceStatus.ONLINE },
        data: { status: PresenceStatus.OFFLINE, socketCount: 0 },
      })
      .then(
        (reset) => {
          if (reset.count) {
            this.logger.log(`Cleared ${reset.count} stale presence row(s)`);
          }
        },
        (error) => this.logger.warn(`Presence reset failed: ${String(error)}`),
      );

    this.logger.log('Chat WebSocket endpoint mounted at /ws/chats');
  }

  /**
   * Stops accepting sockets and closes the open ones with 1001 ("going
   * away"), so every app reconnects at once — to this process's replacement —
   * instead of discovering a dead connection on its next send.
   */
  async beforeApplicationShutdown(): Promise<void> {
    this.closing = true;
    if (this.heartbeat) clearInterval(this.heartbeat);
    const userIds = [...this.userClients.keys()];
    for (const client of [...this.clients.values()]) {
      if (client.recheck) clearInterval(client.recheck);
      try {
        const reason = 'Server restarting';
        const payload = Buffer.alloc(2 + Buffer.byteLength(reason));
        payload.writeUInt16BE(1001, 0);
        payload.write(reason, 2);
        this.sendFrame(client.socket, payload, 0x8);
      } catch {
        // Already gone.
      }
      client.socket.end();
    }
    this.clients.clear();
    this.userClients.clear();
    if (userIds.length === 0) return;
    try {
      await this.prisma.userPresence.updateMany({
        where: { userId: { in: userIds } },
        data: { status: PresenceStatus.OFFLINE, socketCount: 0, lastSeenAt: new Date() },
      });
    } catch {
      // The database may be going away too; the next boot clears these.
    }
  }

  /** Pings every connection, and closes the ones that stopped answering. */
  private sweepConnections(): void {
    const now = Date.now();
    for (const client of [...this.clients.values()]) {
      if (now - client.lastSeenAt > DEAD_AFTER_MS) {
        client.socket.destroy();
        void this.unregister(client);
        continue;
      }
      try {
        this.sendFrame(client.socket, Buffer.alloc(0), 0x9);
      } catch {
        void this.unregister(client);
      }
    }
  }

  @OnEvent('chat.message.created')
  handleCreated(event: ChatMessageCreatedEvent) {
    this.broadcastToUsers(event.participantIds, {
      event: 'message.created',
      chat_id: event.chatId,
      message: event.message,
    });
  }

  @OnEvent('chat.messages.read')
  handleRead(event: ChatReadEvent) {
    void this.chats.participantIds(event.chatId).then((participantIds) => {
      this.broadcastToUsers(participantIds, {
        event: 'messages.read',
        chat_id: event.chatId,
        user_id: event.userId,
        message_id: event.messageId,
        read_at: event.readAt,
      });
    });
  }

  @OnEvent('chat.presence.changed')
  handlePresence(event: PresenceEvent) {
    void this.chats.visiblePeerIds(event.userId).then((peerIds) => {
      this.broadcastToUsers(peerIds, {
        event: 'presence.changed',
        user_id: event.userId,
        status: event.status,
        last_seen_at: event.lastSeenAt,
      });
    });
  }

  private async handleUpgrade(
    req: IncomingMessage,
    socket: Socket,
    _head: Buffer,
  ) {
    const url = new URL(req.url ?? '', 'http://localhost');
    if (!url.pathname.endsWith('/ws/chats')) {
      socket.destroy();
      return;
    }
    if (this.closing) {
      this.reject(socket, 503, 'Service Unavailable');
      return;
    }

    const offered = this.offeredProtocols(req);
    const token = this.bearerFrom(req, offered, url);
    const key = req.headers['sec-websocket-key'];
    if (!token || typeof key !== 'string') {
      this.reject(socket, 401, 'Unauthorized');
      return;
    }

    const payload = await this.verifyToken(token);
    if (!payload || !(await this.principalIsLive(payload))) {
      this.reject(socket, 401, 'Unauthorized');
      return;
    }
    const userId = payload.sub;

    // The authorisation above awaited the database; the client may have given
    // up in the meantime.
    if (socket.destroyed) return;

    socket.setNoDelay(true);
    // Under the heartbeat, not instead of it: lets the kernel notice a dead
    // peer even while this process is too busy to sweep.
    socket.setKeepAlive(true, 30_000);
    socket.write(this.acceptResponse(key, offered));
    const now = Date.now();
    const client: RealtimeClient = {
      id: `${userId}:${now}:${randomUUID()}`,
      userId,
      sessionId: payload.sid,
      socket,
      rooms: new Set(),
      buffer: Buffer.alloc(0),
      lastSeenAt: now,
      windowStartedAt: now,
      framesInWindow: 0,
    };
    this.register(client);

    // The handshake decided once; this keeps deciding. A revoked session or a
    // disabled account closes the socket within a minute rather than lasting
    // as long as the woman leaves the screen open.
    client.recheck = setInterval(() => {
      void this.principalIsLive(payload).then((live) => {
        if (!live) this.close(client, 4401, 'Session is no longer valid');
      });
    }, SESSION_RECHECK_MS);
    client.recheck.unref?.();

    socket.on('data', (chunk) => {
      this.consume(client, chunk);
    });
    socket.on('close', () => {
      void this.unregister(client);
    });
    socket.on('error', () => {
      void this.unregister(client);
    });

    this.send(client, {
      event: 'connection.ready',
      user_id: userId,
      connected_at: new Date().toISOString(),
    });
  }

  private async verifyToken(token: string): Promise<JwtPayload | null> {
    try {
      return await this.jwt.verifyAsync<JwtPayload>(token, {
        secret: this.config.get<string>('jwt.accessSecret'),
      });
    } catch {
      return null;
    }
  }

  /**
   * The checks `JwtStrategy` runs on every HTTP request, run here too.
   *
   * A valid signature only says the token was minted by this platform, which
   * is the least interesting question: it stays true after she signs out,
   * after she revokes the handset she was pickpocketed, and after an
   * administrator disables the account. Until now the gateway asked nothing
   * else, so a token that HTTP had stopped accepting still carried full
   * conversation access — reading her messages and sending in her name — for
   * as long as it had left to run.
   */
  private async principalIsLive(payload: JwtPayload): Promise<boolean> {
    try {
      const user = await this.prisma.user.findUnique({
        where: { id: payload.sub },
        select: { id: true, disabledAt: true },
      });
      if (!user || user.disabledAt) return false;

      if (!payload.sid) return true;

      const now = new Date();
      const session = await this.prisma.session.findFirst({
        where: {
          id: payload.sid,
          userId: payload.sub,
          status: SessionStatus.ACTIVE,
          idleExpiresAt: { gt: now },
          absoluteExpiresAt: { gt: now },
        },
        select: { id: true },
      });
      return Boolean(session);
    } catch {
      // A database blip must not hand out access it cannot verify.
      return false;
    }
  }

  private register(client: RealtimeClient) {
    this.clients.set(client.id, client);
    const set = this.userClients.get(client.userId) ?? new Set<string>();
    set.add(client.id);
    this.userClients.set(client.userId, set);
    void this.chats.setPresence(client.userId, PresenceStatus.ONLINE, set.size);
  }

  private async unregister(client: RealtimeClient) {
    if (client.recheck) {
      clearInterval(client.recheck);
      client.recheck = undefined;
    }
    if (!this.clients.delete(client.id)) return;
    const set = this.userClients.get(client.userId);
    if (!set) return;
    set.delete(client.id);
    if (set.size === 0) {
      this.userClients.delete(client.userId);
      await this.chats.setPresence(client.userId, PresenceStatus.OFFLINE, 0);
    } else {
      this.userClients.set(client.userId, set);
      await this.chats.setPresence(client.userId, PresenceStatus.ONLINE, set.size);
    }
  }

  private consume(client: RealtimeClient, chunk: Buffer) {
    client.lastSeenAt = Date.now();
    client.buffer = Buffer.concat([client.buffer, chunk]);
    let decoded: { frames: DecodedFrame[]; remaining: Buffer };
    try {
      decoded = this.decodeFrames(client.buffer);
    } catch {
      // An oversized or malformed frame is not something to recover from: the
      // stream is no longer synchronised with anything we can parse.
      this.close(client, 1009, 'Frame too large');
      return;
    }
    client.buffer = decoded.remaining;

    // A frame that never completes must not be allowed to grow without end.
    if (client.buffer.length > MAX_BUFFERED_BYTES) {
      this.close(client, 1009, 'Frame too large');
      return;
    }

    for (const frame of decoded.frames) {
      if (!this.withinRate(client)) {
        this.close(client, 1008, 'Too many messages');
        return;
      }
      if (frame.opcode === 0x8) {
        client.socket.end();
        continue;
      }
      if (frame.opcode === 0x9) {
        this.sendFrame(client.socket, frame.payload, 0xa);
        continue;
      }
      if (frame.opcode !== 0x1) continue;
      void this.handleText(client, frame.payload.toString('utf8'));
    }
  }

  private async handleText(client: RealtimeClient, text: string) {
    let payload: Record<string, unknown>;
    try {
      payload = JSON.parse(text) as Record<string, unknown>;
    } catch {
      this.send(client, { event: 'error', message: 'Invalid JSON payload' });
      return;
    }

    const event = payload.event;
    try {
      if (event === 'conversation.join') {
        const chatId = String(payload.chat_id ?? '');
        await this.chats.assertMember(chatId, client.userId);
        client.rooms.add(chatId);
        this.send(client, { event: 'conversation.joined', chat_id: chatId });
        return;
      }

      if (event === 'conversation.leave') {
        const chatId = String(payload.chat_id ?? '');
        client.rooms.delete(chatId);
        this.send(client, { event: 'conversation.left', chat_id: chatId });
        return;
      }

      if (event === 'message.send') {
        const chatId = String(payload.chat_id ?? '');
        await this.chats.send(chatId, client.userId, {
          content: this.parseText(payload.content, MAX_CONTENT_CHARS),
          kind: this.parseKind(payload.kind),
          client_id: this.parseText(payload.client_id, 120) || undefined,
          attachments: this.parseAttachments(payload.attachments),
          metadata: payload.metadata,
        });
        return;
      }

      if (event === 'typing') {
        const chatId = String(payload.chat_id ?? '');
        const participantIds = await this.chats.participantIds(chatId);
        if (!participantIds.includes(client.userId)) {
          throw new Error('Not a member of this chat');
        }
        this.broadcastToUsers(
          participantIds.filter((id) => id !== client.userId),
          {
            event: 'typing',
            chat_id: chatId,
            user_id: client.userId,
            is_typing: Boolean(payload.is_typing),
          },
        );
        return;
      }

      if (event === 'message.read') {
        const chatId = String(payload.chat_id ?? '');
        await this.chats.markRead(chatId, client.userId, {
          message_id:
            typeof payload.message_id === 'string'
              ? payload.message_id
              : undefined,
        });
        return;
      }

      if (event === 'presence.ping') {
        const set = this.userClients.get(client.userId);
        await this.chats.setPresence(
          client.userId,
          PresenceStatus.ONLINE,
          set?.size ?? 1,
        );
        this.send(client, { event: 'presence.pong' });
        return;
      }

      this.send(client, { event: 'error', message: 'Unknown event' });
    } catch (error) {
      this.send(client, {
        event: 'error',
        message: error instanceof Error ? error.message : 'Realtime error',
      });
    }
  }

  /** Counts a frame against its connection's window; false once over. */
  private withinRate(client: RealtimeClient): boolean {
    const now = Date.now();
    if (now - client.windowStartedAt > FRAME_WINDOW_MS) {
      client.windowStartedAt = now;
      client.framesInWindow = 0;
    }
    client.framesInWindow += 1;
    return client.framesInWindow <= MAX_FRAMES_PER_WINDOW;
  }

  private broadcastToUsers(userIds: string[], payload: unknown) {
    const uniqueIds = [...new Set(userIds)];
    for (const userId of uniqueIds) {
      const ids = this.userClients.get(userId);
      if (!ids) continue;
      for (const id of ids) {
        const client = this.clients.get(id);
        if (client) this.send(client, payload);
      }
    }
  }

  /**
   * The bounds `SendMessageDto` states, applied on the socket path too.
   *
   * Everything arriving here skips the global `ValidationPipe` — it is a JSON
   * frame, not a request body — so the limits the HTTP route enforces were
   * simply absent on this one. Same message, same table, two different sets of
   * rules depending on which door it came through.
   */
  private parseText(value: unknown, max: number): string {
    return typeof value === 'string' ? value.slice(0, max) : '';
  }

  /**
   * Attachments were previously cast straight through with `as never`.
   *
   * The ownership check in `ChatsService.send` is what stops one woman
   * attaching another's upload, and it holds regardless — but everything
   * around it (kind, sizes, dimensions) reached the database unexamined.
   */
  private parseAttachments(value: unknown) {
    if (!Array.isArray(value)) return undefined;

    const attachments = value
      .slice(0, MAX_ATTACHMENTS)
      .filter(
        (entry): entry is Record<string, unknown> =>
          typeof entry === 'object' && entry !== null,
      )
      .map((entry) => {
        const kind = this.parseKind(entry.kind);
        const url = this.parseText(entry.url, 2048);
        if (!kind || !url) return null;
        return {
          kind,
          url,
          mime_type: this.parseText(entry.mime_type, 120) || undefined,
          file_name: this.parseText(entry.file_name, 180) || undefined,
          size_bytes: this.parseCount(entry.size_bytes),
          width: this.parseCount(entry.width),
          height: this.parseCount(entry.height),
          duration_ms: this.parseCount(entry.duration_ms),
          metadata: entry.metadata,
        };
      })
      .filter((entry): entry is NonNullable<typeof entry> => entry !== null);

    return attachments.length ? attachments : undefined;
  }

  private parseCount(value: unknown): number | undefined {
    return typeof value === 'number' && Number.isSafeInteger(value) && value >= 1
      ? value
      : undefined;
  }

  private parseKind(value: unknown) {
    if (typeof value !== 'string') return undefined;
    const normalized = value.toUpperCase();
    return Object.values(MessageKind).includes(normalized as MessageKind)
      ? (normalized as MessageKind)
      : undefined;
  }

  private send(client: RealtimeClient, payload: unknown) {
    this.sendFrame(client.socket, Buffer.from(JSON.stringify(payload), 'utf8'));
  }

  private sendFrame(socket: Socket, payload: Buffer, opcode = 0x1) {
    const length = payload.length;
    let header: Buffer;
    if (length < 126) {
      header = Buffer.from([0x80 | opcode, length]);
    } else if (length <= 0xffff) {
      header = Buffer.alloc(4);
      header[0] = 0x80 | opcode;
      header[1] = 126;
      header.writeUInt16BE(length, 2);
    } else {
      header = Buffer.alloc(10);
      header[0] = 0x80 | opcode;
      header[1] = 127;
      header.writeBigUInt64BE(BigInt(length), 2);
    }
    socket.write(Buffer.concat([header, payload]));
  }

  private decodeFrames(buffer: Buffer): {
    frames: DecodedFrame[];
    remaining: Buffer;
  } {
    const frames: DecodedFrame[] = [];
    let offset = 0;

    while (offset + 2 <= buffer.length) {
      const first = buffer[offset];
      const second = buffer[offset + 1];
      const opcode = first & 0x0f;
      const masked = (second & 0x80) === 0x80;
      let length = second & 0x7f;
      let headerLength = 2;

      if (length === 126) {
        if (offset + 4 > buffer.length) break;
        length = buffer.readUInt16BE(offset + 2);
        headerLength = 4;
      } else if (length === 127) {
        if (offset + 10 > buffer.length) break;
        length = Number(buffer.readBigUInt64BE(offset + 2));
        headerLength = 10;
      }

      // Checked against the *declared* length, before a single byte of it is
      // waited for. Checking after the frame arrives would be no protection at
      // all: arriving is the expensive part.
      if (!Number.isSafeInteger(length) || length > MAX_FRAME_BYTES) {
        throw new Error('WS_FRAME_TOO_LARGE');
      }

      const maskLength = masked ? 4 : 0;
      const frameLength = headerLength + maskLength + length;
      if (offset + frameLength > buffer.length) break;

      const maskOffset = offset + headerLength;
      const payloadOffset = maskOffset + maskLength;
      const payload = Buffer.from(
        buffer.subarray(payloadOffset, payloadOffset + length),
      );
      if (masked) {
        const mask = buffer.subarray(maskOffset, maskOffset + 4);
        for (let i = 0; i < payload.length; i += 1) {
          payload[i] = payload[i] ^ mask[i % 4];
        }
      }

      frames.push({ opcode, payload });
      offset += frameLength;
    }

    return { frames, remaining: buffer.subarray(offset) };
  }

  /** The subprotocols the client offered, in the order it offered them. */
  private offeredProtocols(req: IncomingMessage): string[] {
    const header = req.headers['sec-websocket-protocol'];
    if (!header) return [];
    return (Array.isArray(header) ? header.join(',') : header)
      .split(',')
      .map((entry) => entry.trim())
      .filter(Boolean);
  }

  /**
   * The bearer token, taken from a header rather than from the URL.
   *
   * Two sources, both headers. `Authorization` is the ordinary one, and what
   * anything that is not a browser should send. The subprotocol pair —
   * `AUTH_SUBPROTOCOL` followed by the token — is the browser's only way to
   * say the same thing, because the `WebSocket` constructor accepts no
   * headers of its own.
   *
   * The query string is read only while a transitional deadline is still
   * running, and never otherwise. See `queryTokenDeadline`.
   */
  private bearerFrom(
    req: IncomingMessage,
    offered: string[],
    url: URL,
  ): string {
    const header = req.headers.authorization;
    if (header) return header.replace(/^Bearer\s+/i, '').trim();

    const at = offered.indexOf(AUTH_SUBPROTOCOL);
    if (at !== -1 && at + 1 < offered.length) return offered[at + 1];

    const legacy = url.searchParams.get('token');
    if (legacy && this.queryTokenAllowed()) {
      this.warnLegacyHandshake();
      return legacy;
    }

    return '';
  }

  /**
   * Is the retired `?token=` still inside its transition?
   *
   * Evaluated per handshake rather than cached at boot, so the window closes
   * on its own at the instant it names — a fallback that needs someone to
   * remember to restart the process is a fallback that outlives its reason.
   */
  private queryTokenAllowed(): boolean {
    const configured = (
      this.config.get<string>('security.wsQueryTokenUntil') ?? ''
    ).trim();
    if (!configured) return false;

    const deadline = new Date(configured);
    // Boot validation already refused an unparseable value; if one reaches
    // here anyway, the safe reading is that the transition is over.
    if (Number.isNaN(deadline.getTime())) return false;

    return deadline.getTime() > Date.now();
  }

  /**
   * Says, at most once a minute, that a client is still on the old handshake.
   *
   * This is the signal the deadline is set against: when it stops appearing,
   * the rollout is done and `WS_QUERY_TOKEN_UNTIL` can be cleared early. Rate
   * limited because it fires per connection, and a chat screen reconnects
   * every time it is opened — an unthrottled warning would bury the log it is
   * meant to be read from.
   */
  private warnLegacyHandshake(): void {
    this.legacyHandshakes += 1;
    const now = Date.now();
    if (now - this.lastLegacyWarnAt < 60_000) return;
    this.lastLegacyWarnAt = now;
    this.logger.warn(
      `A client authenticated the chat socket with ?token= — the access token ` +
        `is in the URL and therefore in every proxy log on the way. ` +
        `${this.legacyHandshakes} such handshake(s) so far; this stops being ` +
        `accepted at ${this.config.get<string>('security.wsQueryTokenUntil')}.`,
    );
  }

  /**
   * The 101, echoing the negotiated subprotocol when there was one.
   *
   * Not optional: a browser that offered subprotocols fails the connection
   * outright if the server selects none of them. Only the marker is echoed,
   * never the token beside it — putting the credential in a response header
   * would undo the point of moving it out of the URL.
   */
  private acceptResponse(key: string, offered: string[] = []) {
    const accept = createHash('sha1')
      .update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
      .digest('base64');
    const lines = [
      'HTTP/1.1 101 Switching Protocols',
      'Upgrade: websocket',
      'Connection: Upgrade',
      `Sec-WebSocket-Accept: ${accept}`,
    ];
    if (offered.includes(AUTH_SUBPROTOCOL)) {
      lines.push(`Sec-WebSocket-Protocol: ${AUTH_SUBPROTOCOL}`);
    }
    return [...lines, '', ''].join('\r\n');
  }

  /** Close an established connection with a WebSocket close frame. */
  private close(client: RealtimeClient, code: number, reason: string) {
    try {
      const payload = Buffer.alloc(2 + Buffer.byteLength(reason));
      payload.writeUInt16BE(code, 0);
      payload.write(reason, 2);
      this.sendFrame(client.socket, payload, 0x8);
    } catch {
      // The socket is already gone; `end()` below is still the right move.
    }
    client.socket.end();
    void this.unregister(client);
  }

  private reject(socket: Socket, status: number, message: string) {
    socket.write(
      `HTTP/1.1 ${status} ${message}\r\nConnection: close\r\n\r\n${message}`,
    );
    socket.destroy();
  }
}
