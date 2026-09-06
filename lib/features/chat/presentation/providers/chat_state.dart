import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';

class ChatState {
  const ChatState({
    this.threads = const [],
    this.isLoading = false,
    this.hasLoadedOnce = false,
    this.query = '',
    this.error,
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
  }) {
    return ChatState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
      hasLoadedOnce: hasLoadedOnce ?? this.hasLoadedOnce,
      query: query ?? this.query,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ChatMessagesState {
  const ChatMessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.isPeerTyping = false,
    this.error,
    this.chatId,
  });

  final List<ChatMessageEntity> messages;
  final bool isLoading;
  final bool isSending;
  final bool isPeerTyping;
  final String? error;
  final String? chatId;

  ChatMessagesState copyWith({
    List<ChatMessageEntity>? messages,
    bool? isLoading,
    bool? isSending,
    bool? isPeerTyping,
    String? error,
    String? chatId,
    bool clearError = false,
    bool clearMessages = false,
  }) {
    return ChatMessagesState(
      messages: clearMessages ? const [] : (messages ?? this.messages),
      isLoading: isLoading ?? this.isLoading,
      isSending: isSending ?? this.isSending,
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
