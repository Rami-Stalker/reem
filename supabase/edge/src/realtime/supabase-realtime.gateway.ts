import { Injectable, Logger } from '@nestjs/common';
import { OnEvent } from '@nestjs/event-emitter';
import { ChatsService } from '../../../../backend/src/modules/chats/chats.service';
import { trackBackgroundWork } from '../runtime/background';
import { SupabaseHttp } from '../supabase/supabase-http';
import { userTopic } from './topics';

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

interface BroadcastMessage {
  topic: string;
  event: string;
  payload: Record<string, unknown>;
  private: true;
}

/**
 * The chat gateway, delivered over Supabase Realtime instead of a WebSocket
 * this process holds open.
 *
 * `ChatRealtimeGateway` upgrades HTTP connections on the server and keeps one
 * socket per device in memory. An edge isolate lives for seconds and holds no
 * sockets, so this class takes its place in the container: it listens to the
 * very same domain events `ChatsService` emits and publishes each frame, in
 * the very same shape, to a private Realtime topic per recipient —
 * `reem:user:<id>`. Only that user can subscribe to it; the policy on
 * `realtime.messages` checks (see supabase/migrations).
 *
 * Frames client→server (`message.send`, `message.read`) already have REST
 * twins the app calls. `typing` never touches the server: clients broadcast it
 * on the conversation's own private topic, authorised by membership.
 */
@Injectable()
export class SupabaseRealtimeGateway {
  private readonly logger = new Logger(SupabaseRealtimeGateway.name);

  constructor(
    private readonly chats: ChatsService,
    private readonly http: SupabaseHttp,
  ) {}

  @OnEvent('chat.message.created')
  handleCreated(event: ChatMessageCreatedEvent) {
    this.broadcastToUsers(event.participantIds, 'message.created', {
      event: 'message.created',
      chat_id: event.chatId,
      message: event.message,
    });
  }

  @OnEvent('chat.messages.read')
  handleRead(event: ChatReadEvent) {
    trackBackgroundWork(
      this.chats.participantIds(event.chatId).then((participantIds) =>
        this.broadcastToUsers(participantIds, 'messages.read', {
          event: 'messages.read',
          chat_id: event.chatId,
          user_id: event.userId,
          message_id: event.messageId,
          read_at: event.readAt,
        }),
      ),
    );
  }

  @OnEvent('chat.presence.changed')
  handlePresence(event: PresenceEvent) {
    trackBackgroundWork(
      this.chats.visiblePeerIds(event.userId).then((peerIds) =>
        this.broadcastToUsers(peerIds, 'presence.changed', {
          event: 'presence.changed',
          user_id: event.userId,
          status: event.status,
          last_seen_at: event.lastSeenAt,
        }),
      ),
    );
  }

  private broadcastToUsers(userIds: string[], event: string, payload: Record<string, unknown>) {
    const messages: BroadcastMessage[] = [...new Set(userIds)].map((userId) => ({
      topic: userTopic(userId),
      event,
      payload,
      private: true,
    }));
    if (messages.length === 0) return Promise.resolve();

    const delivery = this.http
      .expectOk('/realtime/v1/api/broadcast', { method: 'POST', json: { messages }, timeoutMs: 10_000 })
      .then(() => undefined)
      .catch((error: unknown) => {
        // A missed frame is recovered by the next thread refresh; failing the
        // request that sent the message would lose the message itself.
        this.logger.warn(`Realtime broadcast "${event}" failed: ${String(error)}`);
      });
    trackBackgroundWork(delivery);
    return delivery;
  }
}
