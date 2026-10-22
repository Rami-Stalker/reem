import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';

class ChatState {
  const ChatState({
    this.threads = const [],
    this.isLoading = false,
    this.hasLoadedOnce = false,
    this.query = '',
    this.error,
    this.typingChatIds = const {},
  });

  final List<ChatThreadEntity> threads;
  final bool isLoading;

  /// Separates "still loading the first page" from "loaded, and there is
  /// nothing here" — the two need very different screens.
  final bool hasLoadedOnce;

  /// The search term the current [threads] answer. Held in state so a result
  /// arriving after she has cleared the box can be recognised and dropped.
  final String query;
  final String? error;

  /// Conversations whose other side is typing right now. Live from the
  /// socket; it never survives a reload and is never sent by the server.
  final Set<String> typingChatIds;

  bool get isSearching => query.trim().isNotEmpty;
  bool get isEmpty => threads.isEmpty;

  /// Unread across every conversation — what a badge on the inbox shows.
  int get totalUnread =>
      threads.fold(0, (sum, thread) => sum + thread.unreadCount);

  ChatState copyWith({
    List<ChatThreadEntity>? threads,
    bool? isLoading,
    bool? hasLoadedOnce,
    String? query,
    String? error,
    bool clearError = false,
    Set<String>? typingChatIds,
  }) {
    return ChatState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      query: query ?? this.query,
      error: clearError ? null : (error ?? this.error),
      typingChatIds: typingChatIds ?? this.typingChatIds,
    );
  }
}

class ChatMessagesState {
  const ChatMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isLoadingOlder = false,
    this.hasMore = false,
    this.isPeerTyping = false,
    this.error,
    this.chatId,
  });

  /// Oldest first, her unsent messages included.
  final List<ChatMessageEntity> messages;
  final bool isLoading;

  /// An older page is on its way, drawn as a small spinner at the top.
  final bool isLoadingOlder;

  /// The server may hold messages older than the oldest one here.
  final bool hasMore;
  final bool isPeerTyping;

  /// Why the conversation could not be *loaded*. A message that fails to send
  /// is not this: it stays in the list, marked, with a way to try again — a
  /// refused send used to replace the whole conversation with an error text.
  final String? error;
  final String? chatId;

  ChatMessagesState copyWith({
    List<ChatMessageEntity>? messages,
    bool? isLoading,
    bool? isLoadingOlder,
    bool? hasMore,
    bool? isPeerTyping,
    String? error,
    String? chatId,
    bool clearError = false,
    bool clearMessages = false,
  }) {
    return ChatMessagesState(
      messages: clearMessages ? const [] : (messages ?? this.messages),
      isLoading: isLoading ?? this.isLoading,
      isLoadingOlder: isLoadingOlder ?? this.isLoadingOlder,
      hasMore: hasMore ?? this.hasMore,
      isPeerTyping: isPeerTyping ?? this.isPeerTyping,
      error: clearError ? null : (error ?? this.error),
      chatId: chatId ?? this.chatId,
    );
  }
}

/// One conversation's header. Its [error] is deliberately non-fatal: the
/// messages load on their own, so a failure here costs a name, not the screen.
class ChatThreadState {
  const ChatThreadState({this.thread, this.isLoading = false, this.error});

  final ChatThreadEntity? thread;
  final bool isLoading;
  final String? error;
}
