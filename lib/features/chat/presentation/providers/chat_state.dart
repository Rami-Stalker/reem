import '../../domain/entities/chat_message_entity.dart';
import '../../domain/entities/chat_thread_entity.dart';

class ChatState {
  const ChatState({
    this.threads = const [],
    this.isLoading = false,
    this.error,
  });

  final List<ChatThreadEntity> threads;
  final bool isLoading;
  final String? error;

  ChatState copyWith({
    List<ChatThreadEntity>? threads,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ChatState(
      threads: threads ?? this.threads,
      isLoading: isLoading ?? this.isLoading,
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
