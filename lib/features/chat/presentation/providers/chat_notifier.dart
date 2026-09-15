import 'dart:async';

import 'package:flutter_riverpod/legacy.dart';
import 'package:reem/core/result/result.dart';

import 'package:reem/features/chat/data/models/chat_message_model.dart';
import 'package:reem/features/chat/domain/entities/chat_message_entity.dart';
import 'package:reem/features/chat/domain/entities/chat_start_request.dart';
import 'package:reem/features/chat/domain/entities/chat_thread_entity.dart';
import 'package:reem/features/chat/domain/usecases/get_messages_usecase.dart';
import 'package:reem/features/chat/domain/usecases/get_thread_usecase.dart';
import 'package:reem/features/chat/domain/usecases/get_threads_usecase.dart';
import 'package:reem/features/chat/domain/usecases/send_message_usecase.dart';
import 'package:reem/features/chat/domain/usecases/start_conversation_usecase.dart';
import 'package:reem/features/chat/presentation/providers/chat_state.dart';

class ChatNotifier extends StateNotifier<ChatState> {
  ChatNotifier({
    required GetThreadsUseCase getThreadsUseCase,
    required StartConversationUseCase startConversationUseCase,
  })  : _getThreads = getThreadsUseCase,
        _startConversation = startConversationUseCase,
        super(const ChatState());

  final GetThreadsUseCase _getThreads;
  final StartConversationUseCase _startConversation;

  Timer? _debounce;

  /// Rises with every search, so a slow reply to an abandoned term cannot
  /// overwrite the results of a newer one.
  int _requestId = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> load() => _fetch(state.query);

  /// Pull-to-refresh and the return from a conversation. Keeps the rows on
  /// screen while it runs — blanking a list she is looking at reads as a bug.
  Future<void> refresh() => _fetch(state.query, silent: true);

  /// Typed into the search field. Debounced, because every keystroke would
  /// otherwise be a round trip.
  void search(String term) {
    if (term == state.query) return;
    state = state.copyWith(query: term);
    _debounce?.cancel();
    if (term.trim().isEmpty) {
      // Clearing the box should feel instant; there is nothing to wait for.
      unawaited(_fetch(term));
      return;
    }
    _debounce = Timer(
      const Duration(milliseconds: 320),
      () => unawaited(_fetch(term)),
    );
  }

  Future<void> _fetch(String term, {bool silent = false}) async {
    final requestId = ++_requestId;
    if (!silent) state = state.copyWith(isLoading: true, clearError: true);
    final result = await _getThreads(query: term);
    // She moved on: a newer search is already in flight, or the notifier is
    // gone entirely.
    if (!mounted || requestId != _requestId) return;
    state = switch (result) {
      Success(:final data) => state.copyWith(
          isLoading: false,
          hasLoadedOnce: true,
          threads: data,
          clearError: true,
        ),
      Error(:final failure) => state.copyWith(
          isLoading: false,
          hasLoadedOnce: true,
          error: failure.message,
        ),
    };
  }

  /// Opens the conversation [request] describes and returns it, or null with
  /// [ChatState.error] set when the server refused. The list is refreshed on
  /// success so a brand-new thread is already there when she comes back.
  Future<ChatThreadEntity?> startConversation(ChatStartRequest request) async {
    state = state.copyWith(clearError: true);
    final result = await _startConversation(request);
    if (!mounted) return null;
    return switch (result) {
      Success(:final data) => () {
          state = state.copyWith(threads: _upsert(data));
          return data;
        }(),
      Error(:final failure) => () {
          state = state.copyWith(error: failure.message);
          return null;
        }(),
    };
  }

  /// Puts a thread at the top of the list, replacing any older copy of it.
  List<ChatThreadEntity> _upsert(ChatThreadEntity thread) {
    return [
      thread,
      ...state.threads.where((existing) => existing.id != thread.id),
    ];
  }
}

/// The header of one conversation — who she is talking to.
///
/// Separate from the message list because it survives on its own: the details
/// screen can be opened by deep link, with no list ever having been loaded.
class ChatThreadNotifier extends StateNotifier<ChatThreadState> {
  ChatThreadNotifier({required GetThreadUseCase getThreadUseCase})
      : _getThread = getThreadUseCase,
        super(const ChatThreadState());

  final GetThreadUseCase _getThread;

  Future<void> load(String chatId) async {
    if (chatId.isEmpty) return;
    state = const ChatThreadState(isLoading: true);
    final result = await _getThread(chatId);
    if (!mounted) return;
    state = switch (result) {
      Success(:final data) => ChatThreadState(thread: data),
      // A header that cannot be loaded degrades to a nameless one; the
      // conversation itself is still perfectly usable.
      Error(:final failure) => ChatThreadState(error: failure.message),
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

  /// Fetches the conversation again without clearing it — after the socket
  /// reconnects, for whatever arrived while it was down. A failure keeps what
  /// is on screen; the next event or visit corrects it.
  Future<void> resync() async {
    final chatId = state.chatId;
    if (chatId == null || chatId.isEmpty) return;
    final result = await _getMessages(chatId);
    if (!mounted || state.chatId != chatId) return;
    if (result case Success(:final data)) {
      state = state.copyWith(messages: data);
    }
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
