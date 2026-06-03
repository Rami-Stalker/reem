import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import '../../domain/usecases/get_messages_usecase.dart';
import '../../domain/usecases/get_threads_usecase.dart';
import '../../domain/usecases/send_message_usecase.dart';
import 'chat_state.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier({required GetThreadsUseCase getThreadsUseCase})
      : _getThreads = getThreadsUseCase,
        super(const ChatState());

  final GetThreadsUseCase _getThreads;

  Future<void> load() async {
    state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getThreads();
    state = switch (result) {
      Success(:final data) =>
        state.copyWith(isLoading: false, threads: data),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message),
    };
  }
}

class ChatMessagesNotifier extends StateNotifier<ChatMessagesState> {
  ChatMessagesNotifier({
    required GetMessagesUseCase getMessagesUseCase,
    required SendMessageUseCase sendMessageUseCase,
  })  : _getMessages = getMessagesUseCase,
        _sendMessage = sendMessageUseCase,
        super(const ChatMessagesState());

  final GetMessagesUseCase _getMessages;
  final SendMessageUseCase _sendMessage;

  Future<void> load(String chatId) async {
    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearMessages: true,
      chatId: chatId,
    );
    final result = await _getMessages(chatId);
    state = switch (result) {
      Success(:final data) =>
        state.copyWith(isLoading: false, messages: data, chatId: chatId),
      Error(:final failure) =>
        state.copyWith(isLoading: false, error: failure.message, chatId: chatId),
    };
  }

  Future<bool> sendMessage(String content) async {
    final chatId = state.chatId;
    if (chatId == null || chatId.isEmpty || content.trim().isEmpty) {
      return false;
    }

    state = state.copyWith(isSending: true, clearError: true);
    final result = await _sendMessage(chatId: chatId, content: content.trim());
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(
            isSending: false,
            messages: [...state.messages, data],
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isSending: false, error: failure.message);
          return false;
        }(),
    };
  }
}
