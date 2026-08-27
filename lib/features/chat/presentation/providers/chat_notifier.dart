import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/chat/data/models/chat_message_model.dart';
import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:reem/features/chat/domain/usecases/get_threads_usecase.dart';
import 'package:reem/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:reem/features/chat/presentation/providers/chat_state.dart';

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
    return send(
      content: content,
      kind: 'TEXT',
    );
  }

  Future<bool> send({
    required String content,
    String kind = 'TEXT',
    List<Map<String, dynamic>> attachments = const [],
  }) async {
    final chatId = state.chatId;
    if (chatId == null ||
        chatId.isEmpty ||
        (content.trim().isEmpty && attachments.isEmpty)) {
      return false;
    }

    state = state.copyWith(isSending: true, clearError: true);
    final result = await _sendMessage(
      chatId: chatId,
      content: content.trim(),
      kind: kind,
      attachments: attachments,
    );
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(
            isSending: false,
            messages: _merge(data),
          );
          return true;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(isSending: false, error: failure.message);
          return false;
        }(),
    };
  }

  void applyRealtime(Map<String, dynamic> event) {
    final eventName = event['event'];
    if (eventName == 'message.created') {
      final raw = event['message'];
      if (raw is! Map) return;
      final message = ChatMessageModel.fromJson(Map<String, dynamic>.from(raw));
      if (message.chatId != state.chatId) return;
      state = state.copyWith(messages: _merge(message), isPeerTyping: false);
      return;
    }
    if (eventName == 'typing' && event['chat_id'] == state.chatId) {
      state = state.copyWith(isPeerTyping: event['is_typing'] == true);
      return;
    }
    if (eventName == 'messages.read' && event['chat_id'] == state.chatId) {
      state = state.copyWith(
        messages: state.messages
            .map(
              (message) => message.isMine
                  ? ChatMessageModel(
                      id: message.id,
                      chatId: message.chatId,
                      senderId: message.senderId,
                      content: message.content,
                      sentAt: message.sentAt,
                      isMine: message.isMine,
                      kind: message.kind,
                      status: 'read',
                      attachments: message.attachments,
                      deliveredAt: message.deliveredAt,
                      readAt: DateTime.tryParse(
                        event['read_at'] as String? ?? '',
                      ),
                    )
                  : message,
            )
            .toList(),
      );
    }
  }

  List<ChatMessageEntity> _merge(ChatMessageEntity message) {
    final existing = state.messages.where((item) => item.id != message.id);
    return [...existing, message]..sort((a, b) => a.sentAt.compareTo(b.sentAt));
  }
}
