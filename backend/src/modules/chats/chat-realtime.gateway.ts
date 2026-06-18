import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { HttpAdapterHost } from '@nestjs/core';
import { OnEvent } from '@nestjs/event-emitter';
import { JwtService } from '@nestjs/jwt';
import { MessageKind, PresenceStatus } from '@prisma/client';
import { createHash } from 'crypto';
import { IncomingMessage } from 'http';
import { Socket } from 'net';
import { URL } from 'url';
import { JwtPayload } from '../auth/interfaces/jwt-payload.interface';
import { ChatsService } from './chats.service';

interface RealtimeClient {
  id: string;
  userId: string;
  socket: Socket;
  rooms: Set<string>;
  buffer: Buffer;
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
export class ChatRealtimeGateway implements OnModuleInit {
  private readonly logger = new Logger(ChatRealtimeGateway.name);
  private readonly clients = new Map<string, RealtimeClient>();
  private readonly userClients = new Map<string, Set<string>>();

  constructor(
    private readonly adapterHost: HttpAdapterHost,
    private readonly jwt: JwtService,
    private readonly config: ConfigService,
    private readonly chats: ChatsService,
  ) {}

  onModuleInit() {
    const server = this.adapterHost.httpAdapter.getHttpServer() as {
      on(event: 'upgrade', listener: (req: IncomingMessage, socket: Socket, head: Buffer) => void): void;
    };
    server.on('upgrade', (req, socket, head) => {
      void this.handleUpgrade(req, socket, head);
    });
    this.logger.log('Chat WebSocket endpoint mounted at /ws/chats');
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

    const token =
      url.searchParams.get('token') ??
      req.headers.authorization?.replace(/^Bearer\s+/i, '') ??
      '';
    const key = req.headers['sec-websocket-key'];
    if (!token || typeof key !== 'string') {
      this.reject(socket, 401, 'Unauthorized');
      return;
    }

    const userId = await this.verifyToken(token);
    if (!userId) {
      this.reject(socket, 401, 'Unauthorized');
      return;
    }

    socket.write(this.acceptResponse(key));
    const client: RealtimeClient = {
      id: `${userId}:${Date.now()}:${Math.random().toString(36).slice(2)}`,
      userId,
      socket,
      rooms: new Set(),
      buffer: Buffer.alloc(0),
    };
    this.register(client);

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

  private async verifyToken(token: string) {
    try {
      const payload = await this.jwt.verifyAsync<JwtPayload>(token, {
        secret: this.config.get<string>('jwt.accessSecret'),
      });
      return payload.sub;
    } catch {
      return null;
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
    client.buffer = Buffer.concat([client.buffer, chunk]);
    const decoded = this.decodeFrames(client.buffer);
    client.buffer = decoded.remaining;

    for (const frame of decoded.frames) {
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
          content: typeof payload.content === 'string' ? payload.content : '',
          kind: this.parseKind(payload.kind),
          client_id:
            typeof payload.client_id === 'string' ? payload.client_id : undefined,
          attachments: Array.isArray(payload.attachments)
            ? (payload.attachments as never)
            : undefined,
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

  private acceptResponse(key: string) {
    const accept = createHash('sha1')
      .update(`${key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11`)
      .digest('base64');
    return [
      'HTTP/1.1 101 Switching Protocols',
      'Upgrade: websocket',
      'Connection: Upgrade',
      `Sec-WebSocket-Accept: ${accept}`,
      '',
      '',
    ].join('\r\n');
  }

  private reject(socket: Socket, status: number, message: string) {
    socket.write(
      `HTTP/1.1 ${status} ${message}\r\nConnection: close\r\n\r\n${message}`,
    );
    socket.destroy();
  }
}
