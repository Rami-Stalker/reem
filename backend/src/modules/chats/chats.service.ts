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
} from '@prisma/client';
import { PrismaService } from '../../prisma/prisma.service';
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
    });

    return Promise.all(
      participations.map(async (participation) => {
        const unread = await this.unreadCount(participation.chatId, userId);
        return serializeChatThread(
          participation.chat as ChatWithRelations,
          userId,
          unread,
        );
      }),
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

  async startConversation(userId: string, dto: StartConversationDto) {
    const resolved = await this.resolveConversation(userId, dto);
    await this.assertNotBlocked(userId, resolved.participantIds);

    let chat = await this.prisma.chat.findFirst({
      where: {
        type: resolved.type,
        buyerId: resolved.buyerId,
        sellerId: resolved.sellerId,
        productId: resolved.productId,
        sellerOrderId: resolved.sellerOrderId,
      },
      include: chatInclude,
    });

    if (!chat) {
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
    }

    if (dto.message?.trim()) {
      await this.send(chat.id, userId, { content: dto.message.trim() });
      chat = await this.prisma.chat.findUniqueOrThrow({
        where: { id: chat.id },
        include: chatInclude,
      });
    }

    return serializeChatThread(chat as ChatWithRelations, userId);
  }

  async messages(chatId: string, userId: string, query: MessageQueryDto = new MessageQueryDto()) {
    await this.assertMember(chatId, userId);
    const messages = await this.prisma.message.findMany({
      where: {
        chatId,
        deletedAt: null,
        ...(query.q
          ? { content: { contains: query.q, mode: 'insensitive' } }
          : {}),
      },
      orderBy: { createdAt: 'desc' },
      skip: (query.page - 1) * query.limit,
      take: query.limit,
      include: messageInclude,
    });
    await this.markDelivered(chatId, userId, messages);
    return messages.reverse().map((message) => serializeMessage(message, userId));
  }

  async send(chatId: string, userId: string, dto: SendMessageDto) {
    const chat = await this.assertMember(chatId, userId);
    const content = dto.content?.trim() ?? '';
    const attachments = dto.attachments ?? [];
    const kind = dto.kind ?? (attachments[0]?.kind ?? MessageKind.TEXT);
    if (!content && attachments.length === 0) {
      throw new BadRequestException('Message content or attachment is required');
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

    const message = await this.prisma.message.create({
      data: {
        chatId,
        senderId: userId,
        clientId: dto.client_id,
        kind,
        content,
        metadata: dto.metadata as Prisma.InputJsonValue,
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
      data: { updatedAt: new Date() },
    });

    // The upload is now part of a conversation, so it is no longer an orphan.
    await this.media.markAttached(
      userId,
      attachments.map((attachment) => attachment.url),
    );

    await this.notifyRecipients(chat, userId, message);

    const serialized = serializeMessage(message, userId);
    this.events.emit('chat.message.created', {
      chatId,
      participantIds: chat.participants.map((participant) => participant.userId),
      senderId: userId,
      message: serialized,
    });
    return serialized;
  }

  async markRead(chatId: string, userId: string, dto: MarkReadDto = {}) {
    await this.assertMember(chatId, userId);
    const lastMessage = dto.message_id
      ? await this.prisma.message.findFirst({
          where: { id: dto.message_id, chatId },
          select: { id: true, createdAt: true },
        })
      : await this.prisma.message.findFirst({
          where: { chatId },
          orderBy: { createdAt: 'desc' },
          select: { id: true, createdAt: true },
        });
    if (!lastMessage) return { read: 0 };

    const messages = await this.prisma.message.findMany({
      where: {
        chatId,
        senderId: { not: userId },
        createdAt: { lte: lastMessage.createdAt },
      },
      select: { id: true },
      take: 500,
    });
    const now = new Date();
    await Promise.all(
      messages.map((message) =>
        this.prisma.messageReadReceipt.upsert({
          where: { messageId_userId: { messageId: message.id, userId } },
          create: {
            messageId: message.id,
            userId,
            deliveredAt: now,
            readAt: now,
          },
          update: { deliveredAt: now, readAt: now },
        }),
      ),
    );
    await Promise.all([
      this.prisma.message.updateMany({
        where: {
          id: { in: messages.map((message) => message.id) },
          readAt: null,
        },
        data: {
          status: MessageDeliveryStatus.READ,
          deliveredAt: now,
          readAt: now,
        },
      }),
      this.prisma.chatParticipant.update({
        where: { chatId_userId: { chatId, userId } },
        data: { lastReadMessageId: lastMessage.id, lastReadAt: now },
      }),
    ]);

    this.events.emit('chat.messages.read', {
      chatId,
      userId,
      messageId: lastMessage.id,
      readAt: now.toISOString(),
    });
    return { read: messages.length, message_id: lastMessage.id };
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
        title: `Order #${sellerOrder.number}`,
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
    return this.conversationShape({
      type: dto.type ?? ChatContextType.DIRECT,
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

  private async markDelivered(
    chatId: string,
    userId: string,
    messages: MessageWithRelations[],
  ) {
    const now = new Date();
    const deliverable = messages.filter((message) => message.senderId !== userId);
    await Promise.all(
      deliverable.map((message) =>
        this.prisma.messageReadReceipt.upsert({
          where: { messageId_userId: { messageId: message.id, userId } },
          create: { messageId: message.id, userId, deliveredAt: now },
          update: { deliveredAt: now },
        }),
      ),
    );
    await this.prisma.message.updateMany({
      where: {
        chatId,
        id: { in: deliverable.map((message) => message.id) },
        status: MessageDeliveryStatus.SENT,
      },
      data: { status: MessageDeliveryStatus.DELIVERED, deliveredAt: now },
    });
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
    const recipients = chat.participants
      .map((participant) => participant.userId)
      .filter((id) => id !== senderId);
    if (recipients.length === 0) return;
    try {
      await this.notifications.dispatch(senderId, {
        user_ids: recipients,
        channels: [NotificationChannel.IN_APP, NotificationChannel.PUSH],
        type: NotificationType.message,
        title: 'New message',
        body:
          message.kind === MessageKind.TEXT
            ? message.content.slice(0, 160)
            : message.kind === MessageKind.IMAGE
              ? 'Image shared'
              : 'Voice message shared',
        payload: { chat_id: chat.id, message_id: message.id },
      });
    } catch {
      // Notification transport failures should not fail chat delivery.
    }
  }
}
