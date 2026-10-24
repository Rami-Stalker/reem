import {
  BadRequestException,
  ForbiddenException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { EventEmitter2 } from '@nestjs/event-emitter';
import {
  ChatContextType,
  ChatParticipantRole,
  MessageDeliveryStatus,
  MessageKind,
  NotificationChannel,
  NotificationType,
  PresenceStatus,
  Prisma,
  UserRole,
  NotificationCategory,
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
import { LIVE_OFFER_WHERE } from '../../common/catalog/product-include';
import { Money } from '../../common/money/money';
import { MediaService } from '../media/media.service';
import {
  ChatWithRelations,
  MessageWithRelations,
  serializeChatThread,
  serializeMessage,
} from '../../common/serializers';
import { NotificationsService } from '../notifications/notifications.service';
import {
  BlockUserDto,
  ChatListQueryDto,
  MarkReadDto,
  MessageQueryDto,
  ReportUserDto,
  SendMessageDto,
  StartConversationDto,
} from './dto/chat.dto';

/** A client-sent metadata blob as an object to extend, whatever was sent. */
function asRecord(value: unknown): Record<string, unknown> {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? (value as Record<string, unknown>)
    : {};
}

const messageInclude = {
  attachments: true,
  receipts: true,
} satisfies Prisma.MessageInclude;

const chatInclude = {
  participants: {
    include: {
      user: { include: { presence: true } },
    },
  },
  messages: {
    orderBy: { createdAt: 'desc' as const },
    take: 1,
    include: messageInclude,
  },
} satisfies Prisma.ChatInclude;

/**
 * The inbox is not paged — the client draws one list — so this is the line past
 * which one account stops being able to cost the platform its memory. A seller
 * whose shop generates three hundred live conversations is doing well; one with
 * more needs search, which this endpoint already supports, not a longer list.
 */
const MAX_INBOX_THREADS = 300;

/** Receipts one read call writes; anything older is caught by the next. */
const MAX_RECEIPTS_PER_READ = 1000;

/** What the push says, in Arabic, for each kind of message. */
function notificationBody(message: MessageWithRelations): string {
  switch (message.kind) {
    case MessageKind.IMAGE:
      return '📷 صورة';
    case MessageKind.VOICE:
      return '🎤 رسالة صوتية';
    case MessageKind.FILE:
      return `📎 ${message.attachments?.[0]?.fileName ?? 'ملف'}`;
    default:
      return message.content.slice(0, 160);
  }
}

@Injectable()
export class ChatsService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly events: EventEmitter2,
    private readonly notifications: NotificationsService,
    private readonly media: MediaService,
  ) {}

  async threads(userId: string, query: ChatListQueryDto = {}) {
    const participations = await this.prisma.chatParticipant.findMany({
      where: {
        userId,
        archivedAt: null,
        ...(query.q
          ? {
              chat: {
                OR: [
                  { title: { contains: query.q, mode: 'insensitive' } },
                  {
                    messages: {
                      some: {
                        deletedAt: null,
                        content: { contains: query.q, mode: 'insensitive' },
                      },
                    },
                  },
                  {
                    participants: {
                      some: {
                        user: {
                          name: { contains: query.q, mode: 'insensitive' },
                        },
                      },
                    },
                  },
                ],
              },
            }
          : {}),
      },
      include: { chat: { include: chatInclude } },
      orderBy: { chat: { updatedAt: 'desc' } },
      take: MAX_INBOX_THREADS,
    });

    const unread = await this.unreadCounts(
      userId,
      participations.map((participation) => participation.chatId),
    );

    return participations.map((participation) =>
      serializeChatThread(
        participation.chat as ChatWithRelations,
        userId,
        unread.get(participation.chatId) ?? 0,
      ),
    );
  }

  /**
   * One conversation's header row — who she is talking to, and how many of
   * their messages she has not read. The details screen opens straight from a
   * deep link or a freshly created chat, where the list was never loaded, so
   * it cannot borrow this from `threads()`.
   */
  async thread(chatId: string, userId: string) {
    await this.assertMember(chatId, userId);
    const chat = await this.prisma.chat.findUniqueOrThrow({
      where: { id: chatId },
      include: chatInclude,
    });
    const unread = await this.unreadCount(chatId, userId);
    return serializeChatThread(chat as ChatWithRelations, userId, unread);
  }

  /**
   * The one conversation between these two people.
   *
   * **One thread per pair, not one per subject.** This used to look a chat up
   * by `(type, buyerId, sellerId, productId, sellerOrderId)`, which means a
   * shopper who asked a boutique about a dress, then about a scarf, then about
   * the parcel carrying both, ended up with three separate conversations with
   * the same woman — and the inbox showed her name three times, each row
   * holding a third of the history. Asking about a second dress made a fourth.
   * That is the «تكرار المحادثات» complaint, and it was the lookup key.
   *
   * The pair is now the key. The product or parcel that occasioned the message
   * is still recorded on the chat, as *the latest thing this conversation is
   * about* — it drives the header and the subject line of a notification — but
   * it no longer partitions the history.
   *
   * **And exactly one, under concurrency.** Two taps on «راسلي المتجر» before
   * the first answered used to pass the same `findFirst` miss and create two
   * rows. The unique index on `(buyer_id, seller_id)` makes the second create
   * fail rather than succeed, and the retry below finds the row the first one
   * won with.
   */
  async startConversation(userId: string, dto: StartConversationDto) {
    const resolved = await this.resolveConversation(userId, dto);
    await this.assertNotBlocked(userId, resolved.participantIds);

    let chat = await this.findPairChat(resolved.buyerId, resolved.sellerId);

    if (chat) {
      // Keep the context current. What she is asking about now is what the
      // header should say, and the row it points at is the one a notification
      // should deep-link to.
      chat = await this.prisma.chat.update({
        where: { id: chat.id },
        data: {
          type: resolved.type,
          productId: resolved.productId ?? chat.productId,
          sellerOrderId: resolved.sellerOrderId ?? chat.sellerOrderId,
          title: resolved.title ?? chat.title,
        },
        include: chatInclude,
      });
    } else {
      try {
        chat = await this.prisma.chat.create({
          data: {
            type: resolved.type,
            buyerId: resolved.buyerId,
            sellerId: resolved.sellerId,
            productId: resolved.productId,
            sellerOrderId: resolved.sellerOrderId,
            title: resolved.title,
            participants: {
              create: resolved.participants.map((participant) => ({
                userId: participant.userId,
                role: participant.role,
              })),
            },
          },
          include: chatInclude,
        });
      } catch (error) {
        // The index caught a concurrent create. Whoever won holds the thread.
        if (
          !(error instanceof Prisma.PrismaClientKnownRequestError) ||
          error.code !== 'P2002'
        ) {
          throw error;
        }
        chat = await this.findPairChat(resolved.buyerId, resolved.sellerId);
        if (!chat) throw error;
      }
    }

    if (dto.message?.trim()) {
      await this.send(chat.id, userId, { content: dto.message.trim() });
      chat = await this.prisma.chat.findUniqueOrThrow({
        where: { id: chat.id },
        include: chatInclude,
      });
    }

    // Reopening a thread she already has must not draw it as fully read: the
    // details screen and the inbox both take this row as the truth.
    const unread = await this.unreadCount(chat.id, userId);
    return serializeChatThread(chat as ChatWithRelations, userId, unread);
  }

  /** Their conversation, whatever it was last about. */
  private findPairChat(buyerId: string, sellerId: string) {
    return this.prisma.chat.findFirst({
      where: { buyerId, sellerId },
      include: chatInclude,
      // Deterministic while duplicates from before the unique index may still
      // exist in a database that has not been migrated: always the oldest, so
      // two callers never disagree about which one is "the" thread.
      orderBy: { createdAt: 'asc' },
    });
  }

  /**
   * One page of a conversation, oldest first.
   *
   * `before` is the way to scroll back. Offset paging (`page`) shifts under a
   * live conversation — every message that arrives while she reads pushes the
   * next page down by one, so "load older" fetched a message she already had
   * and skipped one she had not. A cursor on the oldest message she holds
   * cannot drift. `page` still works for older builds of the app.
   */
  async messages(chatId: string, userId: string, query: MessageQueryDto = new MessageQueryDto()) {
    await this.assertMember(chatId, userId);
    const before = query.before ? new Date(query.before) : undefined;
    const messages = await this.prisma.message.findMany({
      where: {
        chatId,
        deletedAt: null,
        ...(before ? { createdAt: { lt: before } } : {}),
        ...(query.q
          ? { content: { contains: query.q, mode: 'insensitive' } }
          : {}),
      },
      orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
      skip: before ? 0 : (query.page - 1) * query.limit,
      take: query.limit,
      include: messageInclude,
    });
    await this.markDelivered(chatId, userId, messages);
    return messages.reverse().map((message) => serializeMessage(message, userId));
  }

  async send(chatId: string, userId: string, dto: SendMessageDto) {
    const chat = await this.assertMember(chatId, userId);
    if (chat.closedAt) {
      throw new ForbiddenException('This conversation is closed');
    }
    const content = dto.content?.trim() ?? '';
    const attachments = dto.attachments ?? [];
    if (!content && attachments.length === 0) {
      throw new BadRequestException('Message content or attachment is required');
    }
    // A media kind with nothing attached is a text message that claims to be
    // a photograph — the client draws an empty frame for it. The kind follows
    // what was actually sent.
    const kind =
      attachments.length === 0
        ? MessageKind.TEXT
        : (dto.kind ?? attachments[0].kind);

    // A retry, not a second message. The phone resends with the same
    // `client_id` when the first attempt's answer was lost on the way back
    // (a lift, a tunnel) — and the server had already stored it. Without this
    // the seller received every such message twice.
    if (dto.client_id) {
      const existing = await this.prisma.message.findFirst({
        where: { chatId, senderId: userId, clientId: dto.client_id },
        include: messageInclude,
      });
      if (existing) return serializeMessage(existing, userId);
    }

    const recipientIds = chat.participants
      .map((participant) => participant.userId)
      .filter((id) => id !== userId);
    await this.assertNotBlocked(userId, recipientIds);

    // Resolved before the write so the attachment rows carry the link from the
    // moment they exist. Scoped to the sender: quoting somebody else's upload
    // URL must not make it readable by this chat's participants.
    const assetIds = await Promise.all(
      attachments.map((attachment) =>
        this.media.resolveAssetId(attachment.url, userId),
      ),
    );

    // The piece she is asking about, as the boutique will see it on the
    // message. Built here from the catalogue rather than taken from the
    // phone, so a card can never show a price or a photo that is not real.
    const product = dto.product_id
      ? await this.productReference(dto.product_id, chat.sellerId)
      : null;
    const metadata = product
      ? { ...asRecord(dto.metadata), product }
      : dto.metadata;

    const message = await this.prisma.message.create({
      data: {
        chatId,
        senderId: userId,
        clientId: dto.client_id,
        kind,
        content,
        metadata: metadata as Prisma.InputJsonValue,
        status: MessageDeliveryStatus.SENT,
        attachments: attachments.length
          ? {
              create: attachments.map((attachment, index) => ({
                kind: attachment.kind,
                url: attachment.url,
                // The link that later answers "may this person open it".
                // Null for a URL that is not one of ours, which is fine — the
                // reader of an external link is whoever the internet lets.
                mediaAssetId: assetIds[index],
                mimeType: attachment.mime_type,
                fileName: attachment.file_name,
                sizeBytes: attachment.size_bytes,
                width: attachment.width,
                height: attachment.height,
                durationMs: attachment.duration_ms,
                metadata: attachment.metadata as Prisma.InputJsonValue,
              })),
            }
          : undefined,
        receipts: {
          create: [
            {
              userId,
              deliveredAt: new Date(),
              readAt: new Date(),
            },
          ],
        },
      },
      include: messageInclude,
    });

    await this.prisma.chat.update({
      where: { id: chatId },
      data: {
        updatedAt: new Date(),
        // What the conversation is about now — the header and the next
        // notification's subject follow the latest piece asked about.
        ...(product
          ? {
              type: ChatContextType.PRODUCT,
              productId: product.id,
              title: product.title,
            }
          : {}),
      },
    });

    // The upload is now part of a conversation, so it is no longer an orphan.
    await this.media.markAttached(
      userId,
      attachments.map((attachment) => attachment.url),
    );

    const serialized = serializeMessage(message, userId);
    // The open conversation first, the push after. The push used to go first,
    // so a reply sat behind a round trip to the notification provider before
    // the person looking at the screen saw it.
    this.events.emit('chat.message.created', {
      chatId,
      participantIds: chat.participants.map((participant) => participant.userId),
      senderId: userId,
      message: serialized,
    });

    await this.notifyRecipients(chat, userId, message);
    return serialized;
  }

  /**
   * She has read the conversation up to [dto.message_id] — or to its end.
   *
   * Three things this used to get wrong:
   *
   *  - **The marker moved backwards.** Marking an older message read set the
   *    cutoff to *now*, so every newer message — ones she had not seen — was
   *    counted read too; and a late `message_id` from a second handset pulled
   *    the marker back past messages she had already read. The cutoff is now
   *    the read message's own timestamp, and it only ever advances.
   *  - **It rewrote every receipt on every call.** The app marks read each
   *    time a message arrives while the conversation is open, and each call
   *    upserted up to 500 receipts one query at a time — including the ones
   *    already read — in no particular order. Only messages not yet read by
   *    her are touched now, in two set-based writes.
   *  - **It broadcast even when nothing changed**, so the other side redrew
   *    its ticks for nothing. The event now fires only on a change.
   */
  async markRead(chatId: string, userId: string, dto: MarkReadDto = {}) {
    await this.assertMember(chatId, userId);
    const target = dto.message_id
      ? await this.prisma.message.findFirst({
          where: { id: dto.message_id, chatId },
          select: { id: true, createdAt: true },
        })
      : await this.prisma.message.findFirst({
          where: { chatId, deletedAt: null },
          orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
          select: { id: true, createdAt: true },
        });
    if (!target) return { read: 0 };

    const participant = await this.prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId, userId } },
      select: { lastReadAt: true, lastReadMessageId: true },
    });
    const advances =
      !participant?.lastReadAt || participant.lastReadAt < target.createdAt;

    const unread = await this.prisma.message.findMany({
      where: {
        chatId,
        senderId: { not: userId },
        createdAt: { lte: target.createdAt },
        receipts: { none: { userId, readAt: { not: null } } },
      },
      select: { id: true },
      orderBy: { createdAt: 'desc' },
      take: MAX_RECEIPTS_PER_READ,
    });

    const cutoffId = advances
      ? target.id
      : (participant?.lastReadMessageId ?? target.id);
    if (unread.length === 0 && !advances) {
      return { read: 0, message_id: cutoffId };
    }

    const now = new Date();
    const ids = unread.map((message) => message.id);
    if (ids.length > 0) {
      await this.prisma.messageReadReceipt.createMany({
        data: ids.map((messageId) => ({
          messageId,
          userId,
          deliveredAt: now,
          readAt: now,
        })),
        skipDuplicates: true,
      });
      await Promise.all([
        // Rows that existed already, as "delivered" from an earlier fetch.
        this.prisma.messageReadReceipt.updateMany({
          where: { userId, messageId: { in: ids }, readAt: null },
          data: { readAt: now },
        }),
        this.prisma.message.updateMany({
          where: { id: { in: ids }, deliveredAt: null },
          data: { deliveredAt: now },
        }),
      ]);
      await this.prisma.message.updateMany({
        where: { id: { in: ids }, readAt: null },
        data: { status: MessageDeliveryStatus.READ, readAt: now },
      });
    }

    if (advances) {
      await this.prisma.chatParticipant.update({
        where: { chatId_userId: { chatId, userId } },
        data: { lastReadMessageId: target.id, lastReadAt: target.createdAt },
      });
    }

    const upTo = advances
      ? target.createdAt
      : (participant?.lastReadAt ?? target.createdAt);
    this.events.emit('chat.messages.read', {
      chatId,
      userId,
      messageId: cutoffId,
      readAt: now.toISOString(),
      upTo: upTo.toISOString(),
    });
    return { read: ids.length, message_id: cutoffId };
  }

  /**
   * The recipient's device has these messages — the second tick.
   *
   * Called by the socket the moment it hands a new message to a connected
   * recipient, and by the message fetch for everything she loads. Until now
   * the only path was the fetch, and nothing told the sender: her ticks stayed
   * at one until she reopened the conversation herself.
   */
  async acknowledgeDelivery(chatId: string, userId: string, messageIds: string[]) {
    if (messageIds.length === 0) return;
    const pending = await this.prisma.message.findMany({
      where: {
        chatId,
        id: { in: messageIds },
        senderId: { not: userId },
        receipts: { none: { userId, deliveredAt: { not: null } } },
      },
      select: { id: true },
    });
    if (pending.length === 0) return;

    const now = new Date();
    const ids = pending.map((message) => message.id);
    await this.prisma.messageReadReceipt.createMany({
      data: ids.map((messageId) => ({ messageId, userId, deliveredAt: now })),
      skipDuplicates: true,
    });
    await Promise.all([
      this.prisma.messageReadReceipt.updateMany({
        where: { userId, messageId: { in: ids }, deliveredAt: null },
        data: { deliveredAt: now },
      }),
      this.prisma.message.updateMany({
        where: { id: { in: ids }, status: MessageDeliveryStatus.SENT },
        data: { status: MessageDeliveryStatus.DELIVERED, deliveredAt: now },
      }),
    ]);

    this.events.emit('chat.messages.delivered', {
      chatId,
      userId,
      messageIds: ids,
      deliveredAt: now.toISOString(),
    });
  }

  async search(userId: string, query: MessageQueryDto) {
    if (!query.q?.trim()) return [];
    const messages = await this.prisma.message.findMany({
      where: {
        content: { contains: query.q.trim(), mode: 'insensitive' },
        chat: { participants: { some: { userId } } },
        deletedAt: null,
      },
      include: messageInclude,
      orderBy: { createdAt: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
    });
    return messages.map((message) => serializeMessage(message, userId));
  }

  async blockUser(userId: string, blockedId: string, dto: BlockUserDto) {
    if (userId === blockedId) {
      throw new BadRequestException('You cannot block yourself');
    }
    // An unknown id used to reach the insert and fail the foreign key — a 500
    // for what is a plain "no such person".
    const target = await this.prisma.user.findUnique({
      where: { id: blockedId },
      select: { id: true },
    });
    if (!target) throw new NotFoundException('User not found');
    await this.prisma.chatBlock.upsert({
      where: { blockerId_blockedId: { blockerId: userId, blockedId } },
      create: { blockerId: userId, blockedId, reason: dto.reason },
      update: { reason: dto.reason },
    });
    return { message: 'User blocked' };
  }

  async unblockUser(userId: string, blockedId: string) {
    await this.prisma.chatBlock.deleteMany({
      where: { blockerId: userId, blockedId },
    });
    return { message: 'User unblocked' };
  }

  async reportUser(chatId: string, userId: string, dto: ReportUserDto) {
    const chat = await this.assertMember(chatId, userId);
    const participantIds = chat.participants.map((participant) => participant.userId);
    if (
      dto.reported_user_id === userId ||
      !participantIds.includes(dto.reported_user_id)
    ) {
      throw new BadRequestException('Reported user must be another chat participant');
    }
    if (dto.message_id) {
      const message = await this.prisma.message.findFirst({
        where: { id: dto.message_id, chatId },
        select: { id: true },
      });
      if (!message) {
        throw new BadRequestException('Reported message does not belong to this chat');
      }
    }
    const report = await this.prisma.chatReport.create({
      data: {
        chatId,
        reporterId: userId,
        reportedUserId: dto.reported_user_id,
        messageId: dto.message_id,
        reason: dto.reason,
        description: dto.description,
      },
    });
    return {
      id: report.id,
      status: report.status.toLowerCase(),
      created_at: report.createdAt.toISOString(),
    };
  }

  async setPresence(userId: string, status: PresenceStatus, socketCount: number) {
    const presence = await this.prisma.userPresence.upsert({
      where: { userId },
      create: {
        userId,
        status,
        socketCount,
        lastSeenAt: new Date(),
      },
      update: {
        status,
        socketCount,
        lastSeenAt: new Date(),
      },
    });
    this.events.emit('chat.presence.changed', {
      userId,
      status: presence.status.toLowerCase(),
      lastSeenAt: presence.lastSeenAt.toISOString(),
    });
    return presence;
  }

  async participantIds(chatId: string) {
    const participants = await this.prisma.chatParticipant.findMany({
      where: { chatId },
      select: { userId: true },
    });
    return participants.map((participant) => participant.userId);
  }

  async visiblePeerIds(userId: string) {
    const participants = await this.prisma.chatParticipant.findMany({
      where: { userId },
      select: {
        chat: { select: { participants: { select: { userId: true } } } },
      },
    });
    return [
      ...new Set(
        participants.flatMap((participant) =>
          participant.chat.participants
            .map((peer) => peer.userId)
            .filter((id) => id !== userId),
        ),
      ),
    ];
  }

  /**
   * A product as a message carries it: enough for a card, priced at *this*
   * boutique's live offer when she has one (the conversation is with her, not
   * with the cheapest seller of the same catalogue entry).
   */
  private async productReference(productId: string, sellerId: string | null) {
    const product = await this.prisma.product.findUnique({
      where: { id: productId },
      select: {
        id: true,
        title: true,
        media: {
          orderBy: { sortOrder: 'asc' },
          take: 1,
          select: { url: true },
        },
        offers: {
          where: { ...LIVE_OFFER_WHERE, ...(sellerId ? { sellerId } : {}) },
          orderBy: [{ priceSyp: 'asc' }, { price: 'asc' }],
          take: 1,
          select: { price: true, currency: true },
        },
      },
    });
    if (!product) throw new NotFoundException('Product not found');
    const offer = product.offers[0];
    return {
      id: product.id,
      title: product.title,
      image_url: product.media[0]?.url ?? null,
      price: offer ? Money.of(offer.price, offer.currency).toJSON() : null,
    };
  }

  async assertMember(chatId: string, userId: string) {
    const chat = await this.prisma.chat.findFirst({
      where: { id: chatId, participants: { some: { userId } } },
      include: { participants: true },
    });
    if (!chat) throw new ForbiddenException('Not a member of this chat');
    return chat;
  }

  private async resolveConversation(userId: string, dto: StartConversationDto) {
    if (dto.order_id) {
      // An order chat is really a chat about ONE seller's parcel. The old code
      // took `order.items[0].product.sellerId` — silently binding a
      // multi-seller order's conversation to whoever happened to be first.
      const sellerOrder = await this.prisma.sellerOrder.findUnique({
        where: { id: dto.order_id },
        include: { order: { select: { userId: true } } },
      });
      if (!sellerOrder) throw new NotFoundException('Order not found');

      const buyerId = sellerOrder.order.userId;
      if (!buyerId) {
        throw new BadRequestException('Guest orders have no chat thread');
      }
      if (userId !== buyerId && userId !== sellerOrder.sellerId) {
        throw new ForbiddenException('You cannot access this order chat');
      }
      await this.assertBuyerSellerPair(buyerId, sellerOrder.sellerId);
      return this.conversationShape({
        type: ChatContextType.ORDER,
        buyerId,
        sellerId: sellerOrder.sellerId,
        sellerOrderId: sellerOrder.id,
        // Arabic, like everything else a woman reads in this product. The
        // clients show the other party's name as the heading and keep this as
        // the subject line, but it does surface — in a notification, in an
        // inbox row for a thread whose peer could not be resolved.
        title: `طلب ${sellerOrder.number}`,
      });
    }

    if (dto.product_id) {
      // A shared catalog entry has several sellers, so the caller must say
      // which one they want to talk to.
      const product = await this.prisma.product.findUnique({
        where: { id: dto.product_id },
        select: {
          id: true,
          title: true,
          offers: { select: { sellerId: true }, orderBy: { price: 'asc' } },
        },
      });
      if (!product) throw new NotFoundException('Product not found');
      if (product.offers.length === 0) {
        throw new BadRequestException('Nobody currently sells this product');
      }

      const sellerId = dto.seller_id ?? product.offers[0].sellerId;
      if (!product.offers.some((offer) => offer.sellerId === sellerId)) {
        throw new BadRequestException(
          'That seller does not list this product',
        );
      }

      await this.assertBuyerSellerPair(userId, sellerId);
      return this.conversationShape({
        type: ChatContextType.PRODUCT,
        buyerId: userId,
        sellerId,
        productId: product.id,
        title: product.title,
      });
    }

    const peerId = dto.participant_id ?? dto.seller_id;
    if (!peerId) {
      throw new BadRequestException('A participant, product, or order is required');
    }
    const [me, peer] = await Promise.all([
      this.prisma.user.findUnique({ where: { id: userId } }),
      this.prisma.user.findUnique({ where: { id: peerId } }),
    ]);
    if (!me || !peer) throw new NotFoundException('Participant not found');
    const { buyerId, sellerId } = this.resolveBuyerSellerPair(me, peer);
    // Always DIRECT. A `type` of PRODUCT or ORDER with no product or parcel
    // behind it was taken at its word, and the lookup that reuses threads —
    // which skips an `undefined` column — then matched *any* product chat
    // between the two and opened that one instead.
    return this.conversationShape({
      type: ChatContextType.DIRECT,
      buyerId,
      sellerId,
    });
  }

  private resolveBuyerSellerPair(
    me: { id: string; role: UserRole },
    peer: { id: string; role: UserRole },
  ) {
    if (me.id === peer.id) {
      throw new BadRequestException('You cannot start a chat with yourself');
    }
    if (me.role === UserRole.CUSTOMER && peer.role === UserRole.SELLER) {
      return { buyerId: me.id, sellerId: peer.id };
    }
    if (me.role === UserRole.SELLER && peer.role === UserRole.CUSTOMER) {
      return { buyerId: peer.id, sellerId: me.id };
    }
    throw new ForbiddenException('Chats are only available between buyers and sellers');
  }

  private async assertBuyerSellerPair(buyerId: string, sellerId: string) {
    if (buyerId === sellerId) {
      throw new BadRequestException('Buyer and seller must be different users');
    }
    const [buyer, seller] = await Promise.all([
      this.prisma.user.findUnique({
        where: { id: buyerId },
        select: { id: true, role: true },
      }),
      this.prisma.user.findUnique({
        where: { id: sellerId },
        select: { id: true, role: true },
      }),
    ]);
    if (!buyer || !seller) {
      throw new NotFoundException('Chat participant not found');
    }
    if (buyer.role !== UserRole.CUSTOMER || seller.role !== UserRole.SELLER) {
      throw new ForbiddenException('Chats are only available between buyers and sellers');
    }
  }

  private conversationShape(input: {
    type: ChatContextType;
    buyerId: string;
    sellerId: string;
    productId?: string;
    sellerOrderId?: string;
    title?: string;
  }) {
    const participants = [
      { userId: input.buyerId, role: ChatParticipantRole.BUYER },
      { userId: input.sellerId, role: ChatParticipantRole.SELLER },
    ].filter(
      (participant, index, list) =>
        list.findIndex((item) => item.userId === participant.userId) === index,
    );
    return {
      ...input,
      participants,
      participantIds: participants.map((participant) => participant.userId),
    };
  }

  /**
   * Unread counts for a whole inbox, in one query.
   *
   * The list used to call `unreadCount` per thread, and that helper issues two
   * queries of its own — so opening the inbox cost `1 + 2N`, fired
   * concurrently at the connection pool. A seller with three hundred
   * conversations opened six hundred queries to draw one screen, and the
   * participant lookup inside each was redundant: `threads()` had just loaded
   * that very row.
   *
   * Raw SQL rather than Prisma because the cutoff is per-chat — every
   * conversation compares against its own `last_read_at` — which a `groupBy`
   * cannot express. Chats with nothing unread simply do not come back, which
   * is why the caller defaults to zero.
   */
  private async unreadCounts(
    userId: string,
    chatIds: string[],
  ): Promise<Map<string, number>> {
    if (chatIds.length === 0) return new Map();

    const rows = await this.prisma.$queryRaw<
      { chat_id: string; unread: bigint }[]
    >`
      SELECT m.chat_id, COUNT(*) AS unread
      FROM messages m
      JOIN chat_participants p
        ON p.chat_id = m.chat_id
       AND p.user_id = ${userId}::uuid
      WHERE m.chat_id = ANY(${chatIds}::uuid[])
        AND m.sender_id <> ${userId}::uuid
        AND m.deleted_at IS NULL
        AND (p.last_read_at IS NULL OR m.created_at > p.last_read_at)
      GROUP BY m.chat_id
    `;

    return new Map(rows.map((row) => [row.chat_id, Number(row.unread)]));
  }

  private async unreadCount(chatId: string, userId: string) {
    const participant = await this.prisma.chatParticipant.findUnique({
      where: { chatId_userId: { chatId, userId } },
      select: { lastReadAt: true },
    });
    return this.prisma.message.count({
      where: {
        chatId,
        senderId: { not: userId },
        deletedAt: null,
        ...(participant?.lastReadAt
          ? { createdAt: { gt: participant.lastReadAt } }
          : {}),
      },
    });
  }

  /**
   * Everything she just loaded from the other side is now on her phone.
   *
   * Only messages she has no delivery receipt for are touched: the old version
   * re-upserted a receipt for every one of the fifty messages on each fetch,
   * one query apiece, and overwrote the original delivery time while it was
   * at it.
   */
  private async markDelivered(
    chatId: string,
    userId: string,
    messages: MessageWithRelations[],
  ) {
    const pending = messages.filter(
      (message) =>
        message.senderId !== userId &&
        !(message.receipts ?? []).some(
          (receipt) => receipt.userId === userId && receipt.deliveredAt,
        ),
    );
    await this.acknowledgeDelivery(
      chatId,
      userId,
      pending.map((message) => message.id),
    );
  }

  private async assertNotBlocked(senderId: string, recipientIds: string[]) {
    if (recipientIds.length === 0) return;
    const block = await this.prisma.chatBlock.findFirst({
      where: {
        OR: [
          { blockerId: senderId, blockedId: { in: recipientIds } },
          { blockerId: { in: recipientIds }, blockedId: senderId },
        ],
      },
    });
    if (block) {
      throw new ForbiddenException('Messaging is not available for this user');
    }
  }

  private async notifyRecipients(
    chat: Awaited<ReturnType<ChatsService['assertMember']>>,
    senderId: string,
    message: MessageWithRelations,
  ) {
    const now = new Date();
    const recipients = chat.participants
      // Someone who muted the conversation still receives the message; she
      // is just not woken for it.
      .filter((participant) => !(participant.mutedUntil && participant.mutedUntil > now))
      .map((participant) => participant.userId)
      .filter((id) => id !== senderId);
    if (recipients.length === 0) return;
    try {
      const sender = await this.prisma.user.findUnique({
        where: { id: senderId },
        select: { name: true },
      });
      await this.notifications.dispatch(senderId, {
        user_ids: recipients,
        channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH],
        type: NotificationType.message,
        // Who wrote, in the title — the way every messenger on her phone
        // does it. It used to read "New message", in English, for everyone.
        title: sender?.name?.trim() || 'رسالة جديدة',
        body: notificationBody(message),
        payload: { chat_id: chat.id, message_id: message.id },
        // Somebody wrote to her. Transactional, so it is never held for quiet
        // hours and never counted against a marketing cap — a message she is
        // waiting for is not a promotion.
        category: NotificationCategory.TRANSACTIONAL,
      });
    } catch {
      // Notification transport failures should not fail chat delivery.
    }
  }
}
