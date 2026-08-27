import {
  Chat,
  ChatParticipant,
  Message,
  MessageAttachment,
  MessageReadReceipt,
  User,
  UserPresence,
} from '@prisma/client';

type ParticipantWithUser = ChatParticipant & {
  user: User & { presence?: UserPresence | null };
};

export type ChatWithRelations = Chat & {
  participants: ParticipantWithUser[];
  messages: MessageWithRelations[];
};

export type MessageWithRelations = Message & {
  attachments?: MessageAttachment[];
  receipts?: MessageReadReceipt[];
};

export function serializeChatThread(
  chat: ChatWithRelations,
  currentUserId: string,
  unreadCount = 0,
) {
  const other = chat.participants.find((p) => p.userId !== currentUserId);
  const otherUser = other?.user;
  const lastMessage = chat.messages[0];
  const title =
    chat.title ??
    otherUser?.name ??
    (chat.type === 'ORDER' ? 'Order conversation' : 'Chat');

  return {
    id: chat.id,
    type: chat.type.toLowerCase(),
    title,
    avatar_url: otherUser?.imageUrl ?? '',
    participant_ids: chat.participants.map((p) => p.userId),
    buyer_id: chat.buyerId,
    seller_id: chat.sellerId,
    product_id: chat.productId,
    seller_order_id: chat.sellerOrderId,
    last_message: lastMessage ? messagePreview(lastMessage) : '',
    unread_count: unreadCount,
    updated_at: (lastMessage?.createdAt ?? chat.updatedAt).toISOString(),
    online: otherUser?.presence?.status === 'ONLINE',
    last_seen_at: otherUser?.presence?.lastSeenAt?.toISOString() ?? null,
  };
}

export function serializeMessage(
  message: MessageWithRelations,
  currentUserId: string,
) {
  return {
    id: message.id,
    chat_id: message.chatId,
    sender_id: message.senderId,
    client_id: message.clientId,
    kind: message.kind.toLowerCase(),
    content: message.content,
    metadata: message.metadata ?? null,
    status: message.status.toLowerCase(),
    delivered_at: message.deliveredAt?.toISOString() ?? null,
    read_at: message.readAt?.toISOString() ?? null,
    sent_at: message.createdAt.toISOString(),
    created_at: message.createdAt.toISOString(),
    edited_at: message.editedAt?.toISOString() ?? null,
    deleted_at: message.deletedAt?.toISOString() ?? null,
    is_mine: message.senderId === currentUserId,
    attachments: (message.attachments ?? []).map((attachment) => ({
      id: attachment.id,
      kind: attachment.kind.toLowerCase(),
      url: attachment.url,
      mime_type: attachment.mimeType,
      file_name: attachment.fileName,
      size_bytes: attachment.sizeBytes,
      width: attachment.width,
      height: attachment.height,
      duration_ms: attachment.durationMs,
      metadata: attachment.metadata ?? null,
    })),
    receipts: (message.receipts ?? []).map((receipt) => ({
      user_id: receipt.userId,
      delivered_at: receipt.deliveredAt?.toISOString() ?? null,
      read_at: receipt.readAt?.toISOString() ?? null,
    })),
  };
}

function messagePreview(message: MessageWithRelations) {
  if (message.deletedAt) return 'Message deleted';
  if (message.kind === 'IMAGE') return message.content || 'Image';
  if (message.kind === 'VOICE') return message.content || 'Voice message';
  return message.content;
}
