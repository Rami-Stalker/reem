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
    (chat.type === 'ORDER' ? 'محادثة طلب' : 'محادثة');

  return {
    id: chat.id,
    type: chat.type.toLowerCase(),
    title,
    avatar_url: otherUser?.imageUrl ?? '',
    // The person on the other side, named outright. The client needs an id to
    // block or report them, and a name for the conversation header; deriving
    // it from `participant_ids` would mean the client re-implementing the
    // "whoever is not me" rule this function already applied.
    peer_id: otherUser?.id ?? null,
    peer_name: otherUser?.name ?? null,
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
  // «حُذفت عند الجميع» — the row stays so the conversation keeps its shape,
  // but nothing of what was said travels any more.
  const deleted = message.deletedAt !== null && message.deletedAt !== undefined;
  return {
    id: message.id,
    chat_id: message.chatId,
    sender_id: message.senderId,
    client_id: message.clientId,
    kind: deleted ? 'text' : message.kind.toLowerCase(),
    content: deleted ? '' : message.content,
    metadata: deleted ? null : (message.metadata ?? null),
    status: message.status.toLowerCase(),
    delivered_at: message.deliveredAt?.toISOString() ?? null,
    read_at: message.readAt?.toISOString() ?? null,
    sent_at: message.createdAt.toISOString(),
    created_at: message.createdAt.toISOString(),
    edited_at: message.editedAt?.toISOString() ?? null,
    deleted_at: message.deletedAt?.toISOString() ?? null,
    is_mine: message.senderId === currentUserId,
    attachments: (deleted ? [] : (message.attachments ?? [])).map((attachment) => ({
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

/**
 * The inbox line under a name. Arabic, like the rest of what she reads, and a
 * document now says it is one — a FILE message used to preview as its content,
 * which for a file sent without a caption was nothing at all.
 */
function messagePreview(message: MessageWithRelations) {
  if (message.deletedAt) return 'رسالة محذوفة';
  if (message.kind === 'IMAGE') return message.content || 'صورة';
  if (message.kind === 'VOICE') return message.content || 'رسالة صوتية';
  if (message.kind === 'FILE') {
    return message.content || message.attachments?.[0]?.fileName || 'ملف';
  }
  return message.content;
}
